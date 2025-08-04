CFLAGS+="-march=native"
CXXFLAGS+="-march=native"

SUDO="sudo"
ifeq ($(shell whoami), 'root')
	echo "running as root, avoid doing this if possible."
	SUDO=""
endif

DARWIN="no"
PROCS=$(shell nproc)
EXTSO="so"
SHA256SUM="sha256sum"

ifeq ($(shell uname), 'Darwin')
	DARWIN="yes"
	PROCS=$(shell sysctl -n hw.physicalcpu)
	EXTSO="dylib"
	SHA256SUM="shasum -a 256"
endif

BENCHMARKS_BIG=lean lua redis rocksdb
ALLOCS = dh ff fg gd hd hm iso je lp lf lt mesh mi mi2 mng nomesh pa rp sc scudo sg sm sn tbb tc tcg yal

PDFDOC=bench/large.pdf

.PHONY: all benchmarks benchmarks_all benchmarks_big

all: $(ALLOCS) benchmarks_all

benchmarks_all: benchmarks $(BENCHMARKS_BIG)

benchmarks: bench/CMakeLists.txt bench/shbench/.patched $(PDFDOC)
	cmake -B out/bench -S bench
	cmake --build out/bench -j $(PROCS)

PDF_URL=https://raw.githubusercontent.com/geekaaron/Resources/master/resources/Writing_a_Simple_Operating_System--from_Scratch.pdf
#USERAGENT=Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:95.0) Gecko/20100101 Firefox/95.0
$(PDFDOC):
	wget --no-verbose -O $(PDFDOC) $(PDF_URL)

bench/shbench/.patched: bench/shbench/sh6bench.patch bench/shbench/sh6bench.c bench/shbench/sh8bench.patch bench/shbench/SH8BENCH.C
	dos2unix $(@D)/*.patch
	patch -p1 -o $(@D)/sh6bench-new.c $(@D)/sh6bench.c $(@D)/sh6bench.patch
	patch -p1 -o $(@D)/sh8bench-new.c $(@D)/SH8BENCH.C $(@D)/sh8bench.patch
	touch $@

bench/shbench/sh6bench.c: bench/shbench/bench.zip
	cd $(@D) && unzip -o $(<F)
	dos2unix $@

bench/shbench/SH8BENCH.C: bench/shbench/SH8BENCH.zip
	cd $(@D) && unzip -o $(<F)
	dos2unix $@

define err_msg
$@ does not have the expected checksum. Please delete the archive and retry. If this error persists, something is wrong.
endef

SH8BENCH_FILENAME=SH8BENCH.zip
SH8BENCH_SHA256SUM=12a8e75248c9dcbfee28245c12bc937a16ef56ec9cbfab88d0e348271667726f
bench_FILENAME=shbench/bench.zip
bench_SHA256SUM=506354d66b9eebef105d757e055bc55e8d4aea1e7b51faab3da35b0466c923a1
bench/shbench/%.zip:
	@cd $(@D) && wget -nc --no-verbose http://www.microquill.com/smartheap/$($*_FILENAME)
	@(echo "$($*_SHA256SUM) $@" | $(SHA256SUM) --check --status) || { echo $(err_msg); exit 1; }

dependencies:

########################################################################
# Environment flags for the individual make processes, may just be the #
# respective target name.                                              #
########################################################################

#Todo: only set this if not running on x86
gd_ENV=ARC4RNG=1
iso_ENV=library
lf_ENV=liblite-malloc-shared.so
lt_ENV=-C gnu.make.lib

########################################################################
# ALLOCS: generic targets for the standard scheme: download, unpack,   #
# configure (nop for the standard), compile (using make).              #
########################################################################

# Todo: check for the big benchmarks
$(ALLOCS) $(BENCHMARKS_BIG): %: extern/%/.built

extern/%/.built: extern/%/.unpacked
	make -C $(@D) $($*_ENV) -j$(PROCS)
	touch $@

extern/%/.unpacked: archives/%.tar.gz
	mkdir -p $(@D)
	tar -x --strip-components=1 -f $< -C $(@D)
	touch $@

.PRECIOUS: archives/%.tar.gz
archives/%.tar.gz:
	mkdir -p $(@D)
	wget -O $@ $(shell grep "$*:" VERSIONS | cut -d, -f3)/archive/$(shell grep "$*:" VERSIONS | cut -d, -f2| tr -d ' ').tar.gz

########################################################################
# ALLOCS: special cases
########################################################################

# dh: uses cmake
extern/dh/.configured: extern/dh/.unpacked
	cd $(@D) && rm -rf ./benchmarks/ ./src/exterminator/ ./src/local/ ./src/replicated/ ./docs
	cmake -S $(@D)/src -B $(@D)/build
	touch $@

extern/dh/.built: extern/dh/.configured
	cmake --build $(@D)/build -j $(PROCS)
	touch $@

# hml (hm light): built from the same source, differently configured
hm_ENV=CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=default
hml_ENV=CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=light
extern/hm/.built: extern/hm/.configured
	make -C $(@D) $(hm_ENV) -j$(PROCS)
	make -C $(@D) $(hml_ENV) -j$(PROCS)
	touch $@

# TODO: scudo needs only part of the source archive, maybe port partial_checkout to make and overwrite extern/scudo/.unpacked
extern/scudo/.built: extern/scudo/.configured
	cd $(@D)/compiler-rt/lib/scudo/standalone && clang++ -flto -fuse-ld=lld -fPIC -std=c++17 -fno-exceptions $CXXFLAGS -fno-rtti -fvisibility=internal -msse4.2 -O3 -I include -shared -o libscudo$extso *.cpp -pthread
# TODO: lp the same

extern/lean/.built: extern/lean/.unpacked
	mkdir -p $(@D)/out/release
	env CC=gcc CXX="g++" cmake -S $(@D)/src -B $(@D)/out/release -DCUSTOM_ALLOCATORS=OFF -DLEAN_EXTRA_CXX_FLAGS="-w" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
	make -C $(@D)/out/release -j$(PROCS)
	rm -rf $(@D)/out/release/tests
	mkdir -p extern/mathlib
	cp -u $(@D)/leanpkg/leanpkg.toml extern/mathlib
	touch $@

# lua only needs to be fetched, not more.
extern/lua/.built: extern/lua/.unpacked
