#!/bin/bash
# Copyright 2018-2022, Microsoft Research, Daan Leijen, Julien Voisin, Matthew Parkinson

set -eo pipefail

CFLAGS='-march=native'
CXXFLAGS='-march=native'

procs=8
extso=".so"
case "$OSTYPE" in
  darwin*) 
    export HOMEBREW_NO_EMOJI=1
    darwin="1"
    extso=".dylib"
    procs=`sysctl -n hw.physicalcpu`;;
  *)
    darwin=""
    if command -v nproc > /dev/null; then 
      procs=`nproc`
    fi;;
esac

SUDO=sudo
if [ "$EUID" -eq 0 ]; then
  echo "[*] $0 is running as root, avoid doing this if possible."
  SUDO=""
fi

curdir=`pwd`
rebuild=0
all=0

# allocator versions
readonly version_dh=master   # ~unmaintained
readonly version_ff=4be6234
readonly version_gd=master   # ~unmaintained since 2021
readonly version_hd=5afe855  # 3.13 #a43ac40 #d880f72  #9d137ef37
readonly version_hm=11
readonly version_iso=1.2.2
readonly version_je=5.3.0
readonly version_lp=main
readonly version_lt=master  # ~ unmaintained since 2019
readonly version_mesh=7ef171c7870c8da1c52ff3d78482421f46beb94c
readonly version_mi=v1.7.6
readonly version_mng=master  # ~unmaintained
readonly version_nomesh=$version_mesh
readonly version_rp=1.4.4
readonly version_sc=v1.0.0
readonly version_scudo=main
readonly version_sg=master   # ~unmaintained since 2021
readonly version_sm=master   # ~unmaintained since 2017
readonly version_sn=0.6.0
readonly version_tbb=3a7f96d # v2021.5.0 + a fix for musl
readonly version_tc=gperftools-2.10
readonly version_tcg=0fdd7dce282523ed7f76849edf37d6a97eda007e

# benchmark versions
readonly version_redis=6.2.7
readonly version_lean=v3.4.2

# allocators
setup_dh=0
setup_ff=0
setup_gd=0
setup_hd=0
setup_hm=0
setup_iso=0
setup_je=0
setup_lp=0
setup_lt=0
setup_mesh=0
setup_mi=0
setup_mng=0
setup_nomesh=0
setup_rp=0
setup_sc=0
setup_scudo=0
setup_sg=0
setup_sm=0
setup_sn=0
setup_tbb=0
setup_tc=0
setup_tcg=0

# bigger benchmarks
setup_bench=0
setup_ch=0
setup_lean=0
setup_redis=0

# various
setup_packages=0


