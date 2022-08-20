#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc(ALLOCATION_SIZE);
    free(p);
    void *q = malloc(ALLOCATION_SIZE);
    free(p);
    free(q);

    NOT_CAUGHT();

    return 0;
}
