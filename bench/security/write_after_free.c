#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

int main(void) {
    char *p = malloc(ALLOCATION_SIZE);
    free(p);
    memset(p, 'A', ALLOCATION_SIZE);

    NOT_CAUGHT();

    return 0;
}
