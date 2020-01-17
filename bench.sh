#!/bin/bash
# Copyright 2018, Microsoft Research, Daan Leijen
echo "--- Benchmarking ---"
echo ""
echo "Use '-h' or '--help' for help on configuration options."
echo ""

procs=4

run_je=0
run_mi=0
run_dmi=0
run_smi=0
run_xmi=0
run_xdmi=0
run_xsmi=0

run_tc=0
run_hd=0
run_sys=0
run_rp=0
run_sm=0
run_sn=0
run_tbb=0
run_mesh=0
run_tlsf=0

run_cfrac=0
run_larson=0
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
run_rptest=0

verbose="no"
ldpreload="LD_PRELOAD"
case "$OSTYPE" in
  darwin*) ldpreload="DYLD_INSERT_LIBRARIES";;
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

pushd "../../extern" > null # up from `mimalloc-bench/out/bench`
localdevdir=`pwd`
popd > null
pushd "../../bench" > null
benchdir=`pwd`
popd > null

leandir="$localdevdir/lean"
leanmldir="$leandir/../mathlib"
redis_dir="$localdevdir/redis-5.0.3/src"
pdfdoc="$localdevdir/325462-sdm-vol-1-2abcd-3abcd.pdf"

lib_mi="$localdevdir/mimalloc/out/release/libmimalloc.so"
lib_dmi="$localdevdir/mimalloc/out/debug/libmimalloc-debug.so"
lib_smi="$localdevdir/mimalloc/out/secure/libmimalloc-secure.so"
lib_xmi="$localdevdir/../../mimalloc/out/release/libmimalloc.so"
lib_xdmi="$localdevdir/../../mimalloc/out/debug/libmimalloc-debug.so"
lib_xsmi="$localdevdir/../../mimalloc/out/secure/libmimalloc-secure.so"

lib_hd="$localdevdir/Hoard/src/libhoard.so"
lib_sn="$localdevdir/snmalloc/release/libsnmallocshim.so"
lib_sm="$localdevdir/SuperMalloc/release/lib/libsupermalloc.so"
#lib_sm="$localdevdir/SuperMalloc/release/lib/libsupermalloc_pthread.so"
lib_je="${localdevdir}/jemalloc/lib/libjemalloc.so"
lib_rp="`find ${localdevdir}/rpmalloc/bin/*/release -name librpmallocwrap.so`"
#lib_rp="/usr/lib/x86_64-linux-gnu/librpmallocwrap.so"
lib_mesh="${localdevdir}/mesh/libmesh.so"
lib_tlsf="${localdevdir}/tlsf/out/release/libtlsf.so"
lib_tc="$localdevdir/gperftools/.libs/libtcmalloc_minimal.so"
lib_tbb="`find $localdevdir/tbb/build -name libtbbmalloc_proxy.so.*`"

if test "$use_packages" = "1"; then
  lib_tc="/usr/lib/libtcmalloc.so"
  lib_tbb="/usr/lib/libtbbmalloc_proxy.so"

  if test -f "/usr/lib/x86_64-linux-gnu/libtcmalloc.so"; then
    lib_tc="/usr/lib/x86_64-linux-gnu/libtcmalloc.so"u
  fi
  if test -f "/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy.so"; then
    lib_tbb="/usr/lib/x86_64-linux-gnu/libtbbmalloc_proxy.so"
  fi
fi


