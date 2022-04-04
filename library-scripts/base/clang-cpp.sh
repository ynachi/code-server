#!/usr/bin/env bash

LLVM_VERSION=${1:-"14"}
LLVM_GPG_FINGERPRINT=${2:-"6084F3CF814B57C1CF12EFD515CF4D18AF4F7421"}


apt-get update && \
    #
    # Install C++ tools
    apt-get -y install \
        build-essential \
        cmake \
        git \
        git-lfs \
        ninja-build \
        ccache \
        zsh 

apt-get update \
    && wget -O- https://apt.llvm.org/llvm-snapshot.gpg.key| apt-key add - \
    && echo "deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-${LLVM_VERSION} main" >> /etc/apt/sources.list \
    && echo "deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-${LLVM_VERSION} main" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
        clang-${LLVM_VERSION} \
        clang-${LLVM_VERSION}-doc \
        lldb-${LLVM_VERSION} \
        lld-${LLVM_VERSION} \
        libllvm-${LLVM_VERSION}-ocaml-dev \
        libllvm${LLVM_VERSION} \
        llvm-${LLVM_VERSION} \
        llvm-${LLVM_VERSION}-dev \
        llvm-${LLVM_VERSION}-doc \
        llvm-${LLVM_VERSION}-examples \
        llvm-${LLVM_VERSION}-runtime \
        clang-tools-${LLVM_VERSION} \
        libclang-common-${LLVM_VERSION}-dev \
        libclang-${LLVM_VERSION}-dev \
        libclang1-${LLVM_VERSION} \
        clang-format-${LLVM_VERSION} \
        python3-clang-${LLVM_VERSION} \
        clangd-${LLVM_VERSION} \
        libfuzzer-${LLVM_VERSION}-dev \
        libc++-${LLVM_VERSION}-dev \
        libc++abi-${LLVM_VERSION}-dev \
        libomp-${LLVM_VERSION}-dev \
        libclc-${LLVM_VERSION}-dev \
        libunwind-${LLVM_VERSION}-dev

ln -s /usr/bin/clang-${LLVM_VERSION} /usr/bin/clang  \
    && ln -s /usr/bin/lldb-${LLVM_VERSION} /usr/bin/lldb \
    && ln -sf /usr/bin/lldb-server-${LLVM_VERSION} /usr/lib/llvm-${LLVM_VERSION}/bin/lldb-server-${LLVM_VERSION}.0.1
# Fixes clangd
ln -sf /usr/lib/llvm-${LLVM_VERSION}/include/c++/v1 /usr/include/c++/v1
update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-${LLVM_VERSION} 100

apt-get autoremove -y \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*