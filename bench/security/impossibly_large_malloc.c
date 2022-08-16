#include <stdio.h>
#include <stdlib.h>

int main(void) {
    char *p = malloc(-2);
    if (p != NULL) {
        puts("NOT_CAUGHT");
        fflush(stdout);
    }
    free(p);
    return 0;
}
