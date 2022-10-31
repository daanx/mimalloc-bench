#ifndef _MIMALLOC_BENCH_SECURITY_COMMON_H_
#define _MIMALLOC_BENCH_SECURITY_COMMON_H_

#ifndef ALLOCATION_SIZE
#error Unspecified allocation size
#endif

#define NOT_CAUGHT() do { puts("NOT_CAUGHT"); fflush(stdout); } while ((0));

#if defined(_MSC_VER) 
#define NOINLINE __declspec(noinline)
#elif defined(__INTEL_COMPILER)
#define NOINLINE _Pragma("noinline")
#else
#define NOINLINE __attribute((noinline))
#endif

NOINLINE
void* memcpy_noinline(void* dest, const void* src, size_t n) {
    return memcpy(dest, src, n);
}

NOINLINE
void* malloc_noinline(size_t size) {
    return malloc(size);
}

NOINLINE
void free_noinline(void* ptr) {
    return free(ptr);
}

#endif //_MIMALLOC_BENCH_SECURITY_COMMON_H
