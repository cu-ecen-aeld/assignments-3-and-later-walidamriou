
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

#define PORT      9000 // the Port number to bind the server socket
#define FILE_PATH "/var/tmp/aesdsocketdata" // File path to store received data

// Global file descriptors to manage cleanup
int sockfd = -1; 
int clientfd = -1;

/**
 * Signal handler for SIGINT and SIGTERM
 * SIGINT: Sent by pressing Ctrl+C, used to interrupt a running program interactively.
 * SIGTERM: Sent by system tools (e.g., kill), used to request graceful termination of a program.
 */
void signal_handler(int signal) {
    syslog(LOG_INFO, "Caught signal, exiting");
    // Close open connections and delete the data file
    if (clientfd >= 0) 
        close(clientfd);
    if (sockfd >= 0)
        close(sockfd);
    remove(FILE_PATH); // Ensure file is deleted on exit
    exit(0);
}

/**
 * Main server application
 */
int main(int argc, char *argv[]) {
    // Initialize syslog for logging messages
    // Initializes syslog with "aesdsocket" as the identifier logging PID, and using the user-level facility.
    openlog("aesdsocket", LOG_PID | LOG_CONS, LOG_USER);

    struct sockaddr_in server_addr, client_addr; // Structs to hold socket address info
    socklen_t addr_len = sizeof(client_addr);   // Size of the client address struct

    // Register signal handlers for SIGINT and SIGTERM
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Create a socket as IPv4 TCP (SOCK_STREAM) socket
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1) {
        syslog(LOG_ERR, "Socket creation failed: %s", strerror(errno));
        return -1;
    }

    // Set up the server address structure
    memset(&server_addr, 0, sizeof(server_addr)); // Zero out the structure
    server_addr.sin_family = AF_INET; // set IPv4 address family type
    server_addr.sin_addr.s_addr = INADDR_ANY; // Bind to any available network interface
    server_addr.sin_port = htons(PORT); // Set the specified port number

    // Bind the socket to the specified port and address
    if (bind(sockfd, (struct sockaddr *)&server_addr, sizeof(server_addr)) == -1) {
        syslog(LOG_ERR, "Bind failed: %s", strerror(errno));
        close(sockfd);
        return -1; 
    }

    // Start listening for incoming connections
    if (listen(sockfd, 10) == -1) { // Allow up to 10 pending connections in the queue
        syslog(LOG_ERR, "Listen failed: %s", strerror(errno));
        close(sockfd);
        return -1; 
    }

    // Main loop to accept and handle client connections
    while (1) { 
        // Accept an incoming connection
        clientfd = accept(sockfd, (struct sockaddr *)&client_addr, &addr_len);
        if (clientfd == -1) {
            syslog(LOG_ERR, "Accept failed: %s", strerror(errno));
            continue; // Log the error but continue accepting connections
        }

        // Log the IP address of the connected client (inet_ntoa to Convert IP in IN to ASCII)
        syslog(LOG_INFO, "Accepted connection from %s", inet_ntoa(client_addr.sin_addr));

        // Create or open the file for appending received data
        int fd = open(FILE_PATH, O_CREAT | O_APPEND | O_RDWR, 0666);
        if (fd < 0) {
            syslog(LOG_ERR, "File open failed: %s", strerror(errno));
            close(clientfd); // Close the client connection and skip this iteration
            continue; // Log the error but continue accepting connections
        }

        char buffer[60000]; // Buffer to store incoming data
        ssize_t bytes_read;

        // Receive data from the client
        while ((bytes_read = recv(clientfd, buffer, sizeof(buffer), 0)) > 0) {
            // Ensure the received data ends with a newline character before appending
            if (bytes_read > 0 && buffer[bytes_read - 1] != '\n') {
                buffer[bytes_read] = '\n'; // Add newline if not already present
                bytes_read++;  // Adjust the number of bytes read to include the newline
            }

            // Write the received data to the file
            write(fd, buffer, bytes_read);

            // Break out of the loop if a newline character is found
            if (strchr(buffer, '\n')) 
                break;
        }


        if (bytes_read < 0) {
            // Log an error if receiving data failed
            syslog(LOG_ERR, "Receive failed: %s", strerror(errno));
        }

        // Send the entire contents of the file back to the client
        lseek(fd, 0, SEEK_SET); // Move the file pointer to the beginning
        while ((bytes_read = read(fd, buffer, sizeof(buffer))) > 0) {
            send(clientfd, buffer, bytes_read, 0); // Send the file content to the client
        }

        close(fd); // Close the file
        close(clientfd); // Close the client connection

        // Log the disconnection
        syslog(LOG_INFO, "Closed connection from %s", inet_ntoa(client_addr.sin_addr));
    }

    closelog(); // Close syslog
    close(sockfd); // Close the server socket
    return 0;
}
