#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#define KMSG_PATH "/dev/kmsg"
#define BUFFER_SIZE 4096

static void handle_kmsg(int fd)
{
    char buffer[BUFFER_SIZE];
    ssize_t amt = read(fd, buffer, sizeof(buffer));
    if (amt < 0 && errno != EINTR)
        err(EXIT_FAILURE, "read %s", KMSG_PATH);

    while (amt > 0) {
        ssize_t written = write(STDOUT_FILENO, buffer, amt);
        if (written < 0 && errno != EINTR)
            err(EXIT_FAILURE, "write stdout");
        amt -= written;
    }
}

int kmsg_tailer_main(int argc, char *argv[])
{
    (void) argc;
    (void) argv;

    int fd = open(KMSG_PATH, O_RDONLY);
    if (fd < 0)
        err(EXIT_FAILURE, "open %s", KMSG_PATH);

    for (;;) {
        struct pollfd fdset[2];

        fdset[0].fd = fd;
        fdset[0].events = POLLIN;
        fdset[0].revents = 0;

        fdset[1].fd = STDIN_FILENO;
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
            handle_kmsg(fd);

        // Any notification from Erlang is to exit
        if (fdset[1].revents & (POLLIN | POLLHUP))
            break;
    }

    return 0;
}

