#!/bin/bash

if [ $# -lt 4 ];then
	echo "Usage: $0 srcpath rootpath diskimg rootfs_fstype [firstboot_script]"
	exit 1
fi
srcpath=$1
rootpath=$2
diskimg=$3
rootfs_fstype=$4
firstboot=$5

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

if [ "$firstboot" == "" ];then
	firstboot="${WORKDIR}/scripts/firstboot/firstboot.sh"
fi

if [ ! -f "${firstboot}" ];then
	echo "The firstboot script is not exists! [${firstboot}]"
	exit 1
fi

if [ ! -f "${WORKDIR}/build/uuid.env" ];then
	echo "file uuid.env is not exists!"
	exit 1
fi

source ${WORKDIR}/build/uuid.env
losetup -fP ${diskimg}
loopdev=$(losetup | grep $diskimg | awk '{print $1}')
echo "The loop device is ${loopdev}"

bootloader_mb=16

case ${rootfs_fstype} in
	btrfs) echo "mount -o compress=zstd:3 -t btrfs ${loopdev}p2 ${rootpath}"
	       mount -o compress=zstd:3 -t btrfs ${loopdev}p2 ${rootpath} || { losetup -D; exit 1; }
	       ;;
	 ext4) echo "mount -t ext4 ${loopdev}p2 ${rootpath}"
	       mount -t ext4 ${loopdev}p2 ${rootpath} || { losetup -D; exit 1; }
	       ;;
	  xfs) echo "mount -t xfs ${loopdev}p2 ${rootpath}"
	       mount -t xfs ${loopdev}p2 ${rootpath} || { losetup -D; exit 1; }
	       ;;
	    *) echo "Unsupport filesystem type: ${rootfs_fstype}"
	       losetup -D
	       exit 1
	       ;;
esac

mkdir -p ${rootpath}/boot
echo "mount -t ext4 ${loopdev}p1 ${rootpath}/boot"
mount -t ext4 ${loopdev}p1 ${rootpath}/boot || { umount -f ${rootpath} ; losetup -D; exit 1; }

function exit_on_failue() {
	umount -f ${rootpath}/boot
	umount -f ${rootpath}
	losetup -D
	exit 1
}

cd ${rootpath}
(
	echo "Extract rootfs ... "
	(cd ${srcpath} && tar --exclude 'debootstrap' --exclude 'stage1-ok' --exclude 'stage2-ok' -cf - .) | tar xf -
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_failue
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
		exit_on_failue
	fi
)

(
	echo "Extract kernel headers ... "
	if [ -L lib/modules/${kernel_version}/source ];then
	    linux_src_dir=$(readlink lib/modules/${kernel_version}/source)
	    linux_src_dir=${linux_src_dir#/}
	else
	    linux_src_dir="usr/src/linux"
	fi
	mkdir -p ${linux_src_dir} && \
		cd ${linux_src_dir} && \
		tar xf ${kernel_home}/header-${kernel_version}.tar.gz
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_failue
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
	sed -e '/rootfstype=/d' -i bootEnv.txt && \
	sed -e '/rootflags=/d' -i bootEnv.txt && \
	echo "rootdev=UUID=${rootuuid}" >> bootEnv.txt && \
	echo "rootfstype=${rootfs_fstype}" >> bootEnv.txt && \
	if [ "$rootfs_fstype" == "btrfs" ];then
		echo "rootflags=compress=zstd:3" >> bootEnv.txt
	else
		echo "rootflags=defaults" >> bootEnv.txt
	fi && \
	echo "bootEnv.txt:" && \
	echo "================================================================" && \
	cat bootEnv.txt && \
	echo "================================================================" && \
	mkdir -p dtb-${kernel_version}/rockchip && \
	ln -s dtb-${kernel_version} dtb && \
	cd dtb/rockchip && \
	tar xf ${kernel_home}/dtb-rockchip-${kernel_version}.tar.gz
	if [ $? -eq 0 ];then
		echo "done"
	else
		echo "Failed!"
		exit_on_failue
	fi
)

if [ "${rootfs_fstype}" != "btrfs" ];then
	(
		echo "Modify bootEnv ..."
		cd boot
		sed -e "s/rootfstype=btrfs/rootfstype=${rootfs_fstype}/" -i bootEnv.txt
		sed -e "/rootflags=/d" -i bootEnv.txt
		echo "rootflags=defaults" >> bootEnv.txt
	)
fi

(
	echo "Create /etc/fstab ... "
	cd etc
	case $rootfs_fstype in
		btrfs) cat > fstab <<EOF
UUID=${rootuuid}  /                      btrfs  defaults,compress=zstd:3        0  0
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
	if [ -n "${DEFAULT_USER_PSWD}" ];then
		echo "init user_password_group file"
		for upg in ${DEFAULT_USER_PSWD};do
			echo $upg >> etc/user_pswd
		done
		echo "done"
	fi
)

