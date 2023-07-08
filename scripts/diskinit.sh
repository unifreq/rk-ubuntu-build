#!/bin/bash
img_name=$1
img_size=$2
bootloader_size=$3
bootfs_size=$4
rootfs_format=$5
bootloader=$6

losetup -D
if [ -f $img_name ];then
	rm -f $img_name
fi

dd if=/dev/zero of=$img_name bs=1M count=$img_size

losetup -fP $img_name
loopdev=$(losetup | grep $img_name | awk '{print $1}')
echo "The loop device is $loopdev"

if [ -z "$bootloader_size" ];then
	bootloader_size=16
fi

if [ -z "$bootfs_size" ];then
	bootfs_size=256
fi

if [ -z "$rootfs_format" ];then
	rootfs_format=btrfs
fi

parted $loopdev mklabel gpt || exit 1
bootfs_end=$((bootloader_size + bootfs_size))
parted $loopdev mkpart primary ${bootloader_size}Mib ${bootfs_end}Mib || (losetup -D ; exit 1)
parted $loopdev mkpart primary ${bootfs_end}Mib 100% || (losetup -D ;exit 1)
bootuuid=$(uuidgen)
rootuuid=$(uuidgen)
echo "mkfs.ext4 -U $bootuuid -L "boot" ${loopdev}p1"
mkfs.ext4 -U $bootuuid -L "boot" ${loopdev}p1 || (losetup -D; exit 1)

case $rootfs_format in
	btrfs) echo "mkfs.btrfs -U $rootuuid -L "root" ${loopdev}p2 -m single"
	       mkfs.btrfs -U $rootuuid -L "root" ${loopdev}p2 -m single || (losetup -D; exit 1)
	       ;;
	 ext4) echo "mkfs.ext4 -U $rootuuid -L "root" ${loopdev}p2"
	       mkfs.ext4 -U $rootuuid -L "root" ${loopdev}p2 || (losetup -D; exit 1)
	       ;;
	  xfs) echo "mkfs.xfs -m uuid=$rootuuid -L "root" ${loopdev}p2"
	       mkfs.xfs -m uuid=$rootuuid -L "root" ${loopdev}p2 || (losetup -D; exit 1)
	       ;;
	    *) echo "Unknown filesystem format: $rootfs_format"
	       losetup -D
	       exit 1
	       ;;
esac

if [ -f "${bootloader}" ];then
	echo "write bootloader ..."
	echo dd if=${bootloader} of=${loopdev} bs=512 skip=64 seek=64
	dd if="${bootloader}" of="${loopdev}" bs=512 skip=64 seek=64
	echo "bootloader writed"
	echo
fi

echo "The disk partition map is:"
echo "=================================================================="
parted ${loopdev} unit Mib print
echo "=================================================================="

sync
losetup -D
sync

cat > ${WORKDIR}/build/uuid.env <<EOF
bootuuid=$bootuuid
rootuuid=$rootuuid
EOF

exit 0
