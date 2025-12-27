#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # Deep clean the kernel source
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    # Set default configuration for our virtual ARM board
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    # Build the kernel image (vmlinux)
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    # Build the hardware description files (Device Tree)
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    make distclean
    make defconfig
    # Install BusyBox into our staging folder
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install CONFIG_PREFIX=${OUTDIR}/rootfs
else
    cd busybox
fi

# TODO: Make and install busybox

echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

    # Copy the Dynamic Linker/Loader
    cp -L ${SYSROOT}/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
    
    # Copy Shared Libraries from lib64
    cp -L ${SYSROOT}/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
    cp -L ${SYSROOT}/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/
    cp -L ${SYSROOT}/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/
# TODO: Make device nodes

# TODO: Clean and build the writer utility

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
# Cross-compile your writer app
    cd ${FINDER_APP_DIR}
    make clean
    make CROSS_COMPILE=${CROSS_COMPILE}

    # Copy everything to the rootfs /home directory
    cp writer ${OUTDIR}/rootfs/home/
    cp finder.sh ${OUTDIR}/rootfs/home/
    cp finder-test.sh ${OUTDIR}/rootfs/home/
    cp autorun-qemu.sh ${OUTDIR}/rootfs/home/
    
    # Copy the configuration folder
    mkdir -p ${OUTDIR}/rootfs/home/conf
    cp conf/username.txt ${OUTDIR}/rootfs/home/conf/
    cp conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
# TODO: Chown the root directory

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
    # Find all files, bundle them, and change ownership to root
    find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
    cd ${OUTDIR}
    gzip -f initramfs.cpio
