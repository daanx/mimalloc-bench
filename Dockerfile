ARG platform=ubuntu
ARG platform_version=24.04

FROM ${platform}:${platform_version} as bench-env

# Pull mimalloc-bench
RUN mkdir -p /mimalloc-bench
COPY . /mimalloc-bench

WORKDIR /mimalloc-bench
# Install dependencies
RUN ./build-bench-env.sh packages

# Build benchmarks
RUN ./build-bench-env.sh bench

# RUN ./build-bench-env.sh redis

# RUN ./build-bench-env.sh rocksdb

# RUN ./build-bench-env.sh lean


FROM bench-env as benchmark

WORKDIR /mimalloc-bench

ARG allocator=mi
ARG benchs=cfrac
ARG repeats=1

RUN ./build-bench-env.sh $allocator

# Run benchmarks
WORKDIR /mimalloc-bench/out/bench
RUN ../../bench.sh $allocator $benchs -r=$repeats