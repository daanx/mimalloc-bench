#!/bin/bash
# Copyright 2018-2021, Microsoft Research, Daan Leijen
echo "--- Benchmarking ---"
echo ""
echo "Use '-h' or '--help' for help on configuration options."
echo ""

alloc_all="sys je tc hd sp sm sn tbb mesh nomesh tlsf sc scudo hm iso mi dmi smi xmi xdmi xsmi"
alloc_run=""           # allocators to run (expanded by command line options)
alloc_installed="sys"  # later expanded to include all installed allocators
alloc_libs="sys="      # mapping from allocator to its .so as "<allocator>=<sofile> ..."

run_cfrac=0
run_larson=0
run_larson_sized=0
run_ebizzy=0
run_sh6bench=0
run_sh8bench=0
run_espresso=0
run_barnes=0
run_lean=0
run_lean_mathlib=0
run_alloc_test=0
run_malloc_test=0
run_xmalloc_test=0
run_malloc_large=0
run_cthrash=0
run_cscratch=0
run_z3=0
run_redis=0
run_gs=0
run_rbstress=0
run_spec=0
run_spec_bench=0
run_mstress=0
run_mleak=0
run_rptest=0
run_glibc_simple=0
run_glibc_thread=0

# --------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------

verbose="no"
ldpreload="LD_PRELOAD"
timecmd=/usr/bin/time
darwin=""
extso=".so"
procs=8
case "$OSTYPE" in
  darwin*) 
    darwin="yes"
    timecmd=gtime  # use brew install gnu-time
    extso=".dylib"
    ldpreload="DYLD_INSERT_LIBRARIES"
    procs=`sysctl -n hw.physicalcpu`;;
  *)
    if command -v nproc; then 
      procs=`nproc`
    fi;;
esac

# --------------------------------------------------------------------
# Check directories
# --------------------------------------------------------------------

curdir=`pwd`
if test -f ../../build-bench-env.sh; then
  :
else
  echo "error: you must run this script from the 'out/bench' directory!"
  exit 1
fi

if test -d ../../extern; then
  :
else
  echo "error: you must first run `./build-build/bench.sh` (in `../..`) to install benchmarks and allocators."
  exit 1
fi

pushd "../../extern" > /dev/null # up from `mimalloc-bench/out/bench`
localdevdir=`pwd`
popd > /dev/null
pushd "../../bench" > /dev/null
benchdir=`pwd`
popd > /dev/null


# --------------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------------

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

function is_runnable {   # <allocator>
  contains "$alloc_run" $1
}

function alloc_run_add {  # <allocator>   :add to runnable
  alloc_run="$alloc_run $1"
}

function alloc_run_remove {   # <allocator>  :remove from runnables
  if is_runnable "$1"; then
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
  alloc_installed="$alloc_installed smi"   # secure mimalloc
fi


function alloc_lib_add {  # <allocator> <variable> <librarypath>
  alloc_libs="$1=$2 $alloc_libs"
}

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
  echo "warning: cannot set library path for allocator $1"
  alloc_lib="lib$1.so"
}


# --------------------------------------------------------------------
# The allocator library paths
# --------------------------------------------------------------------

leandir="$localdevdir/lean"
leanmldir="$leandir/../mathlib"
redis_dir="$localdevdir/redis-6.0.9/src"
pdfdoc="$localdevdir/325462-sdm-vol-1-2abcd-3abcd.pdf"

spec_dir="$localdevdir/../../spec2017"
spec_base="base"
spec_bench="refspeed"
spec_config="malloc-test-m64"

