#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    free(alloca(ALLOCATION_SIZE));

    NOT_CAUGHT();

    return 0;
}
