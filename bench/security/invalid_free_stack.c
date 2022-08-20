#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char p[8];
    free(p);

    NOT_CAUGHT();

    return 0;
}
