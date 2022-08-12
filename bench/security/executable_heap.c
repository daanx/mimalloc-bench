#include <stdio.h>
#include <stdlib.h>
#include <string.h>

const char* shellcode = "\x90\x90\x90\x90\xc3";  // nop, ..., ret on x86

int main(void) {
    char *p = malloc(8);
    memcpy(p, shellcode, sizeof(shellcode));
    void(*fptr)(void) = (void(*)(void))p;
    fptr();

    puts("NOT_CAUGHT");
    fflush(stdout);
    return 0;
}
