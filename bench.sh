#!/bin/bash
# Copyright 2018-2022, Microsoft Research, Daan Leijen, Julien Voisin, Matthew Parkinson

if grep -q -e 'ID=debian' -e 'ID=ubuntu' /etc/os-release 2>/dev/null; then
  echo "Running on Debian or Ubuntu: errors are considered fatal"
  set -eo pipefail
elif brew --version 2> /dev/null >/dev/null; then
  echo "Running on OSX: errors are considered fatal"
  set -eo pipefail
fi


# --------------------------------------------------------------------
# Allocators and tests
# --------------------------------------------------------------------

readonly alloc_all="sys dh ff gd hd hm hml iso je lp mi mi-sec mng mesh nomesh rp sc scudo sg sm sn sn-sec tbb tc tcg dmi xmi xsmi xdmi"
readonly alloc_secure="dh ff gd hm hml iso mi-sec mng scudo sg sn-sec sg"
alloc_run=""           # allocators to run (expanded by command line options)
alloc_installed="sys"  # later expanded to include all installed allocators
alloc_libs="sys="      # mapping from allocator to its .so as "<allocator>=<sofile> ..."

readonly tests_all1="cfrac espresso barnes redis lean larson-sized mstress rptest sed gs"
readonly tests_all2="alloc-test sh6bench sh8bench xmalloc-test cscratch glibc-simple glibc-thread"
readonly tests_all3="larson lean-mathlib malloc-large mleak rbstress cthrash"
readonly tests_all4="z3 spec spec-bench"

readonly tests_all="$tests_all1 $tests_all2 $tests_all3 $tests_all4"
readonly tests_allt="$tests_all1 $tests_all2"  # run with 'allt' command option

tests_run=""
tests_exclude=""
# sed: "RE error: invalid repetition count(s)" on OSX
readonly tests_exclude_macos="sh6bench sh8bench redis sed"


# --------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------

verbose="no"
ldpreload="LD_PRELOAD"
timecmd="$(type -P time)"  # the shell builtin doesn't have all the options we need
sedcmd=sed
darwin=""
extso=".so"
procs=8
repeats=1          # repeats of all tests
test_repeats=1     # repeats per test
sleep=0            # mini sleeps between tests seem to improve stability
case "$OSTYPE" in
  darwin*) 
    darwin="1"
    timecmd=gtime  # use brew install gnu-time
    extso=".dylib"
    ldpreload="DYLD_INSERT_LIBRARIES"
    libc=`clang --version | head -n 1`
    procs=`sysctl -n hw.physicalcpu`
    sedcmd=gsed;;
  *)
    libc=`ldd --version 2>&1 | head -n 1` || true
    libc="${libc#ldd }"
    if command -v nproc > /dev/null; then 
      procs=`nproc`
    fi;;
esac


# --------------------------------------------------------------------
# Check directories
# --------------------------------------------------------------------

readonly curdir=`pwd`
if ! test -f ../../build-bench-env.sh; then
  echo "error: you must run this script from the 'out/bench' directory!"
  exit 1
fi
if ! test -d ../../extern; then
  echo "error: you must first run `./build-build/bench.sh` (in `../..`) to install benchmarks and allocators."
  exit 1
fi

pushd "../../extern" > /dev/null # up from `mimalloc-bench/out/bench`
readonly localdevdir=`pwd`
popd > /dev/null
pushd "../../bench" > /dev/null
readonly benchdir=`pwd`
popd > /dev/null


# --------------------------------------------------------------------
# The allocator library paths
# --------------------------------------------------------------------
function alloc_lib_add {  # <allocator> <variable> <librarypath>
  alloc_libs="$1=$2 $alloc_libs"
}

readonly lib_rp="`find ${localdevdir}/rpmalloc/bin/*/release -name librpmallocwrap$extso 2> /dev/null`"
readonly lib_tbb="$localdevdir/tbb/bench_release/libtbbmalloc_proxy$extso"
readonly lib_tbb_dir="$(dirname $lib_tbb)"


