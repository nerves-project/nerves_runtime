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
#include "erlcmd.h"

#include <err.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <arpa/inet.h>
#include <libmnl/libmnl.h>
#include <linux/if.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>

struct netif {
    // NETLINK_ROUTE socket information
    struct mnl_socket *nl;
    int seq;

    // NETLINK_KOBJECT_UEVENT socket information
    struct mnl_socket *nl_uevent;

    // AF_INET socket for ioctls
    int inet_fd;

    // Netlink buffering
    char nlbuf[8192]; // See MNL_SOCKET_BUFFER_SIZE

    // Erlang request processing
    const char *req;
    int req_index;

    // Erlang response processing
    char resp[ERLCMD_BUF_SIZE];
    int resp_index;

    // Async response handling
    void (*response_callback)(struct netif *nb, int bytecount);
    void (*response_error_callback)(struct netif *nb, int err);
    unsigned int response_portid;
    int response_seq;

    // Holder of the most recently encounted errno.
    int last_error;
};

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
    if (mnl_socket_bind(nb->nl_uevent, (1<<0), MNL_SOCKET_AUTOPID) < 0)
        err(EXIT_FAILURE, "mnl_socket_bind");

    nb->inet_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (nb->inet_fd < 0)
        err(EXIT_FAILURE, "socket");

    nb->seq = 1;
}

static void netif_cleanup(struct netif *nb)
{
    mnl_socket_close(nb->nl);
    mnl_socket_close(nb->nl_uevent);
    nb->nl = NULL;
}

static void uevent_request_handler(const char *req, void *cookie)
{

}

static void nl_uevent_process(struct netif *nb)
{
  int bytecount = mnl_socket_recvfrom(nb->nl_uevent, nb->nlbuf, sizeof(nb->nlbuf));
  if (bytecount <= 0)
      err(EXIT_FAILURE, "mnl_socket_recvfrom");

  const char *str = nb->nlbuf;
  debug("UEvent: %s", str);
  nb->resp_index = sizeof(uint16_t); // Skip over payload size
  nb->resp[nb->resp_index++] = 'n';
  ei_encode_version(nb->resp, &nb->resp_index);
  ei_encode_tuple_header(nb->resp, &nb->resp_index, 3);
  ei_encode_atom(nb->resp, &nb->resp_index, "uevent");
  ei_encode_string(nb->resp, &nb->resp_index, str);

  const char *str_end = str + bytecount;
  str += strlen(str) + 1;

  for (;str < str_end; str += strlen(str) + 1) {
    debug("String: %s", str);
    ei_encode_list_header(nb->resp, &nb->resp_index, 1);
    ei_encode_binary(nb->resp, &nb->resp_index, str, strlen(str));
  }
  ei_encode_empty_list(nb->resp, &nb->resp_index);
  erlcmd_send(nb->resp, nb->resp_index);
}

int main(int argc, char *argv[])
{
  debug("UEvent Main");
    (void) argc;
    (void) argv;

    struct netif nb;
    netif_init(&nb);

    struct erlcmd handler;
    erlcmd_init(&handler, uevent_request_handler, &nb);

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

        if (fdset[0].revents & (POLLIN | POLLHUP))
            erlcmd_process(&handler);
        if (fdset[1].revents & (POLLIN | POLLHUP))
            nl_uevent_process(&nb);
    }

    netif_cleanup(&nb);
    return 0;
}