alloc_lib_add "mi"    "$localdevdir/mimalloc/out/release/libmimalloc$extso"
alloc_lib_add "dmi"   "$localdevdir/mimalloc/out/debug/libmimalloc-debug$extso"
alloc_lib_add "smi"   "$localdevdir/mimalloc/out/secure/libmimalloc-secure$extso"
alloc_lib_add "xmi"   "$localdevdir/../../mimalloc/out/release/libmimalloc$extso"
alloc_lib_add "xdmi"  "$localdevdir/../../mimalloc/out/debug/libmimalloc-debug$extso"
alloc_lib_add "xsmi"  "$localdevdir/../../mimalloc/out/secure/libmimalloc-secure$extso"
export MIMALLOC_EAGER_COMMIT_DELAY=0
alloc_lib_add "hd"    "$localdevdir/Hoard/src/libhoard$extso"
alloc_lib_add "sn"    "$localdevdir/snmalloc/release/libsnmallocshim$extso"
alloc_lib_add "sm"    "$localdevdir/SuperMalloc/release/lib/libsupermalloc$extso"
alloc_lib_add "je"    "${localdevdir}/jemalloc/lib/libjemalloc$extso"
alloc_lib_add "rp"    "`find ${localdevdir}/rpmalloc/bin/*/release -name librpmallocwrap$extso`"
#lib_rp="/usr/lib/x86_64-linux-gnu/librpmallocwrap$extso"
alloc_lib_add "mesh"  "${localdevdir}/mesh/build/lib/libmesh$extso"
alloc_lib_add "nomesh" "${localdevdir}/nomesh/build/lib/libmesh$extso"
alloc_lib_add "tlsf"  "${localdevdir}/tlsf/out/release/libtlsf$extso"
alloc_lib_add "tc"    "$localdevdir/gperftools/.libs/libtcmalloc_minimal$extso"
alloc_lib_add "sc"    "$localdevdir/scalloc/out/Release/lib.target/libscalloc$extso"
alloc_lib_add "iso"   "${localdevdir}/iso/build/libisoalloc$extso"
alloc_lib_add "scudo" "${localdevdir}/scudo/compiler-rt/lib/scudo/standalone/libscudo$extso"
alloc_lib_add "hm"    "${localdevdir}/hm/libhardened_malloc$extso"
alloc_lib_add "tbb"   "$localdevdir/tbb/bench_release/libtbbmalloc_proxy$extso"
lib_tbb_dir="$(dirname $lib_tbb)"

if test "$use_packages" = "1"; then
  alloc_lib_add "tc"  "/usr/lib/libtcmalloc$extso"
  alloc_lib_add "tbb" "/usr/lib/libtbbmalloc_proxy$extso"

  if test -f "/usr/lib/x86_64-linux-gnu/libtcmalloc$extso"; then
    alloc_lib_add "tc" "/usr/lib/x86_64-linux-gnu/libtcmalloc$extso"u
  fi
  if test -f "/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy$extso"; then
    alloc_lib_add "tbb" "/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy$extso"
  fi
fi


# --------------------------------------------------------------------
# Parse command line
# --------------------------------------------------------------------

