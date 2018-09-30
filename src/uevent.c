/*
 *  Copyright 2016 Nerves
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "utils.h"
#include <ctype.h>
#include <err.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <libmnl/libmnl.h>
#include <linux/rtnetlink.h>

#include <ei.h>

struct netif {
    // NETLINK_ROUTE socket information
    struct mnl_socket *nl;

    // NETLINK_KOBJECT_UEVENT socket information
    struct mnl_socket *nl_uevent;

    // Netlink buffering
    char nlbuf[8192]; // See MNL_SOCKET_BUFFER_SIZE

    // Erlang response processing
    char resp[8192];
    int resp_index;
};

/**
 * @brief Synchronously send a response back to Erlang
 *
 * @param response what to send back
 */
static void erlcmd_send(char *response, size_t len)
{
    uint16_t be_len = htons(len - sizeof(uint16_t));
    memcpy(response, &be_len, sizeof(be_len));

    size_t wrote = 0;
    do {
        ssize_t amount_written = write(STDOUT_FILENO, response + wrote, len - wrote);
        if (amount_written < 0) {
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "write");
        }

        wrote += amount_written;
    } while (wrote < len);
}

static void netif_init(struct netif *nb)
{
    memset(nb, 0, sizeof(*nb));
    nb->nl = mnl_socket_open(NETLINK_ROUTE);
    if (!nb->nl)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_ROUTE)");

    if (mnl_socket_bind(nb->nl, RTMGRP_LINK, MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");

    nb->nl_uevent = mnl_socket_open(NETLINK_KOBJECT_UEVENT);
    if (!nb->nl_uevent)
        err(EXIT_FAILURE, "mnl_socket_open (NETLINK_KOBJECT_UEVENT)");

    // There is one single group in kobject over netlink
    if (mnl_socket_bind(nb->nl_uevent, (1 << 0), MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");
}

static void netif_cleanup(struct netif *nb)
{
    mnl_socket_close(nb->nl);
    mnl_socket_close(nb->nl_uevent);
    nb->nl = NULL;
}

static void str_tolower(char *str)
{
    for (; *str; str++)
        *str = tolower(*str);
}

static int ei_encode_elixir_string(char *buf, int *index, const char *p)
{
    size_t len = strlen(p);
    return ei_encode_binary(buf, index, p, len);
}

static void nl_uevent_process(struct netif *nb)
{
    int bytecount = mnl_socket_recvfrom(nb->nl_uevent, nb->nlbuf, sizeof(nb->nlbuf));
    if (bytecount <= 0)
        err(EXIT_FAILURE, "mnl_socket_recvfrom");

    char *str = nb->nlbuf;
    char *str_end = str + bytecount;

    debug("uevent: %s", str);
    nb->resp_index = sizeof(uint16_t); // Skip over payload size
    ei_encode_version(nb->resp, &nb->resp_index);

    // The uevent comes in with the form:
    //
    // "action@devpath\0ACTION=action\0DEVPATH=devpath\0KEY=value\0"
    //
    // Construct the tuple for Elixir:
    //   {action, devpath, kv_map}
    //
    // The kv_map contains all of the kv pairs in the uevent except
    // ACTION, DEVPATH, and SEQNUM.

    ei_encode_tuple_header(nb->resp, &nb->resp_index, 3);

    char *atsign = strchr(str, '@');
    if (!atsign)
        return;
    *atsign = '\0';

    // action
    ei_encode_elixir_string(nb->resp, &nb->resp_index, str);

    // devpath - filter anything that's not under "/devices"
    str = atsign + 1;
    if (strncmp("/devices", str, 8) != 0)
        return;
    ei_encode_elixir_string(nb->resp, &nb->resp_index, str);

    str += strlen(str) + 1;

#define MAX_KV_PAIRS 16
    int kvpairs_count = 0;
    char *keys[MAX_KV_PAIRS];
    char *values[MAX_KV_PAIRS];

    for (; str < str_end; str += strlen(str) + 1) {
        // Don't encode these keys in the map
        if (strncmp("ACTION=", str, 7) == 0 ||
                strncmp("DEVPATH=", str, 8) == 0 ||
                strncmp("SEQNUM=", str, 7) == 0)
            continue;

        char *equalsign = strchr(str, '=');
        if (!equalsign)
            continue;
        *equalsign = '\0';

        // We like lowercase keys
        str_tolower(str);
        keys[kvpairs_count] = str;
        values[kvpairs_count] = equalsign + 1;
        kvpairs_count++;
    }

    ei_encode_map_header(nb->resp, &nb->resp_index, kvpairs_count);
    for (int i = 0; i < kvpairs_count; i++) {
        ei_encode_elixir_string(nb->resp, &nb->resp_index, keys[i]);
        ei_encode_elixir_string(nb->resp, &nb->resp_index, values[i]);
    }
    erlcmd_send(nb->resp, nb->resp_index);
}

int main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;

    struct netif nb;
    netif_init(&nb);

    for (;;) {
        struct pollfd fdset[3];

        fdset[0].fd = STDIN_FILENO;
        fdset[0].events = POLLIN;
        fdset[0].revents = 0;

        fdset[1].fd = mnl_socket_get_fd(nb.nl_uevent);
        fdset[1].events = POLLIN;
        fdset[1].revents = 0;

        int rc = poll(fdset, 2, -1);
        if (rc < 0) {
            // Retry if EINTR
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "poll");
        }

        if (fdset[1].revents & (POLLIN | POLLHUP))
            nl_uevent_process(&nb);

        // Any notification from Erlang is to exit
        if (fdset[0].revents & (POLLIN | POLLHUP))
            break;
    }

    netif_cleanup(&nb);
    return 0;
}
