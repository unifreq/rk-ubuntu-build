#!/bin/sh

CONF_FILE="/etc/capture.conf"

# --- 内置默认期望参数备份 ---
ISP_DEV="/dev/video24"
VPSS_DEV="/dev/video42"
DISPLAY_WIDTH=480
DISPLAY_HEIGHT=800
DISPLAY_ROTATE="270"
CAPTURE_WIDTH=2560
CAPTURE_HEIGHT=1440
CAPTURE_FPS=60
ENCODER_CODEC="h264_rkmpp"
RTSP_URL="rtsp://127.0.0.1:8554/live/0"
FORCE_MODESETTING="false"

if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
    echo "ℹ️ 已成功加载外部配置文件: $CONF_FILE"
else
    echo "⚠️ 未找到配置文件，将使用脚本内置默认参数运行。"
fi

# ==============================================================================
# 🧠 算法一：摄像头物理能力动态侦测与多梯队降级自愈 (完全校准“限高不限低”逻辑)
# ==============================================================================
echo "🔍 正在对硬件节点 ${ISP_DEV} 执行镜头物理上限探测..."

# 精准提炼出物理硬件底层唯一最大的那个绝对纯数字宽度 (如 2688)
HW_MAX_W=$(v4l2-ctl -d $ISP_DEV --list-formats-ext 2>/dev/null | grep "Size: Stepwise" | sed -n 's/.*- \([0-9]*\)x.*/\1/p' | sort -nu | tail -n 1)

if [ -z "$HW_MAX_W" ] || ! [ "$HW_MAX_W" -eq "$HW_MAX_W" ] 2>/dev/null; then
    echo "⚠️ 硬件探测文本未识别，安全采用配置设定的期望参数。"
else
    echo "📷 当前接入的物理摄像头最大硬件点阵宽度为: [${HW_MAX_W}] 像素"

    # 初始化运行时目标采集参数（初始状态完全继承用户的配置期望）
    RUN_W=$CAPTURE_WIDTH
    RUN_H=$CAPTURE_HEIGHT
    RUN_FPS=$CAPTURE_FPS

    # 梯队一：用户配置要求 4K (3840), 但物理镜头最大宽度达不到 3840
    if [ $CAPTURE_WIDTH -ge 3840 ] && [ $HW_MAX_W -lt 3840 ]; then
        echo "📉 [降级警报] 当前摄像头无法支持 4K 分辨率！"
        if [ $HW_MAX_W -ge 2560 ]; then
            # 降级到 2K 梯队安全上限
            RUN_W=2560; RUN_H=1440
            # 💡 核心修正：如果用户原本配置的帧率低于 60 (比如指定了30)，则保持 30，绝不上调！
            [ $CAPTURE_FPS -gt 60 ] && RUN_FPS=60 || RUN_FPS=$CAPTURE_FPS
            echo "🔄 自动向下修正至 2K 硬件梯队 (当前限制上限为: ${RUN_W}x${RUN_H} @ ${RUN_FPS}fps)"
        else
            # 直接降级到 1080P 梯队安全上限
            RUN_W=1920; RUN_H=1080
            [ $CAPTURE_FPS -gt 30 ] && RUN_FPS=30 || RUN_FPS=$CAPTURE_FPS
            echo "🔄 自动向下修正至 1080P 硬件梯队 (当前限制上限为: ${RUN_W}x${RUN_H} @ ${RUN_FPS}fps)"
        fi
    fi

    # 梯队二：用户配置要求 2K (2560), 但物理镜头最大宽度达不到 2560 (说明是 1080P 镜头)
    if [ $CAPTURE_WIDTH -ge 2560 ] && [ $HW_MAX_W -lt 2560 ]; then
        echo "📉 [降级警报] 当前摄像头无法支持 2K 分辨率！"
        RUN_W=1920; RUN_H=1080
        # 💡 核心修正：1080P 梯队安全上限为 30fps。如果用户本来配置的就是 25 或 30，保持原样，绝不拔高。
        [ $CAPTURE_FPS -gt 30 ] && RUN_FPS=30 || RUN_FPS=$CAPTURE_FPS
        echo "🔄 自动向下修正至 1080P 硬件梯队 (当前限制上限为: ${RUN_W}x${RUN_H} @ ${RUN_FPS}fps)"
    fi

    # 梯队三：极端安全降级。如果物理镜头的绝对能力连上面算出来的期望宽度都够不着
    if [ $HW_MAX_W -lt $RUN_W ]; then
        HW_MAX_H=$(v4l2-ctl -d $ISP_DEV --list-formats-ext 2>/dev/null | grep "Size: Stepwise" | sed -n 's/.*x\([0-9]*\) with.*/\1/p' | sort -nu | tail -n 1)
        [ -z "$HW_MAX_H" ] && HW_MAX_H=1080
        
        RUN_W=$HW_MAX_W
        RUN_H=$HW_MAX_H
        # 极端情况下最高强制降到 30fps。若配置低于 30 (比如 15fps)，维持 15 不变。
        [ $CAPTURE_FPS -gt 30 ] && RUN_FPS=30 || RUN_FPS=$CAPTURE_FPS
        echo "🚨 [极端降级] 已强制收敛到该镜头物理最高规格: ${RUN_W}x${RUN_H} @ ${RUN_FPS}fps"
    fi

    # 将最终优化对齐、只减不增的参数写回运行时变量
    CAPTURE_WIDTH=$RUN_W
    CAPTURE_HEIGHT=$RUN_H
    CAPTURE_FPS=$RUN_FPS
