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
 * Memory allocator tester -- common
 * 
 * v.1.00    Jun-22-2018    Initial release
 * 
 * -------------------------------------------------------------------------------*/


#include "test_common.h"

#include <stdint.h>
#include <assert.h>

#ifdef _MSC_VER
#include <Windows.h>
#else
#include <time.h>
#endif


int64_t GetMicrosecondCount()
{
	int64_t now = 0;
#ifdef _MSC_VER
	static int64_t frec = 0;
	if (frec == 0)
	{
		LARGE_INTEGER val;
		BOOL ok = QueryPerformanceFrequency(&val);
		assert(ok);
		frec = val.QuadPart;
	}
	LARGE_INTEGER val;
	BOOL ok = QueryPerformanceCounter(&val);
	assert(ok);
	now = (val.QuadPart * 1000000) / frec;
#endif
	return now;
}



NOINLINE
size_t GetMillisecondCount()
{
    size_t now;
#ifdef _MSC_VER
	static uint64_t frec = 0;
	if (frec == 0)
	{
		LARGE_INTEGER val;
		BOOL ok = QueryPerformanceFrequency(&val);
		assert(ok);
		frec = val.QuadPart / 1000;
	}
	LARGE_INTEGER val;
	BOOL ok = QueryPerformanceCounter(&val);
	assert(ok);
	now = val.QuadPart / frec;
	
#else
#if 1
    struct timespec ts;
    timespec_get(&ts, TIME_UTC);//clock get time monotonic
    now = (uint64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000; // mks
#else
    struct timeval now_;
    gettimeofday(&now_, NULL);
    now = now_.tv_sec;
    now *= 1000;
    now += now_.tv_usec / 1000000;
#endif
#endif
    return now;
}

#ifdef _MSC_VER
#include <psapi.h>
size_t getRss()
{
    HANDLE hProcess;
    PROCESS_MEMORY_COUNTERS pmc;
	hProcess = GetCurrentProcess();
	BOOL ok = GetProcessMemoryInfo( hProcess, &pmc, sizeof(pmc));
    CloseHandle( hProcess );
    if ( ok )
		return pmc.PagefileUsage >> 12; // note: we may also be interested in 'PeakPagefileUsage'
	else
		return 0;
}
#elif defined(__APPLE__)
#include <unistd.h>
size_t getRss() {
	struct rusage rusage;
  getrusage(RUSAGE_SELF, &rusage);
	return rusage.ru_maxrss;
}
#else
size_t getRss()
{
	// see http://man7.org/linux/man-pages/man5/proc.5.html for details
	FILE* fstats = fopen( "/proc/self/statm", "rb" );
	constexpr size_t buffsz = 0x1000;
	char buff[buffsz];
	buff[buffsz-1] = 0;
	fread( buff, 1, buffsz-1, fstats);
	fclose( fstats);
	const char* pos = buff;
	while ( *pos && *pos == ' ' ) ++pos;
	while ( *pos && *pos != ' ' ) ++pos;
	return atol( pos );
}
#endif

