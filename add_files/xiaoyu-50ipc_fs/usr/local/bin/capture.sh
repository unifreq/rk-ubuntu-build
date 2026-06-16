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

export GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC=1
export GST_MPP_VIDEODEC_DEFAULT_FORMAT=NV12
export GST_V4L2_PREFERRED_FOURCC=NV12:YU12:NV16:YUY2
export GST_VIDEO_CONVERT_PREFERRED_FORMAT=NV12:NV16:I420:YUY2
export GST_VIDEO_CONVERT_USE_RGA=1
export GST_VIDEO_FLIP_USE_RGA=1

audio=0

if [ $audio -eq 1 ];then
	audio_pipe="alsasrc device=hw:0,0 provide-clock=false ! \
audio/x-raw,format=S16LE,rate=16000,channels=2 ! queue max-size-buffers=100 ! \
audioconvert ! voaacenc bitrate=64000 ! aacparse ! mux. "
else
	audio_pipe=""
fi

# 启动 pipeline
# 设置cpu为高性能模式
current_governor=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)
echo performance > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
(
	sleep 30
	echo ${current_governor} > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
) &
gst-launch-1.0 -e \
    v4l2src device=${DEVICE} do-timestamp=true io-mode=4 ! \
        video/x-raw,format=NV12,width=2560,height=1440,framerate=30/1 ! \
    tee name=video \
    video. ! \
        queue leaky=downstream max-size-buffers=10 ! \
        mpph264enc gop=30 rc-mode=vbr bps-min=2000000 bps=4000000 bps-max=8000000 ! \
        h264parse config-interval=-1 ! \
        mux. \
    video. ! \
        queue leaky=downstream max-size-buffers=10 ! \
        videoscale ! video/x-raw,width=800,height=480 ! \
        videoflip video-direction=90l ! \
        kmssink sync=false \
    ${audio_pipe} \
    rtspclientsink name=mux location=rtsp://localhost:8554/live/0 protocols=tcp
