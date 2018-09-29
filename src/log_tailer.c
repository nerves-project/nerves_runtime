#include <err.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define KMSG_PATH "/proc/kmsg"
#define BUFFER_SIZE 1024

static char buffer[BUFFER_SIZE];

static void usage()
{
    errx(EXIT_FAILURE, "Specify kmsg as the parameter");
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
    if (strcmp(argv[1], "kmsg") == 0)
        fd = open_klog();
    else
        usage();

    for (;;) {
        ssize_t amt = read(fd, buffer, sizeof(buffer) - 1);
        if (amt < 0)
            err(EXIT_FAILURE, "%s: read", argv[1]);

        if (amt > 0) {
            // Tack on a newline if one wasn't included
            if (buffer[amt - 1] != '\n')
                buffer[amt++] = '\n';

            if (write(STDOUT_FILENO, &buffer, amt) < 0)
                err(EXIT_FAILURE, "%s: write", argv[1]);
        }
    }
}
