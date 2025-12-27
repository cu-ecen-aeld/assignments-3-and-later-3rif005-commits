#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo (Revised for Assignment 3 Part 2)

set -e
set -u

# Use the first argument as OUTDIR, or default to /tmp/aeld if not specified.
# The :- syntax prevents a crash from "set -u" when no argument is provided.
OUTDIR=${1:-/tmp/aeld}
FINDER_APP_DIR=$(realpath $(dirname $0))

echo "Using directory ${OUTDIR} for output"

mkdir -p ${OUTDIR}

export ARCH=arm64
export CROSS_COMPILE=aarch64-none-linux-gnu-

# --- KERNEL STEPS ---
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    # Clone only if the repository does not exist.
    echo "CLONING GIT LINUX STABLE VERSION v5.15.163 IN ${OUTDIR}"
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git ${OUTDIR}/linux-stable --depth 1 --single-branch --branch v5.15.163
fi

cd "${OUTDIR}/linux-stable"
if [ ! -e ${OUTDIR}/Image ]; then
    echo "Checking out version v5.15.163"
    git checkout v5.15.163

    # 1. Deep clean the kernel source
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    # 2. Set default configuration for the virtual ARM board
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    # 3. Build the kernel image (vmlinux)
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    # 4. Build the hardware description files (Device Tree)
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
    
    # --- KERNEL BUILD ENDS HERE ---
    echo "Copying the Image to outdir"
    cp arch/${ARCH}/boot/Image ${OUTDIR}/
fi

# --- ROOTFS STEPS ---
echo "Creating the staging directory for the root filesystem"
if [ -d "${OUTDIR}/rootfs" ]; then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi

# Create necessary base directories
mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

# --- BUSYBOX STEPS ---
cd "${OUTDIR}"
if [ ! -d "${OUTDIR}/busybox" ]; then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout 1_33_1
else
    cd busybox
fi

# Make and install busybox
make distclean
make defconfig
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install CONFIG_PREFIX="${OUTDIR}/rootfs"

# Library dependencies
echo "Library dependencies"
cd "${OUTDIR}/rootfs"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 "${OUTDIR}/rootfs/lib/"
cp -L ${SYSROOT}/lib64/libm.so.6 "${OUTDIR}/rootfs/lib64/"
cp -L ${SYSROOT}/lib64/libresolv.so.2 "${OUTDIR}/rootfs/lib64/"
cp -L ${SYSROOT}/lib64/libc.so.6 "${OUTDIR}/rootfs/lib64/"

# Make device nodes
sudo mknod -m 666 "${OUTDIR}/rootfs/dev/null" c 1 3
sudo mknod -m 600 "${OUTDIR}/rootfs/dev/console" c 5 1

# Clean and build the writer utility
# (Assumes script is in finder-app/ and writer code is in same folder)
cd "${FINDER_APP_DIR}"
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# Copy the finder related scripts and executables to /home
cp writer "${OUTDIR}/rootfs/home/"
cp finder.sh "${OUTDIR}/rootfs/home/"
cp finder-test.sh "${OUTDIR}/rootfs/home/"
cp autorun-qemu.sh "${OUTDIR}/rootfs/home/"
mkdir -p "${OUTDIR}/rootfs/home/conf"
cp conf/username.txt "${OUTDIR}/rootfs/home/conf/"
cp conf/assignment.txt "${OUTDIR}/rootfs/home/conf/"

# Chown the root directory
cd "${OUTDIR}/rootfs"
sudo chown -R root:root *

# Create initramfs.cpio.gz
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"
cd "${OUTDIR}"
gzip -f initramfs.cpio