fi
# ==============================================================================


# ==============================================================================
# 🧠 算法二：屏幕横竖屏轴向与 GStreamer 原生枚举转换算法
# ==============================================================================
V4L2_REQ_W=$DISPLAY_WIDTH
V4L2_REQ_H=$DISPLAY_HEIGHT
GST_FLIP_ELEMENT=""
GST_DIRECTION=""
NEED_XYZ_SWAP=0

case "$DISPLAY_ROTATE" in
    "90")  GST_DIRECTION="90r"; NEED_XYZ_SWAP=1 ;;
    "180") GST_DIRECTION="180"; NEED_XYZ_SWAP=0 ;;
    "270") GST_DIRECTION="90l"; NEED_XYZ_SWAP=1 ;;
    *)     GST_DIRECTION="identity"; NEED_XYZ_SWAP=0 ;;
esac

if [ "$NEED_XYZ_SWAP" = "1" ]; then
    echo "📱 检测到画面需要进行 [轴向调换旋转] (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}) -> GST 标志: [${GST_DIRECTION}]"
    V4L2_REQ_W=$DISPLAY_HEIGHT
    V4L2_REQ_H=$DISPLAY_WIDTH
    GST_FLIP_ELEMENT="! videoflip video-direction=${GST_DIRECTION}"
elif [ "$GST_DIRECTION" = "180" ]; then
    echo "🙃 检测到画面需要进行 [180度上下翻转]，保持原高宽比例。"
    GST_FLIP_ELEMENT="! videoflip video-direction=180"
else
    echo "🖥️ 检测到当前设备为 [0度正常横屏直通模式] (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT})，跳过硬件旋转链。"
fi
# ==============================================================================

# --- 设置 GST 环境变量（Rockchip 硬件加速） ---
unset GST_V4L2_PREFERRED_FOURCC
unset GST_VIDEO_CONVERT_PREFERRED_FORMAT
export GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC=1
export GST_MPP_VIDEODEC_DEFAULT_FORMAT=NV12
export GST_VIDEO_CONVERT_USE_RGA=1
export GST_VIDEO_FLIP_USE_RGA=1

LOCK_FILE="/tmp/run_vpss_isp.lock"

stop_apps() {
    echo "=========================================="
    echo "⚠️ 正在启动[最高级会话隔离]的逆序安全退出流程..."
    echo "=========================================="
    echo "STOP" > "$LOCK_FILE"
    
    if pgrep -f "ffmpeg.*${ISP_DEV}" > /dev/null; then
        echo "1. 正在通过内核句柄优雅停止 FFmpeg (ISP 推流端)..."
        pkill -2 -f "ffmpeg.*${ISP_DEV}"
        echo "⏳ 正在强制休眠 3 秒，等待物理 DMA 链表和 MPP 队列完全排空..."
        sleep 3
        pkill -9 -f "ffmpeg.*${ISP_DEV}" 2>/dev/null
    fi
    
    if pgrep -f "gst-launch-1.0.*${VPSS_DEV}" > /dev/null; then
        echo "2. 上游已完全断流，正在安全回收 GStreamer (VPSS 本地显示)..."
        pkill -2 -f "gst-launch-1.0.*${VPSS_DEV}"
        sleep 1
        pkill -9 -f "gst-launch-1.0.*${VPSS_DEV}" 2>/dev/null
    fi
    
    echo "✅ 全链路后台硬件节点成功解耦释放，无任何残留死锁！"
    if [ "$1" = "self" ]; then
        rm -f "$LOCK_FILE"
        exit 0
    fi
}