alloc_lib_add "dh"     "$localdevdir/dh/src/libdieharder$extso"
alloc_lib_add "ff"     "$localdevdir/ff/libffmallocnpmt$extso"
alloc_lib_add "gd"     "$localdevdir/gd/libguarder$extso"
alloc_lib_add "hd"     "$localdevdir/Hoard/src/libhoard$extso"
alloc_lib_add "hm"     "$localdevdir/hm/out/libhardened_malloc$extso"
alloc_lib_add "hml"    "$localdevdir/hm/out-light/libhardened_malloc-light$extso"
alloc_lib_add "iso"    "$localdevdir/iso/build/libisoalloc$extso"
alloc_lib_add "je"     "$localdevdir/jemalloc/lib/libjemalloc$extso"
alloc_lib_add "lp"     "$localdevdir/lp/Source/bmalloc/libpas/build-cmake-default/Release/libpas_lib$extso"
alloc_lib_add "mesh"   "$localdevdir/mesh/build/lib/libmesh$extso"
alloc_lib_add "mng"    "$localdevdir/mng/libmallocng$extso"
alloc_lib_add "nomesh" "$localdevdir/nomesh/build/lib/libmesh$extso"
alloc_lib_add "rp"     "$lib_rp"
alloc_lib_add "sc"     "$localdevdir/scalloc/out/Release/lib.target/libscalloc$extso"
alloc_lib_add "scudo"  "$localdevdir/scudo/compiler-rt/lib/scudo/standalone/libscudo$extso"
alloc_lib_add "sg"     "$localdevdir/sg/libSlimGuard.so"
alloc_lib_add "sm"     "$localdevdir/SuperMalloc/release/lib/libsupermalloc$extso"
alloc_lib_add "sn"     "$localdevdir/snmalloc/release/libsnmallocshim$extso"
alloc_lib_add "sn-sec" "$localdevdir/snmalloc/release/libsnmallocshim-checks$extso"
alloc_lib_add "tbb"    "$lib_tbb"
alloc_lib_add "tc"     "$localdevdir/tc/.libs/libtcmalloc_minimal$extso"
alloc_lib_add "tcg"    "$localdevdir/tcg/bazel-bin/tcmalloc/libtcmalloc$extso"

alloc_lib_add "mi"     "$localdevdir/mimalloc/out/release/libmimalloc$extso"
alloc_lib_add "mi-sec"    "$localdevdir/mimalloc/out/secure/libmimalloc-secure$extso"
alloc_lib_add "mi-dbg"    "$localdevdir/mimalloc/out/debug/libmimalloc-debug$extso"
alloc_lib_add "xmi"    "$localdevdir/../../mimalloc/out/release/libmimalloc$extso"
alloc_lib_add "xmi-sec"   "$localdevdir/../../mimalloc/out/secure/libmimalloc-secure$extso"
alloc_lib_add "xmi-dbg"   "$localdevdir/../../mimalloc/out/debug/libmimalloc-debug$extso"

if test "$use_packages" = "1"; then
  if test -f "/usr/lib/libtcmalloc$extso"; then
    alloc_lib_add "tc"  "/usr/lib/libtcmalloc$extso"
  fi
  if test -f "/usr/lib/libtbbmalloc_proxy$extso"; then
    alloc_lib_add "tbb" "/usr/lib/libtbbmalloc_proxy$extso"
  fi
  if test -f "/usr/lib/x86_64-linux-gnu/libtcmalloc$extso"; then
    alloc_lib_add "tc" "/usr/lib/x86_64-linux-gnu/libtcmalloc$extso"
  fi
  if test -f "/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy$extso"; then
    alloc_lib_add "tbb" "/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy$extso"
  fi
fi

readonly leandir="$localdevdir/lean"
readonly leanmldir="$leandir/../mathlib"
readonly redis_dir="$localdevdir/redis-6.2.6/src"
readonly pdfdoc="$localdevdir/large.pdf" 
                

readonly spec_dir="$localdevdir/../../spec2017"
readonly spec_base="base"
readonly spec_bench="refspeed"
readonly spec_config="malloc-test-m64"


# --------------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------------

function warning { # <message> 
  echo ""
  echo "warning: $1"
  echo ""
}

function contains {  # <string> <substring>   does string contain substring?
  for s in $1; do
    if test "$s" = "$2"; then
      return 0
    fi
  done
  return 1
}