# Parse command-line arguments
while : ; do
  flag="$1"
  case "$flag" in
  *=*)  flag_arg="${flag#*=}";;
  no-*) flag_arg="0"
        flag="${flag#no-}";;
  none) flag_arg="0" ;;
  *)    flag_arg="1" ;;
  esac
  # echo "option: $flag, arg: $flag_arg"
  case "$flag" in
    "") break;;
    all|none)
        all=$flag_arg
        setup_dh=$flag_arg
        setup_ff=$flag_arg
        setup_gd=$flag_arg
        setup_hd=$flag_arg              
        setup_iso=$flag_arg
        setup_je=$flag_arg
        setup_lp=$flag_arg
        setup_mi=$flag_arg
        setup_sn=$flag_arg
        setup_sg=$flag_arg
        setup_tbb=$flag_arg
        setup_tc=$flag_arg
        if [ -z "$darwin" ]; then
          setup_tcg=$flag_arg       # lacking 'malloc.h'
          setup_dh=$flag_arg        
          setup_lt=$flag_arg        # GNU only
          setup_mng=$flag_arg       # lacking getentropy()
          setup_hm=$flag_arg        # lacking <thread.h>
          setup_mesh=$flag_arg          
          setup_rp=$flag_arg
          setup_scudo=$flag_arg     # lacking <sys/auxv.h>
          setup_sm=$flag_arg        # ../src/supermalloc.h:10:31: error: expected function body after function declarator + error: use of undeclared identifier 'MADV_HUGEPAGE'
        else
          if ! [ `uname -m` = "x86_64" ]; then
            setup_dh=$flag_arg      # does not compile on macos x64
          fi
        fi        
        # only run Mesh's 'nomesh' configuration if asked
        #   setup_nomesh=$flag_arg
        # bigger benchmarks
        setup_lean=$flag_arg
        setup_redis=$flag_arg
        setup_bench=$flag_arg
        #setup_ch=$flag_arg
        setup_packages=$flag_arg
        ;;
    bench)
        setup_bench=$flag_arg;;
    ch)
        setup_ch=$flag_arg;;
    ff)
        setup_ff=$flag_arg;;
    dh)
        setup_dh=$flag_arg;;
    gd)
        setup_gd=$flag_arg;;
    hd)
        setup_hd=$flag_arg;;
    hm)
        setup_hm=$flag_arg;;
    iso)
        setup_iso=$flag_arg;;
    je)
        setup_je=$flag_arg;;
    lp)
        setup_lp=$flag_arg;;
    lt)
        setup_lt=$flag_arg;;
    lean)
        setup_lean=$flag_arg;;
    mng)
        setup_mng=$flag_arg;;
    mesh)
        setup_mesh=$flag_arg;;
    mi)
        setup_mi=$flag_arg;;
    nomesh)
        setup_nomesh=$flag_arg;;
    packages)
        setup_packages=$flag_arg;;
    redis)
        setup_redis=$flag_arg;;
    rp)
        setup_rp=$flag_arg;;
    sc)
        setup_sc=$flag_arg;;
    scudo)
        setup_scudo=$flag_arg;;
    sg)
        setup_sg=$flag_arg;;
    sm)
        setup_sm=$flag_arg;;
    sn)
        setup_sn=$flag_arg;;
    tbb)
        setup_tbb=$flag_arg;;
    tc)
        setup_tc=$flag_arg;;
    tcg)
        setup_tcg=$flag_arg;;
    -r|--rebuild)
        rebuild=1;;
    -j=*|--procs=*)
        procs=$flag_arg;;
    -h|--help|-\?|help|\?)
        echo "./build-bench-env [options]"
        echo ""
        echo "  all                          setup and build (almost) everything"
        echo ""
        echo "  --procs=<n>                  number of processors (=$procs)"
        echo "  --rebuild                    force re-clone and re-build for given tools"
        echo ""
        echo "  dh                           setup dieharder ($version_dh)"
        echo "  ff                           setup ffmalloc ($version_ff)"
        echo "  gd                           setup guarder ($version_gd)"
        echo "  hd                           setup hoard ($version_hd)"
        echo "  hm                           setup hardened_malloc ($version_hm)"
        echo "  iso                          setup isoalloc ($version_iso)"
        echo "  je                           setup jemalloc ($version_je)"
        echo "  lp                           setup libpas ($version_lp)"
        echo "  lt                           setup ltmalloc ($version_lt)"
        echo "  mesh                         setup mesh allocator ($version_mesh)"
        echo "  mi                           setup mimalloc ($version_mi)"
        echo "  mng                          setup mallocng ($version_mng)"
        echo "  nomesh                       setup mesh allocator w/o meshing ($version_mesh)"
        echo "  rp                           setup rpmalloc ($version_rp)"
        echo "  sc                           setup scalloc ($version_sc)"
        echo "  scudo                        setup scudo ($version_scudo)"
        echo "  sg                           setup slimguard ($version_sg)"
        echo "  sm                           setup supermalloc ($version_sm)"
        echo "  sn                           setup snmalloc ($version_sn)"
        echo "  tbb                          setup Intel TBB malloc ($version_tbb)"
        echo "  tc                           setup tcmalloc ($version_tc)"
        echo "  tcg                          setup Google's tcmalloc ($version_tcg)"
        echo ""
        echo "  bench                        build all local benchmarks"
        echo "  lean                         setup lean 3 benchmark"
        echo "  packages                     setup required packages"
        echo "  redis                        setup redis benchmark"
        echo ""
        echo "Prefix an option with 'no-' to disable an option"
        exit 0;;
    *) echo "warning: unknown option \"$1\"." 1>&2
  esac
  shift
done

if test -f ./build-bench-env.sh; then
  echo ""
  echo "use '-h' to see all options"
  echo "use 'all' to build all allocators"
  echo ""
  echo "building with $procs threads"
  echo "--------------------------------------------"
  echo ""
