#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    free_noinline(alloca(ALLOCATION_SIZE));

    NOT_CAUGHT();

    return 0;
}
