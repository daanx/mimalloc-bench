FROM ubuntu:20.04

# suppress questions from apt
ENV DEBIAN_FRONTEND=noninteractive

# suppress questions from apt even more
RUN echo '\
APT::Get::Assume-Yes "true";\n\
APT::Get::force-yes "true";' > /etc/apt/apt.conf.d/90forceyes

# workaround /build-bench-env.sh deficiencies
RUN apt update && apt install git make curl wget gpg software-properties-common lsb-release gawk bsdmainutils && apt clean all

# install latest cmake
RUN \
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null && \
apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" && \
apt update && \
apt install kitware-archive-keyring && \
rm /etc/apt/trusted.gpg.d/kitware.gpg && \
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6AF7F09730B3F0A4 && \
apt update && \
apt install cmake

RUN git clone https://github.com/daanx/mimalloc-bench

WORKDIR "/mimalloc-bench"

RUN \
git config --global advice.detachedHead false &&\
git config --global init.defaultBranch main

RUN ./build-bench-env.sh all no-lean no-gd no-sg no-ff no-fg no-lt no-lf no-hd

WORKDIR "/mimalloc-bench/out/bench"
CMD ../../bench.sh alla allt || /bin/bash