else
  echo "error: must run from the toplevel mimalloc-bench directory!"
  exit 1
fi

mkdir -p extern
readonly devdir="$curdir/extern"

function phase {
  cd "$curdir"
  echo
  echo
  echo "--------------------------------------------"
  echo "$1"
  echo "--------------------------------------------"
  echo
}

function write_version {  # name, git-tag, repo
  commit=$(git log -n1 --format=format:"%h")
  echo "$1: $2, $commit, $3" > "$devdir/version_$1.txt"
}

function partial_checkout {  # name, git-tag, directory, git repo, directory to download
  phase "build $1: version $2"
  pushd $devdir
  if test "$rebuild" = "1"; then
    rm -rf "$3"
  fi
  if test -d "$3"; then
    echo "$devdir/$3 already exists; no need to git clone"
    cd "$3"
  else
    mkdir "$3"
    cd "$3"
    git init
    git remote add origin $4
    git config extensions.partialClone origin
    git sparse-checkout set $5
  fi
  git fetch --depth=1 --filter=blob:none origin $2
  git checkout $2
  git reset origin/$2 --hard
  write_version $1 $2 $4
}

function checkout {  # name, git-tag, directory, git repo, options
  phase "build $1: version $2"
  pushd $devdir
  if test "$rebuild" = "1"; then
    rm -rf "$3"
  fi
  if test -d "$3"; then
    echo "$devdir/$3 already exists; no need to git clone"
  else
    git clone $5 $4 $3
  fi
  cd "$3"
  git checkout $2
  write_version $1 $2 $4
}

function aptinstall {
  echo ""
  echo "> $SUDO apt install $1"
  echo ""
  $SUDO apt install --no-install-recommends $1
}

function dnfinstall {
  echo ""
  echo "> $SUDO dnf -y --quiet --nodocs install $1"
  echo ""
  $SUDO dnf -y --quiet --nodocs install $1
}

function apkinstall {
  echo ""
  echo "> apk add -q $1"
  echo ""
  apk add -q $1
}

function brewinstall {
  echo ""
  echo "> brew install $1"
  echo ""
  brew install $1
}

function aptinstallbazel {
  echo ""
  echo "> installing bazel"
  echo ""
  aptinstall apt-transport-https curl gnupg
  curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg
  $SUDO mv bazel.gpg /etc/apt/trusted.gpg.d/bazel.gpg
  echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | $SUDO tee /etc/apt/sources.list.d/bazel.list
  $SUDO apt update
  aptinstall bazel
}

function dnfinstallbazel {
  echo ""
  echo "> installing bazel"
  echo ""
  dnfinstall dnf-plugins-core
  $SUDO dnf copr -y enable vbatts/bazel
  dnfinstall bazel4
}

if test "$all" = "1"; then
  if test "$rebuild" = "1"; then
    phase "clean $devdir for a full rebuild"
    pushd "$devdir"
    cd ..
    rm -rf "extern/*"
    popd
  fi
fi


if test "$setup_packages" = "1"; then
  phase "install packages"
  if grep -q 'ID=fedora' /etc/os-release 2>/dev/null; then
    # no 'apt update' equivalent needed on Fedora
    dnfinstall "gcc-c++ clang lld llvm-devel unzip dos2unix bc gmp-devel wget gawk \
      cmake python3 ruby ninja-build libtool autoconf git patch time sed \
      ghostscript libatomic"
    dnfinstallbazel
  elif grep -q -e 'ID=debian' -e 'ID=ubuntu' /etc/os-release 2>/dev/null; then
    echo "updating package database... ($SUDO apt update)"
    $SUDO apt update -qq
    aptinstall "g++ clang lld llvm-dev unzip dos2unix linuxinfo bc libgmp-dev wget \
      cmake python3 ruby ninja-build libtool autoconf sed ghostscript time \
      curl automake libatomic1"
    aptinstallbazel
  elif grep -q -e 'ID=alpine' /etc/os-release 2>/dev/null; then
    apk update
    apkinstall "clang lld unzip dos2unix bc gmp-dev wget cmake python3 automake gawk \
      samurai libtool git build-base linux-headers autoconf util-linux sed \
      ghostscript libatomic"
  elif brew --version 2> /dev/null >/dev/null; then
    brewinstall "dos2unix wget cmake ninja automake libtool gnu-time gmp mpir gnu-sed \
      ghostscript bazelisk"
  fi
