#include <string>
#include <string.h>

#include "common.h"

int main(void) {
    std::string* a = new std::string[ALLOCATION_SIZE];
    delete a;

    NOT_CAUGHT();

    return 0;
}
