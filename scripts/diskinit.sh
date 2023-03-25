#!/bin/bash
name=$1
size=$2
bootloader=$3

dd if=/dev/zero of=$name bs=1M count=$size
losetup -fP $name
loopdev=$(losetup | grep $name | awk '{print $1}')
echo "The loop device is $loopdev"

if [ -z "$bootfs_size" ];then
	bootfs_size=256
fi

parted $loopdev mklabel gpt || exit 1
bootfs_end=$((16 + bootfs_size))
parted $loopdev mkpart primary 16Mib ${bootfs_end}Mib || (losetup -D ; exit 1)
parted $loopdev mkpart primary ${bootfs_end}Mib 100% || (losetup -D ;exit 1)
bootuuid=$(uuidgen)
rootuuid=$(uuidgen)
echo "mkfs.ext4 -U $bootuuid -L "boot" ${loopdev}p1"
mkfs.ext4 -U $bootuuid -L "boot" ${loopdev}p1 || (losetup -D; exit 1)
echo "mkfs.btrfs -U $rootuuid -L "root" ${loopdev}p2 -m single"
mkfs.btrfs -U $rootuuid -L "root" ${loopdev}p2 -m single || (losetup -D; exit 1)

if [ -f "${bootloader}" ];then
	echo "write bootloader ..."
	echo dd if=${bootloader} of=${loopdev} bs=512 skip=64 seek=64
	dd if="${bootloader}" of="${loopdev}" bs=512 skip=64 seek=64
	echo "bootloader writed"
	echo
fi

sync
losetup -D
sync

cat > ${WORKDIR}/env/uuid.env <<EOF
bootuuid=$bootuuid
rootuuid=$rootuuid
EOF

exit 0
