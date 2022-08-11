#include <stdio.h>
#include <stdlib.h>

int main() {
    void *p = malloc(256 * 1024);
    free(p);

    for(int i=0; i<1024; i++)
        free(malloc(256 * 1024));

    free(p);

    puts("NOT_CAUGHT");
    return 0;
}
