/**
 * \file   test-malloc_test.c
 * \author C. Lever and D. Boreham, Christian Eder ( ederc@mathematik.uni-kl.de )
 * \date   2000
 * \brief  Test file for xmalloc. This is a multi-threaded test system by
 *         Lever and Boreham. It is first noted in their paper "malloc()
 *         Performance in a Multithreaded Linux Environment", appeared at the
 *         USENIX 2000 Annual Technical Conference: FREENIX Track.
 *         This file is part of XMALLOC, licensed under the GNU General
 *         Public License version 3. See COPYING for more information.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <unistd.h>
//#include "xmalloc-config.h"
//#include "xmalloc.h"

#include "random.h"

#define CACHE_ALIGNED 1

#define xmalloc malloc
#define xfree free

#define DEFAULT_OBJECT_SIZE 1024

int debug_flag = 0;
int verbose_flag = 0;
#define num_workers_default 4
int num_workers = num_workers_default;
double run_time = 5.0;
int object_size = DEFAULT_OBJECT_SIZE;
/* array for thread ids */
pthread_t *thread_ids;
/* array for saving result of each thread */
struct counter {
  long c
#if CACHE_ALIGNED
 __attribute__((aligned(64)))
#endif
;
};
struct counter *counters;

volatile int done_flag = 0;
struct timeval begin;


#define atomic_load(addr) __atomic_load_n(addr, __ATOMIC_CONSUME)
#define atomic_store(addr, v) __atomic_store_n(addr, v, __ATOMIC_RELEASE)


static void
tvsub(tdiff, t1, t0)
	struct timeval *tdiff, *t1, *t0;
{

	tdiff->tv_sec = t1->tv_sec - t0->tv_sec;
	tdiff->tv_usec = t1->tv_usec - t0->tv_usec;
	if (tdiff->tv_usec < 0)
		tdiff->tv_sec--, tdiff->tv_usec += 1000000;
}

double elapsed_time(struct timeval *time0)
{
	struct timeval timedol;
	struct timeval td;
	double et = 0.0;

	gettimeofday(&timedol, (struct timezone *)0);
	tvsub( &td, &timedol, time0 );
	et = td.tv_sec + ((double)td.tv_usec) / 1000000;

	return( et );
}

static const long possible_sizes[] = {8,12,16,24,32,48,64,96,128,192,256,(256*3)/2,512, (512*3)/2, 1024, (1024*3)/2, 2048};
static const int n_sizes = sizeof(possible_sizes)/sizeof(long);

#define OBJECTS_PER_BATCH 4096
struct batch {
  struct batch *next_batch;
  void *objects[OBJECTS_PER_BATCH];
};

volatile struct batch *batches = NULL;
volatile int batch_count = 0;
const int batch_count_limit = 100;
pthread_cond_t empty_cv = PTHREAD_COND_INITIALIZER;
pthread_cond_t full_cv = PTHREAD_COND_INITIALIZER;
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

void enqueue_batch(struct batch *batch) {
  pthread_mutex_lock(&lock);
  while (batch_count >= batch_count_limit && !atomic_load(&done_flag)) {
    pthread_cond_wait(&full_cv, &lock);
  }
  batch->next_batch = batches;
  batches = batch;
  batch_count++;
  pthread_cond_signal(&empty_cv);
  pthread_mutex_unlock(&lock);
}

struct batch* dequeue_batch() {
  pthread_mutex_lock(&lock);
  while (batches == NULL && !atomic_load(&done_flag)) {
    pthread_cond_wait(&empty_cv, &lock);
  }
  struct batch* result = batches;
  if (result) {
    batches = result->next_batch;
    batch_count--;
    pthread_cond_signal(&full_cv);
  }
  pthread_mutex_unlock(&lock);
  return result;
}

void *mem_allocator (void *arg) {
  int thread_id = *(int *)arg;
  struct lran2_st lr;
  lran2_init(&lr, thread_id);

  while (!atomic_load(&done_flag)) {
    struct batch *b = xmalloc(sizeof(*b));
    for (int i = 0; i < OBJECTS_PER_BATCH; i++) {
      size_t siz = object_size > 0 ? object_size : possible_sizes[lran2(&lr)%n_sizes];
      b->objects[i] = xmalloc(siz);
      memset(b->objects[i],i%256,(siz > 128 ? 128 : siz));
    }
    enqueue_batch(b);
  }
  return NULL;
}

