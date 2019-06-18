<img align="left" width="100" height="100" src="doc/mimalloc-logo.png"/>

# Mimalloc-bench

&nbsp;

Suite for benchmarking malloc implementations, originally
developed for benchmarking [`mimalloc`](https://github.com/microsoft/mimalloc).
It is quite easy to add new benchmarks and allocator implementations.

Enjoy,
  Daan


# Benchmarking

The benchmarks can be locally built as:

- `mkdir -p out/bench`
- `cd out/bench`
- `CXX=g++ cmake ../../bench`  
- `make` (compile all benchmarks, this may fail on `shbench`, see below)

and after that run the benchmark suite (from `out/bench`) as:

- `../../bench.sh alla allt`

Generally, you can specify the allocators (`rx`,`je`,
`tc`, `hd`, and `mc` (system allocator)), and the benchmarks
(`cfrac`, `espresso`, `barnes`, `lean`, `larson`, `alloc-test`, `cscratch`,
  and `shbench`). Or all allocators (`alla`) and tests (`allt`).
Use `--procs=<n>` to set the concurrency, and `--help` for all options.

However, to run all tests you need to manually download and patch
the `bench/shbench` benchmark (see the readme there), build the `lean`
benchmark, and install and build various allocators (jemalloc, tcmalloc, hoard, etc).
The `build-bench-env.sh` script will do all of this for you
on systems with `apt-get`:
```
~/dev/mimalloc-bench> ./build-bench-env.sh
```
It starts installing packages and you will need to enter the sudo password.
All other programs will be build as a peer to `mimalloc-bench`, e.g. `~/dev/Hoard`,
`~/dev/jemalloc`, and `~/dev/lean`.



## The Benchmarks

All the benchmarks are _not_ part of the `mimalloc-bench` project and are covered
individually by their own specific licenses and copyright. See the `license.txt` files in
each subfolder. These are just part of the repository for convenience.

- __cfrac__: by Dave Barrett, implementation of continued fraction factorization:
  uses many small short-lived allocations.
- __espresso__: a programmable logic array analyzer \[3].
- __barnes__: a hierarchical n-body particle solver \[4].
- __larson__: by Larson and Krishnan \[1]. Simulates a server workload where
   threads allocate and free many objects but leave some objects to
   be freed by other threads. Larson and Krishnan observe this behavior
   (which they call _bleeding_) in actual server applications, and the
   benchmark simulates this.
- __cache-scratch__: by Emery Berger _et al_ \[2]. Introduced with the [Hoard](http://hoard.org/)
  allocator to test for _passive-false_ sharing of cache lines: first some
  small objects are allocated and given to each thread; the threads free that
  object and allocate another one and access that repeatedly. If an allocator
  allocates objects from different threads close to each other this will
  lead to cache-line contention.
- __alloc-test__: a modern [allocator test](http://ithare.com/testing-memory-allocators-ptmalloc2-tcmalloc-hoard-jemalloc-while-trying-to-simulate-real-world-loads/)
  developed by by OLogN Technologies AG at [ITHare.com](http://ithare.com). Simulates intensive allocation workloads with a Pareto
  size distribution. The `alloc-testN` benchmark runs on N cores doing 100&times;10<sup>6</sup>
  allocations per thread with objects up to 1KB in size.
- __shbench__: by [MicroQuill](http://www.microquill.com) as part of SmartHeap. Stress test for
   multithreaded allocation where some of the objects are freed
   in a usual last-allocated, first-freed (LIFO) order, but others
   are freed in reverse order. Unfortunately we cannot include it in the repo and
   you need to download it from the public [source](http://www.microquill.com/smartheap/shbench/bench.zip).
   and patch it yourself. See the `sh6bench/readme.md` for instructions.


## References

- [1] P. Larson and M. Krishnan. _Memory allocation for long-running server applications_. In ISMM, Vancouver,  B.C., Canada, 1998.
  [pdf](http://citeseerx.ist.psu.edu/viewdoc/download;jsessionid=5F0BFB4F57832AEB6C11BF8257271088?doi=10.1.1.45.1947&rep=rep1&type=pdf)

- [2] Emery D. Berger, Kathryn S. McKinley, Robert D. Blumofe, and Paul R. Wilson.
   _Hoard: A Scalable Memory Allocator for Multithreaded Applications_
   the Ninth International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS-IX). Cambridge, MA, November 2000.
   [pdf](http://www.cs.utexas.edu/users/mckinley/papers/asplos-2000.pdf)

- [3] D. Grunwald, B. Zorn, and R. Henderson.
  _Improving the cache locality of memory allocation_. In R. Cartwright, editor,
  Proceedings of the Conference on Programming Language Design and Implementation, pages 177–186, New York, NY, USA, June 1993.
  [pdf](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.43.6621&rep=rep1&type=pdf)

- [4] J. Barnes and P. Hut. _A hierarchical O(n*log(n)) force-calculation algorithm_. Nature, 324:446-449, 1986.
