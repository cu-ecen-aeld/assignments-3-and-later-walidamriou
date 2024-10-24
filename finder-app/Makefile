# Makefile for the writer application

# Define the compiler to use
CC := gcc # defaul gcc (GNU C Compiler)

# Define the source files
SRC := writer.c

# Define the output executable
TARGET := writer

# Define object files
# Automatically generates object file names from source files by replacing .c with .o. 
OBJ := $(SRC:.c=.o)

# Define the cross-compiler if specified
# example: make CROSS_COMPILE=aarch64-none-linux-gnu-
ifeq ($(CROSS_COMPILE),)
    CC := $(CC)  # No cross-compiler specified, use native compiler
else
    CC := $(CROSS_COMPILE)gcc  # Use the specified cross-compiler
endif

# Default target (build the $(TARGET) using the all target, this is will use by: make)
all: $(TARGET) # this default target, the make will build to it when no target is specified.

# Linking Rule to build the target
# Compiles and links the object files into the final executable. $@ represents the target, $^ represents all prerequisites
$(TARGET): $(OBJ)
	$(CC) -o $@ $^

# Compile the .c files into .o files
%.o: %.c
	$(CC) -c $< -o $@  

# Clean command (use it by: make clean)
clean:
	rm -f $(TARGET) $(OBJ)

.PHONY: all clean # Marks all and clean as phony targets to prevent conflicts with files named all or clean