#include <stdio.h>
#include <stdlib.h>

int main() {
    void *p = malloc(8);
    free(p);
    free(p);

    for (size_t i=0; i< 1024 * 256; i++)
        free(malloc(8));

    puts("NOT_CAUGHT");
    fflush(stdout);
    return 0;
}
