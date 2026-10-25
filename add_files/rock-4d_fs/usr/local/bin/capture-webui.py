#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
capture-webui.py - capture 服务 Web 管理界面 (轻量级, 仅用 Python 标准库)
======================================================================
功能:
  - 服务状态监测与控制: capture.service 的启停/重启/开机自启
  - capture 进程状态与运行参数摘要
  - /etc/capture.conf 参数可视化调整 (保存配置 / 即时生效)
  - 系统资源监控: CPU / 内存 / 温度 (前端 Chart.js 折线图)

技术:
  - Python3 标准库 http.server (ThreadingHTTPServer), 零额外依赖
  - 登录: 复用操作系统 root 密码 (crypt 模块 + /etc/shadow)
  - 会话: 内存 token (secrets) + httpOnly Cookie
  - 图表: 内嵌 Chart.js (/usr/share/javascript/chart.js/chart.min.js)

用法:
  python3 /usr/local/bin/capture-webui.py [--port 80] [--bind 0.0.0.0]
"""

import argparse
import glob
import json
import os
import re
import secrets
import shutil
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

# ---------------------------------------------------------------------------
# 常量与配置
# ---------------------------------------------------------------------------
VERSION = "1.3.4"                    # 软件版本
SERVICE = "capture.service"
CONF_PATH = "/etc/capture.conf"
CONF_DEFAULT = "/etc/capture.conf.default"   # 首次启动备份的默认配置
CAPTURE_PL = "/usr/local/bin/capture.pl"
ENUM_PL = "/usr/local/bin/capture-enum.pl"
CHART_JS_PATH = "/usr/local/www/chart.min.js"
HTML_PAGE = "/usr/local/www/capture-webui.html"   # 前端页面 (独立文件)

# ---- 简单 TTL 缓存: 避免页面重载/设备切换时反复跑 capture-enum/modetest/实测抓帧 ----
# 例: 采集帧率(ISP 只读)实测一次需 ~8-10s(预热40帧+300帧), devices/DRM/capture_res 各 ~0.3-1.5s.
_CACHE = {}
_CACHE_MAX = 256

def _cached(key, ttl, build):
    now = time.time()
    hit = _CACHE.get(key)
    if hit and now - hit[0] < ttl:
        return hit[1]
    val = build()
    if len(_CACHE) >= _CACHE_MAX:
        _CACHE.clear()
    _CACHE[key] = (now, val)
    return val


def _cache_clear():
    _CACHE.clear()


def _warm_cache():
    """后台预热常用动态枚举: 服务启动/配置变更后立即测量,
    首次打开配置页时下拉基本即时 (ISP 采集帧率实测一次约数秒)."""
    try:
        cfg = load_config()
        devs = {"/dev/video24", "/dev/video32"}
        if isinstance(cfg, dict):
            d0 = cfg.get("FFMPEG_CAM_DEV", "/dev/video24")
            if isinstance(d0, str) and d0:
                devs.add(d0)
        for dd in devs:
            _cached("capres:" + dd, 12, (lambda x: lambda: list_capture_res(dev=x))(dd))
            _cached("fmt:" + dd + ":", 25, (lambda x: lambda: list_fps_formats(dev=x))(dd))
    except Exception:
        pass


def _start_warmup():
    try:
        threading.Thread(target=_warm_cache, daemon=True).start()
    except Exception:
        pass


SESSION_TTL = 12 * 3600      # 会话有效期 12 小时
SESSIONS = {}                # token -> 过期时间戳

# 密码哈希: 优先 Python crypt 模块 (3.12), 3.13+ 移除后回退 ctypes 调用系统 libcrypt
try:
    import crypt as _crypt
except Exception:
    _crypt = None


def _crypt_hash(password, salt):
    """计算 password+salt 的密码哈希 (兼容 Python 3.13)"""
    if _crypt is not None:
        try:
            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                return _crypt.crypt(password, salt)
        except Exception:
            pass
    try:  # 回退: ctypes 调用系统 libcrypt 的 crypt() (支持 yescrypt/$6$/$5$/$1$ 等)
        import ctypes
        import ctypes.util
        lib = ctypes.CDLL(ctypes.util.find_library("crypt") or "libcrypt.so.1", use_errno=True)
        lib.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
        lib.crypt.restype = ctypes.c_char_p
        res = lib.crypt(password.encode("utf-8"), salt.encode("utf-8"))
        return res.decode("utf-8") if res else None
    except Exception:
        return None

# ---------------------------------------------------------------------------
# 配置项 schema (供前端渲染表单)
# 字段: key / type(bool|int|str) / group / label
# ---------------------------------------------------------------------------
CONFIG_SCHEMA = [
    # 系统 / 品牌
    {"key": "BRAND_NAME",   "type": "str", "group": "系统", "label": "品牌名称",
     "help": "WebUI 标题/页头与 OSD 默认文字显示的品牌名 (留空则用默认 小宇智联)"},
    # 功能开关
    {"key": "DISPLAY_ENABLE",   "type": "bool", "group": "功能开关", "label": "本地显示",
     "help": "是否启用本地显示屏输出"},
    {"key": "STREAM_ENABLE",    "type": "bool", "group": "功能开关", "label": "推流",
     "help": "是否启用 RTSP 推流"},
    # 3A 算法
    {"key": "RESTART_3A",       "type": "bool", "group": "3A 算法", "label": "启动前重启 3A",
     "help": "启动前执行 systemctl restart rkaiq_3A.service"},
    {"key": "WAIT_3A",          "type": "bool", "group": "3A 算法", "label": "等待 3A 就绪",
     "help": "等待 3A 服务(端口4894)就绪后再启动管线"},
    # 采集->推流
    {"key": "FFMPEG_CAM_DEV",   "type": "select", "group": "采集->推流", "label": "推流视频采集", "dynamic": "devices",
     "help": "推流视频采集设备 (通常 rkisp_mainpath)"},
    {"key": "CAPTURE_RES",      "type": "select", "group": "采集->推流", "label": "分辨率", "dynamic": "capture_res",
     "help": "采集分辨率 (按当前推流采集设备支持的枚举自动筛选, 宽x高)"},
    {"key": "CAPTURE_FPS",      "type": "select", "group": "采集->推流", "label": "采集帧率", "dynamic": "formats",
     "help": "采集帧率 (ISP 设备由 3A 控制, 只读; 非 ISP 可枚举)"},
    {"key": "STREAM_FPS",       "type": "select", "group": "采集->推流", "label": "输出帧率",
     "help": "推流输出帧率 (滤镜 -vf fps 前置统一, 不再用输出端 -r); 升档=采集帧率整数倍(最高120fps), 降档=折半链÷2/÷4/÷8(缓解高采集帧率下编码器吞吐瓶颈); auto=跟随采集帧率"},
    {"key": "RTSP_URL",         "type": "str", "group": "采集->推流", "label": "RTSP 地址",
     "help": "RTSP 推流目标地址"},
    # 本地显示
    {"key": "GST_CAM_DEV",      "type": "select", "group": "本地显示", "label": "视频采集设备", "dynamic": "devices",
     "help": "本地显示视频采集设备 (通常 rkisp_selfpath)"},
    {"key": "DISPLAY_CONNECTOR_ID",   "type": "select", "group": "本地显示", "label": "DRM connector ID", "dynamic": "drm_ids",
     "help": "DRM connector 数字 ID (-1=自动)"},
    {"key": "DISPLAY_CONNECTOR_NAME", "type": "select", "group": "本地显示", "label": "DRM 设备", "dynamic": "drm",
     "help": "DRM connector 名称 (空=自动)"},
    {"key": "DISPLAY_RES",      "type": "select", "group": "本地显示", "label": "分辨率", "dynamic": "drm_modes",
     "help": "本地显示分辨率 (从 DRM 可用模式枚举, 宽x高). 注意: 部分模式(如 2240x1400)虽在模式列表中, 但可能因板卡像素时钟/PHY/VOP 限制无法 modeset, 若本地显示反复退出请改用已验证分辨率(如 1920x1080)"},
    {"key": "DISPLAY_ROTATE",   "type": "select", "group": "本地显示", "label": "旋转角度",
     "options": ["0", "90", "180", "270"], "help": "显示画面旋转角度"},
    {"key": "FORCE_MODESETTING","type": "bool", "group": "本地显示", "label": "强制 modesetting",
     "help": "kmssink 强制 modesetting"},
    # 采集->推流 / 编码
    {"key": "ENCODER_CODEC",    "type": "radio", "group": "采集->推流", "subgroup": "编码", "label": "编码器",
     "options": ["h264_rkmpp", "hevc_rkmpp"], "help": "选择 H.264 或 HEVC 硬件编码"},
    {"key": "ENCODER_BITRATE",  "type": "str", "group": "采集->推流", "subgroup": "编码", "label": "目标码率",
     "help": "目标码率, 如 8M/12M/16M/24M (仅设此项+码率模式即可, 其余参数自动推导)。编码速查(均为 CBR 推荐): 640x480@25→1M, 1280x720@30→4M, 1920x1080@30→6M(60fps→12M), 2560x1440@30→16M(60fps→18M), 3840x2160@30→24M, 480x800@30→2M。HEVC 同等画质约为 H.264 的 60%~70%; 画质优先可改 VBR/AVBR"},
    {"key": "ENCODER_GOP",      "type": "str", "group": "采集->推流", "subgroup": "编码", "label": "GOP",
     "help": "关键帧间隔: auto=2倍帧率, 或固定 60/120"},
    {"key": "ENCODER_RC_MODE",  "type": "select", "group": "采集->推流", "subgroup": "编码", "label": "码率模式",
     "options": ["CBR", "VBR", "AVBR"],
     "help": "CBR 恒定码率最稳(均值=目标); VBR 真动态范围(150%*T/3*T, 静态可降码率/动态有头寸, 均值略高于目标); AVBR 质量自适应, 实际均值约为目标的 60-70%(码率偏低为特性)"},
    {"key": "ENCODER_EXTRA",    "type": "str", "group": "采集->推流", "subgroup": "编码", "label": "额外参数",
     "help": "追加到自动参数末尾并覆盖, 如 -qp_max 30"},
    {"key": "ENCODER_INTRAREFRESH","type": "select", "group": "采集->推流", "subgroup": "编码", "label": "直播去块刷新",
     "options": ["off", "on"],
     "help": "开启后用逐行分布刷新取代周期性 IDR 关键帧, 可消除关键帧突发导致的卡顿; 但码流不再有整帧 IDR, WebRTC/PotPlayer 等依赖关键帧的播放器将无法起播, 故默认 off"},
    {"key": "RTSP_TRANSPORT",   "type": "select", "group": "采集->推流", "subgroup": "RTSP", "label": "RTSP 传输层",
     "options": ["tcp", "udp"], "help": "RTSP 推流传输层: tcp 更稳 (无 UDP 丢包/乱序), 局域网推荐 tcp"},
    # 采集->推流 / 音频
    {"key": "AUDIO_ENABLE",     "type": "bool", "group": "采集->推流", "subgroup": "音频", "label": "音频推流",
     "help": "是否随视频推流麦克风音频"},
    {"key": "AUDIO_DEVICE",     "type": "select", "group": "采集->推流", "subgroup": "音频", "label": "ALSA 设备", "dynamic": "alsa_dev",
     "help": "ALSA 采集设备 (从系统枚举)"},
    {"key": "AUDIO_SAMPLERATE", "type": "select", "group": "采集->推流", "subgroup": "音频", "label": "采样率", "dynamic": "alsa_rate",
     "help": "录音采样率 (从系统枚举)"},
    {"key": "AUDIO_CHANNELS",   "type": "select", "group": "采集->推流", "subgroup": "音频", "label": "声道数",
     "options": ["1", "2"], "help": "采集声道数 (单声道麦克风选 1)"},
    {"key": "AUDIO_BITRATE",    "type": "select", "group": "采集->推流", "subgroup": "音频", "label": "AAC 码率",
     "options": ["96k", "128k", "160k", "192k"], "help": "AAC 音频编码码率"},
    # 采集->推流 / 推流 OSD
    {"key": "OSD_ENABLE",       "type": "bool", "group": "采集->推流", "subgroup": "推流 OSD", "label": "OSD 开关",
     "help": "是否在推流画面叠加文字"},
    {"key": "OSD_TEXT",         "type": "str", "group": "采集->推流", "subgroup": "推流 OSD", "label": "固定文字",
     "help": "左上角固定文字"},
    {"key": "OSD_FONT",         "type": "select", "group": "采集->推流", "subgroup": "推流 OSD", "label": "字体", "dynamic": "fonts",
     "help": "drawtext 字体文件路径 (中文字体)"},
    {"key": "OSD_TIMESTAMP",    "type": "bool", "group": "采集->推流", "subgroup": "推流 OSD", "label": "时间戳",
     "help": "右上角时间戳开关"},
    {"key": "OSD_TIMESTAMP_FORMAT", "type": "str", "group": "采集->推流", "subgroup": "推流 OSD", "label": "时间戳格式",
     "help": "strftime 格式, 请用全角冒号(：)分隔时分秒"},
    {"key": "OSD_FONTSIZE",     "type": "select", "group": "采集->推流", "subgroup": "推流 OSD", "label": "字号",
     "options": ["0", "20", "24", "28", "32", "36", "40", "48"], "help": "0=自动按分辨率计算"},
    # 本地显示 / 本地 OSD
    {"key": "DISPLAY_OSD_ENABLE",  "type": "bool", "group": "本地显示", "subgroup": "本地 OSD", "label": "OSD 开关",
     "help": "是否在本地显示叠加文字"},
    {"key": "DISPLAY_OSD_TEXT",    "type": "str", "group": "本地显示", "subgroup": "本地 OSD", "label": "固定文字",
     "help": "本地显示左上角固定文字"},
    {"key": "DISPLAY_OSD_FONT",    "type": "select", "group": "本地显示", "subgroup": "本地 OSD", "label": "字体", "dynamic": "pango",
     "help": "pango 字体家族名 (如 WenQuanYi Micro Hei / Sans)"},
    {"key": "DISPLAY_OSD_TIMESTAMP","type": "bool", "group": "本地显示", "subgroup": "本地 OSD", "label": "时间戳",
     "help": "本地显示时间戳开关"},
    {"key": "DISPLAY_OSD_TIMESTAMP_FORMAT", "type": "str", "group": "本地显示", "subgroup": "本地 OSD", "label": "时间戳格式",
     "help": "strftime 格式"},
    {"key": "DISPLAY_OSD_FONTSIZE","type": "select", "group": "本地显示", "subgroup": "本地 OSD", "label": "字号",
     "options": ["0", "10", "12", "14", "16", "18", "20", "24"], "help": "0=自动按分辨率计算"},
]

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------
def run_cmd(cmd, timeout=15):
    """执行命令, 返回 (returncode, stdout, stderr)"""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except Exception as e:
        return -1, "", str(e)


def sysctl(*args):
    return run_cmd(["systemctl"] + list(args), timeout=30)


def _load_shadow_hash(user):
    """从 /etc/shadow 读取指定用户的密码哈希 (root 运行可读)"""
    try:
        with open("/etc/shadow", "r") as f:
            for line in f:
                parts = line.split(":")
                if parts and parts[0] == user and len(parts) >= 2 and parts[1]:
                    return parts[1]
    except Exception:
        pass
    return None


def verify_password(password, user="root"):
    """复用系统用户密码验证 (兼容 3.12 crypt 与 3.13+ libcrypt)"""
    h = _load_shadow_hash(user)
    if not h or h in ("!", "*", "!!"):
        return False
    try:
        return _crypt_hash(password, h) == h
    except Exception:
        return False


# ---------------------------------------------------------------------------
# 会话管理 (内存 token + httpOnly cookie)
# ---------------------------------------------------------------------------
def new_session():
    tok = secrets.token_urlsafe(32)
    SESSIONS[tok] = time.time() + SESSION_TTL
    return tok


def check_session(tok):
    if not tok:
        return False
    exp = SESSIONS.get(tok)
    if exp is None:
        return False
    if time.time() > exp:
        SESSIONS.pop(tok, None)
        return False
    return True


def drop_session(tok):
    SESSIONS.pop(tok, None)


def cleanup_sessions():
    now = time.time()
    for k in [k for k, v in SESSIONS.items() if v < now]:
        SESSIONS.pop(k, None)


# ---------------------------------------------------------------------------
# 服务控制
# ---------------------------------------------------------------------------
def service_status():
    _, act, _ = sysctl("is-active", SERVICE)
    _, enb, _ = sysctl("is-enabled", SERVICE)
    # 解析 KEY=value 键值对, 不依赖 systemctl show 的输出顺序 (实测顺序与 -p 参数不一致)
    code, show, _ = sysctl("show", SERVICE,
                           "-p", "MainPID", "-p", "ActiveState", "-p", "SubState",
                           "-p", "ExecMainStartTimestamp")
    d = {}
    for ln in (show or "").splitlines():
        if "=" in ln:
            k, v = ln.split("=", 1)
            d[k.strip()] = v.strip()
    return {
        "active": act == "active",
        "enabled": enb == "enabled",
        "main_pid": d.get("MainPID", ""),
        "active_state": d.get("ActiveState", ""),
        "sub_state": d.get("SubState", ""),
        "start_time": d.get("ExecMainStartTimestamp", ""),
    }


def service_action(action):
    """action: start/stop/restart/enable/disable"""
    if action in ("start", "stop", "restart", "enable", "disable"):
        code, out, err = sysctl(action, SERVICE)
        return {"ok": code == 0, "out": out, "err": err}
    return {"ok": False, "err": "unknown action"}


def capture_process_summary():
    """capture 进程状态与运行参数摘要"""
    cfg = load_config()

    def _on(v):
        return str(v) in ("1", "true", "yes")

    def _rot(w, h, rot):
        return (h, w) if str(rot) in ("90", "270") else (w, h)

    # 显示分辨率 (按旋转角度换算方向, 自动计算)
    try:
        dr = cfg.get("DISPLAY_ROTATE", "0")
        m = re.match(r"^(\d+)\s*[xX]\s*(\d+)$", (cfg.get("DISPLAY_RES", "") or "").strip())
        if m:
            dw, dh = int(m.group(1)), int(m.group(2))
            vw, vh = _rot(dw, dh, dr)
            disp_res = "%dx%d(旋转%s度)" % (vw, vh, dr)
        else:
            disp_res = cfg.get("DISPLAY_RES", "-")
    except Exception:
        disp_res = "-"

    # DRM connector 信息 (自动探测 + 配置)
    drm_conn = cfg.get("DISPLAY_CONNECTOR_NAME", "-")
    drm_id = cfg.get("DISPLAY_CONNECTOR_ID", "-")
    drm_status, drm_mode = "-", "-"
    try:
        for entry in sorted(os.listdir("/sys/class/drm")):
            if not entry.startswith("card"):
                continue
            sfile = "/sys/class/drm/%s/status" % entry
            if not os.path.exists(sfile):
                continue
            st = open(sfile).read().strip()
            if st == "connected":
                conn = entry.split("-", 1)[1] if "-" in entry else entry
                drm_status = "connected"
                mfile = "/sys/class/drm/%s/modes" % entry
                if os.path.exists(mfile):
                    modes = open(mfile).read().splitlines()
                    if modes:
                        drm_mode = modes[0]
                cfg_name = cfg.get("DISPLAY_CONNECTOR_NAME", "")
                if cfg_name and conn == cfg_name:
                    drm_conn = conn
                    break
                if drm_conn == "-":
                    drm_conn = conn
    except Exception:
        pass

    overview = {
        # ---- 推流组 ----
        "stream": cfg.get("STREAM_ENABLE", "-"),
        "audio": cfg.get("AUDIO_ENABLE", "-"),
        "cap_res": cfg.get("CAPTURE_RES", "-"),
        "cap_fps": cfg.get("CAPTURE_FPS", "-"),
        "stream_fps": cfg.get("STREAM_FPS", "-"),
        "codec": cfg.get("ENCODER_CODEC", "-"),
        "bitrate": cfg.get("ENCODER_BITRATE", "-"),
        "rc_mode": cfg.get("ENCODER_RC_MODE", "-"),
        "rtsp": cfg.get("RTSP_URL", "-"),
        "osd_text": "ON" if (_on(cfg.get("OSD_ENABLE")) and cfg.get("OSD_TEXT", "")) else "OFF",
        "osd_ts": "ON" if _on(cfg.get("OSD_TIMESTAMP")) else "OFF",
        # ---- 显示组 ----
        "display": cfg.get("DISPLAY_ENABLE", "-"),
        "disp_res": disp_res,
        "drm_conn": "%s(id %s)" % (drm_conn, drm_id),
        "drm_status": drm_status,
        "drm_mode": drm_mode,
        "d_osd_text": "ON" if (_on(cfg.get("DISPLAY_OSD_ENABLE")) and cfg.get("DISPLAY_OSD_TEXT", "")) else "OFF",
        "d_osd_ts": "ON" if _on(cfg.get("DISPLAY_OSD_TIMESTAMP")) else "OFF",
    }
    # capture.pl --status 输出
    _, out, _ = run_cmd(["/usr/bin/perl", CAPTURE_PL, "--status"], timeout=15)
    return {"overview": overview, "status_text": out}


# ---------------------------------------------------------------------------
# 配置读写 (保留注释与顺序)
# ---------------------------------------------------------------------------
def load_config():
    cfg = {}
    if not os.path.exists(CONF_PATH):
        return cfg
    try:
        with open(CONF_PATH, "r") as f:
            for line in f:
                m = re.match(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?:"([^"]*)"|(\S+))\s*$', line)
                if m:
                    cfg[m.group(1)] = m.group(2) if m.group(2) is not None else m.group(3)
    except Exception:
        pass
    return cfg


def save_config(new_cfg):
    """写回 /etc/capture.conf, 保留原注释与顺序; 返回新增的 key 列表"""
    # 清洗值 (避免破坏引号格式)
    clean = {}
    for k, v in new_cfg.items():
        if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', str(k)):
            continue
        clean[k] = str(v).replace('"', "'")
    keys = set(clean.keys())

    lines = []
    if os.path.exists(CONF_PATH):
        with open(CONF_PATH, "r") as f:
            lines = f.read().splitlines()

    matched = set()
    out = []
    for line in lines:
        m = re.match(r'^(\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*=\s*)(?:"[^"]*"|\S*)(.*)$', line)
        if m:
            key = m.group(2)
            if key in clean:
                out.append('%s%s%s"%s"%s' % (m.group(1), key, m.group(3), clean[key], m.group(4)))
                matched.add(key)
                continue
        out.append(line)

    # 追加未匹配的新 key
    for k in sorted(keys - matched):
        out.append('%s="%s"' % (k, clean[k]))

    with open(CONF_PATH, "w") as f:
        f.write("\n".join(out) + "\n")
    return sorted(keys - matched)


def ensure_default_config():
    """首次启动备份: 若 capture.conf 存在且 .default 不存在, 复制为默认配置"""
    try:
        if os.path.exists(CONF_PATH) and not os.path.exists(CONF_DEFAULT):
            shutil.copyfile(CONF_PATH, CONF_DEFAULT)
            return True
    except Exception:
        pass
    return False


def restore_default_config():
    """从默认配置恢复 /etc/capture.conf 并重启 capture.service; 返回 (ok, msg)"""
    if not os.path.exists(CONF_DEFAULT):
        return False, "默认配置不存在 (请先保存一次配置生成默认备份)"
    try:
        shutil.copyfile(CONF_DEFAULT, CONF_PATH)
    except Exception as e:
        return False, "恢复失败: %s" % e
    res = service_action("restart")
    if not res.get("ok"):
        return False, "配置已恢复，但 capture.service 重启失败: %s" % res.get("err", "")
    return True, "已恢复默认配置，capture.service 重启中（约3-5秒）"


def config_schema_payload():
    """schema + 当前值 (含 options/help/dynamic)"""
    cfg = load_config()
    schema = []
    for item in CONFIG_SCHEMA:
        schema.append({
            "key": item["key"], "type": item["type"],
            "group": item["group"], "label": item["label"],
            "subgroup": item.get("subgroup", ""),
            "value": cfg.get(item["key"], ""),
            "options": item.get("options", []),
            "help": item.get("help", ""),
            "dynamic": item.get("dynamic", ""),
        })
    return schema


def brand_name():
    """品牌名: 从配置读取 BRAND_NAME, 默认 小宇智联"""
    cfg = load_config()
    v = (cfg.get("BRAND_NAME") or "").strip()
    return v if v else "小宇智联"


# ---------------------------------------------------------------------------
# 系统资源监控
# ---------------------------------------------------------------------------
def _read_proc_stat():
    try:
        with open("/proc/stat") as f:
            parts = f.readline().split()
        nums = [int(x) for x in parts[1:]]
        idle = nums[3] + nums[4]          # idle + iowait
        total = sum(nums)
        return idle, total
    except Exception:
        return 0, 0


def cpu_percent():
    i1, t1 = _read_proc_stat()
    time.sleep(0.5)
    i2, t2 = _read_proc_stat()
    dt = t2 - t1
    if dt <= 0:
        return 0.0
    return round(100.0 * (1 - (i2 - i1) / dt), 1)


def mem_info():
    try:
        d = {}
        with open("/proc/meminfo") as f:
            for line in f:
                if ":" in line:
                    k, v = line.split(":", 1)
                    d[k.strip()] = int(v.strip().split()[0])
        total = d.get("MemTotal", 0)
        avail = d.get("MemAvailable", total)
        used = total - avail
        return {
            "total_mb": round(total / 1024, 1),
            "avail_mb": round(avail / 1024, 1),
            "used_mb": round(used / 1024, 1),
            "percent": round(100.0 * used / total, 1) if total else 0.0,
        }
    except Exception:
        return {"total_mb": 0, "avail_mb": 0, "used_mb": 0, "percent": 0}


def temp_now():
    paths = [
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
    ]
    for p in paths:
        try:
            t = int(open(p).read().strip())
            return round(t / 1000.0, 1)
        except Exception:
            continue
    return None


# ---------------------------------------------------------------------------
# 网络监控
# ---------------------------------------------------------------------------
_NET_PREV = {}   # dev -> (rx_bytes, tx_bytes, ts)


def net_ip(dev):
    """取指定网络设备的 IPv4 地址 (ip -4 -o addr show)"""
    code, out, _ = run_cmd(["ip", "-4", "-o", "addr", "show", dev], timeout=5)
    if code == 0:
        m = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)/", out)
        if m:
            return m.group(1)
    return ""


# 应排除的虚拟/容器网络设备前缀 (docker / kvm / 隧道 / overlay 等)
_VIRT_PREFIX = ("veth", "docker", "virbr", "tun", "tap", "vmnet", "vnet",
                "dummy", "sit", "ip6tnl", "gretap", "erspan", "nftnl", "vxlan")


def _is_virtual(dev):
    """判断是否应排除的虚拟/容器网络设备"""
    if dev == "lo":
        return True
    low = dev.lower()
    if low.startswith(_VIRT_PREFIX):
        return True
    # docker 创建的 bridge 默认命名 br-<12位hex>
    if re.match(r"^br-[0-9a-f]{12}$", low):
        return True
    # veth 类型为 772
    try:
        if open("/sys/class/net/%s/type" % dev).read().strip() == "772":
            return True
    except Exception:
        pass
    return False


def net_ifaces():
    """枚举网络设备: 排除虚拟/容器设备与回环;
    保留物理网卡 + 物理桥接(br0/br-lan等) + bond;
    桥接/bond 从属接口自动隐藏"""
    items = []
    try:
        if not os.path.isdir("/sys/class/net"):
            return items
        for dev in sorted(os.listdir("/sys/class/net")):
            if _is_virtual(dev):
                continue
            p = "/sys/class/net/%s" % dev
            # 桥接/bond 从属接口 (bridge_slave / master) 自动隐藏, 流量已由主设备承载
            if os.path.exists(p + "/bridge_slave") or os.path.exists(p + "/master"):
                continue
            is_bridge = os.path.isdir(p + "/bridge")
            is_bond = os.path.isdir(p + "/bonding")
            physical = os.path.exists(p + "/device")
            # 既非物理也非桥接/bond 的其它接口 (如 vlan 子接口) 仅保留带 IP 的
            if not (physical or is_bridge or is_bond):
                if not net_ip(dev):
                    continue
            item = {"name": dev, "ip": "", "mac": "", "speed": None}
            try:
                item["mac"] = open(p + "/address").read().strip()
            except Exception:
                pass
            # 连接速率 (Mbps): /sys/class/net/<dev>/speed, 未连接或无速率时为 None
            try:
                sp = open(p + "/speed").read().strip()
                if sp.isdigit() and int(sp) > 0:
                    item["speed"] = int(sp)
            except Exception:
                pass
            item["ip"] = net_ip(dev)
            items.append(item)
    except Exception:
        pass
    return items


def net_rates():
    """读 /proc/net/dev 两次采样差, 返回各设备上下行速率 (bytes/s)"""
    result = {}
    try:
        with open("/proc/net/dev") as f:
            lines = f.readlines()[2:]
        now = time.time()
        for ln in lines:
            if ":" not in ln:
                continue
            dev, rest = ln.split(":", 1)
            dev = dev.strip()
            if dev == "lo":
                continue
            flds = rest.split()
            if len(flds) >= 9:
                rx = int(flds[0])
                tx = int(flds[8])
                prev = _NET_PREV.get(dev)
                if prev:
                    prx, ptx, pts = prev
                    dt = now - pts
                    if dt > 0:
                        result[dev] = {
                            "rx": max(0, int((rx - prx) / dt)),
                            "tx": max(0, int((tx - ptx) / dt)),
                        }
                _NET_PREV[dev] = (rx, tx, now)
    except Exception:
        pass
    return result


def stats_payload():
    m = mem_info()
    rates = net_rates()
    nets = []
    for item in net_ifaces():
        r = rates.get(item["name"], {"rx": 0, "tx": 0})
        nets.append({
            "name": item["name"],
            "ip": item["ip"],
            "mac": item["mac"],
            "speed": item.get("speed"),
            "rx": r["rx"],
            "tx": r["tx"],
        })
    return {
        "cpu": cpu_percent(),
        "mem_total": m["total_mb"],
        "mem_used": m["used_mb"],
        "mem_percent": m["percent"],
        "temp": temp_now(),
        "time": int(time.time()),
        "net": nets,
    }


# ---------------------------------------------------------------------------
# 动态枚举 (设备 / DRM / 字体)
# ---------------------------------------------------------------------------
def _media_topology(media):
    """返回 media 设备的 media-ctl -p 拓扑文本 (失败返回空串)"""
    code, out, _ = run_cmd(["media-ctl", "-d", media, "-p"], timeout=10)
    return out if code == 0 else ""


def _media_model_from_text(out):
    """从拓扑文本提取 media 设备 model (如 rkcif-mipi-lvds / rkisp / rkvpss)"""
    m = re.search(r'^\s*model\s+(\S+)', out, re.M)
    return m.group(1) if m else ""


def _ref_regex(model):
    """构造下游引用匹配正则:
    既支持直接实体名 (如 rkcif-mipi-lvds -> ISP 媒体引用该实体),
    也支持虚拟接口名 (如 rkisp0 -> VPSS 媒体引用 rkisp-vir0-sditf)"""
    base = re.sub(r'\d+$', '', model)
    inst = re.search(r'(\d+)$', model)
    pats = [r'\b%s\b' % re.escape(model)]
    if inst and base != model:
        pats.append(r'\b%s-vir%s\b' % (re.escape(base), inst.group(1)))
    return re.compile('|'.join(pats))


def _active_media_set():
    """返回含真实 sensor 的 media 设备及其下游 (ISP/VPSS) 集合; 无 media 时返回 None (不去重).
    双目 DTS 下另一路无真实 sensor (FakeCamera), 其设备无效需排除."""
    medias = sorted(glob.glob('/dev/media*'))
    if not medias:
        return None

    topos = {m: _media_topology(m) for m in medias}
    active = set()
    frontier = []

    # 1. 含真实 Sensor 实体的 media (CIF)
    for media, out in topos.items():
        if not out:
            continue
        if re.search(r'subtype\s+Sensor', out) and not re.search(r'FakeCamera|fake.?camera', out, re.I):
            active.add(media)
            model = _media_model_from_text(out)
            if model:
                frontier.append(model)

    # 2. 沿引用关系扩散下游: CIF -> ISP -> VPSS (最多 3 跳)
    for _ in range(3):
        if not frontier:
            break
        nxt = []
        for media, out in topos.items():
            if media in active or not out:
                continue
            for f in frontier:
                if _ref_regex(f).search(out):
                    active.add(media)
                    model = _media_model_from_text(out)
                    if model:
                        nxt.append(model)
                    break
        frontier = nxt

    return active


def _media_devices_map():
    """返回 {media设备: [video设备路径...]} 映射 (用于双路去重)"""
    m = {}
    for media in sorted(glob.glob('/dev/media*')):
        for ln in _media_topology(media).splitlines():
            mm = re.search(r'device node name\s+(/dev/video\S+)', ln)
            if mm:
                m.setdefault(media, []).append(mm.group(1))
    return m


def list_video_devices():
    """枚举可用视频采集设备 (供推流/显示采集下拉).
    规则: 仅 /dev/videoN; 名称白名单(可拉流节点); 双路去重(仅保留含真实 sensor 的下游设备).
    排除: /dev/media*, rkaiisp/rkisp-statistics/input-params/pdaf/iqtool/rawrd,
          rkcif_tools/rkfec_offline/rkvpss-offline, 以及双目另一路(FakeCamera)设备."""
    ALLOW_RE = re.compile(
        r'^(rkisp_mainpath|rkisp_selfpath|stream_cif_mipi_id\d+|rkcif_scale_ch\d+|rkvpss_scale\d+)$'
    )

    def is_uvc(e, name):
        if re.search(r'uvc|usb.?camera|webcam', name, re.I):
            return True
        try:
            uev = open("/sys/class/video4linux/%s/device/uevent" % e).read()
            return "DRIVER=uvcvideo" in uev
        except Exception:
            return False

    all_devs = []
    try:
        for e in sorted(os.listdir("/sys/class/video4linux")):
            if not e.startswith("video") or "-" in e:
                continue   # 排除 video-camera0 / v4l-subdev 等
            try:
                name = open("/sys/class/video4linux/%s/name" % e).read().strip()
            except Exception:
                name = ""
            all_devs.append((e, "/dev/%s" % e, name))
    except Exception:
        pass

    active = _active_media_set()
    dev_to_media = {d: m for m, devs in _media_devices_map().items() for d in devs}

    devices = []
    for e, path, name in all_devs:
        u = is_uvc(e, name)
        if not (ALLOW_RE.match(name) or u):
            continue
        # 双路去重: 仅对 RK 系(CIF/ISP/VPSS)设备做 media 归属校验; UVC 直接保留
        if active is not None and not u:
            media = dev_to_media.get(path)
            if media is None or media not in active:
                continue
        devices.append({"value": path, "label": "%s · %s" % (path, name or "video device")})
    return devices


def list_drm_connectors():
    """/sys/class/drm 解析 connector (名称/状态/模式) + modetest 获取 connector id"""
    conns = []
    ids = set()
    try:
        for entry in sorted(os.listdir("/sys/class/drm")):
            if not entry.startswith("card"):
                continue
            sfile = "/sys/class/drm/%s/status" % entry
            if not os.path.exists(sfile):
                continue
            st = open(sfile).read().strip()
            modes = []
            mfile = "/sys/class/drm/%s/modes" % entry
            if os.path.exists(mfile):
                modes = open(mfile).read().splitlines()
            conn = entry.split("-", 1)[1] if "-" in entry else entry
            conns.append({"value": conn,
                          "status": st,
                          "all_modes": modes,
                          "label": "%s · %s · %s" % (conn, st, modes[0] if modes else "无模式")})
    except Exception:
        pass
    # 通过 modetest -c 获取 connector id (若可用)
    code, out, _ = run_cmd(["modetest", "-c"], timeout=10)
    if code == 0:
        for ln in out.splitlines():
            m = re.match(r"^\s*(\d+)\s+\d+\s+(?:connected|disconnected|unknown)\s+", ln)
            if m:
                ids.add(int(m.group(1)))
    drm_ids = [{"value": "-1", "label": "-1 (自动)"}]
    for i in sorted(ids):
        drm_ids.append({"value": str(i), "label": "connector id %d" % i})
    # 完整枚举 connected connector 的所有可用模式 (供 DISPLAY_RES 下拉):
    # 剔除隔行/逐行后缀(如 1920x1080i -> 1920x1080)并去重, 保证为 capture.pl 可解析的 WxH
    def _area(m):
        try:
            w, h = m["value"].split("x")
            return int(w) * int(h)
        except Exception:
            return 0
    modes = []
    seen = set()
    for c in conns:
        if c.get("status") != "connected":
            continue
        for mode in c.get("all_modes", []):
            m2 = re.sub(r"[iIpP]\s*$", "", mode).strip()
            if "x" not in m2 or m2 in seen:
                continue
            seen.add(m2)
            modes.append({"value": m2, "label": m2})
    modes.sort(key=_area, reverse=True)
    return {"connectors": conns, "drm_ids": drm_ids, "modes": modes}


def list_chinese_fonts():
    """fc-list 中文字体文件路径"""
    fonts = []
    code, out, _ = run_cmd(["fc-list", ":lang=zh", "file"], timeout=10)
    seen = set()
    for ln in out.splitlines():
        ln = ln.strip()
        if not ln.startswith("/"):
            continue
        path = ln.split(":", 1)[0].strip()
        if path and path not in seen:
            seen.add(path)
            fonts.append({"value": path, "label": path})
    return fonts


def list_pango_fonts():
    """fc-list 中文字体家族名 (pango font-desc 用)"""
    fonts = []
    code, out, _ = run_cmd(["fc-list", ":lang=zh", "family"], timeout=10)
    seen = set()
    for part in out.replace(",", "\n").splitlines():
        fam = part.strip()
        if fam and fam not in seen:
            seen.add(fam)
            fonts.append({"value": fam, "label": fam})
    return fonts


def list_fps_formats(cfg=None, size=None, dev=None):
    """按当前采集设备+分辨率枚举真实帧率 (capture-enum.pl).
    ISP: 帧率由 3A 控制, 只读, 实测当前帧率; 非 ISP: 按分辨率枚举"""
    if cfg is None:
        cfg = load_config()
    dev = dev or cfg.get("FFMPEG_CAM_DEV", "/dev/video24")
    src = _enum_json("--detect-type", dev)
    stype = (src or {}).get("type", "generic")
    readonly = (stype == "isp")

    if readonly:
        af = _enum_json("--actual-fps", dev)
        fps = int((af or {}).get("fps", 0) or 0)
        items = [{"value": str(fps), "label": "%d fps (3A 控制, 只读)" % fps}]
    else:
        args = ["--source-fps", dev]
        if size:
            args += ["--size", size]
        d = _enum_json(*args)
        items = []
        if d and d.get("fps"):
            for f in d["fps"]:
                if f.get("supported"):
                    items.append({"value": str(f["fps"]), "label": "%d fps" % f["fps"]})
        if not items:
            for v in (30, 25, 60, 15):
                items.append({"value": str(v), "label": "%d fps" % v})
    return {"fps": items, "readonly": readonly, "type": stype}


def list_capture_res(dev=None):
    """按当前采集设备枚举可用分辨率; 原生项排前, 标准候选档兜底 (ISP 可缩放输出).

    注意: 不能用"枚举为空才用兜底"——capture-enum --source-res 通常能返回非空
    (如仅 3840x2160/1920x1080), 那样 2560x1440/3200x2000 等 ISP 可缩放输出的
    标准档就永远进不了下拉。改为: 原生+标准候选合并去重, 原生排前。
    """
    cfg = load_config()
    dev = dev or cfg.get("FFMPEG_CAM_DEV", "/dev/video24")
    d = _enum_json("--source-res", dev)
    native = [r for r in ((d or {}).get("res") or []) if r]

    # 该设备 sensor 原生上限 (来自枚举 max, 如 video24/sc850sl=3840x2160,
    # video32/sc450ai=2688x1520). 标准候选档必须能由该 sensor 下缩放输出,
    # 即宽高都不超过此上限 —— 否则 2K 设备会出现 4K/3200 等不可用档.
    max_w = max_h = 0
    if d and d.get("max") and re.match(r"^\d+x\d+$", str(d["max"])):
        try:
            max_w, max_h = (int(x) for x in str(d["max"]).split("x", 1))
        except ValueError:
            max_w = max_h = 0
    if not max_w and native:
        for r in native:
            a, b = r.split("x", 1)
            if b and int(a) * int(b) > max_w * max_h:
                max_w, max_h = int(a), int(b)

    base = ["3840x2160", "3200x2000", "3200x1800", "2560x1600", "2560x1440",
            "1920x1200", "1920x1080", "1600x1000", "1600x900",
            "1280x800", "1280x720", "1024x768", "960x528", "640x480",
            "480x800", "800x480"]

    seen = {}
    vals = []
    for r in (native + base):
        if not r:
            continue
        if max_w and max_h:
            try:
                a, b = r.split("x", 1)
                if int(a) > max_w or int(b) > max_h:
                    continue          # 超出该设备能力, 屏蔽
            except ValueError:
                continue
        if r not in seen:
            seen[r] = 1
            vals.append({"value": r, "label": r})

    # 排序规则: 大的分辨率(总像素面积)优先; 面积相近(相同)时宽高比更大(更宽)优先,
    # 再按宽度大优先 (竖屏如 480x800 因宽高比<1 自然排后)
    def _geom(v):
        a, b = (v["value"].split("x", 1) + ["0"])[:2]
        try:
            return (int(a) * int(b), (int(a) / int(b)) if int(b) else 0.0, int(a))
        except ValueError:
            return (0, 0.0, 0)
    vals.sort(key=_geom, reverse=True)
    return vals


def list_alsa():
    """枚举 ALSA 采集设备 (arecord -l) 与常用采样率"""
    devices = []
    code, out, _ = run_cmd(["arecord", "-l"], timeout=10)
    if code == 0:
        for ln in out.splitlines():
            m = re.match(r"card\s+(\d+):\s+\S+\s*\[.*?\],\s*device\s+(\d+):", ln)
            if m:
                card, dev = m.group(1), m.group(2)
                devices.append({"value": "hw:%s,%s" % (card, dev),
                                "label": "hw:%s,%s (card %s)" % (card, dev, card)})
    if not devices:
        devices.append({"value": "default", "label": "default"})
        devices.append({"value": "hw:0,0", "label": "hw:0,0"})
    return {
        "devices": devices,
        "rates": [{"value": "48000", "label": "48000 Hz"},
                  {"value": "44100", "label": "44100 Hz"},
                  {"value": "16000", "label": "16000 Hz"}],
    }


# ---------------------------------------------------------------------------
# capture-enum.pl 枚举 + HDR/iqfile 管理
# ---------------------------------------------------------------------------
def _enum_json(*args, timeout=15):
    """调用 capture-enum.pl 并解析 JSON"""
    try:
        r = subprocess.run([ENUM_PL] + list(args), capture_output=True, text=True, timeout=timeout)
        if r.returncode == 0 and r.stdout.strip():
            return json.loads(r.stdout)
    except Exception:
        pass
    return None


def wait_3a_ready(timeout=30):
    """等待 rkaiq_3A 服务就绪 (TCP 端口 4894)"""
    for _ in range(timeout):
        code, out, _ = run_cmd(["ss", "-tln"], timeout=5)
        if code == 0 and ":4894" in out:
            return True
        time.sleep(1)
    return False


def hdr_info(dev=None):
    """当前选中设备的 HDR/iqfile 状态 (ISP 及其下游 vpss 才显示 HDR)"""
    cfg = load_config()
    dev = dev or cfg.get("FFMPEG_CAM_DEV", "/dev/video24")
    src = _enum_json("--detect-type", dev)
    stype = (src or {}).get("type", "generic")
    if stype not in ("isp", "vpss"):
        return {"ok": True, "isp": False, "type": stype}
    d = _enum_json("--iqfile", dev)
    if not d or not d.get("iqfile"):
        return {"ok": False, "isp": True, "type": stype, "error": (d or {}).get("error", "iqfile 定位失败")}
    return {
        "ok": True, "isp": True, "type": stype,
        "sensor": d.get("sensor"), "iqfile": d.get("iqfile"),
        "exists": d.get("exists"), "hdr_en": d.get("hdr_en"),
        "hdr_mode": d.get("hdr_mode"),
    }


def hdr_status():
    """HDR 页激活状态: 是否存在 rkisp 设备 + 已激活 iqfile; 并枚举所有 sensor 的 HDR 信息"""
    has_rkisp = False
    try:
        for e in sorted(os.listdir("/sys/class/video4linux")):
            try:
                name = open("/sys/class/video4linux/%s/name" % e).read().strip()
            except Exception:
                name = ""
            if re.search(r'^rkisp_(mainpath|selfpath)$', name):
                has_rkisp = True
                break
    except Exception:
        pass
    d = _enum_json("--sensors") or {}
    sensors = d.get("sensors") or []
    active = has_rkisp and any(s.get("exists") for s in sensors)
    return {"active": active, "has_rkisp": has_rkisp, "sensors": sensors}


def hdr_set(value, dev=None, iqfile=None, reboot=True):
    """切换 HDR: 改 iqfile hdr_en; reboot=True 时延迟重启 OS (HDR 需重启 OS 才彻底生效)

    - 多 sensor 场景: 前端先以 reboot=False 逐个写入 iqfile, 最后统一重启一次
    - 传入 iqfile: 直接修改该 iqfile (每个 sensor 独立 iqfile); 仅传 dev: 由 dev 反查
    """
    if value not in (0, 1):
        return {"ok": False, "error": "hdr 值必须是 0 或 1"}

    # 1. 修改 iqfile hdr_en
    if iqfile:
        d = _enum_json("--set-hdr-path", iqfile, "--hdr-value", str(value), timeout=30)
    else:
        cfg = load_config()
        dev = dev or cfg.get("FFMPEG_CAM_DEV", "/dev/video24")
        d = _enum_json("--set-hdr", dev, "--hdr-value", str(value), timeout=30)
    if not d or not d.get("ok"):
        return {"ok": False, "error": "修改 iqfile 失败: %s" % ((d or {}).get("error", "unknown"))}

    # 2. 可选延迟 2 秒重启 OS (先返回 HTTP 响应, 再 reboot)
    if reboot:
        subprocess.Popen(["sh", "-c", "sleep 2; systemctl reboot"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    return {
        "ok": True,
        "hdr_en": d.get("hdr_en"),
        "hdr_mode": d.get("hdr_mode"),
        "iqfile": d.get("iqfile"),
        "backup": d.get("backup"),
        "rebooting": bool(reboot),
    }


# ---------------------------------------------------------------------------
# HTTP Handler
# ---------------------------------------------------------------------------
class Handler(BaseHTTPRequestHandler):
    # HTTP Server 头必须是 latin-1/ASCII, 不能用中文品牌名 (否则 UnicodeEncodeError)
    server_version = "CaptureConsole/%s" % VERSION

    # ---- 辅助 ----
    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"))

    def _send_text(self, code, text, ctype="text/plain; charset=utf-8"):
        self._send(code, text.encode("utf-8"), ctype)

    def _read_body(self):
        try:
            ln = int(self.headers.get("Content-Length", 0))
            if ln <= 0:
                return {}
            raw = self.rfile.read(ln)
            return json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            return {}

    def _auth_ok(self):
        # 从 Cookie 头取 session token
        cookie = self.headers.get("Cookie", "")
        tok = None
        for part in cookie.split(";"):
            part = part.strip()
            if part.startswith("capture_webui="):
                tok = part[len("capture_webui="):]
                break
        if not check_session(tok):
            return False
        return True

    # ---- 路由 ----
    def do_GET(self):
        u = urlparse(self.path)
        path = u.path

        if path == "/":
            if self._auth_ok():
                self._redirect("/index.html")
            else:
                self._send_file(HTML_PAGE) if os.path.exists(HTML_PAGE) else self._send_text(200, "HTML page missing", "text/html")
            return
        if path == "/index.html":
            if not self._auth_ok():
                self._send_text(401, "Unauthorized")
                return
            self._send_file(HTML_PAGE) if os.path.exists(HTML_PAGE) else self._send_text(200, "HTML page missing", "text/html")
            return
        if path == "/login.html":
            self._send_file(HTML_PAGE) if os.path.exists(HTML_PAGE) else self._send_text(200, "HTML page missing", "text/html")
            return
        if path == "/chart.min.js":
            if os.path.exists(CHART_JS_PATH):
                self._send_file(CHART_JS_PATH, "application/javascript; charset=utf-8")
            else:
                self._send_text(404, "chart.js not found", "text/plain")
            return

        # 品牌名 (公开接口, 供登录页/标题使用; 无需认证)
        if path == "/api/brand":
            self._send_json(200, {"brand": brand_name()})
            return

        # API (需认证)
        if path.startswith("/api/"):
            if not self._auth_ok():
                self._send_json(401, {"error": "unauthorized"})
                return
            if path == "/api/status":
                st = service_status()
                ps = capture_process_summary()
                self._send_json(200, {"service": st, "process": ps})
                return
            if path == "/api/config":
                self._send_json(200, {"schema": config_schema_payload()})
                return
            if path == "/api/devices":
                self._send_json(200, {"devices": _cached("devices", 10, list_video_devices)})
                return
            if path == "/api/drm":
                self._send_json(200, _cached("drm", 15, list_drm_connectors))
                return
            if path == "/api/fonts":
                self._send_json(200, {"fonts": _cached("fonts", 20, list_chinese_fonts),
                                      "pango": _cached("pango", 20, list_pango_fonts)})
                return
            if path == "/api/formats":
                qs = parse_qs(u.query)
                size = qs.get("size", [None])[0] or ""
                dev = qs.get("dev", [None])[0] or ""
                # ISP 只读帧率是实测(预热40帧+300帧≈8-10s), 缓存 20s 避免每次刷新/切换都重测
                self._send_json(200, _cached("fmt:%s:%s" % (dev, size), 20,
                                              lambda: list_fps_formats(size=size or None, dev=dev or None)))
                return
            if path == "/api/capture_res":
                qs = parse_qs(u.query)
                dev = qs.get("dev", [None])[0] or ""
                self._send_json(200, {"res": _cached("capres:%s" % dev, 12,
                                                     lambda: list_capture_res(dev=dev or None))})
                return
            if path == "/api/hdr/status":
                self._send_json(200, hdr_status())
                return
            if path == "/api/hdr":
                qs = parse_qs(u.query)
                dev = qs.get("dev", [None])[0]
                self._send_json(200, _cached("hdr:" + str(dev), 10,
                                              lambda: hdr_info(dev=dev)))
                return
            if path == "/api/alsa":
                self._send_json(200, _cached("alsa", 10, list_alsa))
                return
            if path == "/api/stats":
                self._send_json(200, stats_payload())
                return
            self._send_json(404, {"error": "not found"})
            return

        self._send_json(404, {"error": "not found"})

    def _send_file(self, fpath, ctype=None):
        try:
            with open(fpath, "rb") as f:
                data = f.read()
            if ctype is None:
                ctype = "text/html; charset=utf-8" if fpath.endswith(".html") else "application/octet-stream"
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            if fpath.endswith(".html"):
                # 前端页面每请求刷新, 避免浏览器缓存旧 JS 导致联动物理/屏蔽不生效
                self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
                self.send_header("Pragma", "no-cache")
                self.send_header("Expires", "0")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception:
            self._send_text(404, "not found")

    def _redirect(self, loc):
        self.send_response(302)
        self.send_header("Location", loc)
        self.end_headers()

    def do_POST(self):
        u = urlparse(self.path)
        path = u.path

        if path == "/api/login":
            body = self._read_body()
            pw = body.get("password", "")
            if verify_password(pw):
                tok = new_session()
                self.send_response(200)
                self.send_header("Set-Cookie", "capture_webui=%s; HttpOnly; Path=/" % tok)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(b'{"ok":true}')
            else:
                self._send_json(401, {"error": "密码错误"})
            return

        if path == "/api/logout":
            cookie = self.headers.get("Cookie", "")
            for part in cookie.split(";"):
                part = part.strip()
                if part.startswith("capture_webui="):
                    drop_session(part[len("capture_webui="):])
            self.send_response(200)
            self.send_header("Set-Cookie", "capture_webui=; Max-Age=0; Path=/")
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
            return

        # 以下 API 需认证
        if not self._auth_ok():
            self._send_json(401, {"error": "unauthorized"})
            return

        if path == "/api/service":
            body = self._read_body()
            action = body.get("action", "")
            if action in ("start", "stop", "restart", "enable", "disable"):
                self._send_json(200, service_action(action))
            else:
                self._send_json(400, {"error": "bad action"})
            return

        if path == "/api/hdr/set":
            body = self._read_body()
            value = body.get("value")
            if value not in (0, 1) and str(value) not in ("0", "1"):
                self._send_json(400, {"error": "bad hdr value"})
                return
            rb = body.get("reboot", True)
            if isinstance(rb, str):
                rb = rb.lower() not in ("0", "false", "no")
            self._send_json(200, hdr_set(int(value),
                                         dev=body.get("dev"),
                                         iqfile=body.get("iqfile"),
                                         reboot=bool(rb)))
            return

        if path == "/api/reboot":
            # 统一重启操作系统 (HDR 多 sensor 改完后一次性生效)
            subprocess.Popen(["sh", "-c", "sleep 2; systemctl reboot"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self._send_json(200, {"ok": True, "rebooting": True})
            return

        if path == "/api/config/save":
            body = self._read_body()
            cfg = body.get("config", {})
            if not isinstance(cfg, dict):
                self._send_json(400, {"error": "bad config"})
                return
            added = save_config(cfg)
            _cache_clear()
            _start_warmup()
            self._send_json(200, {"ok": True, "added": added})
            return

        if path == "/api/config/apply":
            body = self._read_body()
            cfg = body.get("config", {})
            if not isinstance(cfg, dict):
                self._send_json(400, {"error": "bad config"})
                return
            added = save_config(cfg)
            res = service_action("restart")
            _cache_clear()
            _start_warmup()
            self._send_json(200, {"ok": res["ok"], "added": added, "restart": res})
            return

        if path == "/api/config/restore":
            ok, msg = restore_default_config()
            _cache_clear()
            _start_warmup()
            self._send_json(200, {"ok": ok, "msg": msg})
            return

        self._send_json(404, {"error": "not found"})


# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="%s采集管理控制台 (Capture Console)" % brand_name())
    ap.add_argument("--port", type=int, default=80, help="监听端口 (默认 80)")
    ap.add_argument("--bind", default="0.0.0.0", help="监听地址 (默认 0.0.0.0)")
    args = ap.parse_args()

    ensure_default_config()   # 首次启动: 备份当前配置为默认配置
    _start_warmup()           # 后台预热动态枚举, 首次打开页面基本即时

    server = ThreadingHTTPServer((args.bind, args.port), Handler)

    def _stop(sig, frm):
        server.shutdown()

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    print("capture-webui listening on %s:%d" % (args.bind, args.port), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
