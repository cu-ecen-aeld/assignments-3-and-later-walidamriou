#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <sys/stat.h>
#include <unistd.h>

// ------------------------------------------------
// log_message: log messages via syslog
// note: to check the syslog use: 
// $ tail -f /var/log/syslog 
// ------------------------------------------------
void debugLog(int priority, const char *message) {
    // Open syslog connection with process ID and console output
    // Notes: - logging session identifier is writer
    //       - flags: set LOG_PID (includes the process ID in log messages) 
    //                and LOG_CONS (directs messages to standard error if syslog is unavailable)
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);
    syslog(priority, "%s", message);
    closelog(); // Close the syslog connection
}

// ------------------------------------------------
// main: 
// ------------------------------------------------
int main(int argc, char *argv[]) {
    // Check for correct number of arguments (expecting 3)
    if (argc != 3) {
        debugLog(LOG_ERR,"ERROR: please include the required arguments next time!\n");
        exit(EXIT_FAILURE);  // Exit with failure if arguments are incorrect
    }

    const char *writefile = argv[1];  // First argument is the directory path of the file
    const char *writestr = argv[2];    // Second argument is the string to write

    // Check if the first argument is a valid directory
    struct stat path_stat;  // Structure to hold information about the path
    if (stat(writefile, &path_stat) != -1) {  // Get status of the path (Get file attributes for FILE and put them in BUF.)
        // Check if the path is a directory
        if (!S_ISREG(path_stat.st_mode)) {
            debugLog(LOG_ERR, "ERROR: The path is not a directory.");  
            exit(EXIT_FAILURE);  
        }
    } 
    else {
        debugLog(LOG_ERR, "ERROR: The path is not valid.");  
        exit(EXIT_FAILURE);  
    }

    // Check if the second argument is valid string
    if (strlen(writestr) == 0) {
        debugLog(LOG_ERR, "ERROR: the string for writing is not valid.");  
        exit(EXIT_FAILURE);  
    }

    // Open the file for writing
    FILE *file = fopen(writefile, "w");
    if (file == NULL) {
        debugLog(LOG_ERR, "ERROR: Could not create this file.");  
        exit(EXIT_FAILURE);  
    }

    // Write the string to the file
    if (fprintf(file, "%s", writestr) < 0) {
        debugLog(LOG_ERR, "ERROR: Failed to write to the file.");  
        fclose(file);  
        exit(EXIT_FAILURE);  
    }

    char log_buffer[256];  // Buffer to hold log message
    snprintf(log_buffer, sizeof(log_buffer), "Writing '%s' to '%s'", writestr, writefile);
    debugLog(LOG_DEBUG, log_buffer);  

    // Cleanup
    fclose(file);
    printf("The writing process passed correctly.\n");  // Indicate success (high level log)
    return EXIT_SUCCESS;  
}