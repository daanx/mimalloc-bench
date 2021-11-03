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
 * Memory allocator tester
 *
 * v.1.00    Jun-22-2018    Initial release
 *
 * -------------------------------------------------------------------------------*/
#ifndef ALLOCATOR_TESTER_H
#define ALLOCATOR_TESTER_H

#include <stdint.h>
#define NOMINMAX

#include <memory>
#include <stdio.h>
#include <time.h>
#include <thread>
#include <assert.h>
#include <chrono>
#include <random>
#include <limits.h>

#ifndef __GNUC__
#include <intrin.h>
#else
#endif

#include "test_common.h"
#include "void_allocator.h" // used as an estimation of the cost of test itself


class PRNG
{
	uint64_t seedVal;
public:
	PRNG() { seedVal = 0; }
	PRNG( size_t seed_ ) { seedVal = seed_; }
	void seed( size_t seed_ ) { seedVal = seed_; }

	/*FORCE_INLINE uint32_t rng32( uint32_t x )
	{
		// Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs"
		x ^= x << 13;
		x ^= x >> 17;
		x ^= x << 5;
		return x;
	}*/
/*	FORCE_INLINE uint32_t rng32()
	{
		unsigned long long x = (seedVal += 7319936632422683443ULL);
		x ^= x >> 32;
		x *= c;
		x ^= x >> 32;
		x *= c;
		x ^= x >> 32;
        return uint32_t(x);
	}*/
	FORCE_INLINE uint32_t rng32()
	{
		// based on implementation of xorshift by Arvid Gerstmann
		// see, for instance, https://arvid.io/2018/07/02/better-cxx-prng/
        uint64_t ret = seedVal * 0xd989bcacc137dcd5ull;
        seedVal ^= seedVal >> 11;
        seedVal ^= seedVal << 31;
        seedVal ^= seedVal >> 18;
        return uint32_t(ret >> 32ull);
	}

	FORCE_INLINE uint64_t rng64()
	{
        uint64_t ret = rng32();
		ret <<= 32;
		return ret + rng32();
	}
};

FORCE_INLINE size_t calcSizeWithStatsAdjustment( uint64_t randNum, size_t maxSizeExp )
{
	assert( maxSizeExp >= 3 );
	maxSizeExp -= 3;
	uint32_t statClassBase = (randNum & (( 1 << maxSizeExp ) - 1)) + 1; // adding 1 to avoid dealing with 0
	randNum >>= maxSizeExp;
	unsigned long idx;
#if _MSC_VER
	uint8_t r = _BitScanForward(&idx, statClassBase);
	assert( r );
#elif __GNUC__
	idx = __builtin_ctzll( statClassBase );
#else
	static_assert(false, "Unknown compiler");
#endif
//	assert( idx <= maxSizeExp - 3 );
	assert( idx <= maxSizeExp );
	idx += 2;
	size_t szMask = ( 1 << idx ) - 1;
	return (randNum & szMask) + 1 + (((size_t)1)<<idx);
}

inline void testDistribution()
{
	constexpr size_t exp = 16;
	constexpr size_t testCnt = 0x100000;
	size_t bins[exp+1];
	memset( bins, 0, sizeof( bins) );
	size_t total = 0;

	PRNG rng;

	for (size_t i=0;i<testCnt;++i)
	{
		size_t val = calcSizeWithStatsAdjustment( rng.rng64(), exp );
//		assert( val <= (((size_t)1)<<exp) );
		assert( val );
		if ( val <= 8 )
			bins[3] +=1;
		else
			for ( size_t j=4; j<=exp; ++j )
				if ( val <= (((size_t)1)<<j) && val > (((size_t)1)<<(j-1) ) )
					bins[j] += 1;
	}
	printf( "<=3: %zd\n", bins[0] + bins[1] + bins[2] + bins[3] );
	total = 0;
	for ( size_t j=0; j<=exp; ++j )
	{
		total += bins[j];
		printf( "%zd: %zd\n", j, bins[j] );
	}
	assert( total == testCnt );
}


constexpr double Pareto_80_20_6[7] = {
	0.262144000000,
	0.393216000000,
	0.245760000000,
	0.081920000000,
	0.015360000000,
	0.001536000000,
	0.000064000000};

struct Pareto_80_20_6_Data
{
	uint32_t probabilityRanges[6];
	uint32_t offsets[8];
};

