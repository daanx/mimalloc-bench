#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

int main(void) {
    char *p = malloc_noinline(ALLOCATION_SIZE);
    free_noinline(p);
    memset(p, 'A', ALLOCATION_SIZE);

    NOT_CAUGHT();

    return 0;
}
