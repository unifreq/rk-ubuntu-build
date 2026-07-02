#!/bin/bash

find_available_video_device() {
    # 检查必要命令
    for cmd in v4l2-ctl media-ctl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "错误: 未找到 $cmd 命令" >&2
            return 1
        fi
    done

    # --- 1. 精准定位 rkisp_mainpath 设备 ---
    local candidate_dev=""
    # 优先查找 vir0 链路 (video24)
    candidate_dev=$(v4l2-ctl --list-devices 2>/dev/null | 
                   awk '/rkisp_mainpath \(platform:rkisp-vir0\)/{flag=1} flag && /\/dev\/video[0-9]+/{print $1; exit}')
    
    # 备用查找 vir1 链路 (video32)
    if [ -z "$candidate_dev" ]; then
        candidate_dev=$(v4l2-ctl --list-devices 2>/dev/null | 
                       awk '/rkisp_mainpath \(platform:rkisp-vir1\)/{flag=1} flag && /\/dev\/video[0-9]+/{print $1; exit}')
    fi

    # 清洗路径
    candidate_dev=$(echo "$candidate_dev" | tr -d '[:space:]')

    # 验证设备存在性
    [ -z "$candidate_dev" ] && {
        echo "错误: 未找到 rkisp_mainpath 视频设备" >&2
        return 1
    }
    [ ! -c "$candidate_dev" ] && {
        echo "错误: $candidate_dev 不是有效的视频设备" >&2
        return 1
    }

    # --- 2. 通过 media-ctl 直接验证设备活性 (Rockchip 专用) ---
    # 关键修复：跳过 v4l2-ctl --info，直接检查拓扑
    local found_in_media=""
    for media_node in /dev/media[0-9]*; do
        # 检查该 media 节点是否包含目标设备
        if media-ctl -d "$media_node" -p 2>/dev/null | grep -q "device node name $candidate_dev"; then
            found_in_media="$media_node"
            # 额外验证：必须存在 [ENABLED] 链路
            if ! media-ctl -d "$media_node" -p | grep -q "\[ENABLED\]"; then
                echo "警告: $media_node 中 $candidate_dev 无 [ENABLED] 链路" >&2
                continue
            fi
            break
        fi
    done

    # 验证结果
    [ -z "$found_in_media" ] && {
        echo "错误: 未在任何 media 节点中找到活动的 $candidate_dev" >&2
        return 1
    }

    echo "$candidate_dev"
    return 0
}

if [ -n "$1" ];then
	DEVICE=$1
else
	DEVICE=$(find_available_video_device)
fi

if [ -z "$DEVICE" ]; then
    echo "错误：未找到可用的视频设备，请检查摄像头连接及驱动。" >&2
    exit 1
fi
echo "使用视频设备: [$DEVICE]"
if [ ! -e "$DEVICE" ]; then
    echo "错误：视频设备 [$DEVICE] 不存在。" >&2
    exit 1
fi
if [ ! -c "$DEVICE" ]; then
    echo "错误：[$DEVICE] 不是合法的视频设备。" >&2
    exit 1
fi

ffmpeg \
  -f v4l2 -input_format nv12 -video_size 1920x1080 -i ${DEVICE} \
  -vf "fps=30" \
  -c:v h264_rkmpp -g 30 \
  -f rtsp -rtsp_transport tcp rtsp://localhost:8554/live/0
