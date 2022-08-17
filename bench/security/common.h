#ifndef _MIMALLOC_BENCH_SECURITY_COMMON_H_
#define _MIMALLOC_BENCH_SECURITY_COMMON_H_

#ifndef ALLOCATION_SIZE
#error Unspecified allocation size
#endif

#define NOT_CAUGHT() do { puts("NOT_CAUGHT"); fflush(stdout); } while ((0));

#endif //_MIMALLOC_BENCH_SECURITY_COMMON_H