function is_installed {  # <allocator>
  contains "$alloc_installed" $1
}

function alloc_run_add {  # <allocator>   :add to runnable
  alloc_run="$alloc_run $1"
}

function alloc_run_remove {   # <allocator>  :remove from runnables
  if contains "$alloc_run" "$1"; then
    alloc_run_old="$alloc_run"
    alloc_run=""
    for s in $alloc_run_old; do
      if [ "$s" != "$1" ]; then
        alloc_run_add "$s"
      fi
    done
  fi
}

function alloc_run_add_remove { # <allocator> <add?> 
  if test "$2" = "1"; then
    alloc_run_add "$1"
  else
    alloc_run_remove "$1"
  fi
}

# read in the installed allocators
while read word _; do alloc_installed="$alloc_installed ${word%:*}"; done < ${localdevdir}/versions.txt
if is_installed "mi"; then
  alloc_installed="$alloc_installed mi-sec"   # secure mimalloc
fi
if is_installed "hm"; then
  alloc_installed="$alloc_installed hml"   # hardened_malloc light
fi
if is_installed "sn"; then
  alloc_installed="$alloc_installed sn-sec"   # secure snmalloc
fi


alloc_lib=""
function alloc_lib_set {  # <allocator>
  for entry in $alloc_libs; do
    entry_name="${entry%=*}"
    entry_lib="${entry#*=}"
    if [ "$entry_name" = "$1" ]; then
      alloc_lib="$entry_lib"
      return 0
    fi
  done
  warning "cannot set library path for allocator $1"
  alloc_lib="lib$1.so"
}

function tests_run_add {  # <tests>   :add to runnable tests
  tests_run="$tests_run $1"
}

function tests_run_remove {   # <test>  :remove from runnable tests
  if contains "$tests_run" "$1"; then
    tests_run_old="$tests_run"
    tests_run=""
    for tst in $tests_run_old; do
      if [ "$tst" != "$1" ]; then
        tests_run_add "$tst"
      fi
    done
  fi
}

function tests_run_add_remove { # <test> <add?> 
  if test "$2" = "1"; then
    tests_run_add "$1"
  else
    tests_run_remove "$1"
  fi
}

if test "$darwin" = "1"; then
  # remove tests that don't run on darwin
  tests_exclude="$tests_exclude $tests_exclude_macos"
fi


if [ ! -f "${localdevdir}/lean/bin/lean" ]; then  # only run lean if it is installed (for CI)
  tests_exclude="$tests_exclude lean lean-mathlib"
fi


# --------------------------------------------------------------------
# Parse command line
# --------------------------------------------------------------------