FORCE_INLINE
void Pareto_80_20_6_Init( Pareto_80_20_6_Data& data, uint32_t itemCount )
{
	data.probabilityRanges[0] = (uint32_t)(UINT32_MAX * Pareto_80_20_6[0]);
	data.probabilityRanges[5] = (uint32_t)(UINT32_MAX * (1. - Pareto_80_20_6[6]));
	for ( size_t i=1; i<5; ++i )
		data.probabilityRanges[i] = data.probabilityRanges[i-1] + (uint32_t)(UINT32_MAX * Pareto_80_20_6[i]);
	data.offsets[0] = 0;
	data.offsets[7] = itemCount;
	for ( size_t i=0; i<6; ++i )
		data.offsets[i+1] = data.offsets[i] + (uint32_t)(itemCount * Pareto_80_20_6[6-i]);
}

FORCE_INLINE
size_t Pareto_80_20_6_Rand( const Pareto_80_20_6_Data& data, uint32_t rnum1, uint32_t rnum2 )
{
	size_t idx = 6;
	if ( rnum1 < data.probabilityRanges[0] )
		idx = 0;
	else if ( rnum1 < data.probabilityRanges[1] )
		idx = 1;
	else if ( rnum1 < data.probabilityRanges[2] )
		idx = 2;
	else if ( rnum1 < data.probabilityRanges[3] )
		idx = 3;
	else if ( rnum1 < data.probabilityRanges[4] )
		idx = 4;
	else if ( rnum1 < data.probabilityRanges[5] )
		idx = 5;
	uint32_t rangeSize = data.offsets[ idx + 1 ] - data.offsets[ idx ];
	uint32_t offsetInRange = rnum2 % rangeSize;
	return data.offsets[ idx ] + offsetInRange;
}

void fillSegmentWithRandomData( uint8_t* ptr, size_t sz, size_t reincarnation )
{
	PRNG rng( ((uintptr_t)ptr) ^ ((uintptr_t)sz << 32) ^ reincarnation );
	for ( size_t i=0; i<(sz>>2); ++i )
		(reinterpret_cast<uint32_t*>(ptr))[i] = rng.rng32();
	ptr += (sz>>2)<<2;
	if ( sz & 3 )
	{
		uint32_t last = rng.rng32();
		for ( size_t i=0; i<(sz&3); ++i )
		{
			(ptr)[i] = (uint8_t)last;
			last >>= 8;
		}
	}
}
void checkSegment( uint8_t* ptr, size_t sz, size_t reincarnation )
{
	PRNG rng( ((uintptr_t)ptr) ^ ((uintptr_t)sz << 32) ^ reincarnation );
	for ( size_t i=0; i<(sz>>2); ++i )
		if ( (reinterpret_cast<uint32_t*>(ptr))[i] != rng.rng32() )
		{
			printf( "memcheck failed for ptr=%zd, size=%zd, reincarnation=%zd, from %zd\n", (size_t)(ptr), sz, reincarnation, i*4 );
			throw std::bad_alloc();
		}
	ptr += (sz>>2)<<2;
	if ( sz & 3 )
	{
		uint32_t last = rng.rng32();
		for ( size_t i=0; i<(sz&3); ++i )
		{
			if( (ptr)[i] != (uint8_t)last )
			{
			printf( "memcheck failed for ptr=%zd, size=%zd, reincarnation=%zd, from %zd\n", (size_t)(ptr), sz, reincarnation, ((sz>>2)<<2) + i );
				throw std::bad_alloc();
			}
			last >>= 8;
		}
	}
}

