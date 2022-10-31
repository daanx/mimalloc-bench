#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char *p = malloc_noinline(8);
    char *q = p;
    realloc(p, 1024);

    if (p == q)
    {
        NOT_CAUGHT();
    }

    return 0;
}
