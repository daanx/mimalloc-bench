/* -------------------------------------------------------------------------------
 * Copyright (c) 2018, OLogN Technologies AG
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * -------------------------------------------------------------------------------
 *
 * Memory allocator tester -- main
 *
 * v.1.00    Jun-22-2018    Initial release
 *
 * -------------------------------------------------------------------------------*/

#include "selector.h"
#include "allocator_tester.h"

template<class Allocator>
void* runRandomTest( void* params )
{
	assert( params != nullptr );
	ThreadStartupParamsAndResults* testParams = reinterpret_cast<ThreadStartupParamsAndResults*>( params );
	Allocator allocator( testParams->threadRes );
	switch ( testParams->startupParams.mat )
	{
		case MEM_ACCESS_TYPE::none:
			randomPos_RandomSize<Allocator,MEM_ACCESS_TYPE::none>( allocator, testParams->startupParams.iterCount, testParams->startupParams.maxItems, testParams->startupParams.maxItemSize, testParams->threadID, testParams->startupParams.rndSeed );
			break;
		case MEM_ACCESS_TYPE::full:
			randomPos_RandomSize<Allocator,MEM_ACCESS_TYPE::full>( allocator, testParams->startupParams.iterCount, testParams->startupParams.maxItems, testParams->startupParams.maxItemSize, testParams->threadID, testParams->startupParams.rndSeed );
			break;
		case MEM_ACCESS_TYPE::single:
			randomPos_RandomSize<Allocator,MEM_ACCESS_TYPE::single>( allocator, testParams->startupParams.iterCount, testParams->startupParams.maxItems, testParams->startupParams.maxItemSize, testParams->threadID, testParams->startupParams.rndSeed );
			break;
		case MEM_ACCESS_TYPE::check:
			randomPos_RandomSize<Allocator,MEM_ACCESS_TYPE::check>( allocator, testParams->startupParams.iterCount, testParams->startupParams.maxItems, testParams->startupParams.maxItemSize, testParams->threadID, testParams->startupParams.rndSeed );
			break;
	}

	return nullptr;
}

template<class Allocator>
void runTest( TestStartupParamsAndResults* startupParams )
{
	size_t threadCount = startupParams->startupParams.threadCount;

	size_t start = GetMillisecondCount();

	ThreadStartupParamsAndResults testParams[max_threads];
	std::thread threads[ max_threads ];

	for ( size_t i=0; i<threadCount; ++i )
	{
		memcpy( testParams + i, startupParams, sizeof(TestStartupParams) );
		testParams[i].threadID = i;
		testParams[i].threadRes = startupParams->testRes->threadRes + i;
	}

	// run threads
	for ( size_t i=0; i<threadCount; ++i )
	{
		printf( "about to run thread %zd...\n", i );
		std::thread t1( runRandomTest<Allocator>, (void*)(testParams + i) );
		threads[i] = std::move( t1 );
		printf( "    ...done\n" );
	}
	// join threads
	for ( size_t i=0; i<threadCount; ++i )
	{
		printf( "joining thread %zd...\n", i );
		threads[i].join();
		printf( "    ...done\n" );
	}

	size_t end = GetMillisecondCount();
	startupParams->testRes->duration = end - start;
	printf( "%zd threads made %zd alloc/dealloc operations in %zd ms (%zd ms per 1 million)\n", threadCount, startupParams->startupParams.iterCount * threadCount, end - start, (end - start) * 1000000 / (startupParams->startupParams.iterCount * threadCount) );
	startupParams->testRes->cumulativeDuration = 0;
	startupParams->testRes->rssMax = 0;
	startupParams->testRes->allocatedAfterSetupSz = 0;
	startupParams->testRes->allocatedMax = 0;
	for ( size_t i=0; i<threadCount; ++i )
	{
		startupParams->testRes->cumulativeDuration += startupParams->testRes->threadRes[i].innerDur;
		startupParams->testRes->allocatedAfterSetupSz += startupParams->testRes->threadRes[i].allocatedAfterSetupSz;
		startupParams->testRes->allocatedMax += startupParams->testRes->threadRes[i].allocatedMax;
		if ( startupParams->testRes->rssMax < startupParams->testRes->threadRes[i].rssMax )
			startupParams->testRes->rssMax = startupParams->testRes->threadRes[i].rssMax;
	}
	startupParams->testRes->cumulativeDuration /= threadCount;
	startupParams->testRes->rssAfterExitingAllThreads = getRss();
}

