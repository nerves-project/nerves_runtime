#include <err.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>
#include <arpa/inet.h>

#define KMSG_PATH "/proc/kmsg"
#define SYSLOG_PATH "/dev/log"
#define BUFFER_SIZE 1024

static char buffer[BUFFER_SIZE];

static void usage()
{
    errx(EXIT_FAILURE, "Specify either syslog or kmsg as the parameter");
}

static int open_syslog()
{
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd < 0)
        err(EXIT_FAILURE, "socket");

    // Erase the old log file (if any) so that we can bind to it
    unlink(SYSLOG_PATH);

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, SYSLOG_PATH);

    if (bind(fd, (struct sockaddr *) &addr, sizeof(addr)) < 0)
        err(EXIT_FAILURE, "bind %s", SYSLOG_PATH);

    // Make the syslog file writable
    chmod(SYSLOG_PATH, 0666);

    return fd;
}

static int open_klog()
{
    int fd = open(KMSG_PATH, O_RDONLY);
    if (fd < 0)
        err(EXIT_FAILURE, "open %s", KMSG_PATH);
    return fd;
}

int main(int argc, char *argv[])
{
    if (argc != 2)
        usage();

    int fd = 0;
    if (strcmp(argv[1], "syslog"))
        fd = open_syslog();
    else if (strcmp(argv[1], "kmsg"))
        fd = open_klog();
    else
        usage();

    for (;;) {
        ssize_t amt = read(fd, buffer, sizeof(buffer));
        if (amt < 0)
            err(EXIT_FAILURE, "%s: read", argv[1]);

        if (write(STDOUT_FILENO, &buffer, amt) < 0)
            err(EXIT_FAILURE, "%s: write", argv[1]);
    }
}