while : ; do
  flag="$1"
  case "$flag" in
    *=*)  flag_arg="${flag#*=}"
          flag="${flag%=*}";;
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
      echo "warning: allocator '$flag' selected but it is not installed ($alloc_installed)"
    fi
    alloc_run_add_remove "$flag" "$flag_arg"    
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

      allt)
          run_cfrac=1
          run_espresso=1
          run_barnes=1
          run_xmalloc_test=1
          run_larson=1        
          run_larson_sized=1
          run_cscratch=1
          run_mstress=1
          run_glibc_simple=1
          run_glibc_thread=1
          if [ -z "$darwin" ]; then
            run_rptest=1
            run_alloc_test=1
            run_sh6bench=1
            run_sh8bench=1
            run_redis=1        
          fi
          if [ -f "${localdevdir}/lean/bin/lean" ]; then  # only run lean if it is installed (for CI)
            run_lean=1
          fi
          # run_lean_mathlib=1
          # run_gs=1
          # run_rbstress=1
          # run_cthrash=1
          # run_malloc_test=1
          ;;

      cfrac)
          run_cfrac=1;;
      espresso)
          run_espresso=1;;
      barnes)
          run_barnes=1;;
      larson)
          run_larson=1;;
      larson-sized)
          run_larson_sized=1;;
      ebizzy)
          run_ebizzy=1;;
      sh6bench)
          run_sh6bench=1;;
      sh8bench)
          run_sh8bench=1;;
      cthrash)
          run_cthrash=1;;
      cscratch)
          run_cscratch=1;;
      lean)
          run_lean=1;;
      no-lean)
          run_lean=0;;
      z3)
          run_z3=1;;
      gs)
          run_gs=1;;
      alloc-test)
          run_alloc_test=1;;
      malloc-test)
          run_malloc_test=1;;
      xmalloc-test)
          run_xmalloc_test=1;;
      malloc-large)
          run_malloc_large=1;;
      mathlib)
          run_lean_mathlib=1;;
      redis)
          run_redis=1;;
      rbstress)
          run_rbstress=1;;
      mstress)
          run_mstress=1;;
      mleak)
          run_mleak=1;;
      rptest)
          run_rptest=1;;
      glibc-simple)
          run_glibc_simple=1;;
      glibc-thread)
          run_glibc_thread=1;;
      spec=*)
          run_spec=1
          run_spec_bench="$flag_arg";;

      -j=*|--procs=*)
          procs="$flag_arg";;
      -v|--verbose)
          verbose="yes";;
      -h|--help|-\?|help|\?)
          echo "./bench [options]"
          echo ""
          echo "  allt                         run all tests"
          echo "  alla                         run all allocators"
          echo ""
          echo "  --verbose                    be verbose"
          echo "  --procs=<n>                  number of processors (=$procs)"
          echo ""
          echo "  sys                          use system malloc (glibc)"
          echo "  je                           use jemalloc"
          echo "  tc                           use tcmalloc"
          echo "  mi                           use mimalloc"
          echo "  hd                           use hoard"
          echo "  sm                           use supermalloc"
          echo "  sn                           use snmalloc"
          echo "  sc                           use scalloc"
          echo "  rp                           use rpmalloc"
          echo "  tbb                          use Intel TBB malloc"
          echo "  scudo                        use scudo"
          echo "  hm                           use hardened_malloc"
          echo "  iso                          use isoalloc"
          echo "  dmi                          use debug version of mimalloc"
          echo "  smi                          use secure version of mimalloc"
          echo "  mesh                         use mesh"
          echo "  nomesh                       use mesh w/ meshing disabled"
          echo ""
          echo "  cfrac                        run cfrac"
          echo "  espresso                     run espresso"
          echo "  barnes                       run barnes"
          echo "  gs                           run ghostscript (~1:50s per test)"
          echo "  lean                         run leanN (~40s per test on 4 cores)"
          echo "  mathlib                      run mathlib (~10 min per test on 4 cores)"
          echo "  redis                        run redis benchmark"
          echo "  spec=<num>                   run selected spec2017 benchmarks (if available)"
          echo "  larson                       run larsonN"
          echo "  larson-sized                 run larsonN sized deallocation test"
          echo "  alloc-test                   run alloc-testN"
          echo "  xmalloc-test                 run xmalloc-testN"
          echo "  sh6bench                     run sh6benchN"
          echo "  sh8bench                     run sh8benchN"
          echo "  cscratch                     run cache-scratch"
          echo "  cthrash                      run cache-thrash"
          echo "  mstress                      run mstressN"
          echo "  rbstress                     run rbstressN"
          echo "  rptest                       run rptestN"
          echo "  mleak                        run mleakN"
          echo ""
          exit 0;;
      *) echo "warning: unknown option \"$1\"." 1>&2
    esac
  fi
  shift
done
echo "Running on $procs cores."
export verbose



# --------------------------------------------------------------------
# Info
# --------------------------------------------------------------------

if test "$verbose"="yes"; then
  echo "Installed allocators:"
  echo ""
  cat ${localdevdir}/versions.txt | column -t
  echo ""
fi

echo "Allocators to be tested: $alloc_run"
echo ""

benchres="$curdir/benchres.csv"
run_pre_cmd=""

procs16=$procs
if [ 18 -gt $procs ]; then
  procs16=16
fi

procsx2=`echo "($procs*2)" | bc`
procsx4=`echo "($procs*4)" | bc`

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

