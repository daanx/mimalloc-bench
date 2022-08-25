#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char *p = malloc(ALLOCATION_SIZE);
    p[ALLOCATION_SIZE - 1 + 32] ^= 'A'; // XOR is used to avoid the test having a 1/256 chance to fail
    free(p);

    NOT_CAUGHT();

    return 0;
}
