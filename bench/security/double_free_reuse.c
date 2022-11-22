#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main()
{
    void *p = malloc_noinline(ALLOCATION_SIZE);
    printf("p = %p", p);
    free_noinline(p);
    free_noinline(p);

    for (size_t i = 0; i < 1024 * 256; i++)
    {
        void *q = malloc_noinline(ALLOCATION_SIZE);
        printf("q = %p", q);
        free_noinline(q);
    }

    NOT_CAUGHT();

    return 0;
}