trap "stop_apps self" 2 15

if [ "$1" = "stop" ]; then
    stop_apps external
    echo "👋 外部关闭命令执行完毕。"
    exit 0
fi

# ==========================================
# 主程序顺序启动流程
# ==========================================
echo "=========================================="
echo "🚀 开始执行最高级自适应生产线启动流程..."
echo "=========================================="
rm -f "$LOCK_FILE"
pkill -9 -f "ffmpeg.*${ISP_DEV}" 2>/dev/null
pkill -9 -f "gst-launch-1.0.*${VPSS_DEV}" 2>/dev/null
sleep 1

# 预注入动态校准：使用完全对齐的分辨率激活内核 VPSS 通道
echo "⚙️ 正在对 VPSS 硬件寄存器执行自适应初值预注入 (${V4L2_REQ_W}x${V4L2_REQ_H})..."
v4l2-ctl -d $VPSS_DEV --set-fmt-video=width=$V4L2_REQ_W,height=$V4L2_REQ_H,pixelformat=NV12 >/dev/null 2>&1

echo "1. 优先拉起本地显示 [GStreamer -> VPSS]..."
setsid gst-launch-1.0 \
        v4l2src device=$VPSS_DEV ! \
        video/x-raw,width=$V4L2_REQ_W,height=$V4L2_REQ_H,format=NV12 \
        $GST_FLIP_ELEMENT ! \
        kmssink sync=false force-modesetting=${FORCE_MODESETTING} >/dev/null 2>&1 &
pid_gst=$!

sleep 5

echo "2. 底层已就绪，拉起 RTSP 推流 [FFmpeg -> ISP]..."
# 💡 核心修复：-vf "fps=${CAPTURE_FPS}" 里的数字完美匹配算法一收敛后的动态变量
setsid ffmpeg -f v4l2 \
        -framerate $CAPTURE_FPS \
        -video_size "${CAPTURE_WIDTH}x${CAPTURE_HEIGHT}" \
        -pix_fmt nv12 -i $ISP_DEV \
        -vf "fps=${CAPTURE_FPS}" \
        -vcodec $ENCODER_CODEC \
        -r $CAPTURE_FPS \
        -f rtsp "$RTSP_URL" >/dev/null 2>&1 &
pid_fmp=$!

echo "=========================================="
echo "🎉 终极自适应双进程独立会话链路已成功建立！"
echo "👉 采集端配置: ${CAPTURE_WIDTH}x${CAPTURE_HEIGHT} @ ${CAPTURE_FPS}fps"
echo "👉 内核驱动注入: ${V4L2_REQ_W}x${V4L2_REQ_H} (NV12)"
echo "👉 屏幕渲染状态: 物理屏宽=${DISPLAY_WIDTH}, 屏高=${DISPLAY_HEIGHT} -> 映射后标志=[${GST_DIRECTION}]"
echo "👉 推流端地址: ${RTSP_URL}"
echo "=========================================="

while true; do
    if [ -f "$LOCK_FILE" ] && [ "$(cat "$LOCK_FILE")" = "$(printf "STOP")" ]; then
        echo "✅ 检测到外部关闭动作成功，主守护进程现在安全退出。"
        rm -f "$LOCK_FILE"
        exit 0
    fi
    
    if ! pgrep -f "ffmpeg.*${ISP_DEV}" > /dev/null && ! pgrep -f "gst-launch-1.0.*${VPSS_DEV}" > /dev/null; then
        echo "⚠️ 检测到后台多媒体链路异常终止，正在自动执行收尾清理..."
        stop_apps self
    fi
    sleep 1
done
