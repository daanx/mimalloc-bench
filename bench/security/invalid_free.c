#include <stdio.h>
#include <stdlib.h>

int main(void) {
    free((void *)1);

    puts("NOT_CAUGHT");
    return 0;
}
