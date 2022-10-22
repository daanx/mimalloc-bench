#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc(ALLOCATION_SIZE);
    void *q = malloc(ALLOCATION_SIZE);
    free(p);
    free(q);
    free(p);

    NOT_CAUGHT();

    return 0;
}
