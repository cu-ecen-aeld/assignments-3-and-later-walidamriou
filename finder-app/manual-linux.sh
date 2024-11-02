#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e # Causes the script to exit immediately if any command fails (returns a non-zero exit status)
set -u # Exits the script if you try to use an undefined variable

# # Update package list
# sudo apt-get update

# # Set non-interactive frontend and timezone
# export DEBIAN_FRONTEND="noninteractive"
# export TZ="America/Denver"

# # Install Assignment 1 requirements
# sudo apt-get install -y --no-install-recommends \
#     ruby cmake git build-essential bsdmainutils valgrind sudo wget

# # Install additional packages for Assignment 3 kernel build
# sudo apt-get install -y --no-install-recommends \
#     bc u-boot-tools kmod cpio flex bison libssl-dev psmisc

# # Choose netcat implementation
# sudo apt-get install -y netcat-openbsd  # or netcat-traditional

# # Enable universe repository for qemu
# sudo add-apt-repository universe
# sudo apt-get update

# # Install qemu-system-arm
# sudo apt-get install -y qemu-system-arm

# # Install additional packages for Assignment 4 Buildroot
# sudo apt-get install -y apt-utils tzdata sudo dialog build-essential \
#     sed make binutils bash patch gzip bzip2 perl tar cpio unzip rsync file \
#     bc wget python3 libncurses5-dev git openssh-client expect sshpass \
#     psmisc iputils-ping

# # Reinstall ca-certificates and update
# sudo apt-get install --reinstall -y ca-certificates
# sudo update-ca-certificates

# # Install netcat again if needed
# sudo apt-get install -y netcat-openbsd  # or netcat-traditional

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
# BUSYBOX_VERSION=1_33_1
BUSYBOX_VERSION=1_37_0
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

# lets the user choose where to save output files. If they don’t specify a location, the script uses a default one
if [ $# -lt 1 ] # This checks if the number of arguments ($#) is less 1
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR} # creates a directory
cd "$OUTDIR" # move to it

# checks if the directory ${OUTDIR}/linux-stable does not exist
if [ ! -d "${OUTDIR}/linux-stable" ]; then # The ! -d tests for the absence of a directory
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi # end of if

# checks if the file ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image does not exist
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then # The ! -e tests for the absence of a file
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here

    # Configure the kernel
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig  # Use the default config

    # Build the kernel
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)  # Adjust for number of cores to run jobs parallel

    # Optionally, build modules
    # make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules -j$(nproc)

    # Install modules
    # make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules_install INSTALL_PATH=${OUTDIR}/linux-stable/rootfs/

fi # end of if

echo "----------------------------------------------------------"
echo "Adding the Image in outdir"
echo "----------------------------------------------------------"

echo "----------------------------------------------------------"
echo "Creating the staging directory for the root filesystem"
echo "----------------------------------------------------------"

cd "$OUTDIR"

# checks if the directory ${OUTDIR}/rootfs does not exist
if [ -d "${OUTDIR}/rootfs" ]
then
    # if ${OUTDIR}/rootfs exist
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
echo "----------------------------------------------------------"
echo "Create necessary base directories"
echo "----------------------------------------------------------"

mkdir -p "${OUTDIR}/rootfs/bin"   # Directory for executable binaries
mkdir -p "${OUTDIR}/rootfs/etc"   # Directory for configuration files
mkdir -p "${OUTDIR}/rootfs/proc"  # Pseudo-filesystem for process information (used by the kernel)
mkdir -p "${OUTDIR}/rootfs/sys"   # Pseudo-filesystem for system information
mkdir -p "${OUTDIR}/rootfs/dev"   # Directory for device files
mkdir -p "${OUTDIR}/rootfs/lib"   # Directory for libraries 
mkdir -p "${OUTDIR}/rootfs/home"  # Directory for home 

cd "$OUTDIR"

echo "----------------------------------------------------------"
echo "busybox"
echo "----------------------------------------------------------"
sudo rm  -rf ${OUTDIR}/busybox

# checks if the directory ${OUTDIR}/busybox does not exist
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make defconfig  # Use the default configuration for BusyBox
else
    cd busybox
fi

# TODO: Make and install busybox
make clean
make CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)  # Build BusyBox
make CROSS_COMPILE=${CROSS_COMPILE} install     # Install BusyBox to the specified locations


echo "----------------------------------------------------------"
echo "Library dependencies"
echo "----------------------------------------------------------"

# ${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
# ${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
# Assuming we need to install the shared libraries
# Copy necessary libraries (replace libname with actual libraries found)
# cp ${CROSS_COMPILE}libc.so.6 "${OUTDIR}/rootfs/lib/"  #  library
# cp ${CROSS_COMPILE}libm.so.6 "${OUTDIR}/rootfs/lib/"  #  librar

echo "----------------------------------------------------------"
echo "Make device nodes"
echo "----------------------------------------------------------"
# TODO: Make device nodes
# Create necessary device nodes in /dev
sudo mknod "${OUTDIR}/rootfs/dev/null" c 1 3  # Null device
sudo mknod "${OUTDIR}/rootfs/dev/tty" c 5 0   # Terminal device

echo "----------------------------------------------------------"
echo "Clean and build the writer utility"
echo "----------------------------------------------------------"
# TODO: Clean and build the writer utility
make clean
make

echo "----------------------------------------------------------"
echo "Copy the scripts and executables to the /home directory"
echo "----------------------------------------------------------"

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
# cp finder-app/finder.sh "${OUTDIR}/rootfs/home/"  # Copy finder-app/finder.sh to home 
cp conf/username.txt "${OUTDIR}/rootfs/home/conf/"  # Copy conf/username.txt to home
cp conf/assignment.txt "${OUTDIR}/rootfs/home/conf/"  # Copy conf/username.txt to home
cp conf/username.txt "${OUTDIR}/rootfs/home/conf/"  # Copy conf/username.txt to home
cp finder-app/* "${OUTDIR}/rootfs/home/"  # Copy finder-app/finder.sh to home

echo "----------------------------------------------------------"
echo "Chown the root directory"
echo "----------------------------------------------------------"
# TODO: Chown the root directory
chown -R root:root "${OUTDIR}/rootfs/"  # Change ownership to root

echo "----------------------------------------------------------"
echo "Create initramfs.cpio.gz"
echo "----------------------------------------------------------"

# TODO: Create initramfs.cpio.gz
cd "${OUTDIR}/rootfs"  # Navigate to rootfs
find . | cpio -H newc -o | gzip > "${OUTDIR}/initramfs.cpio.gz"  # Create the initramfs

echo "----------------------------------------------------------"
echo "Done"
echo "----------------------------------------------------------"

