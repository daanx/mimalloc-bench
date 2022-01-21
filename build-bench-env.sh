#!/bin/bash
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

curdir=`pwd`
rebuild=0
all=0

# allocator versions
version_dh=640949fe0128d9c7013677c8c332698d5c2cefc2
version_hd=5afe855 # 3.13 #a43ac40 #d880f72  #9d137ef37
version_hm=10
version_iso=1.1.0
version_je=5.2.1
version_mng=master
version_mesh=7ef171c7870c8da1c52ff3d78482421f46beb94c
version_mi=v1.7.3
version_nomesh=7ef171c7870c8da1c52ff3d78482421f46beb94c
version_rp=4c10723
version_sc=v1.0.0
version_scudo=main
version_sm=709663f
version_sn=0.5.3
version_tbb=883c2e5245c39624b3b5d6d56d5b203cf09eac38  # needed for musl
version_tc=gperftools-2.9.1

# benchmark versions
version_redis=6.2.6
version_lean=v3.4.2

# allocators
setup_dh=0
setup_hd=0
setup_hm=0
setup_iso=0
setup_je=0
setup_mng=0
setup_mesh=0
setup_mi=0
setup_nomesh=0
setup_rp=0
setup_sc=0
setup_scudo=0
setup_sm=0
setup_sn=0
setup_tbb=0
setup_tc=0

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
        setup_hd=$flag_arg              
        setup_iso=$flag_arg
        setup_je=$flag_arg
        setup_mi=$flag_arg
        setup_sn=$flag_arg
        setup_tbb=$flag_arg
        setup_tc=$flag_arg
        if [ -z "$darwin" ]; then
          setup_dh=$flag_arg        
          setup_mng=$flag_arg       # lacking getentropy()
          setup_hm=$flag_arg        # lacking <thread.h>
          setup_mesh=$flag_arg          
          setup_rp=$flag_arg
          setup_scudo=$flag_arg     # lacking <sys/auxv.h>
          setup_sm=$flag_arg
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
    dh)
          setup_dh=$flag_arg;;
    hd)
        setup_hd=$flag_arg;;
    hm)
        setup_hm=$flag_arg;;
    iso)
        setup_iso=$flag_arg;;
    je)
        setup_je=$flag_arg;;
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
    sm)
        setup_sm=$flag_arg;;
    sn)
        setup_sn=$flag_arg;;
    tbb)
        setup_tbb=$flag_arg;;
    tc)
        setup_tc=$flag_arg;;
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
        echo "  hd                           setup hoard ($version_hd)"
        echo "  hm                           setup hardened_malloc ($version_hm)"
        echo "  iso                          setup isoalloc ($version_iso)"
        echo "  je                           setup jemalloc ($version_je)"
        echo "  mng                          setup mallocng ($version_mng)"
        echo "  mesh                         setup mesh allocator ($version_mesh)"
        echo "  mi                           setup mimalloc ($version_mi)"
        echo "  nomesh                       setup mesh allocator w/o meshing ($version_mesh)"
        echo "  rp                           setup rpmalloc ($version_rp)"
        echo "  sc                           setup scalloc ($version_sc)"
        echo "  scudo                        setup scudo ($version_scudo)"
        echo "  sm                           setup supermalloc ($version_sm)"
        echo "  sn                           setup snmalloc ($version_sn)"
        echo "  tbb                          setup Intel TBB malloc ($version_tbb)"
        echo "  tc                           setup tcmalloc ($version_tc)"
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
devdir="$curdir/extern"

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
  echo "> sudo apt install $1"
  echo ""
  sudo apt install --no-install-recommends $1
}

