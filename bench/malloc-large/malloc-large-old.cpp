// Benchmark supplied by Danila Kutenin (danlark1 @github) and modified by Daan Leijen
#include <memory>
#include <thread>
#include <vector>

const size_t N = 5000;

void Foo() {
    for (size_t i = 0; i < N; ++i) {
        size_t sz = 1ull << 21;
        std::unique_ptr<char[]> a(new char[sz]);
        for(size_t k = 0; k < sz; k++) { a[k] = (char)k; }
    }
}

int main() {
    std::vector<std::thread> thrs;
    for (size_t i = 0; i < 1; ++i) {
        thrs.emplace_back(Foo);
    }
    for (auto&& thr : thrs) {
        thr.join();
    }
    return 0;
}