while : ; do
  # set flag and flag_arg
  flag="$1"
  case "$flag" in
    *=*)  flag_arg="${flag#*=}"
          flag="${flag%=*}=";;
    no-*) flag_arg="0"
          flag="${flag#no-}";;
    none) flag_arg="0" ;;
    *)    flag_arg="1" ;;
  esac
  case "$flag_arg" in
    yes|on|true)  flag_arg="1";;
    no|off|false) flag_arg="0";;
  esac
  #echo "option: $flag, arg: $flag_arg"

  if contains "$alloc_all" "$flag"; then
    #echo "allocator flag: $flag"
    if ! contains "$alloc_installed" "$flag"; then
      warning "allocator '$flag' selected but it seems it is not installed ($alloc_installed)"
    fi
    alloc_run_add_remove "$flag" "$flag_arg"    
  else
    if contains "$tests_all" "$flag"; then
      #echo "test flag: $flag"
      tests_run_add_remove "$flag" "$flag_arg"
    else
      case "$flag" in
        "") break;;
        alla)
            # use all installed allocators (iterate to maintain order as specified in alloc_all)
            for alloc in $alloc_all; do 
              if is_installed "$alloc"; then
                alloc_run_add_remove "$alloc" "$flag_arg"
              fi
            done;;
        allsa)
            # use all "secure" installed allocators (iterate to maintain order as specified in alloc_secure)
            for alloc in $alloc_secure; do 
              if is_installed "$alloc"; then
                alloc_run_add_remove "$alloc" "$flag_arg"
              fi
            done;;
        allt)
            for tst in $tests_allt; do
              tests_run_add_remove "$tst" "$flag_arg"
            done;;
        glibc)
            tests_run_add_remove "glibc-simple" "$flag_arg"
            tests_run_add_remove "glibc-thread" "$flag_arg";;
        spec=*)
            test_run_add "spec"
            run_spec_bench="$flag_arg";;
        -j=*|--procs=*)
            procs="$flag_arg";;
        -r=*)
            repeats="$flag_arg";;
        -n=*)
            test_repeats="$flag_arg";;
        -s=*|--sleep=*)
            sleep="$flag_arg";;
        -v|--verbose)
            verbose="yes";;
        -h|--help|-\?|help|\?)
            echo "./bench [options]"
            echo ""
            echo "options:"
            echo "  -h, --help                   show this help"  
            echo "  -v, --verbose                be verbose (=$verbose)"
            echo "  -j=<n>, --procs=<n>          concurrency level (=$procs)"
            echo "  -r=<n>                       number of repeats of the full suite (=$repeats)"
            echo "  -n=<n>                       number of repeats of each individual test (=$test_repeats)"
            echo "  -s=<n>, --sleep=<n>          seconds of sleep between each test (=$sleep)"
            echo ""
            echo "  allt                         run all tests"
            echo "  alla                         run all allocators"
            echo "  allsa                        run all \"secure\" allocators"
            echo "  no-<test|allocator>          do not run specific <test> or <allocator>"   
            echo ""
            echo "allocators:"
            echo "  dh                           use dieharder"
            echo "  dmi                          use debug version of mimalloc"
            echo "  ff                           use ffmalloc"
            echo "  gd                           use guarder"
            echo "  hd                           use hoard"
            echo "  hm                           use hardened_malloc"
            echo "  hml                          use hardened_malloc light"
            echo "  iso                          use isoalloc"
            echo "  je                           use jemalloc"
            echo "  lp                           use libpas"
            echo "  mesh                         use mesh"
            echo "  mi                           use mimalloc"
            echo "  mi-sec                       use secure version of mimalloc"
            echo "  mng                          use mallocng"
            echo "  nomesh                       use mesh with meshing disabled"
            echo "  rp                           use rpmalloc"
            echo "  sc                           use scalloc"
            echo "  scudo                        use scudo"
            echo "  sg                           use slimguard"
            echo "  sm                           use supermalloc"
            echo "  sn                           use snmalloc"
            echo "  sn-sec                       use secure version of snmalloc"
            echo "  sys                          use system malloc ($libc)"
            echo "  tbb                          use Intel TBB malloc"
            echo "  tc                           use tcmalloc (from gperftools)"
            echo "  tcg                          use tcmalloc (from Google)"
            echo ""
            echo "tests included in 'allt':"
            echo "  $tests_all1"
            echo "  $tests_all2"
            echo ""
            echo "further tests:"
            echo "  $tests_all3 $tests_all4"
            echo ""
            echo "secure allocators included in 'allsa':"
            echo "  $alloc_secure"
            echo ""
            echo "installed allocators:"
            echo "  sys:    $libc"
            column -t "$localdevdir/versions.txt" | sed 's/^/  /'
            echo ""
            exit 0;;
        *) warning "unknown option \"$1\"." 1>&2
      esac
    fi
  fi
  shift
done

echo "benchmarking on $procs cores."
echo "use '-h' or '--help' for help on configuration options."
echo ""
export verbose



# --------------------------------------------------------------------
# Info
# --------------------------------------------------------------------

if test "$verbose" = "yes"; then
  echo "available tests: $verbose"
  echo "  $tests_all1"
  echo "  $tests_all2"
  echo "  $tests_all3 $tests_all4"
  echo ""
  echo "available allocators:"
  echo "  $alloc_all"
  echo ""
  echo "installed allocators:"
  echo "  sys:    $libc"
  column -t "$localdevdir/versions.txt" | sed 's/^/  /'
  echo ""
fi

for tst in $tests_exclude; do
  tests_run_remove "$tst"
done

