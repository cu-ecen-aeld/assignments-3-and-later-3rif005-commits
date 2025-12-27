#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo (Revised for Assignment 3 Part 2)

set -e
set -u

OUTDIR=$1
if [ -z "$OUTDIR" ]; then
    OUTDIR=/tmp/aeld
fi

mkdir -p ${OUTDIR}

export ARCH=arm64
export CROSS_COMPILE=aarch64-none-linux-gnu-

# --- KERNEL STEPS ---
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING LINUX STABLE TO ${OUTDIR}"
    git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ${OUTDIR}/linux-stable
fi

cd "${OUTDIR}/linux-stable"
KERNEL_VERSION=v5.15.163
git checkout ${KERNEL_VERSION}

# Build Kernel
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

# Copy resulting image to OUTDIR
cp arch/${ARCH}/boot/Image ${OUTDIR}/

# --- ROOTFS STEPS ---
echo "Building RootFS"
cd "${OUTDIR}"
if [ -d "${OUTDIR}/rootfs" ]; then
    sudo rm -rf "${OUTDIR}/rootfs"
fi

# Create base directories
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

# Build BusyBox
cd "${OUTDIR}"
if [ ! -d "${OUTDIR}/busybox" ]; then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout 1_33_1
else
    cd busybox
fi
make distclean
make defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install CONFIG_PREFIX="${OUTDIR}/rootfs"

# Library dependencies
echo "Library dependencies"
${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "program interpreter"
${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" | grep "Shared library"

# Copy libraries
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 "${OUTDIR}/rootfs/lib/"
cp -L ${SYSROOT}/lib64/libm.so.6 "${OUTDIR}/rootfs/lib64/"
cp -L ${SYSROOT}/lib64/libresolv.so.2 "${OUTDIR}/rootfs/lib64/"
cp -L ${SYSROOT}/lib64/libc.so.6 "${OUTDIR}/rootfs/lib64/"

# Device nodes
sudo mknod -m 666 "${OUTDIR}/rootfs/dev/null" c 1 3
sudo mknod -m 600 "${OUTDIR}/rootfs/dev/console" c 5 1

# Apps and scripts
REPO_DIR=$(realpath $(dirname $0)/..)
cd "${REPO_DIR}/finder-app"
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

cp writer "${OUTDIR}/rootfs/home/"
cp finder.sh "${OUTDIR}/rootfs/home/"
cp finder-test.sh "${OUTDIR}/rootfs/home/"
cp autorun-qemu.sh "${OUTDIR}/rootfs/home/"
mkdir -p "${OUTDIR}/rootfs/home/conf"
cp conf/username.txt "${OUTDIR}/rootfs/home/conf/"
cp conf/assignment.txt "${OUTDIR}/rootfs/home/conf/"

# Chown rootfs
cd "${OUTDIR}/rootfs"
sudo chown -R root:root *

# Create initramfs.cpio.gz
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"
cd "${OUTDIR}"
gzip -f initramfs.cpio
