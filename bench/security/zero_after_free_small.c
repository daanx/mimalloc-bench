#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *p = malloc(8);
    memset(p, 'A', 8);
    free(p);

    for (int i=0; i<8; i++) {
        if (p[i] != 0) {
            puts("NOT_CAUGHT");
            fflush(stdout);
            return 0;
        }
    }

    return 0;
}
