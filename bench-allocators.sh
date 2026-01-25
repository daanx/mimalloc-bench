#!/bin/bash
set -e

BNAME="mimalloc-bench"

# Collect metadata
GITCOMMIT=$(git rev-parse HEAD)
GITCLEANSTATUS=$( [ -z "$( git status --porcelain )" ] && echo \"Clean\" || echo \"Uncommitted changes\" )
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# CPU type on linuxy
CPUTYPE=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d':' -f2-)
if [ -z "${CPUTYPE}" ] ; then
    # CPU type on macos
    CPUTYPE=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
fi
CPUTYPE=${CPUTYPE:-Unknown}
CPUTYPE=${CPUTYPE## }  # Trim leading space

CPUTYPESTR="${CPUTYPE//[^[:alnum:]]/}"
OSTYPESTR="${OSTYPE//[^[:alnum:]]/}"

CPUCOUNT=$(nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo "${NUMBER_OF_PROCESSORS:-unknown}")

ARGS=$*

CPUSTR_DOT_OSSTR="${CPUTYPESTR}.${OSTYPESTR}"
OUTPUT_DIR="${OUTPUT_DIR:-./bench/results}/${CPUSTR_DOT_OSSTR}"

RESF="${OUTPUT_DIR}/${BNAME}.result.txt"
GRAPH_BASE="${OUTPUT_DIR}/${BNAME}.graph-"

mkdir -p tmp
mkdir -p ${OUTPUT_DIR}
rm -f $RESF

echo "GITCOMMIT: ${GITCOMMIT}" 2>&1 | tee -a $RESF
echo "GITCLEANSTATUS: ${GITCLEANSTATUS}" 2>&1 | tee -a $RESF
echo "CPUTYPE: ${CPUTYPE}" 2>&1 | tee -a $RESF
echo "OSTYPE: ${OSTYPE}" 2>&1 | tee -a $RESF
echo "CPUCOUNT: ${CPUCOUNT}" 2>&1 | tee -a $RESF

mkdir -p ${OUTPUT_DIR}

ALLOCATORS="sys je sn mi2 rp s"

# I picked these ones because I imagine they are more representative of real workloads than the
# other benchmarks in here.
BENCHES="gs lean lua"

EXTRA_BENCHES="rocksdb linux"

# Platform-specific exclusions
case "$OSTYPE" in
    msys*)
        # Windows: no jemalloc or snmalloc
        ALLOCATORS="${ALLOCATORS//je/}"
        ALLOCATORS="${ALLOCATORS//sn/}"
        ;;
    darwin*)
        # macOS: no rpmalloc (it doesn't build the C wrapper support)
        ALLOCATORS="${ALLOCATORS//rp/}"

        # macOS: these two tests don't build
        EXTRA_BENCHES="${EXTRA_BENCHES//rocksdb/}"
        EXTRA_BENCHES="${EXTRA_BENCHES//linux/}"
        ;;
esac

./build-bench-env.sh ${ALLOCATORS} packages bench ${EXTRA_BENCHES} &&

(
    cd out/bench &&
    ../../bench.sh ${ALLOCATORS} ${BENCHES} ${EXTRA_BENCHES}
) 2>&1 | tee tmp/log.txt

echo "#------------------------------------------------------------------" >> $RESF &&
echo "# test    alloc   time  rss    user  sys  page-faults page-reclaims" >> $RESF &&

cat out/bench/benchres.csv >> $RESF &&

echo "# Results are in \"${RESF}\" ."
