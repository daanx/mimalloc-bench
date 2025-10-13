ARG platform=ubuntu

FROM ubuntu:24.04 AS ubuntu
RUN apt-get update
RUN apt-get install -y --no-install-recommends build-essential git gpg \
  g++ clang lld llvm-dev unzip dos2unix linuxinfo bc libgmp-dev wget \
  cmake python3 ruby ninja-build libtool autoconf sed ghostscript \
  time curl automake libatomic1 libgflags-dev libsnappy-dev \
  zlib1g-dev libbz2-dev liblz4-dev libzstd-dev libreadline-dev \
  pkg-config gawk util-linux
# Install bazel
RUN apt-get install -y --no-install-recommends openjdk-8-jdk apt-transport-https
RUN add-apt-repository ppa:webupd8team/java
RUN apt-get update && apt-get install oracle-java8-installer
RUN echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" > /etc/apt/sources.list.d/bazel.list
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add -
RUN apt-get update && apt-get install bazel

FROM fedora:latest AS fedora
RUN dnf -y --quiet --nodocs install gcc-c++ clang lld llvm-devel unzip \
  dos2unix bc gmp-devel wget gawk cmake python3 ruby ninja-build libtool \
  autoconf git patch time sed ghostscript libatomic libstdc++ which \
  gflags-devel xz readline-devel snappy-devel
RUN dnf -y --quiet copr enable ohadm/bazel
RUN dnf -y --quiet --nodocs install bazel8

FROM alpine:latest AS alpine
RUN apk update
RUN apk add --no-cache bash
RUN apk add -q clang lld unzip dos2unix bc gmp-dev wget cmake python3 \
  automake gawk samurai libtool git build-base linux-headers autoconf \
  util-linux sed ghostscript libatomic gflags-dev readline-dev snappy-dev
RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add -q bazel@testing

FROM ${platform} AS bench-env

# Pull mimalloc-bench
RUN mkdir -p /mimalloc-bench
COPY . /mimalloc-bench

WORKDIR /mimalloc-bench

RUN make benchmarks
RUN make redis
RUN make rocksdb
RUN make lean
RUN make lua
RUN make linux

FROM bench-env AS benchmark

WORKDIR /mimalloc-bench

ARG allocator=mi
ARG benchs=cfrac
ARG repeats=1

RUN make $allocator

# Run benchmarks
WORKDIR /mimalloc-bench/out/bench
RUN ../../bench.sh $allocator $benchs -r=$repeats
