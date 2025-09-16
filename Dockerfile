ARG platform=ubuntu

FROM ubuntu:24.04 AS ubuntu
RUN sudo apt-get install --no-install-recommends build-essential git gpg \
  g++ clang lld llvm-dev unzip dos2unix linuxinfo bc libgmp-dev wget \
  cmake python3 ruby ninja-build libtool autoconf sed ghostscript \
  time curl automake libatomic1 libgflags-dev libsnappy-dev \
  zlib1g-dev libbz2-dev liblz4-dev libzstd-dev libreadline-dev \
  pkg-config gawk util-linux bazel-bootstrap

FROM fedora:latest AS fedora


FROM alpine:latest AS alpine
RUN apk add --no-cache bash


FROM ${platform} AS bench-env

# Pull mimalloc-bench
RUN mkdir -p /mimalloc-bench
COPY . /mimalloc-bench

WORKDIR /mimalloc-bench
# Install dependencies
# RUN ./build-bench-env.sh packages

# Build benchmarks
RUN ./build-bench-env.sh bench

RUN ./build-bench-env.sh redis

RUN ./build-bench-env.sh rocksdb

RUN ./build-bench-env.sh lean

FROM bench-env AS benchmark

WORKDIR /mimalloc-bench

ARG allocator=mi
ARG benchs=cfrac
ARG repeats=1

RUN ./build-bench-env.sh $allocator

# Run benchmarks
WORKDIR /mimalloc-bench/out/bench
RUN ../../bench.sh $allocator $benchs -r=$repeats
