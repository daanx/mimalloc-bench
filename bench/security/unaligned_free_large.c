#include <stdio.h>
#include <stdlib.h>

int main() {
    char *p = malloc(256 * 1024);
    free(p + 1);

    puts("NOT_CAUGHT");
    fflush(stdout);
    return 0;
}
