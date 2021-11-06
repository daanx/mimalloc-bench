#!/bin/bash
set -eo pipefail

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
    if command -v nproc; then 
      procs=`nproc`
    fi;;
esac

verbose="no"
curdir=`pwd`
rebuild=0
all=0

# allocator versions
version_je=5.2.1
version_tc=gperftools-2.9.1
version_sn=0.5.3
version_mi=v1.7.2
version_rp=1.4.3
version_tbb=v2021.4.0 # v2020.3
version_scudo=main
version_hm=main
version_iso=1.0.0
version_hd=5afe855 # 3.13 #a43ac40 #d880f72  #9d137ef37
version_sm=709663f
version_mesh=78b9b5d
version_nomesh=78b9b5d
version_sc=v1.0.0
version_redis=6.0.9

# allocators
setup_scudo=0
setup_hm=0
setup_iso=0
setup_je=0
setup_tc=0
setup_sn=0
setup_mi=0
setup_rp=0
setup_hd=0
setup_sm=0
setup_tbb=0
setup_mesh=0
setup_nomesh=0
setup_sc=0

# bigger benchmarks
setup_lean=0
setup_redis=0
setup_ch=0
setup_bench=0

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
        setup_je=$flag_arg
        setup_tc=$flag_arg
        setup_sn=$flag_arg
        setup_mi=$flag_arg
        setup_tbb=$flag_arg
        setup_hd=$flag_arg              
        if [ -z "$darwin" ]; then
          setup_iso=$flag_arg       # sets output to .so on macOS
          setup_hm=$flag_arg        # lacking <thread.h>
          setup_scudo=$flag_arg     # lacking <sys/auxv.h>
          setup_rp=$flag_arg
          setup_sm=$flag_arg
          setup_mesh=$flag_arg          
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
    scudo)
        setup_scudo=$flag_arg;;
    hm)
        setup_hm=$flag_arg;;
    iso)
        setup_iso=$flag_arg;;
    je)
        setup_je=$flag_arg;;
    tc)
        setup_tc=$flag_arg;;
    rp)
        setup_rp=$flag_arg;;
    sm)
        setup_sm=$flag_arg;;
    sn)
        setup_sn=$flag_arg;;
    sc)
        setup_sc=$flag_arg;;
    mi)
        setup_mi=$flag_arg;;
    hd)
        setup_hd=$flag_arg;;
    tbb)
        setup_tbb=$flag_arg;;
    mesh)
        setup_mesh=$flag_arg;;
    nomesh)
        setup_nomesh=$flag_arg;;
    lean)
        setup_lean=$flag_arg;;
    redis)
        setup_redis=$flag_arg;;
    ch)
        setup_ch=$flag_arg;;
    bench)
        setup_bench=$flag_arg;;
    packages)
        setup_packages=$flag_arg;;
    -r|--rebuild)
        rebuild=1;;
    -j=*|--procs=*)
        procs=$flag_arg;;
    -verbose|--verbose)
        verbose="yes";;
    -h|--help|-\?|help|\?)
        echo "./build-bench-env [options]"
        echo ""
        echo "  all                          setup and build (almost) everything"
        echo ""
        echo "  --verbose                    be verbose"
        echo "  --procs=<n>                  number of processors (=$procs)"
        echo "  --rebuild                    force re-clone and re-build for given tools"
        echo ""
        echo "  scudo                        setup scudo ($version_scudo)"
        echo "  hm                           setup hardened_malloc ($version_hm)"
        echo "  iso                          setup isoalloc ($version_iso)"
        echo "  je                           setup jemalloc ($version_je)"
        echo "  tc                           setup tcmalloc ($version_tc)"
        echo "  mi                           setup mimalloc ($version_mi)"
        echo "  tbb                          setup Intel TBB malloc ($version_tbb)"
        echo "  hd                           setup hoard ($version_hd)"
        echo "  mesh                         setup mesh allocator ($version_mesh)"
        echo "  nomesh                       setup mesh allocator w/o meshing ($version_mesh)"
        echo "  sm                           setup supermalloc ($version_sm)"
        echo "  sn                           setup snmalloc ($version_sn)"
        echo "  rp                           setup rpmalloc ($version_rp)"
        echo "  sc                           setup scalloc ($version_sc)"
        echo ""
        echo "  lean                         setup lean 3 benchmark"
        echo "  redis                        setup redis benchmark"
        echo "  bench                        build all local benchmarks"
        echo "  packages                     setup required packages"
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
  echo $1
  echo "--------------------------------------------"
  echo
}

