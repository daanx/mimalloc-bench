#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

int main(void) {
    char *p = malloc_noinline(ALLOCATION_SIZE);
    free_noinline(p);
    memset(p, 'A', ALLOCATION_SIZE);

    for (size_t i=0; i< 1024 * 256; i++)
        free_noinline(malloc_noinline(ALLOCATION_SIZE));

    NOT_CAUGHT();

    return 0;
}
