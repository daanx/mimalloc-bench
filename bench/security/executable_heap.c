#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

const char* shellcode = "\x90\x90\x90\x90\xc3";  // nop, ..., ret on x86

int main(void) {
    char *p = malloc_noinline(ALLOCATION_SIZE);
    memcpy(p, shellcode, sizeof(shellcode));
    void(*fptr)(void) = (void(*)(void))p;
    fptr();

    NOT_CAUGHT();

    return 0;
}
