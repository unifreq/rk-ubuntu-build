#!/bin/bash

export WORKDIR=$(dirname $(readlink -f "$0"))
cd ${WORKDIR}

if [ $# -lt 3 ];then
	echo "Usage: $0 soc machine dist"
	echo "Example: $0 rk3568 h68k focal"
	exit 1
fi

soc=$1
machine=$2
dist=$3
if [ ! -f "${WORKDIR}/env/soc/${soc}.env" ];then
	echo "The soc env file is not exists: ${WORKDIR}/env/soc/${soc}.env"
	exit 1
fi

if [ ! -f "${WORKDIR}/env/machine/${machine}.env" ];then
	echo "The machine env file is not exists: ${WORKDIR}/env/machine/${machine}.env"
	exit 1
fi

BC=$(which bc)
if [ "$BC" == "" ];then
	echo "The bc program is not installed, please install bc."
	echo "Example: sudo apt-get install -y bc"
	exit 1
fi

source ${WORKDIR}/env/linux/${dist}.env
source ${WORKDIR}/env/soc/${soc}.env
source ${WORKDIR}/env/machine/${machine}.env

if [ -n "$DIST_ALIAS" ];then
	os_release=${DIST_ALIAS}
else
	os_release=$dist
fi

if [ -n "$DIST_ALIAS" ];then
	rootfs_source=${DIST_ALIAS}
else
	rootfs_source=${dist}
fi

if [ ! -d "${WORKDIR}/build/${rootfs_source}" ];then
	echo "The rootfs of dist ${rootfs_source} is not exists, please make rootfs first!"
	exit 1
fi

case $OS_RELEASE in
	bionic|focal|jammy) os_name='ubuntu';;
	   buster|bullseys) os_name='debian';;
	                 *) os_name='unknown';;
esac

if [ -n "${DEFAULT_FSTYPE}" ];then
	rootfs_fstype=btrfs
else
	rootfs_fstype=${DEFAULT_FSTYPE}
fi

bootloader_mb=16
if [ -n "${DEFAULT_BOOTFS_MB}" ];then
	bootfs_mb=256
else
	bootfs_mb=${DEFAULT_BOOTFS_MB}
fi

rootfs_source_mb=$(du -m -d1 "${WORKDIR}/build/${rootfs_source}" | tail -n1 | awk '{print $1}')
echo "The rootfs source size is ${rootfs_source_mb} MB"

# modules size (estimated value)
modules_mb=150

if [ "$rootfs_fstype" == "btrfs" ];then
	# the btrfs compress rate (estimated value)
	compress_rate=0.618
	target_img_mb=$(echo -e "(($rootfs_source_mb + $modules_mb) * $compress_rate + $bootloader_mb + $bootfs_mb) / 1\nquit\n" | ${BC} -q)
else
	# reserved size for xfs or ext4
	reserved_mb=256
	target_img_mb=$(( $rootfs_source_mb + $modules_mb + $bootloader_mb + $bootfs_mb + $reserved_mb))
fi
echo "The target image size is ${target_img_mb} MB"

output_img=${WORKDIR}/build/${machine_name}_${os_name}_${os_release}_v$(date +%Y%m%d).img
echo "Create a blank disk image: $output_img ... "
./scripts/diskinit.sh "${output_img}" "${target_img_mb}" "${bootloader_mb}" "${bootfs_mb}" "${rootfs_fstype}"
if [ $? -eq 0 ];then
	echo "succeeded"
	echo
else
	echo "failed"
	exit 1
fi

rm -rf build/temp_root && mkdir -p build/temp_root

umount -f ${WORKDIR}/build/${rootfs_source}/dev/pts 2>/dev/null
umount -f ${WORKDIR}/build/${rootfs_source}/dev 2>/dev/null
umount -f ${WORKDIR}/build/${rootfs_source}/sys 2>/dev/null
umount -f ${WORKDIR}/build/${rootfs_source}/run 2>/dev/null
umount -f ${WORKDIR}/build/${rootfs_source}/proc 2>/dev/null
echo "Make the target image ... "
scripts/write_target_img.sh "${WORKDIR}/build/${rootfs_source}" "${WORKDIR}/build/temp_root" "${output_img}" "${FIRSTBOOT}"
if [ $? -eq 0 ];then
	echo "The target image [${output_img}] has been created successfully"
	echo
else
	echo "failed"
	exit 1
fi

rm -rf ${WORKDIR}/build/temp_root
