#include <stdio.h>
#include <stdlib.h>

#include "common.h"

int main(void) {
    char *p = malloc(-2);
    if (p != NULL) {
      NOT_CAUGHT();
    }
    free(p);
    return 0;
}
