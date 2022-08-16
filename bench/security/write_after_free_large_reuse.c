#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *p = malloc(256 * 1024);
    free(p);
    memset(p, 'A', 256 * 1024);

    for (size_t i=0; i< 1024 * 256; i++)
        free(malloc(256 * 1024));

    puts("NOT_CAUGHT");
    fflush(stdout);

    return 0;
}
