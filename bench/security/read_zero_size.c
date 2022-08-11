#include <stdlib.h>
#include <stdio.h>

int main() {
    char *p = malloc(0);
    if (!p) {
        return 1;
    }
    putchar(*p);

    puts("NOT_CAUGHT");
    return 0;
}
