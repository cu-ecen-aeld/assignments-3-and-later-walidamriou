#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

echo "********************************************************************"
echo "************ Script outline to install and build kernel ************"
echo "********************************************************************"


# Function to check if a package is installed
is_installed() {
    dpkg -l | grep -q "$1"
}

# Name of the compiler
COMPILER="aarch64-none-linux-gnu-gcc"

# Check if the compiler is installed
if command -v $COMPILER &> /dev/null; then
    echo "$COMPILER is already installed."
else
    echo "$COMPILER is not installed. Installing..."

    # Update package list
    sudo apt-get update

    # Install the compiler
    if is_installed "gcc-aarch64-linux-gnu"; then
        echo "$COMPILER is already installed via package."
    else
        sudo apt-get install -y gcc-aarch64-linux-gnu

        # Verify installation
        if command -v $COMPILER &> /dev/null; then
            echo "$COMPILER installed successfully."
        else
            echo "Failed to install $COMPILER."
            exit 1
        fi
    fi
fi


echo "----------------------------------------------------------"
echo "Save the current directory"
echo "----------------------------------------------------------"
original_dir=$(pwd)
echo "$original_dir"

echo "----------------------------------------------------------"
echo "initializations ... "
echo "----------------------------------------------------------"
set -e # Causes the script to exit immediately if any command fails (returns a non-zero exit status)
set -u # Exits the script if you try to use an undefined variable

echo "----------------------------------------------------------"
echo "Set Configs ... "
echo "----------------------------------------------------------"
OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
ROOTFSDIR=${OUTDIR}/rootfs
BUSYBOXBINARY_DIR="${ROOTFSDIR}/bin/busybox"

