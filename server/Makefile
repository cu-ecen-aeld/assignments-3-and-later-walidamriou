# Makefile for the aesdsocket server
CC = gcc
CFLAGS = -Wall -Werror -g

TARGET = aesdsocket

all: $(TARGET)

$(TARGET): aesdsocket.c
	$(CC) $(CFLAGS) aesdsocket.c -o $(TARGET)

clean:
	rm -f $(TARGET)
