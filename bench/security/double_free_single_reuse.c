#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc_noinline(ALLOCATION_SIZE);
    free_noinline(p);
    void *q = malloc_noinline(ALLOCATION_SIZE);
    free_noinline(p);
    free_noinline(q);

    NOT_CAUGHT();

    return 0;
}
