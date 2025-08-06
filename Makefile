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
	export HOMEBREW_NO_EMOJI=1
endif

BENCHMARKS_EXTERN=lean lua redis rocksdb
ALLOCS_TRIVIAL = ff iso je lf mng sg tbb tc
ALLOCS_NONTRIVIAL = dh fg gd hd hm lp lt mesh mi mi2 nomesh rp sc scudo sm sn tcg yal
PDFDOC=extern/large.pdf

.PHONY: all allocs benchmarks benchmarks_all benchmarks_big

all: allocs benchmarks_all
allocs: $(ALLOCS_TRIVIAL) $(ALLOCS_NONTRIVIAL)
benchmarks_all: benchmarks $(BENCHMARKS_EXTERN)

benchmarks: bench/CMakeLists.txt bench/shbench/.patched $(PDFDOC)
	cmake -B out/bench -S bench
	cmake --build out/bench -j $(PROCS)

PDF_URL=https://raw.githubusercontent.com/geekaaron/Resources/master/resources/Writing_a_Simple_Operating_System--from_Scratch.pdf
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
hd_ENV=-C src
redis_ENV=USE_JEMALLOC=no MALLOC=libc BUILD_TLS=no -C src
rocksdb_ENV=DISABLE_WARNING_AS_ERROR=1 DISABLE_JEMALLOC=1 ROCKSDB_DISABLE_TCMALLOC=1 db_bench
########################################################################
# ALLOCS: generic targets for the standard scheme: download, unpack,   #
# configure (nop for the standard), compile (using make).              #
########################################################################

# Todo: check for the big benchmarks
$(ALLOCS_TRIVIAL) $(BENCHMARKS_EXTERN): %: extern/%/.built
$(ALLOCS_NONTRIVIAL): %: extern/%/.built

extern/%/.built: extern/%/.unpacked
	make -C $(@D) $($*_ENV) -j$(PROCS)
	touch $@

extern/%/.unpacked: archives/%.tar.gz
	mkdir -p $(@D)
	tar -x --strip-components=1 --overwrite -f $< -C $(@D)
	touch $@

.PRECIOUS: archives/%.tar.gz
archives/%.tar.gz:
	mkdir -p $(@D)
	wget -O $@ $(shell grep "$*:" VERSIONS | cut -d, -f3)/archive/$(shell grep "$*:" VERSIONS | cut -d, -f2| tr -d ' ').tar.gz

########################################################################
# ALLOCS: special cases
########################################################################
#dh: uses cmake
extern/dh/.configured: extern/dh/.unpacked
	cd $(@D) && rm -rf ./benchmarks/ ./src/exterminator/ ./src/local/ ./src/replicated/ ./docs
	cmake -S $(@D)/src -B $(@D)/build
	touch $@

extern/dh/.built: extern/dh/.configured
	cmake --build $(@D)/build -j $(PROCS)
	touch $@

#hd: fix in Makefile. If later ported into a patch, hd can be reintegrated with ALLOCS_TRIVIAL
extern/hd/.built: extern/hd/.unpacked
	sed -i_orig 's/-arch arm64/ /g' $(@D)/src/GNUmakefile
	make -C $(@D) $(hd_ENV) -j$(PROCS)
	touch $@

#hm/hml (hm light): built from the same source, differently configured
hm_ENV=CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=default
hml_ENV=CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=light
extern/hm/.built: extern/hm/.configured
	make -C $(@D) $(hm_ENV) -j$(PROCS)
	make -C $(@D) $(hml_ENV) -j$(PROCS)
	touch $@

#je: needs configure
extern/je/.built: extern/je/config.status
	make -C $(@D) -j$(PROCS)
	touch @

extern/je/config.status: extern/je/.unpacked
	cd $(@D) && ./autogen.sh --enable-doc=no --enable-static=no --disable-stats

# mi,mi2: cmake, and 3 different variants
extern/mi/.built extern/mi2/.built: extern/%/.built: extern/%/.unpacked
	cmake -S $(@D) -B $(@D)/out/release
	cmake --build $(@D)/out/release -j$(PROCS)
	cmake -S $(@D) -B $(@D)/out/debug -DMI_CHECK_FULL=ON
	cmake --build $(@D)/out/debug -j$(PROCS)
	cmake -S $(@D) -B $(@D)/out/secure -DMI_SECURE=ON
	cmake --build $(@D)/out/secure -j$(PROCS)
	touch $@

#rp: uses ninja, one fix in build.ninja
extern/rp/build.ninja: extern/rp/.unpacked
	cd $(@D) && python3 configure.py
	sed -i 's/-Werror//' $(@D)/build.ninja

extern/rp/.built: extern/rp/build.ninja
	cd $(@D) && ninja
	touch $@

#sc: gyp -> make
sc_ENV=BUILDTYPE=Release
extern/sc/.built: extern/sc/Makefile
	make -C $(@D) $(sc_ENV) -j$(PROCS)
	touch $@

extern/sc/Makefile: extern/sc/build/gyp/gyp
	cd $(@D) && build/gyp/gyp --depth=. scalloc.gyp

extern/sc/build/gyp/gyp: extern/sc/.unpacked
	cd extern/sc && tools/make_deps.sh

#scudo: native clang, in a sub-directory
extern/scudo/.built: extern/scudo/.unpacked
	cd $(@D)/compiler-rt/lib/scudo/standalone && clang++ -flto -fuse-ld=lld -fPIC -std=c++17 -fno-exceptions $(CXXFLAGS) -fno-rtti -fvisibility=internal -msse4.2 -O3 -I include -shared -o libscudo$extso *.cpp -pthread
	touch $@

#sm: make, but a fix before
extern/sm/.built: extern/sm/.unpacked
	rm -rf ./$(@D)/doc ./$(@D)/paper ./$(@D)/short-talk ./$(@D)/talk
	sed -i "s/-Werror//" $(@D)/Makefile.include
	make -C $(@D)/release -j$(PROCS) ../release/lib/libsupermalloc.so

#sn: cmake+ninja, builds in sn/release
extern/sn/.built: extern/sn/build.ninja
	cd $(@D)/release && ninja libsnmallocshim.$(EXTSO) libsnmallocshim-checks.$(EXTSO)
	touch $@

extern/sn/build.ninja: extern/sn/.unpacked
	env CXX=clang++ cmake -S $(@D) -B $(@D)/release -G Ninja -DCMAKE_BUILD_TYPE=Release

#tcg: bazel
extern/tcg/.built: extern/tcg/.unpacked
	cd $(@D) && bazel build -c opt tcmalloc
	touch $@

#yal: custom shell script
extern/yal/.built: extern/yal/.unpacked
	cd $(@D) && ./build.sh -V
	touch $@

########################################################################
# benchmarks residing in ./extern                                      #
########################################################################
# lean: cmake, additional mathlib setup
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
	touch $@
