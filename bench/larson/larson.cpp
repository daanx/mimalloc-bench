/* Test driver for memory allocators           */
/* Author: Paul Larson, palarson@microsoft.com */

#include <assert.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <pthread.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <atomic>

#define TICKS_PER_SEC	(1000000L)
#define MAX_BLOCKS		(1000000L)

#undef CUSTOM_MALLOC
#undef CUSTOM_FREE
#ifdef CPP
# define CUSTOM_MALLOC(size)		(new char[size])
# if defined(SIZED)
#  define CUSTOM_FREE(ptr, size)	(operator delete[] (ptr, size))
#  define VARIANT_STRING			("C++ version (new and sized delete)")
# else
#  define CUSTOM_FREE(ptr, size)	(delete[] ptr)
#  define VARIANT_STRING			("C++ version (new and delete)")
# endif
#else
# define CUSTOM_MALLOC(size)		(malloc(size))
# define CUSTOM_FREE(ptr, size)	(free(ptr))
# define VARIANT_STRING			("C version (malloc and free)")
#endif

void QueryPerformanceCounter (long * x){
	struct timezone tz;
	struct timeval tv;
	gettimeofday (&tv, &tz);
	*x = tv.tv_sec * 1000000L + tv.tv_usec;
}

typedef void * VoidFunction (void *);
void _beginthread (VoidFunction x, int, void * z)
{
	pthread_t pt;
	pthread_attr_t pa;
	pthread_attr_init (&pa);

	pthread_attr_setscope (&pa, PTHREAD_SCOPE_SYSTEM); /* bound behavior */
	pthread_create(&pt, &pa, x, z);
}

// stopflag and thread_data::finished are shared between the main thread
// (runthreads: sets stopflag, then spins on each finished) and the worker /
// respawn threads (exercise_heap: reads stopflag, writes finished).  As plain
// `volatile int` these accesses are an unsynchronized data race (UB) — volatile
// provides neither atomicity nor inter-thread ordering.  ThreadSanitizer flags
// the stopflag and finished races, and the race can strand a slot's `finished`
// at FALSE after a respawn, hanging the completion loop forever.  Use atomics.
std::atomic<int> stopflag{0};

struct lran2_st {
	long x, y, v[97];
};

typedef struct thr_data{
	int		NumBlocks;
	int		seed;
	char**	array;
	size_t*	blksize;
	int		asize;
	long	cAllocs;
	long	cFrees;
	long	cThreads;
	std::atomic<int> finished ;   // was `volatile int`; raced main<->workers (see stopflag note above)
	struct lran2_st rgen;
} thread_data;

void runthreads(long sleep_cnt, int max_threads,
		int chperthread, int num_rounds);
static void warmup(char **blkp, int num_chunks);
static void* exercise_heap(void *pinput);
static void lran2_init(struct lran2_st* d, long seed);
static long lran2(struct lran2_st* d);

char *			blkp[MAX_BLOCKS];
size_t			blksize[MAX_BLOCKS];
struct lran2_st	rgen;
int				min_size;
int				max_size;

int main (int argc, char *argv[]){
	int			max_threads;
	int			num_rounds;
	int			chperthread;
	unsigned	seed = 12345;
	int			num_chunks = 10000;
	long		sleep_cnt;

	if (argc > 7) {
		sleep_cnt = atoi(argv[1]);
		min_size = atoi(argv[2]);
		max_size = atoi(argv[3]);
		chperthread = atoi(argv[4]);
		num_rounds = atoi(argv[5]);
		seed = atoi(argv[6]);
		max_threads = atoi(argv[7]);
	}
	else {
		printf("\nMulti-threaded test driver\n");
		printf("%s\n", VARIANT_STRING);
		printf("runtime (sec):");
		scanf ("%ld", &sleep_cnt);
		printf("chunk size (min,max):");
		scanf("%d %d", &min_size, &max_size);
		printf("chunks/thread:");
		scanf("%d", &chperthread);
		printf("no of rounds:");
		scanf("%d", &num_rounds);
		printf("random seed:");
		scanf("%d", &seed);
		printf("threads:");
		scanf("%d", &max_threads);
	}

	num_chunks = max_threads*chperthread;
	if( num_chunks > MAX_BLOCKS ){
		printf("Max %d chunks, have %d - exiting\n", MAX_BLOCKS, num_chunks);
		return 1;
	}

	lran2_init(&rgen, seed);
	runthreads(sleep_cnt, max_threads, chperthread, num_rounds);
	return 0;
}

