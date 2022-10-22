#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    char *p = malloc(ALLOCATION_SIZE);
    free(p + 1);

    NOT_CAUGHT();

    return 0;
}
