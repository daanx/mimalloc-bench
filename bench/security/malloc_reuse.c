#include <stdio.h>
#include <stdlib.h>

/* This test checks that pointers aren't immediately re-used between
 * allocations. */

int main(void) {
    void *p = malloc(8);
    void *q = p;
    free(p);

    p = malloc(8);

    if (p == q)
	    puts("NOT_CAUGHT");

    return 0;
}
