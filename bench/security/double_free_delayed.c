#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc_noinline(ALLOCATION_SIZE);
    free_noinline(p);

    for(int i=0; i<1024; i++)
        free_noinline(malloc_noinline(ALLOCATION_SIZE));

    free_noinline(p);

    NOT_CAUGHT();

    return 0;
}
