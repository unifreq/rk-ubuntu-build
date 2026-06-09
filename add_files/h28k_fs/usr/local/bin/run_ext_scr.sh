#!/bin/bash
#
# 自动挂载外部存储（TF卡/U盘/移动硬盘）并执行指定 shell 脚本
# 用法: script.sh [script_name]    （默认: iot_install.sh）
# 要求:
#   1. 系统不从该外部设备启动
#   2. 文件系统为 fat32/exfat/ntfs
#   3. 脚本名必须以 .sh 结尾（安全限制）
#   4. 挂载到 /mnt 后若存在目标脚本，先进行语法检查，通过后才执行
#

set -euo pipefail

LOG_TAG="ext-storage-script-run"

log() {
    logger -t "$LOG_TAG" "$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

# ---------- 处理命令行参数 ----------
TARGET_SCRIPT="${1:-iot_install.sh}"

# 必须为 .sh 脚本（简单安全限制）
if [[ "$TARGET_SCRIPT" != *.sh ]]; then
    log "错误: 脚本名必须以 .sh 结尾，当前输入: $TARGET_SCRIPT"
    exit 1
fi

# ---------- 获取系统启动磁盘 ----------
get_boot_disk() {
    local root_src
    root_src=$(findmnt -n -o SOURCE / 2>/dev/null || true)

    if [ -z "$root_src" ]; then
        root_src=$(grep -o 'root=[^ ]*' /proc/cmdline | cut -d= -f2 || true)
        if [[ "$root_src" == UUID=* ]] || [[ "$root_src" == PARTUUID=* ]]; then
            root_src=$(findfs "$root_src" 2>/dev/null || true)
        fi
    fi

    [ -z "$root_src" ] && return 1

    if [ "$root_src" = "/dev/root" ]; then
        root_src=$(readlink -f /dev/root 2>/dev/null || echo "$root_src")
    fi

    # 提取磁盘设备名（去掉分区后缀）
    basename "$root_src" | sed -E 's/(p)?[0-9]+$//'
}

# ---------- 查找设备上的可挂载源（整盘或第一个支持的分区） ----------
find_mount_source() {
    local dev="$1"
    local supported_types=("vfat" "exfat" "ntfs")
    local fstype

    # 检查整盘
    if command -v blkid >/dev/null 2>&1; then
        fstype=$(blkid -s TYPE -o value "/dev/$dev" 2>/dev/null || true)
    fi
    for t in "${supported_types[@]}"; do
        if [ "$fstype" = "$t" ]; then
            echo "/dev/$dev"
            return 0
        fi
    done

    # 检查分区（sdX1 和 mmcblkXp1）
    for part in /dev/${dev}[0-9]* /dev/${dev}p[0-9]*; do
        [ -b "$part" ] || continue
        if command -v blkid >/dev/null 2>&1; then
            fstype=$(blkid -s TYPE -o value "$part" 2>/dev/null || true)
        fi
        for t in "${supported_types[@]}"; do
            if [ "$fstype" = "$t" ]; then
                echo "$part"
                return 0
            fi
        done
    done

    return 1
}

# ---------- 主流程 ----------
# 1. 获取启动磁盘
BOOT_DISK=$(get_boot_disk) || {
    log "无法获取启动磁盘信息，退出"
    exit 1
}
log "系统启动磁盘: $BOOT_DISK"

# 2. 收集候选外部设备（排除启动盘、子设备）
CANDIDATES=()
for dev_path in /sys/block/sd[a-z] /sys/block/mmcblk[0-9]*; do
    [ -d "$dev_path" ] || continue
    dev=$(basename "$dev_path")
    [[ ! "$dev" =~ ^(sd[a-z]+|mmcblk[0-9]+)$ ]] && continue
    [ "$dev" = "$BOOT_DISK" ] && continue
    [ -b "/dev/$dev" ] || continue
    CANDIDATES+=("$dev")
done

if [ ${#CANDIDATES[@]} -eq 0 ]; then
    log "未找到除启动盘外的其他块设备（TF卡/U盘等），退出"
    exit 0
fi
log "候选外部设备: ${CANDIDATES[*]}"

# 3. 遍历设备，挂载并查找目标脚本
MOUNT_POINT="/mnt"
mkdir -p "$MOUNT_POINT"

SUCCESS=0

for dev in "${CANDIDATES[@]}"; do
    log "检查设备: /dev/$dev"
    MOUNT_SOURCE=$(find_mount_source "$dev") || {
        log "  未找到支持的文件系统 (vfat/exfat/ntfs)，跳过"
        continue
    }

    log "  找到可挂载源: $MOUNT_SOURCE"

    # 若 /mnt 已挂载则先卸载
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        log "  卸载现有挂载: $MOUNT_POINT"
        umount "$MOUNT_POINT" || { log "  卸载失败，跳过此设备"; continue; }
    fi

    # 挂载
    if command -v blkid >/dev/null 2>&1; then
        FS_TYPE=$(blkid -s TYPE -o value "$MOUNT_SOURCE" 2>/dev/null || echo "auto")
    else
        FS_TYPE="auto"
    fi

    log "  挂载 $MOUNT_SOURCE (类型: $FS_TYPE) 到 $MOUNT_POINT"
    if ! mount -t "$FS_TYPE" -o defaults,noatime "$MOUNT_SOURCE" "$MOUNT_POINT"; then
        log "  挂载失败，跳过此设备"
        continue
    fi

    # 检查目标脚本
    INSTALL_SCRIPT="$MOUNT_POINT/$TARGET_SCRIPT"
    if [ -f "$INSTALL_SCRIPT" ]; then
        log "  发现 $INSTALL_SCRIPT，正在转换为Unix格式并进行语法检查..."

        # 转换为Unix格式（去除\r）
        CLEAN_CONTENT=$(sed 's/\r$//' "$INSTALL_SCRIPT")
        if [ -z "$CLEAN_CONTENT" ]; then
            log "  错误: 脚本内容为空"
            umount "$MOUNT_POINT"
            continue
        fi

        # 语法校验（bash -n 不会执行任何命令）
        if ! echo "$CLEAN_CONTENT" | bash -n; then
            log "  错误: $TARGET_SCRIPT 包含语法错误，拒绝执行"
            umount "$MOUNT_POINT"
            continue
        fi

        log "  语法检查通过，开始执行 $TARGET_SCRIPT"
        if echo "$CLEAN_CONTENT" | /bin/bash; then
            log "  $TARGET_SCRIPT 执行完毕"
        else
            ret=$?
            log "  $TARGET_SCRIPT 执行失败，退出码: $ret"
            exit $ret
        fi
        SUCCESS=1
        break
    else
        log "  未找到 $TARGET_SCRIPT，卸载并尝试下一个设备"
        umount "$MOUNT_POINT"
    fi
done

if [ "$SUCCESS" -eq 0 ]; then
    log "所有外部设备均已尝试，未找到可用的 $TARGET_SCRIPT，退出"
    exit 0
fi

exit 0
