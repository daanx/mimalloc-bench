#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    free((void *)1);

    NOT_CAUGHT();

    return 0;
}