function run_testx { # <test name> <allocator name> <environment args> <command>
  echo
  echo "run $1 $2: $3 $4"
  # cat $benchres
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
      spec_subdir="${1#*-}"
      set_spec_bench_dir "$spec_dir/benchspec/CPU/$spec_subdir/run/run_${spec_base}_${spec_bench}_${spec_config}"
      echo "run spec benchmark in: $spec_bench_dir"
      pushd "$spec_bench_dir";;
    larson*|ebizzy|redis*|xmalloc*)
      outfile="$1-$2-out.txt";;
    barnes)
      infile="$benchdir/barnes/input";;
  esac
  case "$1" in
    redis*)
       echo "start server"
       $timecmd -a -o $benchres -f "$1 $2 %E %M %U %S %F %R" /usr/bin/env $3 $redis_dir/redis-server > "$outfile.server.txt"  &
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
       $timecmd -a -o $benchres -f "$1 $2 %E %M %U %S %F %R" /usr/bin/env $3 $4 < "$infile" > "$outfile";;
  esac
  # fixup larson with relative time
  case "$1" in
    redis*)
      ops=`tail -$redis_tail "$outfile" | sed -n 's/.*: \([0-9\.]*\) requests per second.*/\1/p'`
      rtime=`echo "scale=3; (2000000 / $ops)" | bc`
      echo "$1 $2: ops/sec: $ops, relative time: ${rtime}s"
      sed -i.bak "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    larson*)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/.* time: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2,${rtime}s"
      sed -i.bak "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    rptest*)
      ops=`cat "$1-$2-out.txt" | sed -n 's/.*\.\.\.\([0-9]*\) memory ops.*/\1/p'`
      rtime=`echo "scale=3; (2000000 / $ops)" | bc`
      echo "$1,$2: ops/sec: $ops, relative time: ${rtime}s"
      sed -i.bak "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    xmalloc*)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/rtime: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2,${rtime}s"
      sed -i.bak "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    ebizzy)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/rtime: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2,${rtime}s"
      sed -i.bak "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    glibc-thread)
      ops=`cat "$1-$2-out.txt" | sed -n 's/\([0-9\.]*\).*/\1/p'`
      rtime=`echo "scale=3; (10000000000 / $ops)" | bc`
      echo "$1 $2: iterations: ${ops}, relative time: ${rtime}s"
      sed -i.bak "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    spec-*)
      popd;;
  esac
  tail -n1 $benchres
}

function run_test {  # <test name> <command>
  echo "      " >> $benchres
  echo ""
  echo "---- $1"  
  for alloc in $alloc_run; do
    # echo "allocator: $alloc"
    alloc_lib_set "$alloc"  # sets alloc_lib to point to the allocator .so file
    case "$alloc" in
      sys) run_testx $1 "sys" "SYSMALLOC=1" "$2";;
      dmi) run_testx $1 "dmi" "MIMALLOC_VERBOSE=1 MIMALLOC_STATS=1 ${ldpreload}=$alloc_lib" "$2";;
      tbb) run_testx $1 "tbb" "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$lib_tbb_dir ${ldpreload}=$alloc_lib" "$2";;
      *)   run_testx $1 "$alloc" "${ldpreload}=$alloc_lib" "$2";;
    esac
  done           
}


# --------------------------------------------------------------------
# Run all tests
# --------------------------------------------------------------------

echo "# benchmark allocator elapsed rss user sys page-faults page-reclaims" > $benchres


if test "$run_cfrac" = "1"; then
  run_test "cfrac" "./cfrac 17545186520507317056371138836327483792789528"
fi
if test "$run_espresso" = "1"; then
  run_test "espresso" "./espresso ../../bench/espresso/largest.espresso"
fi
if test "$run_barnes" = "1"; then
  run_test "barnes" "./barnes"
fi
if test "$run_gs" = "1"; then
  run_test "gs" "gs -dBATCH -dNODISPLAY $pdfdoc"
fi
if test "$run_lean" = "1"; then
  pushd "$leandir/library"
  # run_test "lean1" "../bin/lean --make -j 1"
  run_test "leanN" "../bin/lean --make -j 8" # more than 8 makes it slower
  popd
fi
if test "$run_lean_mathlib" = "1"; then
  pushd "$leanmldir"
  run_test "mathlib" "$leandir/bin/leanpkg build"
  popd
fi
if test "$run_redis" = "1"; then
  #redis_tail="2"
  #run_test "redis-lpush" "$redis_dir/redis-benchmark  -r 1000000 -n 100000 -P 16  -q -t lpush"
  redis_tail="1"
  run_test "redis" "$redis_dir/redis-benchmark -r 1000000 -n 1000000 -q -P 16 lpush a 1 2 3 4 5 lrange a 1 5"
fi

