#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *p = malloc(8);
    p[8] ^= 'A'; // XOR is used to avoid the test having a 1/256 chance to fail
    free(p);

    puts("NOT_CAUGHT");
    fflush(stdout);

    return 0;
}
