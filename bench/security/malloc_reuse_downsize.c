#include <stdio.h>
#include <stdlib.h>

#include "common.h"

/* This test checks that pointers aren't immediately re-used between
 * an allocation and a smaller one. */

int main(void) {
    void *p = malloc(ALLOCATION_SIZE);
    void *q = p;
    free(p);

    p = malloc(ALLOCATION_SIZE / 2);

    if (p == q)
    {
        NOT_CAUGHT();
    }

    return 0;
}
