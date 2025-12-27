#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Error: Invalid number of arguments. Usage: %s <writefile> <writestr>", argv[0]);
        fprintf(stderr, "Usage: %s <writefile> <writestr>\n", argv[0]);
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);

    FILE *fp = fopen(writefile, "w");
    if (fp == NULL) {
        syslog(LOG_ERR, "Error opening file %s: %s", writefile, strerror(errno));
        perror("Error opening file");
        return 1;
    }

    if (fprintf(fp, "%s", writestr) < 0) {
        syslog(LOG_ERR, "Error writing to file %s: %s", writefile, strerror(errno));
        perror("Error writing to file");
        fclose(fp);
        return 1;
    }

    fclose(fp);
    closelog();
    return 0;
}
