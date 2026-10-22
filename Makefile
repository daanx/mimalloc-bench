SUDO=sudo
ifeq ($(shell whoami), root)
$(warning running as root, avoid doing this if possible.)
SUDO=
endif

DARWIN=no
PROCS=$(shell nproc)
EXTSO=so
SHA256SUM=sha256sum
SHA256SUM_FLAGS=-c --status
ORIG=

ifeq ($(shell uname), Darwin)
DARWIN=yes
PROCS=$(shell sysctl -n hw.physicalcpu)
EXTSO=dylib
SHA256SUM=shasum -a 256
SHA256SUM_FLAGS=-c -s
export HOMEBREW_NO_EMOJI=1
ORIG=_orig
endif

ifneq ($(shell grep -e 'ID=alpine' /etc/os-release),)
SHA256SUM_FLAGS=-c -s
endif

BENCHMARKS_EXTERN=lean linux lua mathlib redis rocksdb
ALLOCS = dh ff fg gd hd hm iso je kp lf lp lt mesh mi mi2 mi3 mng nomesh rmalloc rp s sc scudo sg sm sn tbb tc tcg yal
PDFDOC=extern/large.pdf

########################################################################
# Environment flags for the individual make processes, may just be the  #
# respective target name.                                              #
########################################################################

fg_ENV=SSE2RNG=1
iso_ENV=library
mesh_ENV=build
lf_ENV=liblite-malloc-shared.so
lt_ENV=-C gnu.make.lib
hd_ENV=-C src
redis_ENV=USE_JEMALLOC=no MALLOC=libc BUILD_TLS=no -C src
rocksdb_ENV=DISABLE_WARNING_AS_ERROR=1 DISABLE_JEMALLOC=1 ROCKSDB_DISABLE_TCMALLOC=1 db_bench

# TODO: Mac seems to report 'arm64' here
ifeq ($(shell uname -m), aarch64)
ALLOCS := $(filter-out fg lt mesh nomesh sc sm tcg, $(ALLOCS))
endif

all: allocs benchmarks_all
allocs: $(ALLOCS)
benchmarks_all: benchmarks $(BENCHMARKS_EXTERN)

# TODO: Mac seems to report 'arm64' here
ifeq ($(shell uname -m), aarch64)
# gd uses SSE on x86, but ARC4 on ARM - and arc4 needs a fix
gd_ENV := ARC4RNG=1
extern/gd/.built: extern/gd/.unpacked
	sed -i_orig 's/getentropy(/_getentropy(/g' $(@D)/rng/arc4random.{c,h}
	make -C $(@D) $(gd_ENV) -j$(PROCS)
	touch $@
endif

.PHONY: all allocs benchmarks benchmarks_all benchmarks_big clean-archives

benchmarks: bench/CMakeLists.txt bench/shbench/sh6bench-new.c bench/shbench/sh8bench-new.c $(PDFDOC)
	cmake -B out/bench -S bench
	cmake --build out/bench -j $(PROCS)

PDF_URL=https://raw.githubusercontent.com/geekaaron/Resources/master/resources/Writing_a_Simple_Operating_System--from_Scratch.pdf
$(PDFDOC):
	mkdir -p extern
	wget --no-verbose -O $(PDFDOC) $(PDF_URL)

bench/shbench/sh6bench-new.c: bench/shbench/sh6bench.patch bench/shbench/sh6bench.c
	dos2unix $<
	patch -p1 -o $@ $(filter-out $<, $^) $<

bench/shbench/sh8bench-new.c: bench/shbench/sh8bench.patch bench/shbench/SH8BENCH.C
	dos2unix $<
	patch -p1 -o $@ $(filter-out $<, $^) $<

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
	@(echo "$($*_SHA256SUM) $@" | $(SHA256SUM) $(SHA256SUM_FLAGS)) || { echo $(err_msg); exit 1; }

