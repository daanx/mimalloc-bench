The __shbench__ benchmark by [MicroQuill](http://www.microquill.com) as part of SmartHeap.

Unfortunately we cannot distribute it here, so you need to download the source
from [their website](http://www.microquill.com/smartheap/shbench/bench.zip) (retrieved 2019-01-02)
and unzip `sh6bench.c` in this directory.

After that, fire up your Unix prompt and patch the source to fit in our benchmark
framework:
```
> dos2unix sh6bench.c
> dos2unix sh6bench.patch
> patch -p1 sh6bench.c sh6bench.patch
```
