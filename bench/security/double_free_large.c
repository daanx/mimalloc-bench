#include <stdio.h>
#include <stdlib.h>

int main() {
    void *p = malloc(256 * 1024);
    free(p);
    free(p);

    puts("NOT_CAUGHT");
    return 0;
}
