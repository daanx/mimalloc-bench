#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *p = malloc(256 * 1024);
    memset(p, 'A', 256 * 1024);
    free(p);

    for (int i=0; i<256 * 1024; i++) {
        if (p[i] != 0) {
            puts("NOT_CAUGHT");
            return 0;
        }
    }

    return 0;
}
