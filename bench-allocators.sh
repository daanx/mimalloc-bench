echo CPU type:

# print out CPU type on macos
sysctl -n machdep.cpu.brand_string 2>/dev/null

# print out CPU type on linux
grep "model name" /proc/cpuinfo 2>/dev/null | uniq

ALLOCATORS="je mi2 rp sn s"

BUILD_TESTS="rocksdb linux"

# I picked these ones because I imagine they are more representative of real workloads than the
# other benchmarks in here.
BENCHES="gs leanN lua"

EXTRA_BENCHES="rocksdb linux"

./build-bench-env.sh ${ALLOCATORS} packages bench ${EXTRA_BENCHES}

cd out/bench

../../bench.sh ${ALLOCATORS} ${BENCHES} ${EXTRA_BENCHES}