echo "allocators: $alloc_run"
echo "tests     : $tests_run"
if [ ! -z "$tests_exclude" ]; then
  echo "(excluded tests: $tests_exclude)"
fi  

if [ -z "$tests_run" ]; then
  warning "no tests are specified."
  exit 1
fi
if [ -z "$alloc_run" ]; then
  warning "no allocators are specified."
  exit 1
fi  

readonly benchres="$curdir/benchres.csv"

procsx2=$((procs * 2))
procsx4=$((procs * 4))
procs_div2=$((procs / 2))
procs_max16=$((procs > 16 ? 16 : procs))

function set_spec_bench_dir {
  if test -f "$1.0000/compare.out"; then
    spec_bench_dir="$1.0000"
  elif test -f "$1.0001/compare.out"; then
    spec_bench_dir="$1.0001"
  elif test -f "$1.0002/compare.out"; then
    spec_bench_dir="$1.0002"
  elif test -f "$1.0003/compare.out"; then
    spec_bench_dir="$1.0003"
  else
    spec_bench_dir="$1.0004"
  fi
}


# --------------------------------------------------------------------
# Run a test
# --------------------------------------------------------------------
readonly allocfill="     "
readonly benchfill="           "

function run_test_env_cmd { # <test name> <allocator name> <environment args> <command> <repeat>
  if ! [ -z "$sleep" ]; then
    sleep "$sleep"
  fi
  echo
  echo "run $test_repeat: $1 $2: $3 $4"
  # clear temporary output
  if [ -f "$benchres.line" ]; then
    rm "$benchres.line"
  fi
  outfile="$curdir/$1-$2-out.txt"
  infile="/dev/null"
#  outfile="/dev/null"
  case "$1" in
    lean*)
      echo "preprocess..."
      pushd "../out/release"
      make clean-olean
      popd;;
    mathlib)
      echo "preprocess..."
      find -name '*.olean' | xargs rm;;
    spec-*)
      readonly spec_subdir="${1#*-}"
      set_spec_bench_dir "$spec_dir/benchspec/CPU/$spec_subdir/run/run_${spec_base}_${spec_bench}_${spec_config}"
      echo "run spec benchmark in: $spec_bench_dir"
      pushd "$spec_bench_dir";;
    larson*|redis*|xmalloc*)
      outfile="$1-$2-out.txt";;
    barnes)
      infile="$benchdir/barnes/input";;
  esac
  case "$1" in
    redis*)
       echo "start server"
       $timecmd -a -o "$benchres.line" -f "$1${benchfill:${#1}} $2${allocfill:${#2}} %E %M %U %S %F %R" /usr/bin/env $3 $redis_dir/redis-server > "$outfile.server.txt"  &
       sleep 1s
       $redis_dir/redis-cli flushall
       sleep 1s
       $4 >> "$outfile"
       sleep 1s
       $redis_dir/redis-cli flushall
       sleep 1s
       $redis_dir/redis-cli shutdown
       sleep 1s
       ;;
    *)
       $timecmd -a -o "$benchres.line" -f "$1${benchfill:${#1}} $2${allocfill:${#2}} %E %M %U %S %F %R" /usr/bin/env $3 $4 < "$infile" > "$outfile";;
  esac

  # fixup larson with relative time
  case "$1" in
    redis*)
      ops=`tail -$redis_tail "$outfile" | sed -n 's/.*: \([0-9\.]*\) requests per second.*/\1/p'`
      rtime=`echo "scale=3; (2000000 / $ops)" | bc`
      echo "$1 $2: ops/sec: $ops, relative time: ${rtime}s"
      sed -E -i.bak "s/($1  *$2  *)[^ ]*/\10:$rtime/" "$benchres.line";;
    larson*)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/.* time: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2, relative time: ${rtime}s"
      sed -E -i.bak "s/($1  *$2  *)[^ ]*/\10:$rtime/" "$benchres.line";;
    rptest*)
      ops=`cat "$1-$2-out.txt" | sed -n 's/.*\.\.\.\([0-9]*\) memory ops.*/\1/p'`
      rtime=`echo "scale=3; (2000000 / $ops)" | bc`
      echo "$1,$2: ops/sec: $ops, relative time: ${rtime}s"
      sed -E -i.bak "s/($1  *$2  *)[^ ]*/\10:$rtime/" "$benchres.line";;
    xmalloc*)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/rtime: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2, relative time: ${rtime}s"
      sed -E -i.bak "s/($1  *$2  *)[^ ]*/\10:$rtime/" "$benchres.line";;
    glibc-thread)
      ops=`cat "$1-$2-out.txt" | sed -n 's/\([0-9\.]*\).*/\1/p'`
      rtime=`echo "scale=3; (1000000000 / $ops)" | bc`
      echo "$1,$2: iterations: ${ops}, relative time: ${rtime}s"
      sed -E -i.bak "s/($1  *$2  *)[^ ]*/\10:$rtime/" "$benchres.line";;
    spec-*)
      popd;;
  esac
  cat "$benchres.line" | tee -a $benchres
}