fi

if test "$setup_hm" = "1"; then
  checkout hm $version_hm hm https://github.com/GrapheneOS/hardened_malloc
  make CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=light -j $proc
  make CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=default -j $proc
  popd
fi

if test "$setup_gd" = "1"; then
  checkout gd $version_gd gd https://github.com/UTSASRG/Guarder
  make -j $procs
  popd
fi

if test "$setup_iso" = "1"; then
  checkout iso $version_iso iso https://github.com/struct/isoalloc
  make library -j $procs
  popd
fi

if test "$setup_ff" = "1"; then
  checkout ff $version_ff ff https://github.com/bwickman97/ffmalloc
  make -j $procs
  popd
fi

if test "$setup_mng" = "1"; then
  checkout mng $version_mng mng https://github.com/richfelker/mallocng-draft
  make -j $procs
  popd
fi

if test "$setup_scudo" = "1"; then
  partial_checkout scudo $version_scudo scudo https://github.com/llvm/llvm-project "compiler-rt/lib/scudo/standalone"
  cd "compiler-rt/lib/scudo/standalone"
  # TODO: make the next line prettier instead of hardcoding everything.
  clang++ -flto -fuse-ld=lld -fPIC -std=c++14 -fno-exceptions $CXXFLAGS -fno-rtti -fvisibility=internal -msse4.2 -O3 -I include -shared -o libscudo$extso *.cpp -pthread
  cd -
  popd
fi

if test "$setup_lp" = "1"; then
  partial_checkout lp $version_lp lp https://github.com/WebKit/WebKit "Source/bmalloc/libpas"
  cd "Source/bmalloc/libpas"
  ORIG=""
  if test "$darwin" = "1"; then
    ORIG="_orig"
  fi
  sed -i $ORIG '/Werror/d' CMakeLists.txt
  # Remove once/if https://github.com/WebKit/WebKit/pull/1219 is merged
  sed -i $ORIG 's/cmake --build $build_dir --parallel/cmake --build $build_dir --target pas_lib --parallel/' build.sh
  if test "$darwin" = "1"; then
    ./build.sh -s cmake -v default -t pas_lib
  else
    CC=clang CXX=clang++ LDFLAGS='-lpthread -latomic -pthread' bash ./build.sh -s cmake -v default -t pas_lib
  fi
  cd -
  popd
fi

if test "$setup_lt" = "1"; then
  checkout lt $version_lt lt https://github.com/r-lyeh-archived/ltalloc
  make -j $procs -C gnu.make.lib
  popd
fi

if test "$setup_sg" = "1"; then
  checkout sg $version_sg sg https://github.com/ssrg-vt/SlimGuard
  make -j $procs
  popd
fi

if test "$setup_dh" = "1"; then
  checkout dh $version_dh dh https://github.com/emeryberger/DieHard
  # remove all the historical useless junk
  rm -rf ./benchmarks/ ./src/archipelago/ ./src/build/ ./src/exterminator/ ./src/local/ ./src/original-diehard/ ./src/replicated/
  if test "$darwin" = "1"; then
    TARGET=libdieharder make -C src macos
  else
    TARGET=libdieharder make -C src linux-gcc-64
  fi
  popd
fi

if test "$setup_tbb" = "1"; then
  checkout tbb $version_tbb tbb https://github.com/oneapi-src/oneTBB
  cmake -DCMAKE_BUILD_TYPE=Release -DTBB_BUILD=OFF -DTBB_TEST=OFF -DTBB_OUTPUT_DIR_BASE=bench .
  make -j $procs
  popd
fi

if test "$setup_tc" = "1"; then
  checkout tc $version_tc tc https://github.com/gperftools/gperftools
  if test -f configure; then
    echo "already configured"
  else
    ./autogen.sh
    CXXFLAGS="$CXXFLAGS -w -DNDEBUG -O2" ./configure --enable-minimal --disable-debugalloc
  fi
  make -j $procs # ends with error on benchmark, but thats ok.
  #echo ""
  #echo "(note: the error 'Makefile:3912: recipe for target 'malloc_bench' failed' is expected)"
  popd
fi

