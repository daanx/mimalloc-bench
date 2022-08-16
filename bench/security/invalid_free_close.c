#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *p = malloc(16);
    char* q = p + 4 * 1024;
    free(q);

    puts("NOT_CAUGHT");
    fflush(stdout);
    return 0;
}
