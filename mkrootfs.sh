#!/bin/bash

export WORKDIR=$(dirname $(readlink -f "$0"))
cd ${WORKDIR}

if [ $# -lt 1 ];then
	echo "Usage: $0 dist [clean]"
	echo "dist: focal"
	exit 1
fi

dist=$1
if [ ! -f "./env/linux/${dist}.env" ];then
	echo "${WORKDIR}/env/linux/${dist}.env not exists!"
	exit 1
fi
source ./env/linux/${dist}.env

if [ ! -x "/usr/sbin/debootstrap" ];then
	echo "/usr/sbin/debootstrap not found, please install debootstrap!"
	echo "example: sudo apt install debootstrap"
	exit 1
fi

host_arch=$(uname -m)
if [ "${host_arch}" == "aarch64" ];then
	CROSS_FLAG=0
else
	CROSS_FLAG=1
fi

if [ $CROSS_FLAG -eq 1 ] && [ ! -x "/usr/bin/qemu-aarch64-static" ];then
	echo "/usr/bin/qemu-aarch64-static not found, please install qemu-aarch64-static!"
	echo "example: sudo apt install qemu-user-static"
	exit 1
fi

if [ ! -f "${CHROOT}" ];then
	echo "The chroot script is not exists! [${CHROOT}]"
	exit 1
fi

if [ -n "$OS_RELEASE" ];then
	os_release=$OS_RELEASE
else
	os_release=$dist
fi

if [ -n "$DIST_ALIAS" ];then
	output_dir=build/${DIST_ALIAS}
else
	output_dir=build/${dist}
fi

function unbind() {
	cd ${WORKDIR}
	umount -f ${output_dir}/dev/pts
	umount -f ${output_dir}/dev
	umount -f ${output_dir}/proc
	umount -f ${output_dir}/sys
	umount -f ${output_dir}/run
}

function on_trap() {
	unbind
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

if [ $CROSS_FLAG -eq 1 ];then
	debootstrap --arch=arm64 --foreign ${os_release} ${output_dir} "$DEBOOTSTRAP_MIRROR" 
	mkdir -p ${output_dir}/usr/bin && cp -fv /usr/bin/qemu-aarch64-static "${output_dir}/usr/bin/"
else
	debootstrap --arch=arm64 ${os_release} ${output_dir} "$DEBOOTSTRAP_MIRROR" 
fi

mount -o bind /dev ${output_dir}/dev
mount -o bind /dev/pts ${output_dir}/dev/pts
mount -o bind /sys ${output_dir}/sys
mount -o bind /proc ${output_dir}/proc
mount -o bind /run ${output_dir}/run

# second stage
echo "Stage 2 ..."
if [ $CROSS_FLAG -eq 1 ];then
	chroot "${output_dir}" debootstrap/debootstrap --second-stage
fi
echo "done"

# third stage
echo "Stage 3 ..."
cp ${SOURCES_LIST_WORK} ${output_dir}/etc/apt/sources.list

[ "${EXTEND_DEBS_HOME}" != "" ] && [ -d "${EXTEND_DEBS_HOME}" ] && \
	mkdir -p ${output_dir}/tmp/debs && \
	cp -av ${EXTEND_DEBS_HOME}/* ${output_dir}/tmp/debs/

cp -v "${CHROOT}" "${output_dir}/tmp/chroot.sh"

if [ $CROSS_FLAG -eq 1 ];then
	chroot ${output_dir} /usr/bin/qemu-aarch64-static /bin/bash /tmp/chroot.sh
else
	chroot ${output_dir} /bin/bash /tmp/chroot.sh
fi

echo "umount ... "
umount ${output_dir}/dev/pts
umount ${output_dir}/dev
umount ${output_dir}/proc
umount ${output_dir}/sys
umount ${output_dir}/run
echo 'done'
echo

if [ $CROSS_FLAG -eq 1 ];then
	rm ${output_dir}/usr/bin/qemu-aarch64-static
fi
cp -v ${SOURCES_LIST_ORIG} ${output_dir}/etc/apt/sources.list
exit 0
