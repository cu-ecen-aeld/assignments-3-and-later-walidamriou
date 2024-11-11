#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

// Optional: use these functions to add debug or error prints to your application
#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

void* threadfunc(void* thread_param)
{
    // Cast the thread_param to the correct type (thread_data pointer)
    struct thread_data* thread_func_args = (struct thread_data*) thread_param;

    // Initialize thread completion status
    thread_func_args->thread_complete_success = false;

    // Wait before obtaining the mutex (if wait_to_obtain_ms is provided)
    if (thread_func_args->wait_to_obtain_ms > 0) {
        usleep(thread_func_args->wait_to_obtain_ms * 1000);  // Convert ms to microseconds
    }

    // Obtain the mutex
    if (pthread_mutex_lock(thread_func_args->mutex) != 0) {
        // If mutex lock fails, set the completion status to false and return
        printf("Error locking mutex.\n");
        return thread_param;
    }

    printf("Thread obtained mutex, processing...\n");
    if (thread_func_args->wait_to_release_ms > 0) {
        usleep(thread_func_args->wait_to_release_ms * 1000);  // Convert ms to microseconds
    }

    // Release the mutex
    if (pthread_mutex_unlock(thread_func_args->mutex) != 0) {
        // If mutex unlock fails, set the completion status to false and return
        printf("Error unlocking mutex.\n");
        return thread_param;
    }
    // Thread completed successfully
    thread_func_args->thread_complete_success = true;
    printf("mutex unlocked.\n");
    return thread_param;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms)
{
    /**
     * TODO: allocate memory for thread_data, setup mutex and wait arguments, pass thread_data to created thread
     * using threadfunc() as entry point.
     *
     * return true if successful.
     *
     * See implementation details in threading.h file comment block
     */
    struct thread_data* p_tdata = (struct thread_data*) malloc(sizeof(struct thread_data));
    if (p_tdata == NULL) {
        ERROR_LOG("Failed to allocate memory for thread_data");
        return false;
    }
    p_tdata->mutex = mutex;
    p_tdata->thread_complete_success = false; // Initialize the success flag as false

    // Create the thread and pass thread_data to it
    int i_result = pthread_create(thread, NULL, threadfunc, (void*)p_tdata);
    if (i_result != 0) {
        ERROR_LOG("Failed to create thread.");
        free(p_tdata); // Clean up the memory if thread creation fails
        return false;
    }
    return true;
}


