
#include <string.h>
#include <stdlib.h>
#ifndef __APPLE__
#  include <malloc.h>
#endif
#include "alloc-bench.h"
#include "alloc-bench-main.h"

int
benchmark_initialize() {
  bench_start_program();
	return 0;
}

int
benchmark_finalize(void) {
  bench_end_program();
	return 0;
}

int
benchmark_thread_initialize(void) {
  bench_start_thread();
	return 0;
}

int
benchmark_thread_finalize(void) {
  bench_end_thread();
	return 0;
}

void*
benchmark_malloc(size_t alignment, size_t size) {
	// memset/calloc to ensure the memory is touched!
  void* p;
  /*
	if (alignment != 0) {
		posix_memalign(&ptr, alignment, size);    
		if (ptr != NULL) memset(ptr,0xCD,size);
		return ptr;
	}
	else {
		return calloc(1,size);
	}
  */
  if (size > 80 && size <= 96) size = 100;
  p = CUSTOM_MALLOC(size);
  if (p != NULL) memset(p, 0xCD, size);
  return p;
}

extern void
benchmark_free(void* ptr) {
	CUSTOM_FREE(ptr);
}

const char*
benchmark_name(void) {
	return "crt";
}

void
benchmark_thread_collect(void) {
}