void runthreads(long sleep_cnt, int max_threads, int chperthread, int num_rounds)
{
	thread_data		de_area[max_threads];
	thread_data		*pdea;
	long			sum_threads = 0;
	long long		sum_allocs = 0;
	long long		sum_frees = 0;
	double			duration;
	long			start_cnt, end_cnt;
	long long		ticks;

	pdea = &de_area[0];
	memset(&de_area[0], 0, sizeof(thread_data));

	warmup(&blkp[0], max_threads*chperthread );

	for(int i = 0; i < max_threads; i++){
		de_area[i].NumBlocks	= num_rounds*chperthread;
		de_area[i].array		= &blkp[i*chperthread];
		de_area[i].blksize		= &blksize[i*chperthread];
		de_area[i].asize		= chperthread;
		de_area[i].seed			= lran2(&rgen);
		de_area[i].finished		= 0;
		de_area[i].cAllocs		= 0;
		de_area[i].cFrees		= 0;
		de_area[i].cThreads		= 0;

		lran2_init(&de_area[i].rgen, de_area[i].seed);
		_beginthread(exercise_heap, 0, &de_area[i]);
	}

	QueryPerformanceCounter(&start_cnt);
	sleep(sleep_cnt);

	stopflag = 1;
	for(int i = 0; i < max_threads; i++){
		while( !de_area[i].finished )
			sched_yield();
	}

	QueryPerformanceCounter(&end_cnt);

	for(int i = 0; i < max_threads; i++){
		sum_allocs    += de_area[i].cAllocs;
		sum_frees     += de_area[i].cFrees;
		sum_threads   += de_area[i].cThreads;
	}

	ticks = end_cnt - start_cnt;
	duration = (double)ticks/TICKS_PER_SEC;

	double throughput = (double)(sum_allocs +  sum_frees) / duration;
	double rtime      = 1.0e9 / throughput;
	printf ("Throughput = %8.0f operations per second, relative time: %.3fs. Theads run: %ld, duration: %lf\n", throughput, rtime, sum_threads, duration);
}

static void* exercise_heap(void* pinput){
	thread_data	*pdea = (thread_data *)pinput;
	int			victim;
	size_t		blk_size;
	int			range = max_size - min_size;

	if (stopflag){
		pdea->finished = 1;
		return NULL;
	}

	pdea->cThreads++;
	for (int cblks = 0; cblks < pdea->NumBlocks; cblks++){
		victim = lran2(&pdea->rgen)%pdea->asize;
		CUSTOM_FREE(pdea->array[victim], pdea->blksize[victim]);
		pdea->cFrees++;

		if (range == 0)
			blk_size = min_size;
		else
			blk_size = min_size+lran2(&pdea->rgen)%range;

		pdea->array[victim] = CUSTOM_MALLOC(blk_size);
		pdea->blksize[victim] = blk_size;
		assert(pdea->array[victim] != NULL);
		pdea->cAllocs++ ;

		/* Write something! */
		volatile char * chptr = ((char *) pdea->array[victim]);
		*chptr++ = 'a';
		volatile char ch = *((char *) pdea->array[victim]);
		*chptr = 'b';

		if( stopflag ) break;
	}

	if (!stopflag)
		_beginthread(exercise_heap, 0, pdea);
	else
		pdea->finished = 1;

	return NULL;
}

static void warmup(char **blkp, int num_chunks){
	int		cblks;
	int		victim;
	size_t	blk_size;
	size_t	tmp_sz;
	char	*tmp;

	for (cblks = 0; cblks < num_chunks; cblks++){
		if (min_size == max_size)
			blk_size = min_size;
		else
			blk_size = min_size + (lran2(&rgen) % (max_size - min_size));

		blkp[cblks] = CUSTOM_MALLOC(blk_size);
		assert(blkp[cblks] != NULL);
		blksize[cblks] = blk_size;
	}

	/* generate a random permutation of the chunks */
	for (cblks = num_chunks; cblks > 0; cblks--){
		victim = lran2(&rgen)%cblks;
		tmp = blkp[victim];
		tmp_sz = blksize[victim];
		blkp[victim]  = blkp[cblks-1];
		blksize[victim] = blksize[cblks-1];
		blkp[cblks-1] = tmp;
		blksize[cblks-1] = tmp_sz;
	}

	for (cblks = 0; cblks < 4*num_chunks; cblks++){
		victim = lran2(&rgen)%num_chunks;
		CUSTOM_FREE(blkp[victim], blksize[victim]);

		if (max_size == min_size)
			blk_size = min_size;
		else
			blk_size = min_size+lran2(&rgen)%(max_size - min_size);

		blkp[victim] = (char *)CUSTOM_MALLOC(blk_size);
		blksize[victim] = blk_size;
		assert(blkp[victim] != NULL);
	}
}

// =======================================================

/* lran2.h
 * by Wolfram Gloger 1996.
 *
 * A small, portable pseudo-random number generator.
 */

#ifndef _LRAN2_H
#define _LRAN2_H

#define LRAN2_MAX	(714025l)	/* constants for portable */
#define IA			(1366l)		/* random number generator */
#define IC			(150889l)	/* (see e.g. `Numerical Recipes') */

static void lran2_init(struct lran2_st* d, long seed){
	long x;
	int j;

	x = (IC - seed) % LRAN2_MAX;
	if(x < 0)
		x = -x;
	for(j=0; j<97; j++){
		x = (IA*x + IC) % LRAN2_MAX;
		d->v[j] = x;
	}
	d->x = (IA*x + IC) % LRAN2_MAX;
	d->y = d->x;
}

static long lran2(struct lran2_st* d){
	int j = (d->y % 97);

	d->y = d->v[j];
	d->x = (IA*d->x + IC) % LRAN2_MAX;
	d->v[j] = d->x;
	return d->y;
}

#undef IA
#undef IC
#endif