(
	conf="etc/firstboot_machine_id.conf"
	echo "Create $conf ... "
	touch $conf
	echo "RESET_MACHINE_ID=$FIRSTBOOT_RESET_MACHINE_ID" >> $conf
	cat $conf
	echo 
)

(
	conf="etc/firstboot_openssh.conf"
	touch $conf
	echo "Create $conf ... "
	echo "RESET_SSH_KEYS=$FIRSTBOOT_RESET_SSH_KEYS" >> $conf
	echo "SSHD_PORT=$SSHD_PORT" >> $conf
	echo "SSHD_PERMIT_ROOT_LOGIN=$SSHD_PERMIT_ROOT_LOGIN" >> $conf
	echo "SSHD_CIPHERS=$SSHD_CIPHERS" >> $conf
	echo "SSH_CIPHERS=$SSH_CIPHERS" >> $conf
	cat $conf
	echo 
)

(
	conf="etc/firstboot_i18n.conf"
	touch $conf
	echo "Create $conf ... "
	echo "LANGUAGE=$DEFAULT_LANGUAGE" >> $conf
	echo "TIMEZONE=$DEFAULT_TIMEZONE" >> $conf
	cat $conf
	echo 
)

(
	conf="etc/firstboot_network.conf"
	touch $conf
	echo "Create $conf ... "
	if [ -n "${NETPLAN_BACKEND}" ];then
		echo "NETPLAN_BACKEND=${NETPLAN_BACKEND}" >> $conf
		#if [ "${NETPLAN_BACKEND}" == "networkd" ];then
			echo "IF1_IPS=${IF1_IPS}" >> $conf
			echo "IF1_ROUTES=${IF1_ROUTES}" >> $conf
			echo "IF2_IPS=${IF2_IPS}" >> $conf
			echo "IF2_ROUTES=${IF2_ROUTES}" >> $conf
			echo "IF3_IPS=${IF3_IPS}" >> $conf
			echo "IF3_ROUTES=${IF3_ROUTES}" >> $conf
			echo "IF4_IPS=${IF4_IPS}" >> $conf
			echo "IF4_ROUTES=${IF4_ROUTES}" >> $conf
			echo "DNS=${DNS}" >> $conf
			echo "SEARCH_DOMAIN=${SEARCH_DOMAIN}" >> $conf
		#fi
	fi
	cat $conf
	echo 
)

(
	conf="etc/firstboot_hostname"
	touch $conf
	echo "Create $conf ... "
	if [ -z "${DEFAULT_HOSTNAME}" ];then
		hostname=${OS_RELEASE}
	else
		hostname=${DEFAULT_HOSTNAME}
	fi
	echo $hostname > $conf
	cat $conf
	echo 
)

( 
	echo "Create the custom services ... "	
	mkdir -p usr/local/lib/systemd/system usr/local/bin
	cp -v ${WORKDIR}/scripts/firstboot.service usr/local/lib/systemd/system/
	cp -v ${WORKDIR}/scripts/mystartup.service usr/local/lib/systemd/system/
	cp -v ${firstboot} usr/local/bin/firstboot.sh && chmod 755 usr/local/bin/firstboot.sh
	cp -v ${WORKDIR}/scripts/mystartup.sh usr/local/bin/mystartup.sh && chmod 755 usr/local/bin/mystartup.sh
  	ln -sf /usr/local/lib/systemd/system/firstboot.service ./etc/systemd/system/multi-user.target.wants/firstboot.service
	echo "done"
)

if [ -n "${platform_add_archive_home}" ] && [ -d "$platform_add_archive_home" ];then
	echo "Extract platform additition archives ... "
	target_path=${PWD}
	(
		cd $platform_add_archive_home
		arcs=$(ls)
		for arc in $arcs;do
			echo "$arc"
			tar xf $arc -C $target_path
		done
	)
	echo "done"
	echo
fi

if [ -n "${platform_add_fs_home}" ] && [ -d "$platform_add_fs_home" ];then
	echo "Copy platform additition files ... "
	cp -av ${platform_add_fs_home}/* ./ 2>/dev/null
	echo "done"
	echo
fi

if [ -n "${machine_add_archive_home}" ] && [ -d "$machine_add_archive_home" ];then
	echo "Extract machine additition archives ... "
	target_path=${PWD}
	(
		cd $machine_add_archive_home
		arcs=$(ls)
		for arc in $arcs;do
			echo "$arc"
			tar xf $arc -C $target_path
		done
	)
	echo "done"
	echo
fi

if [ -n "${machine_add_fs_home}" ] && [ -d "$machine_add_fs_home" ];then
	echo "Copy machine additition files ... "
	cp -av ${machine_add_fs_home}/* ./ 2>/dev/null
	echo "done"
	echo
fi

echo "The disk usage map:"
echo "==================================================================================="
df -h
echo "==================================================================================="
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
else
	echo "Can't found any bootloader!"
	sync
	losetup -D
	exit 1
fi
echo "done"

sync
losetup -D
exit 0
