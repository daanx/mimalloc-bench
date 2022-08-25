#ifndef _MIMALLOC_BENCH_SECURITY_COMMON_H_
#define _MIMALLOC_BENCH_SECURITY_COMMON_H_

#ifndef ALLOCATION_SIZE
#error Unspecified allocation size
#endif

#define NOT_CAUGHT() do { puts("NOT_CAUGHT"); fflush(stdout); } while ((0));

#if defined(_MSC_VER) 
__declspec(noinline)
#elif defined(__INTEL_COMPILER)
#pragma noinline
#else
__attribute((noinline))
#endif
void* memcpy_noinline(void* dest, const void* src, size_t n) {
    return memcpy(dest, src, n);
}

#endif //_MIMALLOC_BENCH_SECURITY_COMMON_H
