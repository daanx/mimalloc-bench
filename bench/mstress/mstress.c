/* ----------------------------------------------------------------------------
Copyright (c) 2018,2019 Microsoft Research, Daan Leijen
This is free software; you can redistribute it and/or modify it under the
terms of the MIT license.
-----------------------------------------------------------------------------*/

/* This is a stress test for the allocator, using multiple threads and
   transferring objects between threads. This is not a typical workload
   but uses a random size distribution. Do not use this test as a benchmark!
*/
#include <alloc-bench-main.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#define N             (100)  // scaling factor
#define THREADS       (4)
#define TRANSFERS     (1000)

//#define N             (10)  // scaling factor
//#define THREADS       (32)


static void* atomic_exchange_ptr(volatile void** p, void* newval);

static volatile void* transfer[TRANSFERS];

#if (INTPTR_MAX != UINT32_MAX)
const uintptr_t cookie = 0xbf58476d1ce4e5b9UL;
#else
const uintptr_t cookie = 0x1ce4e5b9UL;
#endif


static void* alloc_items(size_t items) {
  if ((rand()%100) == 0) items *= 100; // 1% huge objects;
  if (items==40) items++;              // pthreads uses that size for stack increases
  uintptr_t* p = (uintptr_t*)CUSTOM_MALLOC(items*sizeof(uintptr_t));
  for (uintptr_t i = 0; i < items; i++) p[i] = (items - i) ^ cookie;
  return p;
}

static void free_items(void* p) {
  if (p != NULL) {
    uintptr_t* q = (uintptr_t*)p;
    uintptr_t items = (q[0] ^ cookie);
    for (uintptr_t i = 0; i < items; i++) {
      if ((q[i]^cookie) != items - i) {
        fprintf(stderr,"memory corruption at block %p at %zu\n", p, i);
        abort();
      }
    }
  }
  CUSTOM_FREE(p);
}


static void stress(intptr_t tid) {
  bench_start_thread();
  const size_t max_item = 128;  // in words
  const size_t max_item_retained = 10*max_item;
  size_t allocs = 80*N*(tid%8 + 1); // some threads do more
  size_t retain = allocs/2;
  void** data = NULL;
  size_t data_size = 0;
  size_t data_top = 0;
  void** retained = (void**)CUSTOM_MALLOC(retain*sizeof(void*));
  size_t retain_top = 0;

  while (allocs>0 || retain>0) {
    if (retain == 0 || ((rand()%4 == 0) && allocs > 0)) {
      // 75% alloc
      allocs--;
      if (data_top >= data_size) {
        data_size += 100000;
        data = (void**)CUSTOM_REALLOC(data, data_size*sizeof(void*));
      }
      data[data_top++] = alloc_items((rand() % max_item) + 1);
    }
    else {
      // 25% retain
      retained[retain_top++] = alloc_items( 10*((rand() % max_item_retained) + 1) );
      retain--;
    }
    if ((rand()%3)!=0 && data_top > 0) {
      // 66% free previous alloc
      size_t idx = rand() % data_top;
      free_items(data[idx]);
      data[idx]=NULL;
    }
    if ((tid%2)==0 && (rand()%4)==0 && data_top > 0) {
      // 25% transfer-swap of half the threads
      size_t data_idx = rand() % data_top;
      size_t transfer_idx = rand() % TRANSFERS;
      void* p = data[data_idx];
      void* q = atomic_exchange_ptr(&transfer[transfer_idx],p);
      data[data_idx] = q;
    }
  }
  // free everything that is left
  for (size_t i = 0; i < retain_top; i++) {
    free_items(retained[i]);
  }
  for (size_t i = 0; i < data_top; i++) {
    free_items(data[i]);
  }
  CUSTOM_FREE(retained);
  CUSTOM_FREE(data);
  bench_end_thread();
}

static void run_os_threads();

int main() {
  bench_start_program();
  srand(42);
  memset((void*)transfer,0,TRANSFERS*sizeof(void*));
  run_os_threads();
  for (int i = 0; i < TRANSFERS; i++) {
    free_items((void*)transfer[i]);
  }
  bench_end_program();
  return 0;
}


#ifdef _WIN32

#include <windows.h>

static DWORD WINAPI thread_entry(LPVOID param) {
  stress((intptr_t)param);
  return 0;
}

static void run_os_threads() {
  DWORD tids[THREADS];
  HANDLE thandles[THREADS];
  for(intptr_t i = 0; i < THREADS; i++) {
    thandles[i] = CreateThread(0,4096,&thread_entry,(void*)(i),0,&tids[i]);
  }
  for (int i = 0; i < THREADS; i++) {
    WaitForSingleObject(thandles[i], INFINITE);
  }
}

static void* atomic_exchange_ptr(volatile void** p, void* newval) {
#if (INTPTR_MAX == UINT32_MAX)
  return (void*)InterlockedExchange((volatile LONG*)p, (LONG)newval );
#else
  return (void*)InterlockedExchange64((volatile LONG64*)p, (LONG64)newval);
#endif
}
#else

#include <pthread.h>

static void* thread_entry( void* param ) {
  stress((uintptr_t)param);
  return NULL;
}

static void run_os_threads() {
  pthread_t threads[THREADS];
  memset(threads,0,sizeof(pthread_t)*THREADS);
  //pthread_setconcurrency(THREADS);
  for(uintptr_t i = 0; i < THREADS; i++) {
    pthread_create(&threads[i], NULL, &thread_entry, (void*)i);
  }
  for (size_t i = 0; i < THREADS; i++) {
    pthread_join(threads[i], NULL);
  }
}

#endif
