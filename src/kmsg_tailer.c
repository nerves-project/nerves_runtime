#include <err.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/sendfile.h>
#include <unistd.h>

#define KMSG_PATH "/proc/kmsg"
#define BUFFER_SIZE 4096

int kmsg_tailer_main(int argc, char *argv[])
{
    int fd = open(KMSG_PATH, O_RDONLY);
    if (fd < 0)
        err(EXIT_FAILURE, "open %s", KMSG_PATH);

    for (;;) {
        ssize_t amt = sendfile(STDOUT_FILENO, fd, NULL, BUFFER_SIZE);
        if (amt < 0)
            err(EXIT_FAILURE, "sendfile %s->stdout", KMSG_PATH);
    }
}
