#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    free(alloca(8));

    NOT_CAUGHT();

    return 0;
}