########################################################################
# ALLOCS: generic targets for the standard scheme: download, unpack,   #
# configure (nop for the standard), compile (using make).              #
########################################################################

# Todo: check for the big benchmarks
$(BENCHMARKS_EXTERN): %: extern/%/.built
$(ALLOCS): %: extern/%/.built

extern/%/.built: extern/%/.unpacked
	make -C $(@D) $($*_ENV) -j$(PROCS)
	touch $@

dh_TAR_FLAG=--wildcards --exclude=*/docs --exclude=*/benchmarks --exclude=*/src/{exterminator,local,replicated}
sm_TAR_FLAG=--wildcards --exclude=*/{.junk,benchmarks,coverage,debug,doc,other-mallocs,paper,short-talk,talk,tests,tools}

define parse_version =
	$(eval $1_URL		:= $(shell grep "^$(1):" VERSIONS | cut -d, -f3))
	$(eval $1_VERSION	:= $(shell grep "^$(1):" VERSIONS | cut -d, -f2| tr -d ' '))
	$(eval $1_LABEL		:= $(shell grep "^$(1):" VERSIONS | cut -d, -f1 | cut -d: -f2 | tr -d ' '))
endef

$(foreach alloc,$(ALLOCS),$(eval $(call parse_version,$(alloc))))
$(foreach bench,$(BENCHMARKS_EXTERN),$(eval $(call parse_version,$(bench))))

label_of = $($(1)_LABEL)

projects := $(filter-out lp scudo nomesh,$(ALLOCS) $(BENCHMARKS_EXTERN))
archives := $(foreach project,$(projects),archives/$(project)-$($(project)_LABEL).tar.gz)
clones := $(foreach project,lp scudo,archives/$(project)-$($(project)_LABEL).clone)

$(archives): archives/%.tar.gz:
	mkdir -p $(@D)
	wget -O $@ $($(firstword $(subst -, ,$*))_URL)/archive/$($(firstword $(subst -, ,$*))_VERSION).tar.gz

$(clones): archives/%.clone:
	mkdir -p $(@D)
	echo $* > $@

.SECONDEXPANSION:
extern/%/.unpacked: archives/%-$$(call label_of,$$*).tar.gz
	mkdir -p $(@D)
	tar -x --strip-components=1 --overwrite -f $< -C $(@D) $($*_TAR_FLAG)
	echo "$($*_LABEL) $($*_VERSION)" > $@

