#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *p = malloc(8);
    free(p + 1);

    puts("NOT_CAUGHT");
    return 0;
}