int main(int argc, char** argv)
{
	TestRes testResMyAlloc[max_threads];
	TestRes testResVoidAlloc[max_threads];
	memset( testResMyAlloc, 0, sizeof( testResMyAlloc ) );
	memset( testResVoidAlloc, 0, sizeof( testResVoidAlloc ) );

	size_t maxItems = 1 << 18; // 512k objects
	TestStartupParamsAndResults params;
	params.startupParams.iterCount = 100000000;
	params.startupParams.maxItemSize = 10;  // 1k
	params.startupParams.mat = MEM_ACCESS_TYPE::full;
  params.startupParams.rndSeed = 41;

	size_t threadMin = 1;
	size_t threadMax = 6;
	size_t threadCount = threadMax;
	if (argc==2) {
		char* end;
		long l = strtol(argv[1],&end,10);
		if (l > 0) threadCount = l;
	}
	fprintf(stderr,"threads: %li\n", threadCount);
#ifdef BENCH
  params.startupParams.threadCount=threadCount;
	params.startupParams.maxItems = maxItems / params.startupParams.threadCount;
	params.testRes = testResMyAlloc + params.startupParams.threadCount;
	runTest<MyAllocatorT>( &params );
#else
	for ( params.startupParams.threadCount=threadMin; params.startupParams.threadCount<=threadMax; ++(params.startupParams.threadCount) )
	{
		params.startupParams.maxItems = maxItems / params.startupParams.threadCount;
		params.testRes = testResMyAlloc + params.startupParams.threadCount;
		runTest<MyAllocatorT>( &params );

		if ( params.startupParams.mat != MEM_ACCESS_TYPE::check )
		{
			params.startupParams.maxItems = maxItems / params.startupParams.threadCount;
			params.testRes = testResVoidAlloc + params.startupParams.threadCount;
			runTest<VoidAllocatorForTest<MyAllocatorT>>( &params );
		}
	}
#endif

	if ( params.startupParams.mat == MEM_ACCESS_TYPE::check )
	{
		printf( "Correctness test has been passed successfully\n" );
		return 0;
	}

#ifndef BENCH
	printf( "Test summary:\n" );
	for ( size_t threadCount=threadMin; threadCount<=threadMax; ++threadCount )
	{
		TestRes& trVoid = testResVoidAlloc[threadCount];
		TestRes& trMy = testResMyAlloc[threadCount];
		printf( "%zd,%zd,%zd,%zd\n", threadCount, trMy.duration, trVoid.duration, trMy.duration - trVoid.duration );
		printf( "Per-thread stats:\n" );
		for ( size_t i=0;i<threadCount;++i )
		{
			printf( "   %zd:\n", i );
			printThreadStats( "\t", trMy.threadRes[i] );
		}
	}
	printf( "\n" );
	const char* memAccessTypeStr = params.startupParams.mat == MEM_ACCESS_TYPE::none ? "none" : ( params.startupParams.mat == MEM_ACCESS_TYPE::single ? "single" : ( params.startupParams.mat == MEM_ACCESS_TYPE::full ? "full" : "unknown" ) );
	printf( "Short test summary for \'%s\' and maxItemSizeExp = %zd, maxItems = %zd, iterCount = %zd, allocated memory access mode: %s:\n", MyAllocatorT::name(), params.startupParams.maxItemSize, maxItems, params.startupParams.iterCount, memAccessTypeStr );
	printf( "columns:\n" );
	printf( "thread,duration(ms),duration of void(ms),diff(ms),RSS max(pages),rssAfterExitingAllThreads(pages),RSS max for void(pages),rssAfterExitingAllThreads for void(pages),allocatedAfterSetup(app level,bytes),allocatedMax(app level,bytes),(RSS max<<12)/allocatedMax\n" );
	for ( size_t threadCount=threadMin; threadCount<=threadMax; ++threadCount )
	{
		TestRes& trVoid = testResVoidAlloc[threadCount];
		TestRes& trMy = testResMyAlloc[threadCount];
		printf( "%zd,%zd,%zd,%zd,%zd,%zd,%zd,%zd,%zd,%zd,%f\n", threadCount, trMy.duration, trVoid.duration, trMy.duration - trVoid.duration, trMy.rssMax, trMy.rssAfterExitingAllThreads, trVoid.rssMax, trVoid.rssAfterExitingAllThreads, trMy.allocatedAfterSetupSz, trMy.allocatedMax, (trMy.rssMax << 12) * 1. / trMy.allocatedMax );

	}
	#endif
  /*	printf( "Short test summary for USE_RANDOMPOS_RANDOMSIZE (alt computations):\n" );
	for ( size_t threadCount=threadMin; threadCount<=threadMax; ++threadCount )
	{
		TestRes& trVoid = testResVoidAlloc[threadCount];
		TestRes& trMy = testResMyAlloc[threadCount];
		printf( "%zd,%zd,%zd,%zd,%zd,%zd,%zd,%zd,%zd,%zd,%f\n", threadCount, trMy.cumulativeDuration, trVoid.cumulativeDuration, trMy.cumulativeDuration - trVoid.cumulativeDuration, trMy.rssMax, trMy.rssAfterExitingAllThreads, trVoid.rssMax, trVoid.rssAfterExitingAllThreads, trMy.allocatedAfterSetupSz, trMy.allocatedMax, (trMy.rssMax << 12) * 1. / trMy.allocatedMax );
	}*/

	return 0;
}
