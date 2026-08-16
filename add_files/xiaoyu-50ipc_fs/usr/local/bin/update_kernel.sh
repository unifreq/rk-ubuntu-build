#!/bin/bash

new_version=$1
cur_version=$(uname -r)

if [ -z "$new_version" ];then
	echo "Usage: $0 kernel_version"
	exit 1
fi

if [ -f "/opt/kernel/boot-${new_version}.tar.gz" ] && \
   [ -f "/opt/kernel/modules-${new_version}.tar.gz" ] && \
   [ -f "/opt/kernel/dtb-rockchip-${new_version}.tar.gz" ] ;then
	echo "----------------------------------------------------------------------------------"
	echo "Begin"
	cd /lib/modules
	echo "Remove the old module"
	rm -rf ${cur_version}
	echo "Extract the new module ..."
	tar -xf /opt/kernel/modules-${new_version}.tar.gz
	ls -l
	echo "----------------------------------------------------------------------------------"
	cd /boot
	echo "Remove the old image and dtb"
	rm -rf *${cur_version}*
	echo "Extract the new image ..."
	tar -xf /opt/kernel/boot-${new_version}.tar.gz
	ln -sf vmlinuz-${new_version} zImage
	ln -sf uInitrd-${new_version} uInitrd
	ls -l
	echo "----------------------------------------------------------------------------------"
	echo "Extract the new dtb ... "
	mkdir -p dtb-${new_version}/rockchip
	rm dtb && ln -sf dtb-${new_version} dtb && cd dtb/rockchip && tar -xf /opt/kernel/dtb-rockchip-${new_version}.tar.gz
	ls -l
	echo "----------------------------------------------------------------------------------"
	cd /
	echo "sync ..."
	sync
	echo "Done"	
	exit 0
else
	echo "kernel ${new_version} archive not exists!"
	exit 1
fi
