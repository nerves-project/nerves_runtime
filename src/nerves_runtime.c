#include <err.h>
#include <string.h>
#include <stdlib.h>

int uevent_main(int argc, char *argv[]);
int kmsg_tailer_main(int argc, char *argv[]);

int main(int argc, char *argv[])
{
    const char *name = strrchr(argv[0], '/');
    if (name)
        name++;
    else
        name = argv[0];

    if (strcmp(name, "uevent") == 0)
        return uevent_main(argc, argv);
    else if (strcmp(name, "kmsg_tailer") == 0)
        return kmsg_tailer_main(argc, argv);
    else
        errx(EXIT_FAILURE, "Unexpected name: %s", argv[0]);
}