function run_test_cmd {  # <test name> <command>
  echo "      " >> $benchres
  echo ""
  echo "---- $repeat: $1"  
  for alloc in $alloc_run; do     # use order as given on the command line
  # for alloc in $alloc_all; do   # use order as specified in $alloc_all
    if contains "$alloc_run" "$alloc"; then
      # echo "allocator: $alloc"
      alloc_lib_set "$alloc"  # sets alloc_lib to point to the allocator .so file
      for ((test_repeat=1; test_repeat<=$test_repeats; test_repeat++)); do
        case "$alloc" in
          sys) run_test_env_cmd $1 "sys" "SYSMALLOC=1" "$2";;
          dmi) run_test_env_cmd $1 "dmi" "MIMALLOC_VERBOSE=1 MIMALLOC_STATS=1 ${ldpreload}=$alloc_lib" "$2";;
          tbb) run_test_env_cmd $1 "tbb" "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$lib_tbb_dir ${ldpreload}=$alloc_lib" "$2";;
          *)   run_test_env_cmd $1 "$alloc" "${ldpreload}=$alloc_lib" "$2";;
        esac
      done
    fi
  done             
}


# --------------------------------------------------------------------
# Run all tests
# --------------------------------------------------------------------

echo "# benchmark allocator elapsed rss user sys page-faults page-reclaims" > $benchres

