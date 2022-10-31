#include <stdio.h>
#include <stdlib.h>

#include "common.h"

/* This test checks that pointers aren't immediately re-used between
 * allocations. */

int main(void) {
    void *p = malloc_noinline(ALLOCATION_SIZE);
    void *q = p;
    free_noinline(p);

    p = malloc_noinline(ALLOCATION_SIZE);

    if (p == q)
    {
        NOT_CAUGHT();
    }

    return 0;
}
