#include <stdio.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>

static int filter(const struct dirent *dirp)
{
    return (dirp->d_type == DT_REG && strcmp(dirp->d_name, "uevent") == 0) ||
           (dirp->d_type == DT_DIR && dirp->d_name[0] != '.');
}

static void scandirs(char *path, int path_end)
{
    struct dirent **namelist;
    int n;

    n = scandir(path, &namelist, filter, NULL);
    if (n < 0)
        return;

    path[path_end] = '/';

    int i;
    for (i = 0; i < n; i++) {
        strcpy(&path[path_end + 1], namelist[i]->d_name);
        if (namelist[i]->d_type == DT_DIR) {
            scandirs(path, strlen(path));
        } else {
            int fd = open(path, O_WRONLY);
            if (fd >= 0) {
                write(fd, "add", 3);
                close(fd);
            }
        }
        free(namelist[i]);
    }
    free(namelist);
    path[path_end] = 0;

}

int uevent_discover_main(int argc, char **argv)
{
    char path[PATH_MAX] = "/sys/devices";
    scandirs(path, strlen(path));
}

