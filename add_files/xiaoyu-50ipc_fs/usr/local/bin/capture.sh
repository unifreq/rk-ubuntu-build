#!/bin/bash

# 自动检测可用的视频设备，优先使用 rkisp_mainpath 下的设备
find_available_video_device() {
    # 方法1：通过 v4l2-ctl --list-devices 找到 rkisp_mainpath 对应的设备
    if command -v v4l2-ctl >/dev/null 2>&1; then
        # 解析输出：查找 "rkisp_mainpath" 行，然后向下找第一个 /dev/video 行
        DEV=$(v4l2-ctl --list-devices | awk '/rkisp_mainpath/,/^\s*$/ { if ($0 ~ /\/dev\/video/) { print $0; exit } }')
        if [ -n "$DEV" ]; then
            echo "$DEV"
            return 0
        fi
    fi

    # 方法2：回退方案 - 通过 v4l2-ctl --get-fmt-video 检测第一个可用设备
    for dev in /dev/video*; do
        if [ -c "$dev" ]; then
            if v4l2-ctl -d "$dev" --get-fmt-video >/dev/null 2>&1; then
                echo "$dev"
                return 0
            fi
        fi
    done
    return 1
}

DEVICE=$(find_available_video_device)
if [ -z "$DEVICE" ]; then
    echo "错误：未找到可用的视频设备，请检查摄像头连接及驱动。" >&2
    exit 1
fi
echo "使用视频设备: $DEVICE"

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
    	video/x-raw,format=NV12,width=1920,height=1080,framerate=30/1 ! \
    tee name=video \
    video. ! \
        queue leaky=downstream max-size-buffers=10 ! \
        mpph264enc gop=30 rc-mode=vbr bps-min=2000000 bps=4000000 bps-max=8000000 ! \
        h264parse config-interval=-1 ! \
        mux. \
    video. ! \
        queue leaky=downstream max-size-buffers=10 ! \
        videoscale ! video/x-raw,width=800,height=480 ! \
        videoflip method=counterclockwise ! \
        kmssink sync=false \
    ${audio_pipe} \
    rtspclientsink name=mux location=rtsp://localhost:8554/live/0 protocols=tcp
