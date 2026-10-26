#!/bin/bash
#
# update_kernel.sh - install a kernel package set from a local directory
#
# Usage:
#   update_kernel.sh <kernel_version> [options]
#
# Options:
#   -p <path>   Kernel package directory (default: /opt/kernel)
#   -rm         Remove the currently running kernel's modules and boot files
#   -reboot     Reboot automatically after a successful upgrade
#   -h          Show this help
#
# Notes:
#   - The currently running kernel is always removed, because its modules and
#     boot files are replaced by the new ones.
#   - Free space on the filesystems holding /usr/lib/modules and /boot is
#     checked before anything is touched.  If it is not enough, -rm is forced
#     on so that the old kernel is removed first to make room.
#

set -u

KERNEL_DIR="/opt/kernel"
REMOVE_OLD=0
DO_REBOOT=0

# Extra headroom kept free on each filesystem, in MiB.
SPACE_MARGIN_MB=32

usage()
{
	cat <<EOF
Usage: $(basename "$0") <kernel_version> [options]

Options:
  -p <path>   Kernel package directory (default: ${KERNEL_DIR})
  -rm         Remove the currently running kernel's modules and boot files
  -reboot     Reboot automatically after a successful upgrade
  -h          Show this help

Examples:
  $(basename "$0") 6.18.58-flippy-95+
  $(basename "$0") 6.18.58-flippy-95+ -rm -reboot
  $(basename "$0") 6.18.58-flippy-95+ -p /mnt/usb/kernel
EOF
}

die()
{
	echo "Error: $*" >&2
	exit 1
}

# Convert a size in bytes to MiB, rounding up.
to_mib()
{
	echo $(( ($1 + 1048575) / 1048576 ))
}

# Print the free space in bytes on the filesystem holding $1.
free_bytes()
{
	local path=$1

	# Walk up to the first existing directory so that a not yet created
	# target directory still resolves to its parent filesystem.
	while [ ! -d "$path" ]; do
		path=$(dirname "$path")
	done

	df -B1 --output=avail "$path" 2>/dev/null | tail -n 1 | tr -d ' '
}

# Print the size in bytes of a file, 0 if it does not exist.
file_bytes()
{
	if [ -f "$1" ]; then
		stat -c %s "$1"
	else
		echo 0
	fi
}

# Print the size in bytes of a directory tree, 0 if it does not exist.
dir_bytes()
{
	if [ -d "$1" ]; then
		du -sb "$1" 2>/dev/null | cut -f1
	else
		echo 0
	fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

new_version=""

while [ $# -gt 0 ]; do
	case "$1" in
	-p)
		[ $# -ge 2 ] || die "option -p requires an argument"
		KERNEL_DIR=$2
		shift 2
		;;
	-rm)
		REMOVE_OLD=1
		shift
		;;
	-reboot)
		DO_REBOOT=1
		shift
		;;
	-h|--help)
		usage
		exit 0
		;;
	-*)
		die "unknown option '$1' (try -h for help)"
		;;
	*)
		if [ -z "$new_version" ]; then
			new_version=$1
		else
			die "unexpected argument '$1'"
		fi
		shift
		;;
	esac
done

if [ -z "$new_version" ]; then
	usage
	exit 1
fi

# Normalise the package directory (drop trailing slashes).
KERNEL_DIR=${KERNEL_DIR%/}

cur_version=$(uname -r)

# The running kernel is always removed: its modules and boot files are
# replaced by the new ones, and keeping them around only wastes space.
if [ "$new_version" = "$cur_version" ]; then
	REMOVE_OLD=1
fi

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || die "this script must be run as root"

boot_tar="${KERNEL_DIR}/boot-${new_version}.tar.gz"
modules_tar="${KERNEL_DIR}/modules-${new_version}.tar.gz"
dtb_tar="${KERNEL_DIR}/dtb-rockchip-${new_version}.tar.gz"

for f in "$boot_tar" "$modules_tar" "$dtb_tar"; do
	[ -f "$f" ] || die "kernel ${new_version} archive not found: $f"
done

# /lib/modules is normally a symlink to /usr/lib/modules.
MODULES_DIR="/usr/lib/modules"
BOOT_DIR="/boot"

[ -d "$MODULES_DIR" ] || die "modules directory not found: $MODULES_DIR"
[ -d "$BOOT_DIR" ] || die "boot directory not found: $BOOT_DIR"

# ---------------------------------------------------------------------------
# Free space check
# ---------------------------------------------------------------------------

# Estimate the unpacked size of the new modules.  Kernel modules are mostly
# already-compressed .ko.xz/.ko.zst files, so the tarball size is a good
# approximation; add a safety factor for filesystems and metadata.
modules_tar_size=$(file_bytes "$modules_tar")
modules_need=$(( modules_tar_size * 12 / 10 ))

# Estimate the unpacked size of the new boot files.  The boot tarball holds
# vmlinuz, initrd, uInitrd, System.map and config, which are stored
# uncompressed, so the tarball size is close to the final size.
boot_tar_size=$(file_bytes "$boot_tar")
dtb_tar_size=$(file_bytes "$dtb_tar")
boot_need=$(( (boot_tar_size + dtb_tar_size) * 11 / 10 ))

