#include <stdio.h>
#include <stdlib.h>

int main(void) {
    free(alloca(8));

    puts("NOT_CAUGHT");
    return 0;
}
