procs=4
verbose="no"
curdir=`pwd`
rebuild=0
all=0

# allocators
setup_je=0
setup_tc=0
setup_sn=0
setup_mi=0
setup_rp=0
setup_hd=0
setup_sm=0
setup_tbb=0
setup_ch=0
setup_mesh=0

# bigger benchmarks
setup_lean=0
setup_redis=0
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
        setup_rp=$flag_arg
        setup_hd=$flag_arg
        setup_sm=$flag_arg
        setup_tbb=$flag_arg
        setup_mesh=$flag_arg
        # bigger benchmarks
        setup_lean=$flag_arg
        setup_redis=$flag_arg
        #setup_ch=$flag_arg
        setup_bench=$flag_arg
        setup_packages=$flag_arg
        ;;
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
    mi)
        setup_mi=$flag_arg;;
    hd)
        setup_hd=$flag_arg;;
    tbb)
        setup_tbb=$flag_arg;;
    mesh)
        setup_mesh=$flag_arg;;
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
        echo "  all                          setup and build everything"
        echo "  --verbose                    be verbose"
        echo "  --procs=<n>                  number of processors (=$procs)"
        echo "  --rebuild                    force re-clone and re-build (only for 'all' and 'mi')"
        echo ""
        echo "  je                           setup jemalloc 5.2.0"
        echo "  tc                           setup tcmalloc 2.7"
        echo "  mi                           setup mimalloc"
        echo "  hd                           setup hoard 3.13"
        echo "  sm                           setup supermalloc"
        echo "  sn                           setup snmalloc"
        echo "  rp                           setup rpmalloc"
        echo "  tbb                          setup Intel TBB malloc"
        echo "  mesh                         setup mesh allocator"
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
  echo "use '-h' to see all options"
  echo "building with $procs concurrency"
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

function aptinstall {
  echo ""
  echo "> sudo apt install $1"
  echo ""
  sudo apt install $1
}

if test "$all" = "1"; then
  if test "$rebuild" = "1"; then
    phase "clean $devdir for a full rebuild"
    pushd "$devdir"
    rm -r *
    popd
  fi
fi


if test "$setup_packages" = "1"; then
  phase "install packages"
  echo "updating package database... (sudo apt update)"
  sudo apt update

  aptinstall "g++ clang unzip dos2unix linuxinfo bc"
  aptinstall "cmake python ninja-build autoconf"
  aptinstall "libgmp-dev"
fi

if test "$setup_tbb" = "1"; then
  #todo: build from source
  phase "build the Intel tbb allocator (2019-U8)"
  # aptinstall "libtbb-dev"
  pushd $devdir
  if test -d tbb; then
    echo "$devdir/tbb already exists; no need to git clone"
  else
    git clone https://github.com/intel/tbb
  fi
  cd tbb
  git checkout 2019-U8
  make tbbmalloc
  popd
fi

if test "$setup_tc" = "1"; then
  # todo: build from source
  phase "build tcmalloc 2.7"
  # aptinstall "libgoogle-perftools-dev"
  pushd $devdir
  if test -d gperftools; then
    echo "$devdir/gperftools already exists; no need to git clone"
  else
    git clone https://github.com/gperftools/gperftools
  fi
  cd gperftools
  git checkout gperftools-2.7
  if test -f configure; then
    echo "already configured"
  else
    ./autogen.sh
    ./configure --enable-minimal
  fi
  make # ends with error on benchmark, but thats ok.
  echo ""
  echo "(note: the error 'Makefile:3912: recipe for target 'malloc_bench' failed' is expected)"
  popd
fi

if test "$setup_hd" = "1"; then
  phase "build hoard 3.13"

  pushd $devdir
  if test -d Hoard; then
    echo "$devdir/Hoard already exists; no need to git clone"
  else
    git clone https://github.com/emeryberger/Hoard.git
  fi
  cd Hoard
  git checkout 3.13
  cd src
  make
  sudo make
  popd
fi

if test "$setup_je" = "1"; then
  phase "build jemalloc 5.2.0"

  pushd $devdir
  if test -d jemalloc; then
    echo "$devdir/jemalloc already exists; no need to git clone"
  else
    git clone https://github.com/jemalloc/jemalloc.git
  fi
  cd jemalloc
  if test -f config.status; then
    echo "$devdir/jemalloc is already configured; no need to reconfigure"
  else
    git checkout 5.2.0
    ./autogen.sh
  fi
  make -j $procs
  popd
fi

