#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char *p = malloc_noinline(-2);
    if (p != NULL) {
      NOT_CAUGHT();
    }
    free_noinline(p);
    return 0;
}
