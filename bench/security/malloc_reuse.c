#include <stdio.h>
#include <stdlib.h>

#include "common.h"

/* This test checks that pointers aren't immediately re-used between
 * allocations. */

int main(void) {
    void *p = malloc(ALLOCATION_SIZE);
    void *q = p;
    free(p);

    p = malloc(ALLOCATION_SIZE);

    if (p == q)
    {
        NOT_CAUGHT();
    }

    return 0;
}
