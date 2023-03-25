#!/bin/bash

export WORKDIR=$(dirname $(readlink -f "$0"))
cd ${WORKDIR}

if [ $# -lt 1 ];then
	echo "Usage: $0 dist [clean]"
	echo "dist: focal"
	exit 1
fi

dist=$1
if [ ! -f "./env/${dist}.env" ];then
	echo "${WORKDIR}/env/${dist}.env not exists!"
	exit 1
fi
source ./env/${dist}.env

if [ ! -x "/usr/sbin/debootstrap" ];then
	echo "/usr/sbin/debootstrap not found, please install debootstrap!"
	echo "example: apt install debootstrap"
	exit 1
fi

if [ ! -x "/usr/bin/qemu-aarch64-static" ];then
	echo "/usr/bin/qemu-aarch64-static not found, please install qemu-aarch64-static!"
	echo "example: apt install qemu-aarch64-static"
	exit 1
fi

output_dir=build/${dist}
function on_trap() {
	cd ${WORKDIR}
	umount -f ${output_dir}/dev/pts
	umount -f ${output_dir}/dev
	umount -f ${output_dir}/proc
	umount -f ${output_dir}/sys
	umount -f ${output_dir}/run
	exit 0
}
trap "on_trap" 2 3 15

param=$2
if [ "$param" == "clean" ];then
    rm -rf ${output_dir}
    echo "${output_dir} cleaned"
    exit 0
fi

echo "Stage 1 ..."
# first stage
mkdir -p ${output_dir}
mkdir -p ${output_dir}/dev
mkdir -p ${output_dir}/proc
mkdir -p ${output_dir}/run
mkdir -p ${output_dir}/sys

debootstrap --arch=arm64 --foreign --include=locales-all,tzdata $dist ${output_dir} "$DEBOOTSTRAP_MIRROR" 

mount -o bind /dev ${output_dir}/dev
mount -o bind /dev/pts ${output_dir}/dev/pts
mount -o bind /sys ${output_dir}/sys
mount -o bind /proc ${output_dir}/proc
mount -o bind /run ${output_dir}/run
cp -fv /usr/bin/qemu-aarch64-static "${output_dir}/usr/bin/"

# second stage
echo "Stage 2 ..."
chroot "${output_dir}" debootstrap/debootstrap --second-stage
echo "done"

# third stage
echo "Stage 3 ..."
cp ${SOURCES_LIST_WORK} ${output_dir}/etc/apt/sources.list
mkdir ${output_dir}/tmp/debs
cp -av ${EXTEND_DEBS_HOME}/* ${output_dir}/tmp/debs/
cp -v "${MKROOTFS_CHROOT}" ${output_dir}/tmp/chroot.sh
chroot ${output_dir} /usr/bin/qemu-aarch64-static /bin/bash /tmp/chroot.sh

echo "umount ... "
umount ${output_dir}/dev/pts
umount ${output_dir}/dev
umount ${output_dir}/proc
umount ${output_dir}/sys
umount ${output_dir}/run
echo 'done'
echo

rm ${output_dir}/usr/bin/qemu-aarch64-static
cp -v ${SOURCES_LIST_ORIG} ${output_dir}/etc/apt/sources.list
exit 0