function run_test {  # <test>
  case $1 in
    cfrac)
      run_test_cmd "cfrac" "./cfrac 17545186520507317056371138836327483792789528";;
    espresso)
      run_test_cmd "espresso" "./espresso ../../bench/espresso/largest.espresso";;
    barnes)
      run_test_cmd "barnes" "./barnes";;
    gs)
      run_test_cmd "gs" "gs -dBATCH -dNODISPLAY $pdfdoc";;
    lean)
      pushd "$leandir/library"
      # run_test_cmd "lean1" "../bin/lean --make -j 1"
      if test $procs -gt 8; then # more than 8 makes it slower
        run_test_cmd "leanN" "../bin/lean --make -j 8"
      else
        run_test_cmd "leanN" "../bin/lean --make -j $procs"
      fi
      popd;;
    lean-mathlib)
      pushd "$leanmldir"
      run_test_cmd "mathlib" "$leandir/bin/leanpkg build"
      popd;;
    redis)
      # https://redis.io/topics/benchmarks
      #redis_tail="20"
      #run_test_cmd "redis" "$redis_dir/redis-benchmark -q -r 1000 -n 10000";;
      redis_tail="1"
      run_test_cmd "redis" "$redis_dir/redis-benchmark -r 1000000 -n 1000000 -q -P 16 lpush a 1 2 3 4 5 lrange a 1 5";;
    alloc-test)
      run_test_cmd "alloc-test1" "./alloc-test 1"
      if test "$procs" != "1"; then
        if test $procs -gt 16; then
          run_test_cmd "alloc-testN" "./alloc-test 16"  # 16 is the max for this test
        else
          run_test_cmd "alloc-testN" "./alloc-test $procs"
        fi
      fi;;
    larson)   
      run_test_cmd "larsonN" "./larson 5 8 1000 5000 100 4141 $procs";;
    larson-sized)
      run_test_cmd "larsonN-sized" "./larson-sized 5 8 1000 5000 100 4141 $procs";;
    sh6bench)
      run_test_cmd "sh6benchN" "./sh6bench $procsx2";;
    sh8bench)
      run_test_cmd "sh8benchN" "./sh8bench $procsx2";;
    xmalloc-test)
      #tds=`echo "$procs/2" | bc`
      run_test_cmd "xmalloc-testN" "./xmalloc-test -w $procs -t 5 -s 64"
      #run_test_cmd "xmalloc-fixedN" "./xmalloc-test -w 100 -t 5 -s 128"
      ;;
    cthrash)
      run_test_cmd "cache-thrash1" "./cache-thrash 1 1000 1 2000000 $procs"
      if test "$procs" != "1"; then
        run_test_cmd "cache-thrashN" "./cache-thrash $procs 1000 1 2000000 $procs"
      fi;;
    cscratch)
      run_test_cmd "cache-scratch1" "./cache-scratch 1 1000 1 2000000 $procs"
      if test "$procs" != "1"; then
        run_test_cmd "cache-scratchN" "./cache-scratch $procs 1000 1 2000000 $procs"
      fi;;
    malloc-large)
      # run_test_cmd "malloc-large-old" "./malloc-large-old"
      run_test_cmd "malloc-large" "./malloc-large";;
    z3)
      run_test_cmd "z3" "z3 -smt2 $benchdir/z3/test1.smt2";;
    rbstress)
      run_test_cmd "rbstress1" "ruby $benchdir/rbstress/stress_mem.rb 1"
      if test "$procs" != "1"; then
        run_test_cmd "rbstressN" "ruby $benchdir/rbstress/stress_mem.rb $procs"
      fi;;
    mstress)
      run_test_cmd "mstressN" "./mstress $procs 50 25";;
    mleak)
      run_test_cmd "mleak10"  "./mleak 5"
      run_test_cmd "mleak100" "./mleak 50";;
    rptest)
      run_test_cmd "rptestN" "./rptest $procs 0 1 2 500 1000 100 8 16000"
      # run_test_cmd "rptestN" "./rptest $procs 0 1 2 500 1000 100 8 128000"
      # run_test_cmd "rptestN" "./rptest $procs 0 1 2 500 1000 100 8 512000"
      ;;
    glibc-simple)
      run_test_cmd "glibc-simple" "./glibc-simple";;
    glibc-thread)
      run_test_cmd "glibc-thread" "./glibc-thread $procs";;
    sed)
      for i in {1..10000}; do echo "${i}.${i}.${i}.${i}" >> /tmp/sed_bench.txt; done
      run_test_cmd "sed" 'sed -E -n /^((.|.?){64}(.|.?)?(.|.?)){8}/p /tmp/sed_bench.txt'
      rm /tmp/sed_bench.txt;;
    spec)
      case "$run_spec_bench" in
        602) run_test_cmd "spec-602.gcc_s" "./sgcc_$spec_base.$spec_config gcc-pp.c -O5 -fipa-pta -o gcc-pp.opts-O5_-fipa-pta.s";;
        620) run_test_cmd "spec-620.omnetpp_s" "./omnetpp_s_$spec_base.$spec_config -c General -r 0";;
        623) run_test_cmd "spec-623.xalancbmk_s" "./xalancbmk_s_$spec_base.$spec_config -v t5.xml xalanc.xsl";;
        648) run_test_cmd "spec-648.exchange2_s" "./exchange2_s_base.malloc-test-m64 6";;
        *) echo "error: unknown spec benchmark";;
      esac;;
    *)
      warning "skipping unknown test: $1";;
  esac
}

# Clear previous results
if [ -f "$benchres" ]; then
  rm "$benchres"
fi

for ((repeat=1; repeat<=$repeats; repeat++)); do
  for tst in $tests_run; do
    run_test "$tst"
  done
done


# --------------------------------------------------------------------
# Wrap up
# --------------------------------------------------------------------

sed -i.bak "s/ 0:/ /" $benchres
echo ""
echo "results written to: $benchres"
echo ""
echo "#------------------------------------------------------------------"
echo "# test    alloc   time  rss    user  sys  page-faults page-reclaims"

cat $benchres 
echo ""