clean-archives:
	rm -f $(filter-out $(archives) $(clones),$(wildcard archives/*))

########################################################################
# ALLOCS: nontrivial cases
########################################################################
#dh: uses cmake
extern/dh/.configured: extern/dh/.unpacked
	cmake -S $(@D) -B $(@D)/build -D BUILD_DIEHARDER=1
	touch $@

extern/dh/.built: extern/dh/.configured
	cmake --build $(@D)/build -j $(PROCS)
	touch $@

#hd: fix in Makefile.
extern/hd/.built: extern/hd/.unpacked
	sed -i_orig 's/-arch arm64e//g' $(@D)/src/GNUmakefile
	sed -i_orig 's/-arch arm64//g' $(@D)/src/GNUmakefile
	make -C $(@D) $(hd_ENV) -j$(PROCS)
	touch $@

#hm/hml (hm light): built from the same source, differently configured
hm_ENV=CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=default
hml_ENV=CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=light
extern/hm/.built: extern/hm/.unpacked
	make -C $(@D) $(hm_ENV) -j$(PROCS)
	make -C $(@D) $(hml_ENV) -j$(PROCS)
	touch $@

#je: needs configure
extern/je/.built: extern/je/config.status
	make -C $(@D) -j$(PROCS)
	touch $@

extern/je/config.status: extern/je/.unpacked
	cd $(@D) && ./autogen.sh --enable-doc=no --enable-static=no --disable-stats

# lp: partial checkout and some fixes
extern/lp/.built: extern/lp/.unpacked
	cd $(@D)/Source/bmalloc/libpas && CC=clang CXX=clang++ LDFLAGS='-lpthread -latomic -pthread' bash ./build.sh -s cmake -v default -t pas_lib
	touch $@

extern/lp/.unpacked: archives/lp-$(lp_LABEL).clone
	rm -rf $(@D)
	git clone --depth 1 --no-checkout --filter=blob:none $(lp_URL) $(@D)
	printf '/*\n!/*/\n/Source/bmalloc/libpas/*\n' > $(@D)/.git/info/sparse-checkout
	git -C $(@D) config core.sparseCheckout true
	git -C $(@D) fetch --depth 1 origin $(lp_VERSION)
	git -C $(@D) checkout --detach FETCH_HEAD
	cd $(@D)/Source/bmalloc/libpas && sed -i $(ORIG) 's/extra_cmake_options=""/extra_cmake_options="-D_GNU_SOURCE=1"/' build.sh
	cd $(@D)/Source/bmalloc/libpas && sed -i $(ORIG) 's/cmake --build $$build_dir --parallel/cmake --build $$build_dir --target pas_lib --parallel/' build.sh
	echo "$(lp_LABEL) $(lp_VERSION)" > $@

# mi,mi2: cmake, and 3 different variants
extern/mi/.built extern/mi2/.built extern/mi3/.built: extern/%/.built: extern/%/.unpacked
	cmake -S $(@D) -B $(@D)/out/release
	cmake --build $(@D)/out/release -j$(PROCS)
	cmake -S $(@D) -B $(@D)/out/debug -DMI_CHECK_FULL=ON
	cmake --build $(@D)/out/debug -j$(PROCS)
	cmake -S $(@D) -B $(@D)/out/secure -DMI_SECURE=ON
	cmake --build $(@D)/out/secure -j$(PROCS)
	touch $@

# nomesh: built from mesh's source
nomesh_ENV=DISABLE_MESHING=ON build
extern/nomesh/.built: extern/mesh/.unpacked
	cp -r $(<D) $(@D)
	make -C $(@D) clean
	# only single job: https://github.com/plasma-umass/Mesh/issues/96
	make -C $(@D) $(nomesh_ENV)
	touch $@

# rmalloc: uses CMake
extern/rmalloc/.built: extern/rmalloc/.configured
	cmake --build $(@D)/build --preset linux-release -j$(PROCS)
	touch $@
extern/rmalloc/.configured: extern/rmalloc/.unpacked
	cmake -S $(@D) -B $(@D)/build --preset linux-release
	touch $@

#rp: uses ninja, one fix in build.ninja
extern/rp/build.ninja: extern/rp/.unpacked
	cd $(@D) && python3 configure.py
	sed -i 's/-Werror//' $(@D)/build.ninja

extern/rp/.built: extern/rp/build.ninja
	cd $(@D) && ninja
	touch $@

#kp: cmake, builds in kp/out
extern/kp/.built: extern/kp/.unpacked
	cmake -S $(@D) -B $(@D)/out -DCMAKE_BUILD_TYPE=Release
	cmake --build $(@D)/out -j $(PROCS)
	touch $@

#sc: gyp -> make
sc_ENV=BUILDTYPE=Release
extern/sc/.built: extern/sc/Makefile
	make -C $(@D) $(sc_ENV) -j$(PROCS)
	touch $@

extern/sc/Makefile: extern/sc/tools/gyp
	cd $(@D) && tools/gyp --depth=. scalloc.gyp

extern/sc/tools/gyp: extern/sc/.unpacked
	cd extern/sc && tools/make_deps.sh

#scudo: partial checkout, native clang, in a sub-directory
extern/scudo/.unpacked: archives/scudo-$(scudo_LABEL).clone
	rm -rf $(@D)
	git clone --depth 1 --no-checkout --filter=blob:none $(scudo_URL) $(@D)
	printf '/*\n!/*/\n/compiler-rt/lib/scudo/standalone/*\n' > $(@D)/.git/info/sparse-checkout
	git -C $(@D) config core.sparseCheckout true
	git -C $(@D) fetch --depth 1 origin $(scudo_VERSION)
	git -C $(@D) checkout --detach FETCH_HEAD
	echo "$(scudo_LABEL) $(scudo_VERSION)" > $@

extern/scudo/.built: extern/scudo/.unpacked
	cd $(@D)/compiler-rt/lib/scudo/standalone && clang++ -flto -fuse-ld=lld -fPIC -fno-exceptions $(CXXFLAGS) -fno-rtti -fvisibility=internal -O3 -I include -shared -o libscudo.$(EXTSO) *.cpp
	touch $@

#sm: make, but a fix before
extern/sm/.built: extern/sm/.unpacked
	sed -i "s/-Werror//" $(@D)/Makefile.include
	make -C $(@D)/release -j$(PROCS) ../release/lib/libsupermalloc.so
	touch $@

#sn: cmake+ninja, builds in sn/release
extern/sn/.built: extern/sn/release/build.ninja
	cd $(@D)/release && ninja libsnmallocshim.$(EXTSO) libsnmallocshim-checks.$(EXTSO)
	touch $@

extern/sn/release/build.ninja: extern/sn/.unpacked
	env CXX=clang++ cmake -S $(@D)/.. -B $(@D) -G Ninja -DCMAKE_BUILD_TYPE=Release

#tbb: cmake to configure
extern/tbb/.built: extern/tbb/.configured
	make -C $(@D) -j$(PROCS)
	touch $@

extern/tbb/.configured: extern/tbb/.unpacked
	cd $(@D) && cmake -DCMAKE_BUILD_TYPE=Release -DTBB_BUILD=OFF -DTBB_TEST=OFF -DTBB_OUTPUT_DIR_BASE=bench -DCMAKE_POLICY_VERSION_MINIMUM=3.5 .
	touch $@

#tc: autogen+configure
extern/tc/.built: extern/tc/Makefile
	make -C $(@D) -j $(PROCS)
	touch $@

extern/tc/Makefile: extern/tc/configure
	cd $(@D) && CXXFLAGS="$(CXXFLAGS) -w -DNDEBUG -O2" ./configure --enable-minimal --disable-debugalloc

extern/tc/configure: extern/tc/.unpacked
	cd $(@D) && ./autogen.sh

#tcg: bazel
extern/tcg/.built: extern/tcg/.unpacked
	cd $(@D) && bazel build -c opt tcmalloc
	touch $@

#s: rust workspace
extern/s/.built: extern/s/.unpacked
	cd $(@D) && cargo build --release --package smalloc-ffi
	touch $@

#yal: custom shell script
extern/yal/.built: extern/yal/.unpacked
	cd $(@D) && ./build.sh -V
	touch $@

########################################################################
# benchmarks residing in ./extern                                      #
########################################################################
# lean: cmake
extern/lean/.built: extern/lean/.unpacked
	patch -d $(@D) -p1 -N -r- < patches/lean.patch
	mkdir -p $(@D)/out/release
	env CC=gcc CXX="g++" cmake -S $(@D)/src -B $(@D)/out/release -DCUSTOM_ALLOCATORS=OFF -DLEAN_EXTRA_CXX_FLAGS="-w" -DCMAKE_POLICY_VERSION_MINIMUM=3.5
	make -C $(@D)/out/release -j$(PROCS) bin_lean
	touch $@

# mathlib only needs to be fetched; the benchmark itself builds it via leanpkg
extern/mathlib/.built: extern/mathlib/.unpacked
	touch $@

# lua only needs to be fetched, not more.
extern/lua/.built: extern/lua/.unpacked
	touch $@

# linux only needs to be fetched, not more.
extern/linux/.built: extern/linux/.unpacked
	touch $@
