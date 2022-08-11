#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    char *p = malloc(8);
    free(p);
    memset(p, 'A', 8);

    puts("NOT_CAUGHT");

    return 0;
}