function dnfinstall {
  echo ""
  echo "> sudo dnf -y --quiet --nodocs install $1"
  echo ""
  sudo dnf -y --quiet --nodocs install $1
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
    dnfinstall "gcc-c++ clang lld llvm-devel unzip dos2unix bc gmp-devel wget"
    dnfinstall "cmake python3 ruby ninja-build libtool autoconf git patch time"
  elif grep -q -e 'ID=debian' -e 'ID=ubuntu' /etc/os-release 2>/dev/null; then
    echo "updating package database... (sudo apt update)"
    sudo apt update -qq
    aptinstall "g++ clang lld llvm-dev unzip dos2unix linuxinfo bc libgmp-dev wget"
    aptinstall "cmake python3 ruby ninja-build libtool autoconf"
  elif grep -q -e 'ID=alpine' /etc/os-release 2>/dev/null; then
    apk update
    apkinstall "clang lld unzip dos2unix bc gmp-dev wget cmake python3 automake"
    apkinstall "samurai libtool git build-base linux-headers autoconf util-linux"
  elif brew --version 2> /dev/null >/dev/null; then
    brewinstall "dos2unix wget cmake ninja automake libtool gnu-time gmp mpir"
  fi
fi

if test "$setup_hm" = "1"; then
  checkout hm $version_hm hm https://github.com/GrapheneOS/hardened_malloc
  make CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=light -j $proc 
  make CONFIG_NATIVE=true CONFIG_WERROR=false VARIANT=default -j $proc
  popd
fi

if test "$setup_iso" = "1"; then
  checkout iso $version_iso iso https://github.com/struct/isoalloc
  make library -j $procs
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

if test "$setup_dh" = "1"; then
  checkout dh $version_dh dh https://github.com/emeryberger/DieHard "--recursive"
  if test "$darwin" = "1"; then
    TARGET=libdieharder make -C src -j $procs macos
  else
    TARGET=libdieharder make -C src -j $procs linux-gcc-64
  fi
  popd
fi

if test "$setup_tbb" = "1"; then
  checkout tbb $version_tbb tbb https://github.com/intel/tbb
  cmake -DCMAKE_BUILD_TYPE=Release -DTBB_BUILD=OFF -DTBB_TEST=OFF -DTBB_OUTPUT_DIR_BASE=bench -DTBBMALLOC_PROXY_BUILD=OFF .
  make -j $procs
  popd
fi

if test "$setup_tc" = "1"; then
  checkout tc $version_tc gperftools https://github.com/gperftools/gperftools
  if test -f configure; then
    echo "already configured"
  else
    ./autogen.sh
    CXXFLAGS="-w -DNDEBUG -O2" ./configure --enable-minimal --disable-debugalloc
  fi
  make -j $procs # ends with error on benchmark, but thats ok.
  #echo ""
  #echo "(note: the error 'Makefile:3912: recipe for target 'malloc_bench' failed' is expected)"
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
  ninja libsnmallocshim$extso
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

  mi_use_cxx=""
  if test "$darwin" = "1"; then
    mi_use_cxx="-DMI_USE_CXX=ON"
  fi

  mkdir -p out/release
  cd out/release
  cmake ../..  $mi_use_cxx
  make -j $procs
  cd ../..

  echo ""
  echo "- build mimalloc debug with full checking"

  mkdir -p out/debug
  cd out/debug
  cmake ../.. -DMI_CHECK_FULL=ON $mi_use_cxx
  make -j $procs
  cd ../..

  echo ""
  echo "- build mimalloc secure"

  mkdir -p out/secure
  cd out/secure
  cmake ../.. $mi_use_cxx
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
  phase "get Intel PDF manual"

  pdfdoc="325462-sdm-vol-1-2abcd-3abcd.pdf"
  pushd "$devdir"
  if test -f "$pdfdoc"; then
    echo "do nothing: $devdir/$pdfdoc already exists"
  else
    useragent="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:95.0) Gecko/20100101 Firefox/95.0"
    wget --no-verbose -O "$pdfdoc" -U "useragent" https://www.intel.com/content/dam/develop/external/us/en/documents/325462-sdm-vol-1-2abcd-3abcd-508360.pdf
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
cat $devdir/version_*.txt | tee $devdir/versions.txt | column -t

phase "done in $curdir"
echo "run the cfrac benchmarks as:"
echo "> cd out/bench"
echo "> ../../bench.sh alla cfrac"
echo
echo "to see all options use:"
echo "> ../../bench.sh help"
echo
