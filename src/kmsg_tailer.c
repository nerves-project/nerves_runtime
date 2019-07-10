#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#define KMSG_PATH "/dev/kmsg"
#define BUFFER_SIZE 4096

int kmsg_tailer_main(int argc, char *argv[])
{
    int fd = open(KMSG_PATH, O_RDONLY);
    if (fd < 0)
        err(EXIT_FAILURE, "open %s", KMSG_PATH);

    for (;;) {
        char buffer[BUFFER_SIZE];
        ssize_t amt = read(fd, buffer, sizeof(buffer));
        while (amt > 0) {
            ssize_t written = write(STDOUT_FILENO, buffer, amt);
            if (written < 0)
                err(EXIT_FAILURE, "write stdout");
            amt -= written;
        }
        if (amt < 0) {
            if (errno != EINTR)
                err(EXIT_FAILURE, "read %s", KMSG_PATH);
        }
    }
}
