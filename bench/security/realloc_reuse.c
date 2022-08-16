#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *p = malloc(8);
    char *q = p;
    realloc(p, 1024);

    if (p == q)
    {
        puts("NOT_CAUGHT");
        fflush(stdout);
    }

    return 0;
}
