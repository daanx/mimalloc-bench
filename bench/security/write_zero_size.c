#include <stdlib.h>
#include <stdio.h>

int main() {
    char *p = malloc(0);
    if (!p) {
        return 1;
    }
    *p = 'A';

    puts("NOT_CAUGHT");
    return 0;
}
