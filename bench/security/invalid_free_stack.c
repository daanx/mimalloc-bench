#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char p[ALLOCATION_SIZE];
    free_noinline(p);

    NOT_CAUGHT();

    return 0;
}
