#include <stdio.h>
#include <stdlib.h>

int main() {
    void *p = malloc(8);
    void *q = malloc(8);
    free(p);
    free(q);
    free(p);

    puts("NOT_CAUGHT");
    return 0;
}