if test "$run_alloc_test" = "1"; then
  run_test "alloc-test1" "./alloc-test 1"
  if test "$procs" != "1"; then
    if test $procs -gt 16; then
      run_test "alloc-testN" "./alloc-test 16"  # 16 is the max for this test
    else
      run_test "alloc-testN" "./alloc-test $procs"
    fi
  fi
fi
if test "$run_larson" = "1"; then
  run_test "larsonN" "./larson 5 8 1000 5000 100 4141 $procs"
fi
if test "$run_larson_sized" = "1"; then
  run_test "larsonN-sized" "./larson-sized 5 8 1000 5000 100 4141 $procs"
fi
if test "$run_ebizzy" = "1"; then
  run_test "ebizzy" "./ebizzy -t $procs -M -S 2 -s 128"
fi
if test "$run_sh6bench" = "1"; then
  run_test "sh6benchN" "./sh6bench $procsx2"
fi
if test "$run_sh8bench" = "1"; then
  run_test "sh8benchN" "./sh8bench $procsx2"
fi
if test "$run_xmalloc_test" = "1"; then
  #tds=`echo "$procs/2" | bc`
  run_test "xmalloc-testN" "./xmalloc-test -w $procs -t 5 -s 64"
  #run_test "xmalloc-fixedN" "./xmalloc-test -w 100 -t 5 -s 128"
fi
if test "$run_cthrash" = "1"; then
  run_test "cache-thrash1" "./cache-thrash 1 1000 1 2000000 $procs"
  if test "$procs" != "1"; then
    run_test "cache-thrashN" "./cache-thrash $procs 1000 1 2000000 $procs"
  fi
fi
if test "$run_cscratch" = "1"; then
  run_test "cache-scratch1" "./cache-scratch 1 1000 1 2000000 $procs"
  if test "$procs" != "1"; then
    run_test "cache-scratchN" "./cache-scratch $procs 1000 1 2000000 $procs"
  fi
fi

if test "$run_malloc_test" = "1"; then
  run_test "malloc-test" "./malloc-test"
fi

if test "$run_malloc_large" = "1"; then
  run_test "malloc-large" "./malloc-large"
fi


if test "$run_z3" = "1"; then
  run_test "z3" "z3 -smt2 $benchdir/z3/test1.smt2"
fi

if test "$run_rbstress" = "1"; then
  run_test "rbstress1" "ruby $benchdir/rbstress/stress_mem.rb 1"
  if test "$procs" != "1"; then
    run_test "rbstressN" "ruby $benchdir/rbstress/stress_mem.rb $procs"
  fi
fi

if test "$run_mstress" = "1"; then
  run_test "mstressN" "./mstress $procs 50 25"
fi

if test "$run_mleak" = "1"; then
  run_test "mleak10"  "./mleak 5"
  run_test "mleak100" "./mleak 50"
fi

if test "$run_rptest" = "1"; then
  run_test "rptestN" "./rptest $procs16 0 1 2 500 1000 100 8 16000"
  # run_test "rptestN" "./rptest $procs16 0 1 2 500 1000 100 8 128000"
  # run_test "rptestN" "./rptest $procs16 0 1 2 500 1000 100 8 512000"
fi

if test "$run_glibc_simple" = "1"; then
  run_test "glibc-simple" "./glibc-simple"
fi

if test "$run_glibc_thread" = "1"; then
  run_test "glibc-thread" "./glibc-thread $procs"
fi

if test "$run_spec" = "1"; then
  case "$run_spec_bench" in
    602) run_test "spec-602.gcc_s" "./sgcc_$spec_base.$spec_config gcc-pp.c -O5 -fipa-pta -o gcc-pp.opts-O5_-fipa-pta.s";;
    620) run_test "spec-620.omnetpp_s" "./omnetpp_s_$spec_base.$spec_config -c General -r 0";;
    623) run_test "spec-623.xalancbmk_s" "./xalancbmk_s_$spec_base.$spec_config -v t5.xml xalanc.xsl";;
    648) run_test "spec-648.exchange2_s" "./exchange2_s_base.malloc-test-m64 6";;
    *) echo "error: unknown spec benchmark";;
  esac
fi

sed -i.bak "s/ 0:/ /" $benchres
echo ""
echo "# --------------------------------------------------"
cat $benchres
