CC ?= gcc
CFLAGS ?= -g -Wall -Werror
TARGET ?= aesdsocket
LDFLAGS ?= 

all: $(TARGET)
default: $(TARGET)

$(TARGET): aesdsocket.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(TARGET) aesdsocket.c

clean:
	rm -f $(TARGET) *.o