spec_dir="$localdevdir/../../spec2017"
spec_base="base"
spec_bench="refspeed"
spec_config="malloc-test-m64"


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
        run_je=1
        run_mi=1
        #run_dmi=1
        #run_smi=1
        run_tc=1
        run_hd=1
        run_rp=1
        run_sm=1
        run_sn=1
        run_tbb=1
        run_sys=1;;
    allt)
        run_cfrac=1
        run_espresso=1
        run_barnes=1
        run_lean=1
        # run_lean_mathlib=1
        run_alloc_test=1
        run_xmalloc_test=1
        run_larson=1
        run_sh6bench=1
        run_sh8bench=1
        run_cscratch=1
	      run_redis=1
        run_mstress=1
        run_rptest=1
        run_rbstress=1
        # run_gs=1
        # run_cthrash=1
        # run_malloc_test=1
        ;;
    je)
        run_je=1;;
    rp)
        run_rp=1;;
    sm)
        run_sm=1;;
    sn)
        run_sn=1;;
    tc)
        run_tc=1;;
    mi)
        run_mi=1;;
    dmi)
        run_dmi=1;;
    smi)
        run_smi=1;;
    xmi)
        run_xmi=1;;
    xdmi)
        run_xdmi=1;;
    xsmi)
        run_xsmi=1;;
    hd)
        run_hd=1;;
    tbb)
        run_tbb=1;;
    mesh)
        run_mesh=1;;
    tlsf)
        run_tlsf=1;;
    sys|mc)
        run_sys=1;;
    cfrac)
        run_cfrac=1;;
    espresso)
        run_espresso=1;;
    barnes)
        run_barnes=1;;
    larson)
        run_larson=1;;
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
        echo "  je                           use jemalloc"
        echo "  tc                           use tcmalloc"
        echo "  mi                           use mimalloc"
        echo "  hd                           use hoard"
        echo "  sm                           use supermalloc"
        echo "  sn                           use snmalloc"
        echo "  rp                           use rpmalloc"
        echo "  tbb                          use Intel TBB malloc"
        echo "  mc                           use system malloc (glibc)"
        echo "  dmi                          use debug version of mimalloc"
        echo "  smi                          use secure version of mimalloc"
        echo "  mesh                         use mesh"
        echo ""
        echo "  cfrac                        run cfrac"
        echo "  espresso                     run espresso"
        echo "  barnes                       run barnes"
        echo "  gs                           run ghostscript (~1:50s per test)"
        echo "  lean                         run leanN (~40s per test on 4 cores)"
        echo "  math-lib                     run math-lib (~10 min per test on 4 cores)"
        echo "  redis                        run redis benchmark"
        echo "  spec=<num>                   run selected spec2017 benchmarks (if available)"
        echo "  larson                       run larsonN"
        echo "  alloc-test                   run alloc-testN"
        echo "  xmalloc-test                 run xmalloc-testN"
        echo "  sh6bench                     run sh6benchN"
        echo "  sh8bench                     run sh8benchN"
        echo "  cscratch                     run cache-scratch"
        echo "  cthrash                      run cache-thrash"
        echo "  mstress                      run mstressN"
        echo "  rbstress                     run rbstressN"
        echo "  rptest                       run rptestN"
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

benchres="$curdir/benchres.csv"
run_pre_cmd=""

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
       /usr/bin/time -a -o $benchres -f "$1 $2 %E %M %U %S %F %R" /usr/bin/env $3 $redis_dir/redis-server > "$outfile.server.txt"  &
       sleep 2s
       $redis_dir/redis-cli flushall
       sleep 1s
       $4 >> "$outfile"
       sleep 1s
       $redis_dir/redis-cli flushall
       $redis_dir/redis-cli shutdown
       sleep 1s
       ;;
    *)
       /usr/bin/time -a -o $benchres -f "$1 $2 %E %M %U %S %F %R" /usr/bin/env $3 $4 < "$infile" > "$outfile";;
  esac
  # fixup larson with relative time
  case "$1" in
    redis*)
      ops=`tail -$redis_tail "$outfile" | sed -n 's/.*: \([0-9\.]*\) requests per second.*/\1/p'`
      rtime=`echo "scale=3; (2000000 / $ops)" | bc`
      echo "$1 $2: ops/sec: $ops, relative time: ${rtime}s"
      sed -i "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    larson*)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/.* time: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2,${rtime}s"
      sed -i "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    rptest*)
      ops=`cat "$1-$2-out.txt" | sed -n 's/.*\.\.\.\([0-9]*\) memory ops.*/\1/p'`
      rtime=`echo "scale=3; (2000000 / $ops)" | bc`
      echo "$1,$2: ops/sec: $ops, relative time: ${rtime}s"
      sed -i "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    xmalloc*)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/rtime: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2,${rtime}s"
      sed -i "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    ebizzy)
      rtime=`cat "$1-$2-out.txt" | sed -n 's/rtime: \([0-9\.]*\).*/\1/p'`
      echo "$1,$2,${rtime}s"
      sed -i "s/$1 $2 [^ ]*/$1 $2 0:$rtime/" $benchres;;
    spec-*)
      popd;;
  esac
  tail -n1 $benchres
}

function run_mi_test {
  if test "$run_mi" = "1"; then
    run_testx $1 "mi" "${ldpreload}=$lib_mi" "$2"
  fi
}

function run_dmi_test {
  if test "$run_dmi" = "1"; then
    run_testx $1 "dmi" "MIMALLOC_VERBOSE=1 MIMALLOC_STATS=1 ${ldpreload}=$lib_dmi" "$2"
  fi
}

function run_smi_test {
  if test "$run_smi" = "1"; then
    run_testx $1 "smi" "${ldpreload}=$lib_smi" "$2"
  fi
}

function run_xmi_test {
  if test "$run_xmi" = "1"; then
    run_testx $1 "xmi" "${ldpreload}=$lib_xmi" "$2"
  fi
}

function run_xdmi_test {
  if test "$run_xdmi" = "1"; then
    run_testx $1 "xdmi" "${ldpreload}=$lib_xdmi" "$2"
  fi
}