template< class AllocatorUnderTest, MEM_ACCESS_TYPE mat>
void randomPos_RandomSize( AllocatorUnderTest& allocatorUnderTest, size_t iterCount, size_t maxItems, size_t maxItemSizeExp, size_t threadID, size_t rnd_seed )
{
	if( maxItemSizeExp >= 32 )
	{
		printf( "allocation sizes greater than 2^31 are not yet supported; revise implementation, if desired\n" );
		throw std::bad_exception();
	}

	static constexpr const char* memAccessTypeStr = mat == MEM_ACCESS_TYPE::none ? "none" : ( mat == MEM_ACCESS_TYPE::single ? "single" : ( mat == MEM_ACCESS_TYPE::full ? "full" : ( mat == MEM_ACCESS_TYPE::check ? "check" : "unknown" ) ) );
	printf( "    running thread %zd with \'%s\' and maxItemSizeExp = %zd, maxItems = %zd, iterCount = %zd, allocated memory access mode: %s,  [rnd_seed = %llu] ...\n", threadID, allocatorUnderTest.name(), maxItemSizeExp, maxItems, iterCount, memAccessTypeStr, rnd_seed );
	constexpr bool doMemAccess = mat != MEM_ACCESS_TYPE::none;
	allocatorUnderTest.init();
	allocatorUnderTest.getTestRes()->threadID = threadID; // just as received
	allocatorUnderTest.getTestRes()->rdtscBegin = get_timestamp();

	size_t start = GetMillisecondCount();

	size_t dummyCtr = 0;
	size_t rssMax = 0;
	size_t rss;
	size_t allocatedSz = 0;
	size_t allocatedSzMax = 0;

	uint32_t reincarnation = 0;

	Pareto_80_20_6_Data paretoData;
	assert( maxItems <= UINT32_MAX );
	Pareto_80_20_6_Init( paretoData, (uint32_t)maxItems );

	struct TestBin
	{
		uint8_t* ptr;
		uint32_t sz;
		uint32_t reincarnation;
	};

	TestBin* baseBuff = nullptr;
	//if constexpr ( !allocatorUnderTest.isFake() )
		baseBuff = reinterpret_cast<TestBin*>( allocatorUnderTest.allocate( maxItems * sizeof(TestBin) ) );
	//else
	//	baseBuff = reinterpret_cast<TestBin*>( allocatorUnderTest.allocateSlots( maxItems * sizeof(TestBin) ) );
	assert( baseBuff );
	allocatedSz +=  maxItems * sizeof(TestBin);
	memset( baseBuff, 0, maxItems * sizeof( TestBin ) );

	PRNG rng(rnd_seed);

	// setup (saturation)
	for ( size_t i=0;i<maxItems/32; ++i )
	{
		uint32_t randNum = rng.rng32();
		for ( size_t j=0; j<32; ++j )
			if ( (randNum >> j) & 1 )
			{
				size_t randNumSz = rng.rng64();
				size_t sz = calcSizeWithStatsAdjustment( randNumSz, maxItemSizeExp );
				baseBuff[i*32+j].sz = (uint32_t)sz;
				baseBuff[i*32+j].ptr = reinterpret_cast<uint8_t*>( allocatorUnderTest.allocate( sz ) );
				if constexpr ( doMemAccess )
				{
					if constexpr ( mat == MEM_ACCESS_TYPE::full )
						memset( baseBuff[i*32+j].ptr, (uint8_t)sz, sz );
					else
					{
						if constexpr ( mat == MEM_ACCESS_TYPE::single )
							baseBuff[i*32+j].ptr[sz/2] = (uint8_t)sz;
						else
						{
							static_assert( mat == MEM_ACCESS_TYPE::check, "" );
							baseBuff[i*32+j].reincarnation = reincarnation;
							fillSegmentWithRandomData( baseBuff[i*32+j].ptr, sz, reincarnation++ );
						}
					}
				}
				allocatedSz += sz;
			}
	}
	allocatorUnderTest.doWhateverAfterSetupPhase();
	allocatorUnderTest.getTestRes()->rdtscSetup = get_timestamp();
	allocatorUnderTest.getTestRes()->allocatedAfterSetupSz = allocatedSz;

	rss = getRss();
	if ( rssMax < rss ) rssMax = rss;

	// main loop
	for ( size_t k=0 ; k<32; ++k )
	{
		for ( size_t j=0;j<iterCount>>5; ++j )
		{
			uint32_t rnum1 = rng.rng32();
			uint32_t rnum2 = rng.rng32();
			size_t idx = Pareto_80_20_6_Rand( paretoData, rnum1, rnum2 );
			if ( baseBuff[idx].ptr )
			{
				if constexpr ( doMemAccess )
				{
					if constexpr ( mat == MEM_ACCESS_TYPE::full )
					{
						size_t i=0;
						for ( ; i<baseBuff[idx].sz/sizeof(size_t ); ++i )
							dummyCtr += ( reinterpret_cast<size_t*>( baseBuff[idx].ptr) )[i];
						uint8_t* tail = baseBuff[idx].ptr + i * sizeof(size_t );
						for ( i=0; i<baseBuff[idx].sz % sizeof(size_t); ++i )
							dummyCtr += tail[i];
					}
					else
					{
						if constexpr ( mat == MEM_ACCESS_TYPE::single )
							dummyCtr += baseBuff[idx].ptr[baseBuff[idx].sz/2];
						else
						{
							static_assert( mat == MEM_ACCESS_TYPE::check, "" );
							checkSegment( baseBuff[idx].ptr, baseBuff[idx].sz, baseBuff[idx].reincarnation );
						}
					}
				}
#ifdef COLLECT_USER_MAX_ALLOCATED
				allocatedSz -= baseBuff[idx].sz;
#endif
				allocatorUnderTest.deallocate( baseBuff[idx].ptr );
				baseBuff[idx].ptr = 0;
			}
			else
			{
				size_t sz = calcSizeWithStatsAdjustment( rng.rng64(), maxItemSizeExp );
				baseBuff[idx].sz = (uint32_t)sz;
				baseBuff[idx].ptr = reinterpret_cast<uint8_t*>( allocatorUnderTest.allocate( sz ) );
				if constexpr ( doMemAccess )
				{
					if constexpr ( mat == MEM_ACCESS_TYPE::full )
						memset( baseBuff[idx].ptr, (uint8_t)sz, sz );
					else
					{
						if constexpr ( mat == MEM_ACCESS_TYPE::single )
							baseBuff[idx].ptr[sz/2] = (uint8_t)sz;
						else
						{
							static_assert( mat == MEM_ACCESS_TYPE::check, "" );
							baseBuff[idx].reincarnation = reincarnation;
							fillSegmentWithRandomData( baseBuff[idx].ptr, sz, reincarnation++ );
						}
					}
				}
#ifdef COLLECT_USER_MAX_ALLOCATED
				allocatedSz += sz;
				if ( allocatedSzMax < allocatedSz )
					allocatedSzMax = allocatedSz;
#endif
			}
		}
		rss = getRss();
		if ( rssMax < rss ) rssMax = rss;
	}
	allocatorUnderTest.doWhateverAfterMainLoopPhase();
	allocatorUnderTest.getTestRes()->rdtscMainLoop = get_timestamp();
	allocatorUnderTest.getTestRes()->allocatedMax = allocatedSzMax;

	// exit
	for ( size_t idx=0; idx<maxItems; ++idx )
		if ( baseBuff[idx].ptr )
		{
			if constexpr ( doMemAccess )
			{
				if constexpr ( mat == MEM_ACCESS_TYPE::full )
				{
					size_t i=0;
					for ( ; i<baseBuff[idx].sz/sizeof(size_t ); ++i )
						dummyCtr += ( reinterpret_cast<size_t*>( baseBuff[idx].ptr) )[i];
					uint8_t* tail = baseBuff[idx].ptr + i * sizeof(size_t );
					for ( i=0; i<baseBuff[idx].sz % sizeof(size_t); ++i )
						dummyCtr += tail[i];
				}
				else
				{
						if constexpr ( mat == MEM_ACCESS_TYPE::single )
							dummyCtr += baseBuff[idx].ptr[baseBuff[idx].sz/2];
						else
						{
							static_assert( mat == MEM_ACCESS_TYPE::check, "" );
							checkSegment( baseBuff[idx].ptr, baseBuff[idx].sz, baseBuff[idx].reincarnation );
						}
				}
			}
			allocatorUnderTest.deallocate( baseBuff[idx].ptr );
		}

	//if constexpr ( !allocatorUnderTest.isFake() )
		allocatorUnderTest.deallocate( baseBuff );
	//else
	//	allocatorUnderTest.deallocateSlots( baseBuff );
	allocatorUnderTest.deinit();
	allocatorUnderTest.getTestRes()->rdtscExit = get_timestamp();
	allocatorUnderTest.getTestRes()->innerDur = GetMillisecondCount() - start;
	allocatorUnderTest.doWhateverAfterCleanupPhase();

	rss = getRss();
	if ( rssMax < rss ) rssMax = rss;
	allocatorUnderTest.getTestRes()->rssMax = rssMax;

	printf( "about to exit thread %zd (%zd operations performed) [ctr = %zd]...\n", threadID, iterCount, dummyCtr );
};

#endif // ALLOCATOR_TESTER_H
