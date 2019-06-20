The __shbench__ benchmark by [MicroQuill](http://www.microquill.com) as part of SmartHeap.

Unfortunately we cannot distribute it here, so you need to download the source
for [sh6bench](http://www.microquill.com/smartheap/shbench/bench.zip) (retrieved 2019-01-02)
and  [sh8bench](http://www.microquill.com/smartheap/SH8BENCH.zip) (retrieved 2019-01-02)
and unzip them in this directory.

After that, fire up your Unix prompt and patch the source to fit in our benchmark
framework:
```
> dos2unix sh6bench.c
> dos2unix sh6bench.patch
> patch -p1 sh6bench.c sh6bench.patch
```
and
```
> dos2unix sh8bench.patch
> dos2unix SH8BENCH.C
> patch -p1 -o sh8bench-new.c SH8BENCH.C sh8bench.patch
```

This is done automatically by the `build-bench-env.sh` script.