if test "$setup_tcg" = "1"; then
  checkout tcg $version_tcg tcg https://github.com/google/tcmalloc
  ORIG=""
  if test "$darwin" = "1"; then
    ORIG="_orig"
  fi
  sed -i $ORIG '/linkstatic/d' tcmalloc/BUILD
  sed -i $ORIG '/linkstatic/d' tcmalloc/internal/BUILD
  sed -i $ORIG '/linkstatic/d' tcmalloc/testing/BUILD
  sed -i $ORIG '/linkstatic/d' tcmalloc/variants.bzl
  gawk -i inplace '(f && g) {$0="linkshared = True, )"; f=0; g=0} /This library provides tcmalloc always/{f=1} /alwayslink/{g=1} 1' tcmalloc/BUILD
  gawk -i inplace 'f{$0="cc_binary("; f=0} /This library provides tcmalloc always/{f=1} 1' tcmalloc/BUILD # Change the line after "This library…" to cc_binary (instead of cc_library)
  gawk -i inplace '/alwayslink/ && !f{f=1; next} 1' tcmalloc/BUILD # delete only the first instance of "alwayslink"
  bazel build -c opt tcmalloc
  popd
fi

if test "$setup_hd" = "1"; then
  checkout hd $version_hd Hoard https://github.com/emeryberger/Hoard
  cd src
  if [ "`uname -m -s`" = "Darwin x86_64" ] ; then
    sed -i_orig 's/-arch arm64/ /g' GNUmakefile   # fix the makefile    
  fi
  make -j $procs
  popd
fi

