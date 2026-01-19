#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <syslog.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <stdbool.h>
#include <sys/stat.h>

#define PORT 9000
#define DATA_FILE "/var/tmp/aesdsocketdata"
#define BUFFER_SIZE 1024

int server_fd = -1;
int client_fd = -1;
int file_fd = -1;
bool signal_caught = false;

void handle_signal(int sig) {
    if (sig == SIGINT || sig == SIGTERM) {
        syslog(LOG_INFO, "Caught signal, exiting");
        signal_caught = true;
        if (server_fd != -1) {
            shutdown(server_fd, SHUT_RDWR);
            // We don't close here to avoid race conditions, main loop will close
        }
    }
}

void cleanup() {
    if (client_fd != -1) close(client_fd);
    if (server_fd != -1) close(server_fd);
    if (file_fd != -1) close(file_fd);
    remove(DATA_FILE);
    closelog();
}

void daemonize() {
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);
    if (setsid() < 0) exit(EXIT_FAILURE);
    pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);
    if (chdir("/") < 0) exit(EXIT_FAILURE);
    umask(0);
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
    open("/dev/null", O_RDWR);
    dup(0);
    dup(0);
}

int main(int argc, char *argv[]) {
    bool daemon_mode = false;
    if (argc > 1 && strcmp(argv[1], "-d") == 0) {
        daemon_mode = true;
    }

    openlog("aesdsocket", LOG_PID, LOG_USER);

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_signal;
    if (sigaction(SIGINT, &sa, NULL) != 0 || sigaction(SIGTERM, &sa, NULL) != 0) {
        perror("sigaction");
        return -1;
    }

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd == -1) {
        perror("socket");
        return -1;
    }

    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt))) {
        perror("setsockopt");
        return -1;
    }

    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind");
        return -1;
    }

    if (daemon_mode) {
        daemonize();
    }

    if (listen(server_fd, 10) < 0) {
        perror("listen");
        return -1;
    }

    while (!signal_caught) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
        
        if (signal_caught) break;
        
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            perror("accept");
            continue;
        }

        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, INET_ADDRSTRLEN);
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);

        char *packet_buffer = NULL;
        size_t packet_size = 0;
        char buffer[BUFFER_SIZE];
        ssize_t bytes_read;

        while ((bytes_read = recv(client_fd, buffer, BUFFER_SIZE, 0)) > 0) {
            char *new_buffer = realloc(packet_buffer, packet_size + bytes_read);
            if (!new_buffer) {
                syslog(LOG_ERR, "Malloc failed");
                break;
            }
            packet_buffer = new_buffer;
            memcpy(packet_buffer + packet_size, buffer, bytes_read);
            packet_size += bytes_read;

            char *newline_ptr;
            while ((newline_ptr = memchr(packet_buffer, '\n', packet_size)) != NULL) {
                size_t line_len = newline_ptr - packet_buffer + 1;
                
                file_fd = open(DATA_FILE, O_WRONLY | O_CREAT | O_APPEND, 0644);
                if (file_fd == -1) {
                    syslog(LOG_ERR, "Failed to open data file");
                    break;
                }
                if (write(file_fd, packet_buffer, line_len) != line_len) {
                    syslog(LOG_ERR, "Write failed");
                }
                close(file_fd);

                // Send full content
                file_fd = open(DATA_FILE, O_RDONLY);
                if (file_fd != -1) {
                    char send_buf[BUFFER_SIZE];
                    ssize_t read_bytes;
                    while ((read_bytes = read(file_fd, send_buf, sizeof(send_buf))) > 0) {
                        send(client_fd, send_buf, read_bytes, 0);
                    }
                    close(file_fd);
                }

                // Move remaining data to start of buffer
                size_t remaining = packet_size - line_len;
                memmove(packet_buffer, packet_buffer + line_len, remaining);
                packet_size = remaining;
                // Realloc to shrink? Not strictly necessary but good practice
                char *shrunk_buffer = realloc(packet_buffer, packet_size > 0 ? packet_size : 1);
                if (shrunk_buffer) packet_buffer = shrunk_buffer;
            }
        }

        if (packet_buffer) free(packet_buffer);
        
        syslog(LOG_INFO, "Closed connection from %s", client_ip);
        close(client_fd);
        client_fd = -1;
    }

    cleanup();
    return 0;
}
