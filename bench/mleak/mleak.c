/* ----------------------------------------------------------------------------
Copyright (c) 2018,2019 Microsoft Research, Daan Leijen
This is free software; you can redistribute it and/or modify it under the
terms of the MIT license.
-----------------------------------------------------------------------------*/

/* This is a test that creates threads that allocate a smallish long lived
   object and then terminates those threads doing this 10*N times.
   Some allocators can "leak" a lot of memory doing this.
*/

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

// > mleak [ITERATIONS=1]
//
// argument defaults
#define THREADS     (10)
#define BASEITER    (100)
static int ITER     = 10;  // do ITER*BASEITER iterations

#define ALLOC_WORDS (16)   // allocate 16*sizof(void*) objects

#define custom_alloc(n)    malloc(n)
#define custom_calloc(n,s) calloc(n,s)
#define custom_free(p)     free(p)

// transfer pointer between threads
#define TRANSFERS     (THREADS*BASEITER)
static volatile void* transfer[TRANSFERS];

static void run_os_threads(size_t nthreads, void (*entry)(intptr_t tid));
static void* atomic_exchange_ptr(volatile void** p, void* newval);

static void leak(intptr_t tid) {
  intptr_t* p = custom_calloc(ALLOC_WORDS,sizeof(void*));
  intptr_t i = (rand() % TRANSFERS);
  void* q = atomic_exchange_ptr(&transfer[i], p);
  custom_free(q);
}

static void test_leak(void) {
  srand(0x1ce4e5b9);
  for (int n = 0; n < (ITER*BASEITER); n++) {
    run_os_threads(THREADS, &leak);
#ifndef NDEBUG
    if ((n + 1) % 10 == 0) {
      printf("- iterations left: %3d\n", ITER - (n + 1));
    }
#endif
  }
  for(int i = 0; i < TRANSFERS; i++) {
    custom_free(transfer[i]);
  }
}

int main(int argc, char** argv) {
  // > mleak  [ITER]
  if (argc >= 2) {
    char* end;
    long n = (strtol(argv[1], &end, 10));
    if (n > 0) ITER = n;
  }
  printf("Using %d threads with %d*%d iterations\n", THREADS, BASEITER, ITER);
  test_leak();
  return 0;
}


static void (*thread_entry_fun)(intptr_t) = &leak;

#ifdef _WIN32

#include <windows.h>

static DWORD WINAPI thread_entry(LPVOID param) {
  thread_entry_fun((intptr_t)param);
  return 0;
}

static void run_os_threads(size_t nthreads, void (*fun)(intptr_t)) {
  thread_entry_fun = fun;
  DWORD* tids = (DWORD*)custom_calloc(nthreads,sizeof(DWORD));
  HANDLE* thandles = (HANDLE*)custom_calloc(nthreads,sizeof(HANDLE));
  for (uintptr_t i = 0; i < nthreads; i++) {
    thandles[i] = CreateThread(0, 4096, &thread_entry, (void*)(i), 0, &tids[i]);
  }
  for (size_t i = 0; i < nthreads; i++) {
    WaitForSingleObject(thandles[i], INFINITE);
  }
  for (size_t i = 0; i < nthreads; i++) {
    CloseHandle(thandles[i]);
  }
  custom_free(tids);
  custom_free(thandles);
}

static void* atomic_exchange_ptr(volatile void** p, void* newval) {
#if (INTPTR_MAX == INT32_MAX)
  return (void*)InterlockedExchange((volatile LONG*)p, (LONG)newval);
#else
  return (void*)InterlockedExchange64((volatile LONG64*)p, (LONG64)newval);
#endif
}

#else

#include <pthread.h>

static void* thread_entry(void* param) {
  thread_entry_fun((uintptr_t)param);
  return NULL;
}

static void run_os_threads(size_t nthreads, void (*fun)(intptr_t)) {
  thread_entry_fun = fun;
  pthread_t* threads = (pthread_t*)custom_calloc(nthreads,sizeof(pthread_t));
  memset(threads, 0, sizeof(pthread_t) * nthreads);
  //pthread_setconcurrency(nthreads);
  for (uintptr_t i = 0; i < nthreads; i++) {
    pthread_create(&threads[i], NULL, &thread_entry, (void*)i);
  }
  for (size_t i = 0; i < nthreads; i++) {
    pthread_join(threads[i], NULL);
  }
  custom_free(threads);
}

#ifdef __cplusplus
#include <atomic>
static void* atomic_exchange_ptr(volatile void** p, void* newval) {
  return std::atomic_exchange((volatile std::atomic<void*>*)p, newval);
}
#else
#include <stdatomic.h>
static void* atomic_exchange_ptr(volatile void** p, void* newval) {
  return atomic_exchange((volatile _Atomic(void*)*)p, newval);
}
#endif

#endif
