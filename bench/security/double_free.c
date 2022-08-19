#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc(ALLOCATION_SIZE);
    free(p);
    free(p);

    NOT_CAUGHT();

    return 0;
}
