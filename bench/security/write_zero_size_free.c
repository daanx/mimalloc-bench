#include <stdlib.h>
#include <stdio.h>

#include "common.h"

int main() {
    char *p = malloc(0);
    if (!p) {
        return 1;
    }
    *p = 'A';
    free(p);

    NOT_CAUGHT();

    return 0;
}