function run_xsmi_test {
  if test "$run_xsmi" = "1"; then
    run_testx $1 "xsmi" "${ldpreload}=$lib_xsmi" "$2"
  fi
}

function run_je_test {
  if test "$run_je" = "1"; then
    run_testx $1 "je" "${ldpreload}=$lib_je" "$2"
  fi
}

function run_tc_test {
  if test "$run_tc" = "1"; then
    run_testx $1 "tc" "${ldpreload}=$lib_tc" "$2"
  fi
}

function run_hd_test {
  if test "$run_hd" = "1"; then
    run_testx $1 "hd" "${ldpreload}=$lib_hd" "$2"
  fi
}

function run_mesh_test {
  if test "$run_mesh" = "1"; then
    run_testx $1 "mesh" "${ldpreload}=$lib_mesh" "$2"
  fi
}

function run_rp_test {
  if test "$run_rp" = "1"; then
    run_testx $1 "rp" "${ldpreload}=$lib_rp" "$2"
  fi
}

function run_sm_test {
  if test "$run_sm" = "1"; then
    run_testx $1 "sm" "${ldpreload}=$lib_sm" "$2"
  fi
}

function run_sn_test {
  if test "$run_sn" = "1"; then
    run_testx $1 "sn" "${ldpreload}=$lib_sn" "$2"
  fi
}

function run_tbb_test {
  if test "$run_tbb" = "1"; then
    run_testx $1 "tbb" "${ldpreload}=$lib_tbb" "$2"
  fi
}

function run_tlsf_test {
  if test "$run_tlsf" = "1"; then
    run_testx $1 "tlsf" "${ldpreload}=$lib_tlsf" "$2"
  fi
}

function run_sys_test {
  if test "$run_sys" = "1"; then
    run_testx $1 "mc" "SYSMALLOC=1" "$2"
  fi
}

function run_test {
  echo "      " >> $benchres
  echo ""
  echo "---- $1"
  run_xmi_test $1 "$2"
  run_xdmi_test $1 "$2"
  run_xsmi_test $1 "$2"
  run_mi_test $1 "$2"
  run_dmi_test $1 "$2"
  run_smi_test $1 "$2"
  run_tc_test $1 "$2"
  run_je_test $1 "$2"
  run_sn_test $1 "$2"
  run_tbb_test $1 "$2"
  run_rp_test $1 "$2"
  run_hd_test $1 "$2"
  run_mesh_test $1 "$2"
  run_sm_test $1 "$2"
  run_tlsf_test $1 "$2"
  run_sys_test $1 "$2"
}

echo "# benchmark allocator elapsed rss user sys page-faults page-reclaims" > $benchres


if test "$run_cfrac" = "1"; then
  run_test "cfrac" "./cfrac 175451865205073170563711388363274837927895"
fi
if test "$run_espresso" = "1"; then
  run_test "espresso" "./espresso -s ../../bench/espresso/largest.espresso"
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
  run_test "leanN" "../bin/lean --make -j 8"
  popd
fi
if test "$run_lean_mathlib" = "1"; then
  pushd "$leanmldir"
  run_test "mathlib" "$leandir/bin/leanpkg build"
  popd
fi
if test "$run_redis" = "1"; then
  # redis_tail="2"
  # run_test "redis-incr" "$redis_dir/redis-benchmark  -r 1000000 -n 100000 -P 16  -q -t incr"
  redis_tail="1"
  run_test "redis" "$redis_dir/redis-benchmark -r 1000000 -n 1000000 -P 8 -q lpush a 1 2 3 4 5 6 7 8 9 10 lrange a 1 10"
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
  run_test "larsonN" "./larson 2.5 7 8 1000 10000 42 100"
fi
if test "$run_ebizzy" = "1"; then
  run_test "ebizzy" "./ebizzy -t $procs -M -S 2 -s 128"
fi
if test "$run_sh6bench" = "1"; then
  run_test "sh6benchN" "./sh6bench $procs"
fi
if test "$run_sh8bench" = "1"; then
  run_test "sh8benchN" "./sh8bench $procs"
fi
if test "$run_xmalloc_test" = "1"; then
  tds=`echo "2*$procs" | bc`
  run_test "xmalloc-testN" "./xmalloc-test -w $tds -t 5 -s 64"
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
  run_test "mstressN" "./mstress $procs 100 5"
fi

if test "$run_rptest" = "1"; then
  run_test "rptestN" "./rptest 16 0 2 2 500 1000 200 8 64000"
  # run_test "rptestN" "./rptest $procs 0 1 2 1000 1000 500 8 64000"
  # run_test "rptestN" "./rptest $procs 0 2 2 500 1000 200 16 1600000"
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

sed -i "s/ 0:/ /" $benchres
echo ""
echo "# --------------------------------------------------"
cat $benchres