if test "$setup_je" = "1"; then
  checkout je $version_je jemalloc https://github.com/jemalloc/jemalloc
  if test -f config.status; then
    echo "$devdir/jemalloc is already configured; no need to reconfigure"
  else
    ./autogen.sh --enable-doc=no --enable-static=no --disable-stats
  fi
  make -j $procs
  [ "$CI" ] && rm -rf ./src/*.o  # jemalloc has like ~100MiB of object files
  [ "$CI" ] && rm -rf ./lib/*.a  # jemalloc produces 80MiB of static files
  popd
fi

if test "$setup_rp" = "1"; then
  checkout rp $version_rp rpmalloc https://github.com/mjansson/rpmalloc
  if test -f build.ninja; then
    echo "$devdir/rpmalloc is already configured; no need to reconfigure"
  else
    python3 configure.py
  fi
  ninja
  popd
fi

if test "$setup_sn" = "1"; then
  checkout sn $version_sn snmalloc https://github.com/Microsoft/snmalloc
  if test -f release/build.ninja; then
    echo "$devdir/snmalloc is already configured; no need to reconfigure"
  else
    mkdir -p release
    cd release
    env CXX=clang++ cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release
    cd ..
  fi
  cd release
  ninja libsnmallocshim$extso libsnmallocshim-checks$extso
  popd
fi

if test "$setup_sm" = "1"; then
  checkout sm $version_sm SuperMalloc https://github.com/kuszmaul/SuperMalloc
  sed -i "s/-Werror//" Makefile.include
  cd release
  make -j $procs
  popd
fi

if test "$setup_mesh" = "1"; then
  checkout mesh $version_mesh mesh https://github.com/plasma-umass/mesh
  cmake .
  make  # cannot run in parallel 
  popd
fi

if test "$setup_nomesh" = "1"; then
  checkout nomesh $version_nomesh nomesh https://github.com/plasma-umass/mesh
  cmake . -DDISABLE_MESHING=ON
  make  # cannot run in parallel 
  popd
fi

if test "$setup_sc" = "1"; then
  checkout sc $version_sc scalloc https://github.com/cksystemsgroup/scalloc
  if test -f Makefile; then
    echo "$devdir/scalloc is already configured; no need to reconfigure"
  else
    if test -f build/gyp/gyp; then
      echo "$devdir/scalloc has the gyp tools installed; no need to re-download"
    else
      tools/make_deps.sh
    fi
    build/gyp/gyp --depth=. scalloc.gyp
  fi
  BUILDTYPE=Release make -j $procs
  popd
fi

if test "$setup_mi" = "1"; then
  checkout mi $version_mi mimalloc https://github.com/microsoft/mimalloc

  echo ""
  echo "- build mimalloc release"

  mkdir -p out/release
  cd out/release
  cmake ../..
  make -j $procs
  cd ../..

  echo ""
  echo "- build mimalloc debug with full checking"

  mkdir -p out/debug
  cd out/debug
  cmake ../.. -DMI_CHECK_FULL=ON
  make -j $procs
  cd ../..

  echo ""
  echo "- build mimalloc secure"

  mkdir -p out/secure
  cd out/secure
  cmake ../..
  make -j $procs
  cd ../..
  popd
fi


phase "install benchmarks"

if test "$setup_lean" = "1"; then
  phase "build lean $version_lean"

  pushd $devdir
  if test -d lean; then
    echo "$devdir/lean already exists; no need to git clone"
  else
    git clone https://github.com/leanprover/lean
  fi
  cd lean
  git checkout "$version_lean"
  mkdir -p out/release
  cd out/release
  env CC=gcc CXX="g++" cmake ../../src -DCUSTOM_ALLOCATORS=OFF -DLEAN_EXTRA_CXX_FLAGS="-w"
  echo "make -j$procs"
  make -j $procs
  rm -rf ./tests/  # we don't need tests
  popd
fi

if test "$setup_redis" = "1"; then
  phase "build redis $version_redis"

  pushd "$devdir"
  if test -d "redis-$version_redis"; then
    echo "$devdir/redis-$version_redis already exists; no need to download it"
  else
    wget --no-verbose "http://download.redis.io/releases/redis-$version_redis.tar.gz"
    tar xzf "redis-$version_redis.tar.gz"
    rm "./redis-$version_redis.tar.gz"
  fi

  cd "redis-$version_redis/src"
  USE_JEMALLOC=no MALLOC=libc BUILD_TLS=no make -j $procs
  popd
fi

if test "$setup_ch" = "1"; then
  phase "build ClickHouse v19.8.3.8-stable"
  checkout ClickHouse mimalloc ClickHouse https://github.com/yandex/ClickHouse "--recursive"
  ./release
  popd
fi

if test "$setup_bench" = "1"; then
  phase "patch shbench"
  pushd "bench/shbench"
  if test -f sh6bench-new.c; then
    echo "do nothing: bench/shbench/sh6bench-new.c already exists"
  else
    wget --no-verbose http://www.microquill.com/smartheap/shbench/bench.zip
    unzip -o bench.zip
    dos2unix sh6bench.patch
    dos2unix sh6bench.c
    patch -p1 -o sh6bench-new.c sh6bench.c sh6bench.patch
  fi
  if test -f sh8bench-new.c; then
    echo "do nothing: bench/shbench/sh8bench-new.c already exists"
  else
    wget --no-verbose http://www.microquill.com/smartheap/SH8BENCH.zip
    unzip -o SH8BENCH.zip
    dos2unix sh8bench.patch
    dos2unix SH8BENCH.C
    patch -p1 -o sh8bench-new.c SH8BENCH.C sh8bench.patch
  fi
  popd
fi

if test "$setup_bench" = "1"; then
  phase "get large PDF document"

  readonly pdfdoc="large.pdf"
  readonly pdfurl="https://raw.githubusercontent.com/geekaaron/Resources/master/resources/Writing_a_Simple_Operating_System--from_Scratch.pdf "
  #readonly pdfurl="https://www.intel.com/content/dam/develop/external/us/en/documents/325462-sdm-vol-1-2abcd-3abcd-508360.pdf"
  pushd "$devdir"
  if test -f "$pdfdoc"; then
    echo "do nothing: $devdir/$pdfdoc already exists"
  else
    useragent="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:95.0) Gecko/20100101 Firefox/95.0"
    wget --no-verbose -O "$pdfdoc" -U "useragent" $pdfurl
  fi
  popd
fi

if test "$setup_bench" = "1"; then
  phase "build benchmarks"

  mkdir -p out/bench
  cd out/bench
  cmake ../../bench
  make -j $procs
  cd ../..
fi


curdir=`pwd`

phase "installed allocators"
cat $devdir/version_*.txt 2>/dev/null | tee $devdir/versions.txt | column -t

phase "done in $curdir"
echo "run the cfrac benchmarks as:"
echo "> cd out/bench"
echo "> ../../bench.sh alla cfrac"
echo
echo "to see all options use:"
echo "> ../../bench.sh help"
echo
