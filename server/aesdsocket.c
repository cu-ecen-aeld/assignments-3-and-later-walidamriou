#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <syslog.h>
#include <fcntl.h>

#define PORT        9000
#define BACKLOG     10
#define FILE_PATH   "/var/tmp/aesdsocketdata"
#define BUFFER_SIZE 1024

// Global variables for cleanup
int sockfd = -1, clientfd = -1, filefd = -1;
volatile sig_atomic_t exit_flag = 0;

/**
 * Signal handler for SIGINT and SIGTERM
 */
void signal_handler(int signo) {
    syslog(LOG_INFO, "Caught signal, exiting");
    exit_flag = 1;
}

/**
 * Daemonize the process to run in the background
 */
void daemonize() {
    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        // Parent process exits
        exit(EXIT_SUCCESS);
    }

    // Start a new session
    if (setsid() < 0) {
        perror("setsid");
        exit(EXIT_FAILURE);
    }

    // Fork again to prevent the daemon from acquiring a terminal
    pid = fork();
    if (pid < 0) {
        perror("fork");
        exit(EXIT_FAILURE);
    }
    if (pid > 0) {
        // Intermediate parent exits
        exit(EXIT_SUCCESS);
    }

    // Change working directory to root
    if (chdir("/") < 0) {
        perror("chdir");
        exit(EXIT_FAILURE);
    }

    // Close all standard file descriptors
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
}

/**
 * Clean up resources and exit gracefully
 */
void clean_exit() {
    if (clientfd >= 0) close(clientfd);
    if (sockfd >= 0) close(sockfd);
    if (filefd >= 0) close(filefd);
    unlink(FILE_PATH);
    closelog();
    exit(0);
}

/**
 * Main server function
 */
int main(int argc, char *argv[]) {
    int daemon_mode = 0;
    struct sockaddr_in server_addr, client_addr;
    socklen_t addr_len = sizeof(client_addr);

    // Parse command-line arguments
    if (argc == 2 && strcmp(argv[1], "-d") == 0) {
        daemon_mode = 1;
    }

    // Open syslog for logging
    openlog("aesdsocket", LOG_PID | LOG_CONS, LOG_USER);

    // Set up signal handling with sigaction
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = signal_handler;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    // Create the server socket
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        syslog(LOG_ERR, "Socket creation failed: %s", strerror(errno));
        clean_exit();
    }

    // Enable socket options for address reuse
    int optval = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) < 0) {
        syslog(LOG_ERR, "Setsockopt failed: %s", strerror(errno));
        clean_exit();
    }

    // Configure server address structure
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    server_addr.sin_port = htons(PORT);

    // Bind the socket
    if (bind(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        syslog(LOG_ERR, "Bind failed: %s", strerror(errno));
        clean_exit();
    }

    // Listen for incoming connections
    if (listen(sockfd, BACKLOG) < 0) {
        syslog(LOG_ERR, "Listen failed: %s", strerror(errno));
        clean_exit();
    }

    // Daemonize if the "-d" flag is set
    if (daemon_mode) {
        daemonize();
    }

    // Main loop to handle client connections
    while (!exit_flag) {
        // Accept an incoming connection
        clientfd = accept(sockfd, (struct sockaddr *)&client_addr, &addr_len);
        if (clientfd < 0) {
            if (errno == EINTR) break; // Exit on signal interruption
            syslog(LOG_ERR, "Accept failed: %s", strerror(errno));
            continue;
        }

        // Log client connection
        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
        syslog(LOG_INFO, "Accepted connection from %s", client_ip);

        // Open the file for appending data
        filefd = open(FILE_PATH, O_RDWR | O_CREAT | O_APPEND, 0644);
        if (filefd < 0) {
            syslog(LOG_ERR, "File open failed: %s", strerror(errno));
            close(clientfd);
            clientfd = -1;
            continue;
        }

        // Receive data from client
        char temp_buffer[BUFFER_SIZE];
        char *recv_buffer = NULL;
        ssize_t bytes_received;
        int total_received = 0;

        do {
            bytes_received = recv(clientfd, temp_buffer, sizeof(temp_buffer), 0);
            if (bytes_received < 0) {
                syslog(LOG_ERR, "Receive failed: %s", strerror(errno));
                break;
            } else if (bytes_received == 0) {
                // Connection closed
                break;
            } else {
                // Expand dynamic buffer
                char *new_recv_buffer = realloc(recv_buffer, total_received + bytes_received);
                if (!new_recv_buffer) {
                    syslog(LOG_ERR, "Memory allocation failed");
                    free(recv_buffer);
                    recv_buffer = NULL;
                    break;
                }
                recv_buffer = new_recv_buffer;

                // Append received data
                memcpy(recv_buffer + total_received, temp_buffer, bytes_received);
                total_received += bytes_received;

                // Stop on newline
                if (memchr(temp_buffer, '\n', bytes_received)) {
                    break;
                }
            }
        } while (1);

        // Write received data to file
        if (recv_buffer && total_received > 0) {
            if (write(filefd, recv_buffer, total_received) != total_received) {
                syslog(LOG_ERR, "Write to file failed: %s", strerror(errno));
            }
        }

        // Send file content back to client
        lseek(filefd, 0, SEEK_SET);
        while ((bytes_received = read(filefd, temp_buffer, sizeof(temp_buffer))) > 0) {
            if (send(clientfd, temp_buffer, bytes_received, 0) != bytes_received) {
                syslog(LOG_ERR, "Send to client failed: %s", strerror(errno));
                break;
            }
        }

        // Clean up resources for this client
        free(recv_buffer);
        recv_buffer = NULL;

        close(clientfd);
        clientfd = -1;

        close(filefd);
        filefd = -1;

        syslog(LOG_INFO, "Closed connection from %s", client_ip);
    }

    // Clean up and exit
    clean_exit();
    return 0;
}
