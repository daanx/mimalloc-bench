#include <stdio.h>
#include <stdlib.h>

int main() {
    void *p = malloc(256 * 1024);
    void *q = malloc(256 * 1024);
    free(p);
    free(q);
    free(p);

    puts("NOT_CAUGHT");
    fflush(stdout);
    return 0;
}
