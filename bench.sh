#!/bin/bash
# Copyright 2018, Microsoft Research, Daan Leijen
echo "--- Benchmarking ---"
echo ""
echo "Use '-h' or '--help' for help on configuration options."
echo ""

all_allocators="sys je tc hd sp sm sn tbb mesh nomesh tlsf sc scudo hm iso mi dmi smi xmi xdmi xsmi"
run_allocators=""

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

leandir="$localdevdir/lean"
leanmldir="$leandir/../mathlib"
redis_dir="$localdevdir/redis-6.0.9/src"
pdfdoc="$localdevdir/325462-sdm-vol-1-2abcd-3abcd.pdf"

lib_mi="$localdevdir/mimalloc/out/release/libmimalloc$extso"
lib_dmi="$localdevdir/mimalloc/out/debug/libmimalloc-debug$extso"
lib_smi="$localdevdir/mimalloc/out/secure/libmimalloc-secure$extso"
lib_xmi="$localdevdir/../../mimalloc/out/release/libmimalloc$extso"
lib_xdmi="$localdevdir/../../mimalloc/out/debug/libmimalloc-debug$extso"
lib_xsmi="$localdevdir/../../mimalloc/out/secure/libmimalloc-secure$extso"
export MIMALLOC_EAGER_COMMIT_DELAY=0

lib_hd="$localdevdir/Hoard/src/libhoard$extso"
lib_sn="$localdevdir/snmalloc/release/libsnmallocshim$extso"
lib_sm="$localdevdir/SuperMalloc/release/lib/libsupermalloc$extso"
#lib_sm="$localdevdir/SuperMalloc/release/lib/libsupermalloc_pthread$extso"
lib_je="${localdevdir}/jemalloc/lib/libjemalloc$extso"
lib_rp="`find ${localdevdir}/rpmalloc/bin/*/release -name librpmallocwrap$extso`"
#lib_rp="/usr/lib/x86_64-linux-gnu/librpmallocwrap$extso"
lib_mesh="${localdevdir}/mesh/build/lib/libmesh$extso"
lib_nomesh="${localdevdir}/nomesh/build/lib/libmesh$extso"
lib_tlsf="${localdevdir}/tlsf/out/release/libtlsf$extso"
lib_tc="$localdevdir/gperftools/.libs/libtcmalloc_minimal$extso"
lib_sc="$localdevdir/scalloc/out/Release/lib.target/libscalloc$extso"
lib_tbb="$localdevdir/tbb/bench_release/libtbbmalloc_proxy$extso"
lib_tbb_dir="$(dirname $lib_tbb)"
lib_iso="${localdevdir}/iso/build/libisoalloc$extso"
lib_scudo="${localdevdir}/scudo/compiler-rt/lib/scudo/standalone/libscudo$extso"
lib_hm="${localdevdir}/hm/libhardened_malloc$extso"

if test "$use_packages" = "1"; then
  lib_tc="/usr/lib/libtcmalloc$extso"
  lib_tbb="/usr/lib/libtbbmalloc_proxy$extso"

  if test -f "/usr/lib/x86_64-linux-gnu/libtcmalloc$extso"; then
    lib_tc="/usr/lib/x86_64-linux-gnu/libtcmalloc$extso"u
  fi
  if test -f "/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy$extso"; then
    lib_tbb="/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy$extso"
  fi
fi


spec_dir="$localdevdir/../../spec2017"
spec_base="base"
spec_bench="refspeed"
spec_config="malloc-test-m64"

# list of allocators to run
run_allocators=""

function contains {
  for s in $1; do
    if test "$s" = "$2"; then
      return 0
    fi
  done
  return 1
}

function can_run {
  contains "$run_allocators" $1
}

function run_add {
  run_allocators="$run_allocators $1"
}


