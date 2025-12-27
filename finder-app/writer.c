#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments: %d", argc);
        fprintf(stderr, "Usage: %s <file> <string>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *filepath = argv[1];
    const char *content = argv[2];

    syslog(LOG_DEBUG, "Writing %s to %s", content, filepath);

    FILE *file = fopen(filepath, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "Failed to open file %s: %s", filepath, strerror(errno));
        perror("fopen");
        closelog();
        return 1;
    }

    if (fprintf(file, "%s", content) < 0) {
        syslog(LOG_ERR, "Failed to write to file %s: %s", filepath, strerror(errno));
        perror("fprintf");
        fclose(file);
        closelog();
        return 1;
    }

    fclose(file);
    closelog();
    return 0;
}
