<img align="left" width="100" height="100" src="doc/mimalloc-logo.png"/>

# Mimalloc-bench

&nbsp;

Suite for benchmarking malloc implementations, originally
developed for benchmarking [`mimalloc`](https://github.com/microsoft/mimalloc).
Collection of various benchmarks from the academic literature, together with
automated scripts to pull specific versions of benchmark programs and
allocators from Github and build them.

Due to the large variance in programs and allocators, the suite is currently
only developed for Linux-like systems, and specifically Ubuntu with `apt-get`.

It is quite easy to add new benchmarks and allocator implementations --
please do so!.

Enjoy,
  Daan


Note that all the code in the `bench` directory is not part of
_mimalloc-bench_ as such, and all programs in the `bench` directory are
governed under their own specific licenses and copyrights as detailed in
their `README.md` (or `license.txt`) files. They are just included here for convenience.


# Benchmarking

The `build-bench-env.sh` script will automatically pull all needed benchmarks
and allocators and build them on Linux systems with `apt-get`:
```
~/dev/mimalloc-bench> ./build-bench-env.sh
```
It starts installing packages and you will need to enter the sudo password.
All other programs will be build as a peer to `mimalloc-bench`, e.g. `~/dev/Hoard`,
`~/dev/jemalloc`, and `~/dev/lean`.

If everything succeeded, you can run the full benchmark suite (from `out/bench`) as:

- `~/dev/mimalloc-bench> cd out/bench`
- `~/dev/mimalloc-bench/out/bench>../../bench.sh alla allt`

Or just test _mimalloc_ and _tcmalloc_ on _cfrac_ and _larson_ with 16 threads:

- `~/dev/mimalloc-bench/out/bench>../../bench.sh --procs=16 mi tc cfrac larson`

Generally, you can specify the allocators (`mi`,`je`,
`tc`, `hd`, `mc` (system allocator)) etc, and the benchmarks
, `cfrac`, `espresso`, `barnes`, `lean`, `larson`, `alloc-test`, `cscratch`, etc.
Or all allocators (`alla`) and tests (`allt`).
Use `--procs=<n>` to set the concurrency, and use `--help` to see all supported
allocators and benchmarks.


## Current Allocators

Supported allocators are:

- **mi**: The [_mimalloc_](https://github.com/microsoft/mimalloc) allocator,
  using version tag `v1.0.0`.
  We can also test a secure version of _mimalloc_ as **smi**, and
  the debug version as **dmi** (this can be used to check for any bugs
  in the benchmarks).
- **tc**: The [_tcmalloc_](https://github.com/gperftools/gperftools)
  allocator which comes as part of
  the Google performance tools and is used in the Chrome browser.
  Installed as package `libgoogle-perftools-dev` version
  `2.5-2.2ubuntu3`.
- **je**: The [_jemalloc_](https://github.com/jemalloc/jemalloc)
  allocator by Jason Evans is developed at Facebook
  and widely used in practice, for example in FreeBSD and Firefox.
  Using version tag 5.2.0.
- **sn**: The [_snmalloc_](https://github.com/microsoft/snmalloc) allocator
  is a recent concurrent message passing
  allocator by Liétar et al. \[8]. Using `git-0b64536b`.
- **rp**: The [_rpmalloc_](https://github.com/rampantpixels/rpmalloc) allocator
   uses 32-byte aligned allocations and is developed by Mattias Jansson at Rampant Pixels.
   Using version tag 1.3.1.
- **hd**: The [_Hoard_](https://github.com/emeryberger/Hoard) allocator by
  Emery Berger \[1]. This is one of the first
  multi-thread scalable allocators. Using version tag 3.13.
- **glibc**,**mc**: The system allocator. Here we use the _glibc_ allocator (which is originally based on
  _Ptmalloc2_), using version 2.27.0. Note that version 2.26 significantly improved scalability over
  earlier versions.
- **sm**: The [_Supermalloc_](https://github.com/kuszmaul/SuperMalloc) allocator by
  Bradley Kuszmaul uses hardware transactional memory
  to speed up parallel operations. Using version `git-709663fb`.
- **tbb**: The Intel [TBB](https://github.com/intel/tbb) allocator that comes with
  the Thread Building Blocks (TBB) library \[7].
  Installed as package `libtbb-dev`, version `2017~U7-8`.


## Current Benchmarks

The first set of benchmarks are real world programs and consist of:

- __cfrac__: by Dave Barrett, implementation of continued fraction factorization which
  uses many small short-lived allocations -- exactly the workload
  we are targeting for Koka and Lean.   
- __espresso__: a programmable logic array analyzer, described by
  Grunwald, Zorn, and Henderson \[3]. in the context of cache aware memory allocation.
- __barnes__: a hierarchical n-body particle solver \[4] which uses relatively few
  allocations compared to `cfrac` and `espresso`. Simulates the gravitational forces
  between 163840 particles.
- __leanN__:  The [Lean](https://github.com/leanprover/lean) compiler by
  de Moura _et al_, version 3.4.1,
  compiling its own standard library concurrently using N threads
  (`./lean --make -j N`). Big real-world workload with intensive
  allocation.
- __redis__: running the [redis](https://redis.io/) 5.0.3 server on
  1 million requests pushing 10 new list elements and then requesting the
  head 10 elements. Measures the requests handled per second.
- __larsonN__: by Larson and Krishnan \[2]. Simulates a server workload using 100 separate
   threads which each allocate and free many objects but leave some
   objects to be freed by other threads. Larson and Krishnan observe this
   behavior (which they call _bleeding_) in actual server applications,
   and the benchmark simulates this.

The second set of  benchmarks are stress tests and consist of:

- __alloc-test__: a modern allocator test developed by
  OLogN Technologies AG ([ITHare.com](http://ithare.com/testing-memory-allocators-ptmalloc2-tcmalloc-hoard-jemalloc-while-trying-to-simulate-real-world-loads/))
  Simulates intensive allocation workloads with a Pareto size
  distribution. The _alloc-testN_ benchmark runs on N cores doing
  100&middot;10^6^ allocations per thread with objects up to 1KiB
  in size. Using commit `94f6cb`
  ([master](https://github.com/node-dot-cpp/alloc-test), 2018-07-04)
- __sh6bench__: by [MicroQuill](http://www.microquill.com/) as part of SmartHeap. Stress test
   where some of the objects are freed in a
   usual last-allocated, first-freed (LIFO) order, but others are freed
   in reverse order. Using the
   public [source](http://www.microquill.com/smartheap/shbench/bench.zip)
   (retrieved 2019-01-02)
- __sh8benchN__: by [MicroQuill](http://www.microquill.com/) as part of SmartHeap. Stress test for
  multi-threaded allocation (with N threads) where, just as in _larson_,
  some objects are freed by other threads, and some objects freed in
  reverse (as in _sh6bench_). Using the
  public [source](http://www.microquill.com/smartheap/SH8BENCH.zip)
  (retrieved 2019-01-02)
- __xmalloc-testN__: by Lever and Boreham \[5] and Christian Eder. We use the updated
  version from the SuperMalloc repository. This is a more
  extreme version of the _larson_ benchmark with 100 purely allocating threads,
  and 100 purely deallocating threads with objects of various sizes migrating
  between them. This asymmetric producer/consumer pattern is usually difficult
  to handle by allocators with thread-local caches.
- __cache-scratch__: by Emery Berger \[1]. Introduced with the Hoard
  allocator to test for _passive-false_ sharing of cache lines: first
  some small objects are allocated and given to each thread; the threads
  free that object and allocate immediately another one, and access that
  repeatedly. If an allocator allocates objects from different threads
  close to each other this will lead to cache-line contention.


## Example

Below is an example (Apr 2019) of the benchmark results on an HP
Z4-G4 workstation with a 4-core Intel® Xeon® W2123 at 3.6 GHz with 16GB
ECC memory, running Ubuntu 18.04.1 with LibC 2.27 and GCC 7.3.0.

![bench-z4-1](doc/bench-z4-1.svg)
![bench-z4-2](doc/bench-z4-2.svg)

Memory usage:

![bench-z4-rss-1](doc/bench-z4-rss-1.svg)
![bench-z4-rss-2](doc/bench-z4-rss-2.svg)

(note: the _xmalloc-testN_ memory usage should be disregarded is it
allocates more the faster the program runs. Unfortunately,
there are no entries for _SuperMalloc_ in the _leanN_ and _xmalloc-testN_
benchmarks as it faulted on those)


# References

- \[1] Emery D. Berger, Kathryn S. McKinley, Robert D. Blumofe, and Paul R. Wilson.
   _Hoard: A Scalable Memory Allocator for Multithreaded Applications_
   the Ninth International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS-IX). Cambridge, MA, November 2000.
   [pdf](http://www.cs.utexas.edu/users/mckinley/papers/asplos-2000.pdf)


- \[2] P. Larson and M. Krishnan. _Memory allocation for long-running server applications_. In ISMM, Vancouver, B.C., Canada, 1998.
      [pdf](http://citeseemi.ist.psu.edu/viewdoc/download;jsessionid=5F0BFB4F57832AEB6C11BF8257271088?doi=10.1.1.45.1947&rep=rep1&type=pdf)

- \[3] D. Grunwald, B. Zorn, and R. Henderson.
  _Improving the cache locality of memory allocation_. In R. Cartwright, editor,
  Proceedings of the Conference on Programming Language Design and Implementation, pages 177–186, New York, NY, USA, June 1993.
  [pdf](http://citeseemi.ist.psu.edu/viewdoc/download?doi=10.1.1.43.6621&rep=rep1&type=pdf)

- \[4] J. Barnes and P. Hut. _A hierarchical O(n*log(n)) force-calculation algorithm_. Nature, 324:446-449, 1986.

- \[5] C. Lever, and D. Boreham. _Malloc() Performance in a Multithreaded Linux Environment._
  In USENIX Annual Technical Conference, Freenix Session. San Diego, CA. Jun. 2000.
  Available at <https://​github.​com/​kuszmaul/​SuperMalloc/​tree/​master/​tests>

- \[6] Timothy Crundal. _Reducing Active-False Sharing in TCMalloc._
   2016. <http://​courses.​cecs.​anu.​edu.​au/​courses/​CSPROJECTS/​16S1/​Reports/​Timothy*​Crundal*​Report.​pdf>. CS16S1 project at the Australian National University.

- \[7] Alexey Kukanov, and Michael J Voss.
   _The Foundations for Scalable Multi-Core Software in Intel Threading Building Blocks._
   Intel Technology Journal 11 (4). 2007

- \[8] Paul Liétar, Theodore Butler, Sylvan Clebsch, Sophia Drossopoulou, Juliana Franco, Matthew J Parkinson,
  Alex Shamis, Christoph M Wintersteiger, and David Chisnall.
  _Snmalloc: A Message Passing Allocator._
  In Proceedings of the 2019 ACM SIGPLAN International Symposium on Memory Management, 122–135. ACM. 2019.