# Space that will be freed by removing the running kernel.
modules_freed=0
boot_freed=0
if [ "$REMOVE_OLD" -eq 1 ]; then
	modules_freed=$(dir_bytes "${MODULES_DIR}/${cur_version}")
	boot_freed=$(dir_bytes "${BOOT_DIR}/dtb-${cur_version}")
	# vmlinuz, initrd.img, uInitrd, System.map and config of the old kernel.
	for f in "${BOOT_DIR}"/*"${cur_version}"*; do
		[ -f "$f" ] || continue
		boot_freed=$(( boot_freed + $(file_bytes "$f") ))
	done
fi

margin=$(( SPACE_MARGIN_MB * 1048576 ))

modules_free=$(free_bytes "$MODULES_DIR")
boot_free=$(free_bytes "$BOOT_DIR")

modules_avail=$(( modules_free + modules_freed ))
boot_avail=$(( boot_free + boot_freed ))

echo "----------------------------------------------------------------------------------"
echo "Kernel package directory : ${KERNEL_DIR}"
echo "Current kernel           : ${cur_version}"
echo "New kernel               : ${new_version}"
echo "Remove old kernel        : $([ "$REMOVE_OLD" -eq 1 ] && echo yes || echo no)"
echo "Reboot after upgrade     : $([ "$DO_REBOOT" -eq 1 ] && echo yes || echo no)"
echo "----------------------------------------------------------------------------------"
printf '%-24s %10s %10s %10s\n' "Filesystem" "Need" "Free" "After"
printf '%-24s %10s %10s %10s\n' \
	"${MODULES_DIR}" \
	"$(to_mib "$modules_need")M" \
	"$(to_mib "$modules_free")M" \
	"$(to_mib "$modules_avail")M"
printf '%-24s %10s %10s %10s\n' \
	"${BOOT_DIR}" \
	"$(to_mib "$boot_need")M" \
	"$(to_mib "$boot_free")M" \
	"$(to_mib "$boot_avail")M"
echo "----------------------------------------------------------------------------------"

space_short=0
if [ "$modules_avail" -lt $(( modules_need + margin )) ]; then
	echo "Not enough space in ${MODULES_DIR}: need $(to_mib "$modules_need")M, available $(to_mib "$modules_avail")M"
	space_short=1
fi
if [ "$boot_avail" -lt $(( boot_need + margin )) ]; then
	echo "Not enough space in ${BOOT_DIR}: need $(to_mib "$boot_need")M, available $(to_mib "$boot_avail")M"
	space_short=1
fi

if [ "$space_short" -eq 1 ]; then
	if [ "$REMOVE_OLD" -eq 0 ]; then
		echo "Forcing -rm to free space by removing the running kernel."
		REMOVE_OLD=1
		modules_freed=$(dir_bytes "${MODULES_DIR}/${cur_version}")
		boot_freed=$(dir_bytes "${BOOT_DIR}/dtb-${cur_version}")
		for f in "${BOOT_DIR}"/*"${cur_version}"*; do
			[ -f "$f" ] || continue
			boot_freed=$(( boot_freed + $(file_bytes "$f") ))
		done
		modules_avail=$(( modules_free + modules_freed ))
		boot_avail=$(( boot_free + boot_freed ))
	fi

	if [ "$modules_avail" -lt $(( modules_need + margin )) ]; then
		die "still not enough space in ${MODULES_DIR} after removing the old kernel"
	fi
	if [ "$boot_avail" -lt $(( boot_need + margin )) ]; then
		die "still not enough space in ${BOOT_DIR} after removing the old kernel"
	fi
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

echo "Begin"
cd "$MODULES_DIR" || die "cannot enter ${MODULES_DIR}"

if [ "$REMOVE_OLD" -eq 1 ]; then
	echo "Remove the old module"
	rm -rf "${MODULES_DIR:?}/${cur_version}"
fi

echo "Extract the new module ..."
tar -xf "$modules_tar" || die "failed to extract ${modules_tar}"
ls -l
echo "----------------------------------------------------------------------------------"

cd "$BOOT_DIR" || die "cannot enter ${BOOT_DIR}"

if [ "$REMOVE_OLD" -eq 1 ]; then
	echo "Remove the old image and dtb"
	rm -rf ./*"${cur_version}"*
fi

echo "Extract the new image ..."
tar -xf "$boot_tar" || die "failed to extract ${boot_tar}"
ln -sf "vmlinuz-${new_version}" zImage
ln -sf "uInitrd-${new_version}" uInitrd
ls -l
echo "----------------------------------------------------------------------------------"

echo "Extract the new dtb ... "
mkdir -p "dtb-${new_version}/rockchip"
rm -f dtb
ln -sf "dtb-${new_version}" dtb
cd "dtb/rockchip" || die "cannot enter ${BOOT_DIR}/dtb/rockchip"
tar -xf "$dtb_tar" || die "failed to extract ${dtb_tar}"
ls -l
echo "----------------------------------------------------------------------------------"

cd / || die "cannot enter /"
echo "sync ..."
sync
echo "Done"

if [ "$DO_REBOOT" -eq 1 ]; then
	echo "Rebooting ..."
	systemctl reboot
else
	echo "Please Reboot the system"
	echo "systemctl reboot"
	echo "-- or --"
	echo "echo 'b' > /proc/sysrq-trigger"
fi

exit 0
