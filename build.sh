#!/bin/bash

#init submodules
git submodule init && git submodule update

#main variables
export ARCH=arm64
export RDIR="$(pwd)"
export KBUILD_BUILD_USER="@ravindu644"

#dev
if [ -z "$BUILD_KERNEL_VERSION" ]; then
    export BUILD_KERNEL_VERSION="dev"
fi

# Install requirements
if [ ! -f ".requirements" ]; then
    sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
        default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
        python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
        make repo cpio kmod openssl libelf-dev pahole libssl-dev --fix-missing && touch .requirements
fi

#setting up localversion
echo -e "CONFIG_LOCALVERSION_AUTO=n\nCONFIG_LOCALVERSION=\"-ravindu644-${BUILD_KERNEL_VERSION}\"\n" > "${RDIR}/arch/arm64/configs/version.config"

#init neutron-clang
if [ ! -d "${HOME}/toolchains/neutron-clang" ]; then
    echo -e "\n[INFO] Cloning Neutron-Clang Toolchain\n"

    #install requirements
    sudo apt install libarchive-tools zstd -y    

    mkdir -p "${HOME}/toolchains/neutron-clang"
    cd "${HOME}/toolchains/neutron-clang"
    curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman" && chmod +x antman
    bash antman -S && bash antman --patch=glibc
    cd "${RDIR}"
fi

#init arm gnu toolchain
if [ ! -d "${HOME}/toolchains/gcc" ]; then
    echo -e "\n[INFO] Cloning ARM GNU Toolchain\n"
    mkdir -p "${HOME}/toolchains/gcc"
    cd "${HOME}/toolchains/gcc"
    curl -LO "https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
    tar -xf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
    cd "${RDIR}"
fi

#export toolchain paths
export BUILD_CROSS_COMPILE="${HOME}/toolchains/gcc/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
export BUILD_CC="${HOME}/toolchains/neutron-clang/bin/clang"
export PATH=$PATH:"${HOME}/toolchains/neutron-clang/bin"

#output dir
mkdir -p "${RDIR}/out"

#build dir
if [ ! -d "${RDIR}/build" ]; then
    mkdir -p "${RDIR}/build"
else
    rm -rf "${RDIR}/build" && mkdir -p "${RDIR}/build"
fi

#build options
export ARGS="
-C $(pwd) \
O=$(pwd)/out \
-j$(nproc) \
ARCH=arm64 \
CROSS_COMPILE=${BUILD_CROSS_COMPILE} \
CC=${BUILD_CC} \
CLANG_TRIPLE=aarch64-linux-gnu- \
LLVM=1 \
LLVM_IAS=1 \
AR=${HOME}/toolchains/neutron-clang/bin/llvm-ar \
NM=${HOME}/toolchains/neutron-clang/bin/llvm-nm \
LD=${HOME}/toolchains/neutron-clang/bin/ld.lld \
STRIP=${HOME}/toolchains/neutron-clang/bin/llvm-strip \
OBJCOPY=${HOME}/toolchains/neutron-clang/bin/llvm-objcopy \
OBJDUMP=${HOME}/toolchains/neutron-clang/bin/llvm-objdump \
READELF=${HOME}/toolchains/neutron-clang/bin/llvm-readelf \
HOSTCC=${HOME}/toolchains/neutron-clang/bin/clang \
HOSTCXX=${HOME}/toolchains/neutron-clang/bin/clang++ \
"

export LD_LIBRARY_PATH="${HOME}/toolchains/neutron-clang/lib:$LD_LIBRARY_PATH"

#build kernel image
build_kernel(){
    cd "${RDIR}"
    make ${ARGS} gki_defconfig custom.config version.config
    make ${ARGS} menuconfig
    make ${ARGS}|| exit 1
    cp ${RDIR}/out/arch/arm64/boot/Image* ${RDIR}/build
}

build_kernel
