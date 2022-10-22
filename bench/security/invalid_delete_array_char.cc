#include <string>
#include <string.h>

#include "common.h"

int main(void) {
    char* a = new char[ALLOCATION_SIZE];
    delete a;

    NOT_CAUGHT();

    return 0;
}
