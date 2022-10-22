#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main() {
    void *p = malloc(ALLOCATION_SIZE);
    free(p);

    for(int i=0; i<1024; i++)
        free(malloc(ALLOCATION_SIZE));

    free(p);

    NOT_CAUGHT();

    return 0;
}
