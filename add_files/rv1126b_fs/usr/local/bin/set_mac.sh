#!/bin/bash

version=8.1

# 检查参数数量
if [[ "$#" -ne 1 ]]; then
    echo "Version: $version"
    echo "Usage: $0 <network_interface>" >&2
    exit 1
fi

# 获取网口名称
interface="$1"

# 配置文件位置
mac_prefix_config="/etc/mac_prefix.conf"
mac_address_config="/etc/mac_address.conf"
lock_file="/var/lock/set_mac.lock"
log_file="/var/log/set_mac.log"

# 初始化日志
exec >> "$log_file" 2>&1
echo "=== $(date) 开始处理接口 $interface ==="

# 定义错误处理函数
die() {
    echo "错误：$1" >&2
    exit 1
}

# 增强型MAC地址验证函数
validate_mac() {
    local mac="$1"
    if [[ ! "$mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
        die "无效的MAC地址格式：$mac"
    fi
}

# 获取所有物理以太网接口
get_physical_interfaces() {
    local ifaces=()
    for iface in /sys/class/net/*; do
        iface_name=$(basename "$iface")
        if [[ -e "$iface/device" && \
            ! "$iface_name" =~ ^(lo|docker|virbr|vnet|wlan|wl|ww|tun|tap) ]]; then
            if [[ $(cat "$iface/type" 2>/dev/null) -eq 1 || \
                "$(cat "$iface/uevent" 2>/dev/null | grep DEVTYPE=ether)" ]]; then
                ifaces+=("$iface_name")
            fi
        fi
    done
    echo "${ifaces[@]}" | tr ' ' '\n' | sort | tr '\n' ' '
}

# 获取唯一 ID
get_unique_id() {
    #if [[ -d /sys/block/mmcblk1 ]]; then
    #    serial=$(cat /sys/block/mmcblk1/device/cid 2>/dev/null)
    #elif [[ -d /sys/block/mmcblk0 ]]; then
    #    serial=$(cat /sys/block/mmcblk0/device/cid 2>/dev/null)
    #elif [[ -f /etc/machine-id ]]; then
    #    serial=$(cat /etc/machine-id 2>/dev/null)
    #else
    #    serial=$(od -An -N6 -tx1 /dev/random | tr -d ' \n')
    #fi

    serial=$(od -An -N16 -tx1 /dev/random | tr -d ' ')

    serial="${serial,,}"  # 转换为小写
    serial="${serial//0x/}"  # 去除前缀 "0x"

    echo $serial
}

# 加载MAC前缀
load_mac_prefixes() {
    if [[ ! -f "$mac_prefix_config" ]]; then
        echo -e "00:0e:8e\n00:14:22\n00:18:8c\n00:1b:77\n00:1d:92\n00:20:18\n00:4f:49\n00:60:52\n00:e0:4c\n52:54:ab\nd4:3d:7f\nf0:25:b7\n28:6a:8d\nb0:7b:d5\nd8:0d:26\n" > "$mac_prefix_config"
    fi
    mapfile -t mac_groups < "$mac_prefix_config"
}

# 生成基准MAC地址
generate_base_mac() {
    load_mac_prefixes
    local unique_id=$(get_unique_id)
    
    local raw_hash=$(echo -n "${unique_id}" | sha256sum | cut -d' ' -f1)
    
    local bitfield_index=$(( 0x${raw_hash:8:4} % ${#mac_groups[@]} ))
    local prefix=${mac_groups[$bitfield_index]}

    # max start pos is length(raw_hash) - 6
    local start_pos=$(( 0x${raw_hash:16:4} % (${#raw_hash} - 6) ))

    local mac_tail=$(
    echo -n "$raw_hash $start_pos" | awk '
        {
            printf("%s:%s:%s", 
	           substr($1, $2 + 1, 2), 
	           substr($1, $2 + 3, 2), 
		   substr($1, $2 + 5, 2)); 
	}'
    )

    # 强制设置本地管理位（第2位为1）
    local octet4=$(printf "%02x" $((0x${mac_tail:0:2} & 0xFE | 0x02)))
    echo "${prefix}:${octet4}:${mac_tail:3:8}"
}

# 获取或创建基准MAC
get_or_create_base_mac() {
    # 检查是否已有基准MAC
    if [ -f "$mac_address_config" ]; then
        # 尝试从配置文件中获取标记为BASE的MAC地址
        base_mac=$(awk '/^BASE / {print $2}' "$mac_address_config" 2>/dev/null)
        if [[ "$base_mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
            echo "$base_mac"
            return 0
        fi
    fi
    
    # 如果文件不存在或没有有效的BASE记录，生成新的基准MAC
    local new_mac=$(generate_base_mac)
    # 确保生成的MAC是有效的
    if [[ ! "$new_mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
        # 如果生成的MAC无效，使用随机MAC
        new_mac="00:0e:8e$(od -An -N3 -tx1 /dev/urandom | tr ' ' ':')"
    fi

    # 创建或更新配置文件，只包含BASE MAC
    mkdir -p "$(dirname "$mac_address_config")"
    echo "BASE $new_mac" > "$mac_address_config"
    sync
    echo "$new_mac"
}

# MAC地址偏移计算
mac_offset() {
    local mac_address="$1" offset="$2"
    validate_mac "$mac_address"
    
    IFS=':' read -r b1 b2 b3 b4 b5 b6 <<< "$mac_address"
    local mac_dec=$(( (0x$b1 << 40) | (0x$b2 << 32) | (0x$b3 << 24) | (0x$b4 << 16) | (0x$b5 << 8) | 0x$b6 ))
    mac_dec=$(( mac_dec + offset ))
    
    # 处理后24位溢出
    local tail=$(( mac_dec & 0xFFFFFF ))
    printf "%02x:%02x:%02x:%02x:%02x:%02x" \
        $(( (mac_dec >> 40) & 0xFF )) \
        $(( (mac_dec >> 32) & 0xFF )) \
        $(( (mac_dec >> 24) & 0xFF )) \
        $(( (tail >> 16) & 0xFF )) \
        $(( (tail >> 8) & 0xFF )) \
        $(( tail & 0xFF ))
}

get_current_mac() {
    local iface=$1
    ip -o link show "$iface" | sed -nE 's/.*link\/ether (([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}).*/\1/p' | head -n1
}

# 主过程
(
    # 等待最多30秒获取排他锁
    flock -w 30 -x 200 || die "无法获取文件锁"

    current_mac=$(get_current_mac  "$interface")
    echo "$interface 当前MAC地址: $current_mac"

    # 创建锁文件目录并设置适当权限
    mkdir -p "$(dirname "$lock_file")" || die "无法创建锁文件目录"
    chmod 755 "$(dirname "$lock_file")"
    touch "$lock_file" || die "无法创建锁文件"
    chmod 644 "$lock_file"

    # 加载接口列表
    interfaces=($(get_physical_interfaces))
    
    # 验证接口有效性
    if [[ ! " ${interfaces[@]} " =~ " ${interface} " ]]; then
        die "接口 $interface 不存在或不是物理以太网接口\n可用接口: ${interfaces[@]}"
    fi

    # 生成或获取基准MAC
    base_mac=$(get_or_create_base_mac)
    echo "基准MAC地址: $base_mac" >&2
    validate_mac "$base_mac"

    # 确定接口索引
    interface_index=-1
    for i in "${!interfaces[@]}"; do
        if [[ "${interfaces[$i]}" == "$interface" ]]; then
            interface_index=$i
            break
        fi
    done
    [[ $interface_index -eq -1 ]] && die "无法确定接口索引"

    # 计算最终MAC地址
    final_mac=$(mac_offset "$base_mac" "$interface_index")
    echo "接口 $interface 的MAC地址: $final_mac" >&2
    validate_mac "$final_mac"

    # 原子更新配置文件（保留BASE行，更新或添加接口MAC）
    temp_file=$(mktemp)

    # 添加BASE记录
    echo "BASE $base_mac" > "$temp_file"

    # 添加当前接口记录
    echo "$interface $final_mac" >> "$temp_file"

    # 其它接口记录
    grep -v "^$interface " "$mac_address_config" | grep -v "^BASE " >> "$temp_file"

    # 验证临时文件有效性
    if grep -q "^BASE " "$temp_file" && grep -q "^$interface " "$temp_file"; then
        sort "$temp_file" > "$mac_address_config" || die "配置文件更新失败"
        chmod 600 "$mac_address_config"
    else
        die "临时文件生成失败"
    fi

    # 设置MAC地址
    current_mac=$(get_current_mac "$interface")
    echo "当前MAC: $current_mac, 目标MAC: $final_mac" >&2
    if [[ "$current_mac" != "$final_mac" ]]; then
        echo "正在更新MAC地址: $current_mac -> $final_mac"
        ip link set dev "$interface" down || die "无法关闭接口"
        ip link set dev "$interface" address "$final_mac" || die "设置MAC地址失败"
        ip link set dev "$interface" up || die "无法启动接口"
        echo "MAC地址更新成功"
    else
        echo "MAC地址无需变更"
    fi

    echo "=== $(date) 处理完成 $interface ==="
    echo 
    exit 0
) 200>"$lock_file" || exit 1