void *mem_releaser(void *arg) {
  int thread_id = *(int *)arg;

  while(!atomic_load(&done_flag)) {
    struct batch *b = dequeue_batch();
    if (b) {
      for (int i = 0; i < OBJECTS_PER_BATCH; i++) {
	      xfree(b->objects[i]);
      }
      xfree(b);
    }
    counters[thread_id].c += OBJECTS_PER_BATCH;
  }
  return NULL;
}

int run_memory_free_test()
{
	void *ptr = NULL;
	int i;
	double elapse_time = 0.0;
	long total = 0;
	int *ids = (int *)xmalloc(sizeof(int) * num_workers);

	/* Initialize counter */
	for(i = 0; i < num_workers; ++i)
		counters[i].c = 0;

	gettimeofday(&begin, (struct timezone *)0);

	/* Start up the mem_allocator and mem_releaser threads  */
	for(i = 0; i < num_workers; ++i) {
		ids[i] = i;
		if (verbose_flag) printf("Starting mem_releaser %i ...\n", i);
		if (pthread_create(&thread_ids[i * 2], NULL, mem_releaser, (void *)&ids[i])) {
			perror("pthread_create mem_releaser");
			exit(errno);
		}

		if (verbose_flag) printf("Starting mem_allocator %i ...\n", i);
		if (pthread_create(&thread_ids[i * 2 + 1], NULL, mem_allocator, (void *)&ids[i])) {
			perror("pthread_create mem_allocator");
			exit(errno);
		}
	}

	if (verbose_flag) printf("Testing for %.2f seconds\n\n", run_time);

	while (1) {
	  usleep(1000);
	  if (elapsed_time(&begin) > run_time) {
	    atomic_store(&done_flag, 1);
	    pthread_cond_broadcast(&empty_cv);
	    pthread_cond_broadcast(&full_cv);
	    break;
	  }
	}

  for(i = 0; i < num_workers * 2; ++i)
    pthread_join (thread_ids[i], &ptr);

	elapse_time = elapsed_time (&begin);

	for(i = 0; i < num_workers; ++i) {
		if (verbose_flag) {
			printf("Thread %2i frees %ld blocks in %.2f seconds. %.2f free/sec.\n",
			       i, counters[i].c, elapse_time, ((double)counters[i].c/elapse_time));
		}
	}
	if (verbose_flag) printf("----------------------------------------------------------------\n");
	for(i = 0; i < num_workers; ++i) total += counters[i].c;
	if (verbose_flag)
	  printf("Total %ld freed in %.2f seconds. %.2fM free/second\n",
		 total, elapse_time, ((double) total/elapse_time)*1e-6);
	else {
    double mfree_per_sec = ((double)total/elapse_time) * 1e-6;
    double rtime = 100.0 / mfree_per_sec;
	  printf("rtime: %.3f, free/sec: %.3f M\n", rtime, mfree_per_sec);
  }
	if (verbose_flag) printf("Program done\n");
  if (ids!=NULL) xfree(ids);
	return(0);
}

void usage(char *prog)
{
	printf("%s [-w workers] [-t run_time] [-d] [-v]\n", prog);
	printf("\t -w number of producer threads (and number of consumer threads), default %d\n", num_workers_default);
	printf("\t -t run time in seconds, default 20.0 seconds.\n");
	printf("\t -s size of object to allocate (default %d bytes) (specify -1 to get many different object sizes)\n", DEFAULT_OBJECT_SIZE);
	printf("\t -d debug mode\n");
	printf("\t -v verbose mode (-v -v produces more verbose)\n");
	exit(1);
}

int main(int argc, char **argv)
{
	int c;
	while ((c = getopt(argc, argv, "w:t:ds:v")) != -1) {

		switch (c) {

		case 'w':
			num_workers = atoi(optarg);
			break;
		case 't':
			run_time = atof(optarg);
			break;
		case 'd':
			debug_flag = 1;
			break;
		case 's':
			object_size = atoi(optarg);
			break;
		case 'v':
			verbose_flag++;
			break;
		default:
			usage(argv[0]);
		}
	}

	/* allocate memory for working arrays */
	thread_ids = (pthread_t *) xmalloc(sizeof(pthread_t) * num_workers * 2);
	counters = (struct counter *) xmalloc(sizeof(*counters) * num_workers);

	run_memory_free_test();

  while (batches) {
	  struct batch *b = batches;
	  batches = b->next_batch;
	  for (int i = 0 ; i < OBJECTS_PER_BATCH; i++) {
	    xfree(b->objects[i]);
	  }
	  xfree(b);
	}
  
  xfree(thread_ids);
  xfree(counters);

	return 0;
}
