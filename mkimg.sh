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
if [ ! -f "${WORKDIR}/env/${soc}.env" ];then
	echo "The soc env file is not exists: ${WORKDIR}/env/${soc}.env"
	exit 1
fi

if [ ! -f "${WORKDIR}/env/${machine}.env" ];then
	echo "The machine env file is not exists: ${WORKDIR}/env/${machine}.env"
	exit 1
fi

source ${WORKDIR}/env/${soc}.env
source ${WORKDIR}/env/${machine}.env

if [ ! -d "${WORKDIR}/build/${dist}" ];then
	echo "The rootfs of dist ${dist} is not exists, please make rootfs first!"
	exit 1
fi

case $dist in 
	bionic|focal|jammy) os_release='ubuntu';;
	   buster|bullseys) os_release='debian';;
	                 *) os_release='unknown';;
esac

output_img=${WORKDIR}/build/${machine_name}_${os_release}_${dist}_v$(date +%Y%m%d).img
echo "Create a blank disk image: $output_img ... "
./scripts/diskinit.sh ${output_img} ${img_size}
if [ $? -eq 0 ];then
	echo "done"
	echo
else
	echo "failed"
	exit 1
fi

rm -rf build/temp_root && mkdir -p build/temp_root
umount -f build/${dist}/dev/pts 2>/dev/null
umount -f build/${dist}/dev 2>/dev/null
umount -f build/${dist}/sys 2>/dev/null
umount -f build/${dist}/run 2>/dev/null
umount -f build/${dist}/proc 2>/dev/null
echo "Make the target image ... "
scripts/write_target_img.sh "${WORKDIR}/build/${dist}" "${WORKDIR}/build/temp_root" "${output_img}"
if [ $? -eq 0 ];then
	echo "The target image [${output_img}] has been created successfully"
	echo
else
	echo "failed"
	exit 1
fi

rm -rf ${WORKDIR}/build/temp_root
