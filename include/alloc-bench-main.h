#include "alloc-bench.h"

static void rx_process_info(double* utime, double* stime, size_t* peak_rss, size_t* page_faults, size_t* page_reclaim, size_t* peak_commit);
static double rx_clock_now();

static inline void bench_start_thread() {
  #ifdef USE_RPMALLOC
  rpmalloc_thread_initialize();
  #endif
}

static inline void bench_end_thread() {
  #ifdef USE_RPMALLOC
  rpmalloc_thread_finalize();
  #endif
}

static double time_start = 0;

static inline void bench_start_program() {
  time_start = rx_clock_now();
#ifdef USE_HOARD
  getCustomHeap();
  //InitializeWinWrapper();
  //xxinit();
#endif
#ifdef USE_RPMALLOC
  rpmalloc_initialize();  
  rpmalloc_thread_initialize();
#endif
}

#include <stdio.h>

static inline void bench_end_program() {
#ifdef USE_HOARD
  //FinalizeWinWrapper();
#endif
#ifdef USE_RPMALLOC
  rpmalloc_thread_finalize();
  rpmalloc_finalize();
#endif
  double elapsed = rx_clock_now() - time_start;
  double utime, stime;
  size_t rss, page_faults, page_reclaims, peak_commit;
  rx_process_info(&utime, &stime, &rss, &page_faults, &page_reclaims, &peak_commit);

  fprintf(stderr, "\n----------------------------------------------------------------------------\n"
                  "test       elapsed     rss    commit     user   sys   page-miss  page-fault\n"
                  "%s %4s:  %6.3f  %6zukb  %6zukb  %6.3f %6.3f %6zu  %6zu\n",
          TESTNAME, ALLOCATOR, elapsed, rss/1024, peak_commit/1024,
                               utime, stime, page_faults, page_reclaims);
}



// --------------------------------------------------------
// Basic timer for convenience
// --------------------------------------------------------

#ifdef _WIN32
#include <windows.h>
static double rx_to_seconds(LARGE_INTEGER t) {
  static double freq = 0.0;
  if (freq <= 0.0) {
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    freq = (double)(f.QuadPart);
  }
  return ((double)(t.QuadPart) / freq);
}

static double rx_clock_now() {
  LARGE_INTEGER t;
  QueryPerformanceCounter(&t);
  return rx_to_seconds(t);
}
#else
#include <time.h>
#ifdef TIME_UTC
static double rx_clock_now() {
  struct timespec t;
  timespec_get(&t, TIME_UTC);
  return (double)t.tv_sec + (1.0e-9 * (double)t.tv_nsec);
}
#else
// low resolution timer
static double rx_clock_now() {
  return ((double)clock() / (double)CLOCKS_PER_SEC);
}
#endif
#endif


static double rx_clock_diff = 0.0;

static double rx_clock_start() {
  if (rx_clock_diff == 0.0) {
    double t0 = rx_clock_now();
    rx_clock_diff = rx_clock_now() - t0;
  }
  return rx_clock_now();
}

static double rx_clock_end(double start) {
  double end = rx_clock_now();
  return (end - start - rx_clock_diff);
}


// --------------------------------------------------------
// Basic process statistics
// --------------------------------------------------------

#if defined(_WIN32)
#include <windows.h>
#include <psapi.h>
#pragma comment(lib,"psapi.lib")

static double filetime_secs(const FILETIME* ftime) {
  ULARGE_INTEGER i;
  i.LowPart = ftime->dwLowDateTime;
  i.HighPart = ftime->dwHighDateTime;
  double secs = (double)(i.QuadPart) * 1.0e-7; // FILETIME is in 100 nano seconds
  return secs;
}
static void rx_process_info(double* utime, double* stime, size_t* peak_rss, size_t* page_faults, size_t* page_reclaim, size_t* peak_commit) {
  FILETIME ct;
  FILETIME ut;
  FILETIME st;
  FILETIME et;
  GetProcessTimes(GetCurrentProcess(), &ct, &et, &st, &ut);
  *utime = filetime_secs(&ut);
  *stime = filetime_secs(&st);

  PROCESS_MEMORY_COUNTERS info;
  GetProcessMemoryInfo(GetCurrentProcess(), &info, sizeof(info));
  *peak_rss = (size_t)info.PeakWorkingSetSize;
  *page_faults = (size_t)info.PageFaultCount;
  *peak_commit = (size_t)info.PeakPagefileUsage;
  *page_reclaim = 0;
}

#elif defined(__unix__) || defined(__unix) || defined(unix) || (defined(__APPLE__) && defined(__MACH__))
#include <stdio.h>
#include <unistd.h>
#include <sys/resource.h>

#if defined(__APPLE__) && defined(__MACH__)
#include <mach/mach.h>
#endif

static double timeval_secs(const struct timeval* tv) {
  return (double)tv->tv_sec + ((double)tv->tv_usec * 1.0e-6);
}

static void rx_process_info(double* utime, double* stime, size_t* peak_rss, size_t* page_faults, size_t* page_reclaim, size_t* peak_commit) {
  struct rusage rusage;
  getrusage(RUSAGE_SELF, &rusage);
#if defined(__APPLE__) && defined(__MACH__)
  *peak_rss = rusage.ru_maxrss;
#else
  *peak_rss = rusage.ru_maxrss * 1024;
#endif
  *page_faults = rusage.ru_majflt;
  *page_reclaim = rusage.ru_minflt;
  *peak_commit = *peak_rss;
  *utime = timeval_secs(&rusage.ru_utime);
  *stime = timeval_secs(&rusage.ru_stime);
}

#else
#pragma message("define a way to get process info")
static size_t rx_process_info(double* utime, double* stime, size_t* peak_rss, size_t* page_faults, size_t* page_reclaim) {
  *peak_rss = 0;
  *page_faults = 0;
  *page_reclaim = 0;
  *utime = 0.0;
  *stime = 0.0;
}
#endif
