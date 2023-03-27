#!/bin/bash

if [ $# -lt 3 ];then
	echo "Usage: $0 srcpath rootpath diskimg"
	exit 1
fi
srcpath=$1
rootpath=$2
diskimg=$3

if [ ! -f ${kernel_home}/modules-${kernel_version}.tar.gz ];then
	echo "The kernel modules archive is not exists! [${kernel_home}/modules-${kernel_version}.tar.gz]"
	exit 1
fi
if [ ! -f ${kernel_home}/boot-${kernel_version}.tar.gz ];then
	echo "The kernel boot archive is not exists! [${kernel_home}/boot-${kernel_version}.tar.gz]"
	exit 1
fi
if [ ! -f ${kernel_home}/dtb-rockchip-${kernel_version}.tar.gz ];then
	echo "The kernel dtb archive is not exists! [${kernel_home}/dtb-rockchip-${kernel_version}.tar.gz]"
	exit 1
fi
if [ ! -f ${kernel_home}/header-${kernel_version}.tar.gz ];then
	echo "The kernel header archive is not exists! [${kernel_home}/header-${kernel_version}.tar.gz]"
	exit 1
fi

source ${WORKDIR}/env/uuid.env
losetup -fP ${diskimg}
loopdev=$(losetup | grep $diskimg | awk '{print $1}')
echo "The loop device is ${loopdev}"

if [ -z "$rootfs_format" ];then
	rootfs_format=btrfs
fi

case $rootfs_format in
	btrfs) echo "mount -o compress=zstd:6 -t btrfs ${loopdev}p2 ${rootpath}"
	       mount -o compress=zstd:6 -t btrfs ${loopdev}p2 ${rootpath} || (losetup -D; exit 1)
	       ;;
	 ext4) echo "mount -t ext4 ${loopdev}p2 ${rootpath}"
	       mount -t ext4 ${loopdev}p2 ${rootpath} || (losetup -D; exit 1)
	       ;;
	  xfs) echo "mount -t xfs ${loopdev}p2 ${rootpath}"
	       mount -t xfs ${loopdev}p2 ${rootpath} || (losetup -D; exit 1)
	       ;;
	    *) echo "Unsupport filesystem format: $rootfs_format"
	       losetup -D
	       exit 1
	       ;;
esac

mkdir -p ${rootpath}/boot
echo "mount -t ext4 ${loopdev}p1 ${rootpath}/boot"
mount -t ext4 ${loopdev}p1 ${rootpath}/boot || (umount -f ${rootpath} ; losetup -D; exit 1)

function exit_on_failue() {
	umount -f ${rootpath}/boot
	umount -f ${rootpath}
	losetup -D
	exit 1
}

cd ${rootpath}
(
	echo "Extract rootfs ... "
	(cd ${srcpath} && tar --exclude 'debootstrap' -cf - .) | tar xf -
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_falue
	fi
)

(
	echo "Extract kernel modules ... "
	mkdir -p lib/modules && \
		cd lib/modules && \
		tar xf ${kernel_home}/modules-${kernel_version}.tar.gz
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_falue
	fi
)

(
	echo "Extract kernel headers ... "
	mkdir -p usr/src/linux-5.10.y-rk35xx && \
		cd usr/src/linux-5.10.y-rk35xx && \
		tar xf ${kernel_home}/header-${kernel_version}.tar.gz
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_falue
	fi
)

(	
	echo "Extrace kernel image ... "
	cd boot && \
	cp -a ${boot_src_home}/* . && \
	tar xf ${kernel_home}/boot-${kernel_version}.tar.gz && \
	ln -s vmlinuz-${kernel_version} zImage && \
	ln -s uInitrd-${kernel_version} uInitrd && \
	sed -e '/rootdev=/d' -i bootEnv.txt && \
	echo "rootdev=UUID=${rootuuid}" >> bootEnv.txt && \
	mkdir -p dtb-${kernel_version}/rockchip && \
	ln -s dtb-${kernel_version} dtb && \
	cd dtb/rockchip && \
	tar xf ${kernel_home}/dtb-rockchip-${kernel_version}.tar.gz
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_falue
	fi
)

(
	echo "Create /etc/fstab ... "
	cd etc
	case $rootfs_format in 
		btrfs) cat > fstab <<EOF
UUID=${rootuuid}  /                      btrfs  defaults,compress=zstd:6        0  0
UUID=${bootuuid}  /boot                  ext4   defaults                        0  0
EOF
		       ;;
		 ext4) cat > fstab <<EOF
UUID=${rootuuid}  /                      ext4   defaults                        0  0
UUID=${bootuuid}  /boot                  ext4   defaults                        0  0
EOF
		       ;;
		  xfs) cat > fstab <<EOF
UUID=${rootuuid}  /                      xfs    defaults                        0  0
UUID=${bootuuid}  /boot                  ext4   defaults                        0  0
EOF
		       ;;
	esac
	echo "done"
)

( 
	echo "Create the custom services ... "	
	mkdir -p usr/local/lib/systemd/system usr/local/bin
	cp -v ${WORKDIR}/scripts/firstboot.service usr/local/lib/systemd/system/
	cp -v ${WORKDIR}/scripts/mystartup.service usr/local/lib/systemd/system/
	cp -v ${WORKDIR}/scripts/firstboot.sh usr/local/bin/
	cp -v ${WORKDIR}/scripts/mystartup.sh usr/local/bin/
  	chmod 755 usr/local/bin/*.sh
  	sed -e "s/\$machine_hostname/$machine_hostname/" -i usr/local/bin/firstboot.sh
  	sed -e "s/\$default_ifnames/$default_ifnames/" -i usr/local/bin/firstboot.sh
  	ln -sf /usr/local/lib/systemd/system/firstboot.service ./etc/systemd/system/multi-user.target.wants/firstboot.service
  	ln -sf /usr/local/lib/systemd/system/mystartup.service ./etc/systemd/system/multi-user.target.wants/mystartup.service
	echo "done"
)

if [ -d "$add_files_home" ];then
	echo "Copy Additition files ... "
	cp -av $add_files_home/* ./
	echo "done"
fi

cd ${WORKDIR}
umount ${rootpath}/boot
umount ${rootpath}

echo "Write bootloader ... "
if [ -d "${btld_bin}" ];then
	if [ -f "${btld_bin}/idbloader.img" ] && [ -f "${btld_bin}/u-boot.itb" ];then
		echo "dd if=${btld_bin}/idbloader.img of=${loopdev} conv=fsync,notrunc bs=512 seek=64"
		dd if=${btld_bin}/idbloader.img of=${loopdev} conv=fsync,notrunc bs=512 seek=64
		echo "dd if=${btld_bin}/u-boot.itb of=${loopdev} conv=fsync,notrunc bs=512 seek=16384"
		dd if=${btld_bin}/u-boot.itb of=${loopdev} conv=fsync,notrunc bs=512 seek=16384
	fi
elif [ -f "${btld_bin}" ];then
	echo "dd if=${btld_bin} of=${loopdev} bs=512 skip=64 seek=64"
	dd if=${btld_bin} of=${loopdev} bs=512 skip=64 seek=64
fi
echo "done"

sync
losetup -D
exit 0
