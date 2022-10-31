#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

int main(void) {
    char *p = malloc_noinline(ALLOCATION_SIZE);
    memset(p, 'A', ALLOCATION_SIZE);
    free_noinline(p);

    for (int i=0; i< ALLOCATION_SIZE; i++) {
        if (p[i] != 0) {
            NOT_CAUGHT();
            return 0;
        }
    }

    return 0;
}