# Parse command-line arguments
while : ; do
  flag="$1"
  case "$flag" in
  *=*)  flag_arg="${flag#*=}";;
  *)    flag_arg="yes" ;;
  esac
  # echo "option: $flag, arg: $flag_arg"
  case "$flag" in
    "") break;;
    alla)
        # use all installed allocators
        run_allocators="sys"
        while read word _; do run_add "${word%:*}"; done < ${localdevdir}/versions.txt
        if can_run "mi"; then
          run_allocators="$run_allocators smi"   # secure mimalloc
        fi;;

    scudo)
        run_add "scudo";;
    hm)
        run_add "hm";;
    iso)
        run_add "iso";;
    je)
        run_add "je";;
    rp)
        run_add "rp";;
    sm)
        run_add "sm";;
    sn)
        run_add "sn";;
    sc)
        run_add "sc";;
    tc)
        run_add "tc";;
    mi)
        run_add "mi";;
    dmi)
        run_add "dmi";;
    smi)
        run_add "smi";;
    xmi)
        run_add "xmi";;
    xdmi)
        run_add "xdmi";;
    xsmi)
        run_add "xsmi";;
    hd)
        run_add "hd";;
    tbb)
        run_add "tbb";;
    mesh)
        run_add "mesh";;
    nomesh)
        run_add "nomesh";;
    tlsf)
        run_add "tlsf";;
    sys|mc)
        run_add "sys";;

    allt)
        run_cfrac=1
        run_espresso=1
        run_barnes=1
        run_lean=1
        run_xmalloc_test=1
        run_larson=1        
        run_larson_sized=1
        run_cscratch=1
	      run_mstress=1
        if [ -z "$darwin" ]; then
          run_rptest=1
          run_alloc_test=1
          run_sh6bench=1
          run_sh8bench=1
          run_redis=1        
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
  shift
done
echo "Running on $procs cores."
export verbose

if test "$verbose"="yes"; then
  echo "Installed allocators:"
  echo ""
  cat ${localdevdir}/versions.txt | column -t
  echo ""
fi

echo "Allocators to be tested: $run_allocators"
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

function run_testx {
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
    spec-*)
      popd;;
  esac
  tail -n1 $benchres
}


function try_run_test {  # test allocator env-args lib cmd
  if can_run $2; then
    if [ -z "$4" ]; then
      run_testx $1 $2 "$3" "$5"
    else
      run_testx $1 $2 "$3 ${ldpreload}=$4" "$5"
    fi
  fi
}

function run_test {
  echo "      " >> $benchres
  echo ""
  echo "---- $1"  
  try_run_test $1 "sys"   "SYSMALLOC=1" "" "$2"
  try_run_test $1 "xmi"   "" $lib_xmi   "$2"
  try_run_test $1 "xdmi"  "" $lib_xdmi  "$2"
  try_run_test $1 "xsmi"  "" $lib_xsmi  "$2"
  try_run_test $1 "mi"    "" $lib_mi    "$2"
  try_run_test $1 "dmi"   "MIMALLOC_VERBOSE=1 MIMALLOC_STATS=1" $lib_dmi "$2"
  try_run_test $1 "smi"   "" $lib_smi   "$2"
  try_run_test $1 "tc"    "" $lib_tc    "$2"
  try_run_test $1 "je"    "" $lib_je    "$2"
  try_run_test $1 "tbb"   "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$lib_tbb_dir" $lib_tbb "$2"
  try_run_test $1 "scudo" "" $lib_scudo "$2"
  try_run_test $1 "hm"    "" $lib_hm    "$2"
  try_run_test $1 "iso"   "" $lib_iso   "$2"
  try_run_test $1 "sm"    "" $lib_sm    "$2"
  try_run_test $1 "sc"    "" $lib_sc    "$2"
  try_run_test $1 "sn"    "" $lib_sn    "$2"
  try_run_test $1 "rp"    "" $lib_rp    "$2"
  try_run_test $1 "hd"    "" $lib_hd    "$2"
  try_run_test $1 "mesh"  "" $lib_mesh  "$2"
  try_run_test $1 "nomesh"  "" $lib_nomesh "$2"
  try_run_test $1 "tlsf"  "" $lib_tlsf  "$2"  
}

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
