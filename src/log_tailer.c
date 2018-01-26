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

int main(int argc, char *argv[]) {
    if (argc != 2)
        err(EXIT_FAILURE, "Usage: %s type\n  type must be either syslog or kmsg", argv[0]);

    int fd = 0;

    if (strcasecmp(argv[1], "syslog")) {
        fd = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (fd < 0)
            err(EXIT_FAILURE, "failed to create syslog socket");

        // Erase the old log file (if any) so that we can bind to it
        unlink(SYSLOG_PATH);

        struct sockaddr_un addr;
        memset(&addr, 0, sizeof(addr));
        addr.sun_family = AF_UNIX;
        strcpy(addr.sun_path, SYSLOG_PATH);

        if (bind(fd, (struct sockaddr *) &addr, sizeof(addr)) < 0)
            err(EXIT_FAILURE, "failed to bind");

        // Make the syslog file writable
        chmod(SYSLOG_PATH, 0666);
    } else if (strcasecmp(argv[1], "kmsg")) {
        fd = open(KMSG_PATH, O_RDONLY);
        if (fd < 0)
            err(EXIT_FAILURE, "failed to open");
    } else {
        err(EXIT_FAILURE, "Usage: %s type\n  type must be either syslog or kmsg", argv[0]);
    }

    for (;;) {
        ssize_t amt = read(fd, buffer, sizeof(buffer));
        if (amt < 0)
            err(EXIT_FAILURE, "failed to read");

        write(STDOUT_FILENO, &buffer, amt);
    }
}
