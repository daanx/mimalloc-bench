#include <cstddef>
#include <cstdio>

struct s {
    size_t a, b, c, d, e, f, g, h, i;
};

int main(void) {
    void *p = new char;
    struct s *q = (struct s *)p;
    delete q;

    puts("NOT_CAUGHT");
    fflush(stdout);

    return 0;
}
