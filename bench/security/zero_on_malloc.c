#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common.h"

#define ITERATIONS 4096

int main(void) {
    // Allocate many chunks, and fill them.
    // Do this incase the allocator randomizes new chunks
    char *allocations[ITERATIONS] = { 0 };
    for (int i = 0; i < ITERATIONS; i++) {
        char *chunk = malloc_noinline(ALLOCATION_SIZE);
        memset(chunk, 'A', ALLOCATION_SIZE);
        allocations[i] = chunk;
    }

    for (int i = 0; i < ITERATIONS; i++) {
        free_noinline(allocations[i]);
    }

    char *p = malloc_noinline(ALLOCATION_SIZE);
    for (int i=0; i< ALLOCATION_SIZE; i++) {
        if (p[i] != 0) {
            NOT_CAUGHT();
            return 0;
        }
    }

    return 0;
}
