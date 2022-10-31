#include <stdio.h>
#include <stdlib.h>

#include "common.h"

// This test checks for things like https://github.com/microsoft/snmalloc/blob/main/docs/security/GuardedMemcpy.md

int main(void) {
    const char c[ALLOCATION_SIZE] = {0};
    char *p = malloc_noinline(ALLOCATION_SIZE);
    memcpy_noinline(p - 1, c, sizeof(c));

    NOT_CAUGHT();

    return 0;
}
