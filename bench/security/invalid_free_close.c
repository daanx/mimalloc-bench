#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char *p = malloc(ALLOCATION_SIZE);
    char* q = p + 4 * 1024;
    free(q);

    NOT_CAUGHT();

    return 0;
}
