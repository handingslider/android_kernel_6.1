#!/bin/bash
#
# Compile script for Hydrogen kernel
# Brought to you by rio004 
#

# Date/Time
SECONDS=0
DATE=$(date '+%Y%m%d-%H%M')

# Device
DEVICE="duchamp"
DEFCONFIG="gki_defconfig"
ZIPNAME="PigguVerse-${DEVICE}-${DATE}.zip"
KERNELVERSION="$(make kernelversion)"
KERNELNAME="$(cat "arch/arm64/configs/${DEFCONFIG}" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"

# Install the requirements for building the kernel when running the script for the first time
    sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
        default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
        python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
        make cpio kmod openssl libelf-dev pahole libssl-dev libarchive-tools zstd --fix-missing && touch .requirements

# Some additional info
echo -e "Building for: $DEVICE\n"

# Ensure the toolchain is available
TC_DIR="$HOME/toolchains/neutron-clang"
CURRENT_DIR=$(pwd)
if [ ! -d "$TC_DIR" ]; then
    mkdir -p $TC_DIR
    cd $TC_DIR
    bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") -S=11032023
    cd $CURRENT_DIR
fi
export PATH="$TC_DIR/bin:$PATH"

# Set cross-compile environment variables
export BUILD_CC="$TC_DIR/bin/clang"

# Build options for the kernel
export BUILD_OPTIONS="
-C $CURRENT_DIR \
O=$CURRENT_DIR/out \
-j$(nproc) \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CLANG_TRIPLE=aarch64-linux-gnu- \
CC=${BUILD_CC} \
LLVM=1 \
LLVM_IAS=1 \
AR=$TC_DIR/bin/llvm-ar \
NM=$TC_DIR/bin/llvm-nm \
LD=$TC_DIR/bin/ld.lld \
STRIP=$TC_DIR/bin/llvm-strip \
OBJCOPY=$TC_DIR/bin/llvm-objcopy \
OBJDUMP=$TC_DIR/bin/llvm-objdump \
READELF=$TC_DIR/bin/llvm-readelf \
HOSTCC=$TC_DIR/bin/clang \
HOSTCXX=$TC_DIR/bin/clang++ \
KBUILD_BUILD_USER=HandingSlider
KBUILD_BUILD_HOST=Server
"
mkdir -p out
make ${BUILD_OPTIONS} $DEFCONFIG

echo -e "\nStarting compilation...\n"
if make ${BUILD_OPTIONS} KCFLAGS+="-Wno-error -Wno-array-bounds -mllvm -polly" Image > >(tee $LOG) 2>&1; then
    echo -e "\nKernel compiled successfully! Zipping up...\n"
    git clone -q --depth=1 https://github.com/handingslider/AnyKernel3.git AnyKernel3
    cp out/arch/arm64/boot/Image AnyKernel3
    rm -rf *zip out/arch/arm64/boot
    (cd AnyKernel3 && zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder)
    rm -rf AnyKernel3
    echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
    echo "Zip: $ZIPNAME"
    curl -X POST "https://api.telegram.org/bot${{ secrets.TELEGRAM_BOT_TOKEN }}/sendMessage" \
    -F text="Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!
Kernel Version: $KERNELVERSION-$KERNELNAME" \
    -F chat_id=${{ secrets.TELEGRAM_CHAT_ID }} > /dev/null
    rm log*
else
    echo -e "\nCompilation failed!"
    curl -X POST "https://api.telegram.org/bot${{ secrets.TELEGRAM_BOT_TOKEN }}/sendMessage" \
    -F text="Build failed" \
    -F chat_id=${{ secrets.TELEGRAM_CHAT_ID }}
fi
