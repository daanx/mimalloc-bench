#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc(ALLOCATION_SIZE);
    free(p);
    free(p);

    for (size_t i=0; i< 1024 * 256; i++)
        free(malloc(ALLOCATION_SIZE));

    NOT_CAUGHT();

    return 0;
}