function write_version {  # name, git-tag, repo
  commit=`git log -n 1 | sed -n 's/commit \([0-9A-Fa-f]\{7\}\).*/\1/p' | cut -f1`
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

function checkout {  # name, git-tag, directory, git repo
  phase "build $1: version $2"
  pushd $devdir
  if test "$rebuild" = "1"; then
    rm -rf "$3"
  fi
  if test -d "$3"; then
    echo "$devdir/$3 already exists; no need to git clone"
  else
    git clone $4 $3
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
  echo "> sudo dnf install $1"
  echo ""
  sudo dnf install $1
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
    dnfinstall "gcc-c++ clang lld llvm-dev unzip dos2unix bc gmp-devel wget"
    dnfinstall "cmake python3 ruby ninja-build libtool autoconf"
  elif grep -q -e 'ID=debian' -e 'ID=ubuntu' /etc/os-release 2>/dev/null; then
    echo "updating package database... (sudo apt update)"
    sudo apt update
    aptinstall "g++ clang lld llvm-dev unzip dos2unix linuxinfo bc libgmp-dev wget"
    aptinstall "cmake python3 ruby ninja-build libtool autoconf"
  elif brew --version 2> /dev/null >/dev/null; then
    brewinstall "dos2unix wget cmake ninja automake libtool gnu-time gmp mpir"
  fi
fi

if test "$setup_hm" = "1"; then
  checkout hm $version_hm hm https://github.com/GrapheneOS/hardened_malloc
  make CONFIG_NATIVE=false CONFIG_WERROR=false
  popd
fi

if test "$setup_iso" = "1"; then
  checkout iso $version_iso iso https://github.com/struct/isoalloc
  make library
  popd
fi

if test "$setup_scudo" = "1"; then
  partial_checkout scudo $version_scudo scudo https://github.com/llvm/llvm-project "compiler-rt/lib/scudo/standalone"
  cd "compiler-rt/lib/scudo/standalone"
  # TODO: make the next line prettier instead of hardcoding everything.
  clang++ -flto -fuse-ld=lld -fPIC -std=c++14 -fno-exceptions -fno-rtti -fvisibility=internal -msse4.2 -O3 -I include -shared -o libscudo$extso *.cpp -pthread
  cd -
  popd
fi

if test "$setup_tbb" = "1"; then
  checkout tbb $version_tbb tbb https://github.com/intel/tbb
  # make tbbmalloc
  cmake -DCMAKE_BUILD_TYPE=Release -DTBB_BUILD=OFF -DTBB_TEST=OFF -DTBB_OUTPUT_DIR_BASE=bench
  make -j $procs
  popd
fi

if test "$setup_tc" = "1"; then
  checkout tc $version_tc gperftools https://github.com/gperftools/gperftools
  if test -f configure; then
    echo "already configured"
  else
    ./autogen.sh
    CXXFLAGS="-w -DNDEBUG -O2" ./configure --enable-minimal 
  fi
  make -j $procs .libs/libtcmalloc_minimal$extso # ends with error on benchmark, but thats ok.
  #echo ""
  #echo "(note: the error 'Makefile:3912: recipe for target 'malloc_bench' failed' is expected)"
  popd
fi

if test "$setup_hd" = "1"; then
  checkout hd $version_hd Hoard https://github.com/emeryberger/Hoard.git
  cd src
  if [ "`uname -m -s`" = "Darwin x86_64" ] ; then
    sed -i_orig 's/-arch arm64/ /g' GNUmakefile   # fix the makefile    
  fi
  make -j $procs
  popd
fi

if test "$setup_je" = "1"; then
  checkout je $version_je jemalloc https://github.com/jemalloc/jemalloc.git
  if test -f config.status; then
    echo "$devdir/jemalloc is already configured; no need to reconfigure"
  else
    ./autogen.sh
  fi
  make -j $procs
  popd
fi

if test "$setup_rp" = "1"; then
  checkout rp $version_rp rpmalloc https://github.com/mjansson/rpmalloc.git
  if test -f build.ninja; then
    echo "$devdir/rpmalloc is already configured; no need to reconfigure"
  else
    python3 configure.py
  fi
  ninja -j$procs
  popd
fi

if test "$setup_sn" = "1"; then
  checkout sn $version_sn snmalloc https://github.com/Microsoft/snmalloc.git
  if test -f release/build.ninja; then
    echo "$devdir/snmalloc is already configured; no need to reconfigure"
  else
    mkdir -p release
    cd release
    env CXX=clang++ cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release
    cd ..
  fi
  cd release
  ninja -j$procs libsnmallocshim$extso
  popd
fi

if test "$setup_sm" = "1"; then
  checkout sm $version_sm SuperMalloc https://github.com/kuszmaul/SuperMalloc.git
  sed -i "s/-Werror//" Makefile.include
  cd release
  make
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
  BUILDTYPE=Release make
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
  make -j 4
  cd ../..

  echo ""
  echo "- build mimalloc debug with full checking"

  mkdir -p out/debug
  cd out/debug
  cmake ../.. -DMI_CHECK_FULL=ON $mi_use_cxx
  make -j 4
  cd ../..

  echo ""
  echo "- build mimalloc secure"

  mkdir -p out/secure
  cd out/secure
  cmake ../.. $mi_use_cxx
  make -j 4
  cd ../..
  popd
fi


phase "install benchmarks"

if test "$setup_lean" = "1"; then
  phase "build lean v3.4.1"

  pushd $devdir
  if test -d lean; then
    echo "$devdir/lean already exists; no need to git clone"
  else
    git clone https://github.com/leanprover/lean
  fi
  cd lean
  git checkout v3.4.1
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
  make -j $procs USE_JEMALLOC=no MALLOC=libc
  popd
fi

if test "$setup_ch" = "1"; then
  phase "build ClickHouse v19.8.3.8-stable"

  pushd $devdir
  if test -d "ClickHouse"; then
    echo "$devdir/ClickHouse already exists; no need to git clone"
  else
    sudo apt-get install git pbuilder debhelper lsb-release fakeroot sudo debian-archive-keyring debian-keyring
    git clone --recursive https://github.com/yandex/ClickHouse.git
  fi
  cd ClickHouse
  git checkout mimalloc
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
    # wget https://software.intel.com/sites/default/files/managed/39/c5/325462-sdm-vol-1-2abcd-3abcd.pdf
    curl -o $pdfdoc https://www.intel.com/content/dam/develop/external/us/en/documents/325462-sdm-vol-1-2abcd-3abcd-508360.pdf
  fi
  popd
fi

if test "$setup_bench" = "1"; then
  phase "build benchmarks"

  mkdir -p out/bench
  cd out/bench
  cmake ../../bench
  make
  cd ../..
fi


curdir=`pwd`

phase "installed allocators"
echo "" > $devdir/versions.txt
for f in $devdir/version_*.txt; do
 cat $f >> $devdir/versions.txt
done
cat $devdir/versions.txt | column -t

phase "done in $curdir"
echo "run the cfrac benchmarks as:"
echo "> cd out/bench"
echo "> ../../bench.sh alla cfrac"
echo
echo "to see all options use:"
echo "> ../../bench.sh help"
echo