if test "$setup_rp" = "1"; then
  phase "build rpmalloc 1.3.1"

  pushd $devdir
  if test -d rpmalloc; then
    echo "$devdir/rpmalloc already exists; no need to git clone"
  else
    git clone https://github.com/rampantpixels/rpmalloc.git
  fi
  cd rpmalloc
  if test -f build.ninja; then
    echo "$devdir/rpmalloc is already configured; no need to reconfigure"
  else
    git checkout 1.3.1
    python configure.py
  fi
  ninja
  popd
fi

if test "$setup_sn" = "1"; then
  phase "build snmalloc, commit 0b64536b"

  pushd $devdir
  if test -d snmalloc; then
    echo "$devdir/snmalloc already exists; no need to git clone"
  else
    git clone https://github.com/Microsoft/snmalloc.git
  fi
  cd snmalloc
  if test -f release/build.ninja; then
    echo "$devdir/snmalloc is already configured; no need to reconfigure"
  else
    git checkout 0b64536b
    mkdir -p release
    cd release
    env CXX=clang++ cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release
    cd ..
  fi
  cd release
  ninja
  popd
fi

if test "$setup_sm" = "1"; then
  phase "build SuperMalloc (commit 709663fb)"

  pushd $devdir
  if test -d SuperMalloc; then
    echo "$devdir/SuperMalloc already exists; no need to git clone"
  else
    git clone https://github.com/kuszmaul/SuperMalloc.git
  fi
  cd SuperMalloc
  git checkout 709663fb
  sed -i "s/-Werror//" Makefile.include
  cd release
  make
  popd
fi

if test "$setup_mesh" = "1"; then
  phase "build Mesh (commit aeb626e7 on master)"

  pushd $devdir
  if test -d mesh; then
    echo "$devdir/mesh already exists; no need to git clone"
  else
    git clone --recurse-submodules https://github.com/plasma-umass/mesh
  fi
  cd mesh
  git checkout aeb626e7
  ./configure
  make
  popd
fi

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
  env CC=gcc CXX="g++ -Wno-exceptions" cmake ../../src -DCUSTOM_ALLOCATORS=OFF
  make -j $procs
  popd
fi

if test "$setup_redis" = "1"; then
  phase "build redis 5.0.3"

  pushd "$devdir"
  if test -d "redis-5.0.3"; then
    echo "$devdir/redis-5.0.3 already exists; no need to download it"
  else
    wget "http://download.redis.io/releases/redis-5.0.3.tar.gz"
    tar xzf "redis-5.0.3.tar.gz"
  fi

  cd "redis-5.0.3/src"
  make USE_JEMALLOC=no MALLOC=libc
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

if test "$setup_mi" = "1"; then
  phase "build mimalloc variants"

  pushd "$devdir"
  if test "$rebuild" = "1"; then
    rm -r "mimalloc"
  fi
  if test -d "mimalloc"; then
    echo "$devdir/mimalloc already exists; no need to download it"
  else
    git clone https://github.com/microsoft/mimalloc -b master
  fi
  cd mimalloc
  git checkout

  echo ""
  echo "- build mimalloc release"

  mkdir -p out/release
  cd out/release
  cmake ../..
  make
  cd ../..

  echo ""
  echo "- build mimalloc debug with full checking"

  mkdir -p out/debug
  cd out/debug
  cmake ../.. -DMI_CHECK_FULL=ON
  make
  cd ../..

  echo ""
  echo "- build mimalloc secure"

  mkdir -p out/secure
  cd out/secure
  cmake ../..
  make
  cd ../..
  popd
fi



if test "$setup_bench" = "1"; then
  phase "patch shbench"
  pushd "bench/shbench"
  if test -f sh6bench-new.c; then
    echo "do nothing: bench/shbench/sh6bench-new.c already exists"
  else
    wget http://www.microquill.com/smartheap/shbench/bench.zip
    unzip -o bench.zip
    dos2unix sh6bench.patch
    dos2unix sh6bench.c
    patch -p1 -o sh6bench-new.c sh6bench.c sh6bench.patch
  fi
  if test -f sh8bench-new.c; then
    echo "do nothing: bench/shbench/sh8bench-new.c already exists"
  else
    wget http://www.microquill.com/smartheap/SH8BENCH.zip
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
    wget https://software.intel.com/sites/default/files/managed/39/c5/325462-sdm-vol-1-2abcd-3abcd.pdf
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
phase "done in $curdir"

echo "run the cfrac benchmarks as:"
echo "> cd out/bench"
echo "> ../../bench/bench.sh alla cfrac"
echo
echo "to see all options use:"
echo "> ../../bench/bench.sh help"
echo
