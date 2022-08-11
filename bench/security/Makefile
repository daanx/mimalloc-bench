CFLAGS := -Wno-free-nonheap-object

SRCS = $(wildcard *.c)
PROGS = $(patsubst %.c,%,$(SRCS))

%: %.c
	$(CC) $(CFLAGS)  -o $@ $<

all: $(PROGS)

clean:
	rm -rf $(PROGS)
