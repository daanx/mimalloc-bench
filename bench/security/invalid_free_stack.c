#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char p[8];
    free(p);

    puts("NOT_CAUGHT");
    return 0;
}