echo "----------------------------------------------------------"
echo "Check output directory ... "
echo "----------------------------------------------------------"
if [ $# -lt 1 ]; then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

echo "----------------------------------------------------------"
echo "Check workspace directory ... "
echo "----------------------------------------------------------"
if [ ! -d "${OUTDIR}/" ]; then
    echo "Not exist, create directory ... "
	mkdir -p ${OUTDIR} 
fi

echo "move to it ... "
cd "$OUTDIR"

echo "----------------------------------------------------------"
echo "Linux Kernel"
echo "----------------------------------------------------------"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # Configure the kernel
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

    # Build the kernel
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
fi

echo "----------------------------------------------------------"
echo "Adding the Kernel Image to ${OUTDIR}"
echo "----------------------------------------------------------"
cp "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}"

echo "----------------------------------------------------------"
echo "Root filesystem ... "
echo "----------------------------------------------------------"
cd "$OUTDIR"

if [ -d "${ROOTFSDIR}" ]; then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${ROOTFSDIR}
fi

echo "----------------------------------------------------------"
echo "Create necessary base directories"
echo "----------------------------------------------------------"
mkdir -p "${ROOTFSDIR}/"{bin,dev,etc,home,lib,lib64,proc,sbin,sys,tmp,usr,var,usr/{bin,lib,sbin},var/log}
echo "- Base directories have been created."

echo "move to $OUTDIR"
cd "$OUTDIR"

echo "----------------------------------------------------------"
echo "busybox"
echo "----------------------------------------------------------"
if [ ! -d "${OUTDIR}/busybox" ]; then
    echo "clone busybox ... "
    # git clone git://busybox.net/busybox.git
    git clone https://git.busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    echo "config busybox ... "
    make defconfig
else
    echo "move to /busybox ... "
    cd busybox
    make distclean
    make defconfig
fi

echo "CONFIG_STATIC=y" >> .config
echo "CONFIG_USE_BUNDLED_LIBC=y" >> .config
echo "CONFIG_FEATURE_INIT=y" >> .config

make CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
make CROSS_COMPILE=${CROSS_COMPILE} install
echo "building process of Busybox done."

echo "Cleaning up existing symbolic links in /rootfs/bin..."
rm -f ${OUTDIR}/rootfs/bin/*

echo "Copy busybox (bin, sbin, usr) to the rootfs .."
cp -av ${OUTDIR}/busybox/_install/* ${OUTDIR}/rootfs/

echo "Make /rootfs/bin/sh tool executable.."
chmod +x "${OUTDIR}/rootfs/bin/sh"

echo "Creating symbolic links for BusyBox utilities..."
for tool in $(ls ${OUTDIR}/rootfs/bin); do
    if [ "$tool" != "busybox" ]; then
        ln -sf busybox "${OUTDIR}/rootfs/bin/$tool"
    fi
done

echo "Check symbolic links of BusyBox utilities..."
ls -l ${OUTDIR}/rootfs/bin

echo "Making all tools in /rootfs/bin executable..."
for tool in $(ls ${OUTDIR}/rootfs/bin); do
    chmod +x "${OUTDIR}/rootfs/bin/$tool"
done

echo "----------------------------------------------------------"
echo "init script"
echo "----------------------------------------------------------"
echo "Create the init script..."
cat << 'EOF' > "${OUTDIR}/rootfs/bin/init"
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -o remount,rw /

echo "\n----------------------------------------------------------"
echo "\n BelinOS by Walid \n"
echo "----------------------------------------------------------\n"

# Start a shell or your main application
exec /bin/sh
EOF

echo "Make the init script executable..."
chmod +x "${OUTDIR}/rootfs/bin/init"

echo "----------------------------------------------------------"
echo "Library dependencies"
echo "----------------------------------------------------------"
echo "Installing busybox dependencies in /lib/ and /lib64/"
echo "Creating GCC SYSROOT ... "
GCCSYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

echo "Extracting Interpreter ... "
INTERPRETER=$(${CROSS_COMPILE}readelf -a ${BUSYBOXBINARY_DIR} | grep "program interpreter" | sed 's|.*program interpreter: \(/.*\)].*|\1|')

# Ensure the target directory for the interpreter exists
INTERPRETER_DIR=$(dirname "${ROOTFSDIR}/${INTERPRETER}")
mkdir -p "${INTERPRETER_DIR}"

echo "Copying ${GCCSYSROOT}/${INTERPRETER} to ${ROOTFSDIR}/${INTERPRETER} ..."
if cp "${GCCSYSROOT}/${INTERPRETER}" "${ROOTFSDIR}/${INTERPRETER}"; then
    echo "Successfully copied interpreter to ${ROOTFSDIR}/${INTERPRETER}"
else
    echo "Failed to copy interpreter from ${GCCSYSROOT}/${INTERPRETER} to ${ROOTFSDIR}/${INTERPRETER}"
fi

echo "Creating SHAREDLIBS_DIR ... "
SHAREDLIBS=$(${CROSS_COMPILE}readelf -a ${BUSYBOXBINARY_DIR} | grep "Shared library" | sed 's|.*Shared library: \[\(.*\)].*|\1|')

# Check if SHAREDLIBS is empty
if [ -z "$SHAREDLIBS" ]; then
    echo "No shared libraries found."
else
    # Ensure the lib64 directory exists
    mkdir -p "${ROOTFSDIR}/lib64"

    # Loop through shared libraries and copy them
    echo "Copying shared libraries..."
    echo "$SHAREDLIBS" | while IFS= read -r lib; do
        echo "Copying from ${GCCSYSROOT}/lib64/${lib} to ${ROOTFSDIR}/lib64/ ..."
        if cp "${GCCSYSROOT}/lib64/${lib}" "${ROOTFSDIR}/lib64/"; then
            echo "Successfully copied shared library ${lib} to ${ROOTFSDIR}/lib64/"
        else
            echo "Failed to copy shared library from ${GCCSYSROOT}/lib64/${lib}"
        fi
    done
fi

# Optional: Print contents of lib and lib64
# cd ${ROOTFSDIR}
# print_content lib/ lib64/


echo "----------------------------------------------------------"
echo "Make device nodes"
echo "----------------------------------------------------------"
# Ensure the dev directory exists
mkdir -p dev

# Create device nodes in the dev directory
if sudo mknod "dev/null" c 1 3; then
    echo "Created device node /dev/null"
else
    echo "Failed to create device node /dev/null"
fi

if sudo mknod "dev/console" c 5 1; then
    echo "Created device node /dev/console"
else
    echo "Failed to create device node /dev/console"
fi

# sudo mknod "${OUTDIR}/rootfs/dev/mem" c 1 1
# sudo mknod "${OUTDIR}/rootfs/dev/null" c 1 3
# sudo mknod "${OUTDIR}/rootfs/dev/ttyS1" c 5 0
# sudo mknod "${OUTDIR}/rootfs/dev/console" c 5 1
# sudo mknod "${OUTDIR}/rootfs/dev/tty0" c 204 64

echo "----------------------------------------------------------"
echo "Clean and build the writer utility"
echo "----------------------------------------------------------"
cd "$original_dir" || exit
make clean
make

echo "----------------------------------------------------------"
echo "Copy the scripts and executables to the /home directory"
echo "----------------------------------------------------------"

# Ensure the home directory exists
if [ ! -d "${OUTDIR}/rootfs/home/" ]; then
    echo "Creating home directory at ${OUTDIR}/rootfs/home/"
    mkdir -p "${OUTDIR}/rootfs/home/"
fi

# Copy specific files to the home directory
cp ./conf/username.txt "${OUTDIR}/rootfs/home/"
cp ./conf/assignment.txt "${OUTDIR}/rootfs/home/"

# Copy all files to the home directory, if this is your intention
cp -r * "${OUTDIR}/rootfs/home/"

echo "----------------------------------------------------------"
echo "Chown the root directory"
echo "----------------------------------------------------------"
cd ${ROOTFSDIR}
sudo chown -R root:root *

echo "----------------------------------------------------------"
echo "Create initramfs.cpio"
echo "----------------------------------------------------------"
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio

echo "----------------------------------------------------------"
echo "Create initramfs.cpio.gz"
echo "----------------------------------------------------------"
cd ${OUTDIR}
gzip -f initramfs.cpio

echo "----------------------------------------------------------"
echo "Done"
echo "----------------------------------------------------------"
# ls -l ${OUTDIR}/rootfs/bin
