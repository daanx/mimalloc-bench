#ifndef _MIMALLOC_BENCH_SECURITY_COMMON_H_
#define _MIMALLOC_BENCH_SECURITY_COMMON_H_

#ifndef ALLOCATION_SIZE
#error Unspecified allocation size
#endif

#define NOT_CAUGHT() do { puts("NOT_CAUGHT"); fflush(stdout); } while ((0));

__attribute((noinline))
void* memcpy_noinline(void* dest, const void* src, size_t n) {
    return memcpy(dest, src, n);
}

#endif //_MIMALLOC_BENCH_SECURITY_COMMON_H
