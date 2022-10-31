#include <stdlib.h>
#include <stdio.h>

#include "common.h"

int main() {
    char *p = malloc_noinline(0);
    if (!p) {
        return 1;
    }
    putchar(*p);
    free_noinline(p);

    NOT_CAUGHT();

    return 0;
}
