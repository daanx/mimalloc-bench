# CPU type on linuxy
CPUTYPE=`grep "model name" /proc/cpuinfo 2>/dev/null | uniq | cut -d':' -f2-`

if [ "x${CPUTYPE}" = "x" ] ; then
    # CPU type on macos
    CPUTYPE=`sysctl -n machdep.cpu.brand_string 2>/dev/null`
fi

CPUTYPE="${CPUTYPE//[^[:alnum:]]/}"

OSTYPESTR="${OSTYPE//[^[:alnum:]]/}"

ARGS=$*
ARGSSTR="${ARGS//[^[:alnum:]]/}"

BNAME="mimalloc-bench"
FNAME="${BNAME}.result.${CPUTYPE}.${OSTYPESTR}.${ARGSSTR}.txt"
RESF="tmp/${FNAME}"

echo "# Saving result into \"${RESF}\""

rm -f $RESF
mkdir -p tmp

echo "# git log -1 | head -1" 2>&1 | tee -a $RESF
git log -1 | head -1 2>&1 | tee -a $RESF
echo 2>&1 | tee -a $RESF

echo "( [ -z \"\$(git status --porcelain)\" ] && echo \"Clean\" || echo \"Uncommitted changes\" )" 2>&1 | tee -a $RESF
( [ -z "$(git status --porcelain)" ] && echo "Clean" || echo "Uncommitted changes" ) 2>&1 | tee -a $RESF
echo 2>&1 | tee -a $RESF

echo CPU type: 2>&1 | tee -a $RESF
echo $CPUTYPE 2>&1 | tee -a $RESF
echo 2>&1 | tee -a $RESF

echo OS type: 2>&1 | tee -a $RESF
echo $OSTYPE 2>&1 | tee -a $RESF
echo 2>&1 | tee -a $RESF

if [ "x${OSTYPE}" = "xmsys" ]; then
    # No jemalloc or snmalloc on windows
    ALLOCATORS="mi2 rp s"
else
    ALLOCATORS="je sn mi2 rp s"
fi

# I picked these ones because I imagine they are more representative of real workloads than the
# other benchmarks in here.
BENCHES="gs leanN lua"

EXTRA_BENCHES="rocksdb linux redis"

./build-bench-env.sh ${ALLOCATORS} packages bench ${EXTRA_BENCHES} &&

(
    cd out/bench &&
    ../../bench.sh ${ALLOCATORS} ${BENCHES} ${EXTRA_BENCHES}
) 2>&1 | tee tmp/log.txt

echo "#------------------------------------------------------------------" >> $RESF &&
echo "# test    alloc   time  rss    user  sys  page-faults page-reclaims" >> $RESF &&

cat out/bench/benchres.csv >> $RESF &&

echo "# Results are in \"${RESF}\" ."
