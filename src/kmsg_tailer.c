#include <err.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#define KMSG_PATH "/proc/kmsg"
#define BUFFER_SIZE 4096

static char buffer[BUFFER_SIZE];

int main(int argc, char *argv[])
{
    int fd = open(KMSG_PATH, O_RDONLY);
    if (fd < 0)
        err(EXIT_FAILURE, "open %s", KMSG_PATH);

    for (;;) {
        ssize_t amt = read(fd, buffer, sizeof(buffer));
        if (amt < 0)
            err(EXIT_FAILURE, "%s: read", argv[1]);

        if (write(STDOUT_FILENO, buffer, amt) < 0)
            err(EXIT_FAILURE, "%s: write", argv[1]);
    }
}
