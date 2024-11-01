#include "systemcalls.h"
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>

/**
 * @param cmd the command to execute with system()
 * @return true if the command in @param cmd was executed
 *   successfully using the system() call, false if an error occurred,
 *   either in invocation of the system() call, or if a non-zero return
 *   value was returned by the command issued in @param cmd.
*/
bool do_system(const char *cmd)
{

/*
 * TODO  add your code here
 *  Call the system() function with the command set in the cmd
 *   and return a boolean true if the system() call completed with success
 *   or false() if it returned a failure
*/
    int i_error = system(cmd);
    if (i_error == -1) {
        return false; // error
    }
    
    return true;
}

/**
* @param count -The numbers of variables passed to the function. The variables are command to execute.
*   followed by arguments to pass to the command
*   Since exec() does not perform path expansion, the command to execute needs
*   to be an absolute path.
* @param ... - A list of 1 or more arguments after the @param count argument.
*   The first is always the full path to the command to execute with execv()
*   The remaining arguments are a list of arguments to pass to the command in execv()
* @return true if the command @param ... with arguments @param arguments were executed successfully
*   using the execv() call, false if an error occurred, either in invocation of the
*   fork, waitpid, or execv() command, or if a non-zero return value was returned
*   by the command issued in @param arguments with the specified arguments.
*/

bool do_exec(int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed, included just to avoid a compiler warning about the command variable potentially being unused
    command[count] = command[count];

/*
 * TODO:
 *   Execute a system command by calling fork, execv(),
 *   and wait instead of system (see LSP page 161).
 *   Use the command[0] as the full path to the command to execute
 *   (first argument to execv), and use the remaining arguments
 *   as second argument to the execv() command.
 *
*/

    va_end(args); // clean up
    
    // Check if the command is an absolute path
    if (command[0][0] != '/') {
        return false; // Command must be specified with an absolute path
    }

    pid_t pid = fork(); // Create a new process (create a child process), and save process identifier (PID) in pid
    // A negative value if the fork failed
    // Note: The fork() function creates a new child process. After this call, you have two processes: the parent and the child.
    if (pid < 0) {
        perror("Fork failed");
        return false; // Fork failed
    } 
    // 0 in the child process
    else if (pid == 0) {
        // Notes: In the child process (where pid == 0), you typically replace its execution context with a new 
        // program using execv() (or another exec variant). This is where you actually execute the command.
        // If execv() is successful, the child process stops executing the current code and runs the 
        // specified program. If execv() fails, the child can handle the error (e.g., by calling perror and exiting).

        execv(command[0], command); // Execute the command (replace the current image with the new program specified)
        // perror("execv failed"); // If execv fails
        // exit(EXIT_FAILURE); // Exit child process with failure
        return false; // Execute failed
    } 
    // The child's PID in the parent process
    else {
        // Notes: At this point, the parent needs to wait for the child to finish executing the command 
        // (whether it succeeded or failed) by calling waitpid(). This prevents the child from 
        // becoming a zombie process and allows the parent to get the exit status of the child.
        int status;
        waitpid(pid, &status, 0); // Wait for child process to finish
        return WIFEXITED(status) && WEXITSTATUS(status) == 0; // Return success if child exited normally
    }

    return false;
}

/**
* @param outputfile - The full path to the file to write with command output.
*   This file will be closed at completion of the function call.
* All other parameters, see do_exec above
*/
bool do_exec_redirect(const char *outputfile, int count, ...)
{
    va_list args;
    va_start(args, count);
    char * command[count+1];
    int i;
    for(i=0; i<count; i++)
    {
        command[i] = va_arg(args, char *);
    }
    command[count] = NULL;
    // this line is to avoid a compile warning before your implementation is complete
    // and may be removed
    command[count] = command[count];


/*
 * TODO
 *   Call execv, but first using https://stackoverflow.com/a/13784315/1446624 as a refernce,
 *   redirect standard out to a file specified by outputfile.
 *   The rest of the behaviour is same as do_exec()
 *
*/

    va_end(args); // clean up

    // Check if the command is an absolute path
    if (command[0][0] != '/') {
        return false; // Command must be specified with an absolute path
    }
    
    // Open the output file
    int fd = open(outputfile, O_WRONLY|O_TRUNC|O_CREAT, 0644);
    if (fd < 0) {
        perror("Failed to open output file");
        return false;
    }

    pid_t pid = fork(); // Create a new process (create a child process), and save process identifier (PID) in pid
    if (pid < 0) {
        perror("Fork failed");
        close(fd);
        return false; // Fork failed
    } 
    else if (pid == 0) {
        dup2(fd, STDOUT_FILENO); // Redirect stdout to the file
        close(fd); // Close the original file descriptor
        execv(command[0], command); // Execute the command (replace the current image with the new program specified)
        return false; // Execute failed
    } 
    else {
        close(fd);
        int status;
        waitpid(pid, &status, 0); // Wait for child process to finish
        return WIFEXITED(status) && WEXITSTATUS(status) == 0; // Return success if child exited normally
    }

    return false;
}
