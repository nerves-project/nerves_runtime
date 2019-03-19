#include <err.h>
#include <string.h>
#include <stdlib.h>

int uevent_main(int argc, char *argv[]);
int uevent_discover_main(int argc, char *argv[]);
int kmsg_tailer_main(int argc, char *argv[]);

int main(int argc, char *argv[])
{
    if (strcmp(argv[0], "uevent") == 0)
        return uevent_main(argc, argv);
    else if (strcmp(argv[0], "kmsg_tailer") == 0)
        return kmsg_tailer_main(argc, argv);
    else if (strcmp(argv[0], "uevent_discover") == 0)
        return uevent_discover_main(argc, argv);
    else
        errx(EXIT_FAILURE, "Unexpected name: %s", argv[0]);
}
