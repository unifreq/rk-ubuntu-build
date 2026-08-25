#!/usr/bin/perl
#
# capture.pl - Rockchip RV1126B 摄像头采集与显示管线
#
# 版本:  v3.2.0
# 作者:  flippy <flippy@sina.com>
# 许可:  GPL v2 (GNU General Public License version 2)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#
use strict;
use constant VERSION => 'v3.2.0';
use constant AUTHOR  => 'flippy <flippy@sina.com>';
use constant LICENSE => 'GPL v2';
use warnings;
use POSIX qw(setsid);
use Getopt::Long;
use JSON::PP;

use constant ENUM_PL => "/usr/local/bin/capture-enum.pl";

$Getopt::Long::ignorecase = 0;

my %opt = (
    version              => 0,
    stop                 => 0,
    restart              => 0,
    status               => 0,
    help                 => 0,
    config               => "/etc/capture.conf",
    lockfile             => "/tmp/run_vpss_isp.lock",
    display_enable       => undef,
    stream_enable        => undef,
    restart_3a           => undef,
    wait_3a              => undef,
    gst_cam_dev          => undef,
    ffmpeg_cam_dev       => undef,
    display_res          => undef,
    display_rotate       => undef,
    display_connector_id => undef,
    display_connector_name => undef,
    capture_res          => undef,
    capture_fps          => undef,
    stream_fps           => undef,
    encoder_codec        => undef,
    encoder_bitrate      => undef,
    encoder_gop          => undef,
    encoder_extra        => undef,
    encoder_rc_mode      => undef,
    rtsp_url             => undef,
    force_modesetting    => undef,
    audio_enable         => undef,
    audio_device         => undef,
    audio_bitrate        => undef,
    audio_samplerate     => undef,
    audio_channels       => undef,
    osd_enable           => undef,
    osd_text             => undef,
    osd_font             => undef,
    osd_timestamp        => undef,
    osd_timestamp_format => undef,
    osd_fontsize         => undef,
    display_osd_enable         => undef,
    display_osd_text           => undef,
    display_osd_timestamp      => undef,
    display_osd_timestamp_format => undef,
    display_osd_fontsize       => undef,
    display_osd_font           => undef,
);

GetOptions(
    'version'             => \$opt{version},
    'stop'                => \$opt{stop},
    'restart'             => \$opt{restart},
    'status'              => \$opt{status},
    'help'                => \$opt{help},
    'config=s'            => \$opt{config},
    'lockfile=s'          => \$opt{lockfile},
    'display-enable!'     => \$opt{display_enable},
    'stream-enable!'      => \$opt{stream_enable},
    'restart-3a!'         => \$opt{restart_3a},
    'wait-3a!'            => \$opt{wait_3a},
    'gst-cam-dev=s'       => \$opt{gst_cam_dev},
    'ffmpeg-cam-dev=s'    => \$opt{ffmpeg_cam_dev},
    'display-res=s'       => \$opt{display_res},
    'display-rotate=s'    => \$opt{display_rotate},
    'display-connector-id=i'   => \$opt{display_connector_id},
    'display-connector-name=s' => \$opt{display_connector_name},
    'capture-res=s'       => \$opt{capture_res},
    'capture-fps=i'       => \$opt{capture_fps},
    'stream-fps=s'        => \$opt{stream_fps},
    'encoder-codec=s'     => \$opt{encoder_codec},
    'encoder-bitrate=s'   => \$opt{encoder_bitrate},
    'encoder-gop=s'       => \$opt{encoder_gop},
    'encoder-extra=s'     => \$opt{encoder_extra},
    'encoder-rc-mode=s'   => \$opt{encoder_rc_mode},
    'rtsp-url=s'          => \$opt{rtsp_url},
    'force-modesetting=s' => \$opt{force_modesetting},
    'audio-enable!'       => \$opt{audio_enable},
    'audio-device=s'      => \$opt{audio_device},
    'audio-bitrate=s'     => \$opt{audio_bitrate},
    'audio-samplerate=i'  => \$opt{audio_samplerate},
    'audio-channels=i'    => \$opt{audio_channels},
    'osd-enable!'         => \$opt{osd_enable},
    'osd-text=s'          => \$opt{osd_text},
    'osd-font=s'          => \$opt{osd_font},
    'osd-timestamp!'      => \$opt{osd_timestamp},
    'osd-timestamp-format=s' => \$opt{osd_timestamp_format},
    'osd-fontsize=i'     => \$opt{osd_fontsize},
    'display-osd-enable!' => \$opt{display_osd_enable},
    'display-osd-text=s'  => \$opt{display_osd_text},
    'display-osd-timestamp!' => \$opt{display_osd_timestamp},
    'display-osd-timestamp-format=s' => \$opt{display_osd_timestamp_format},
    'display-osd-fontsize=i' => \$opt{display_osd_fontsize},
    'display-osd-font=s'     => \$opt{display_osd_font},
) or die "用法: $0 [选项]\n使用 --help 查看帮助\n";

if ($opt{version}) {
    print "capture.pl " . VERSION . "\n作者: " . AUTHOR . "\n许可: " . LICENSE . "\n";
    exit 0;
}

if ($opt{help}) {
    print << "USAGE";
用法: $0 [选项]
选项:
  --help, --version                 帮助/版本
  --stop, --restart, --status
  --config=FILE, --lockfile=FILE
  --display-enable / --no-display-enable
  --stream-enable / --no-stream-enable
  --restart-3a / --no-restart-3a   启动前重启 3A 算法服务
  --wait-3a / --no-wait-3a         等待 3A 就绪 (默认开启)

设备节点:
  --gst-cam-dev=PATH               本地显示路径 (selfpath, 默认 /dev/video25)
  --ffmpeg-cam-dev=PATH            推流路径 (mainpath, 默认 /dev/video24)

显示参数:
  --display-res=WxH --display-rotate=ANGLE
  --display-connector-id=NUM       DRM connector ID (优先级高于名称)
  --display-connector-name=NAME    DRM connector 名称 (如 DSI-1)

采集参数:
  --capture-res=WxH --capture-fps=NUM
  --stream-fps=FPS                 输出帧率(滤镜 -vf fps 前置统一, 不再用 -r):
                                  auto=跟随采集; 升档=采集帧率整数倍(≤120), 降档=折半链 ÷2/÷4/÷8

编码参数:
  --encoder-codec=CODEC            h264_rkmpp / hevc_rkmpp
  --encoder-bitrate=BITRATE        目标码率 (如 8M, 12M, 16M)
  --encoder-gop=GOP                auto=2倍帧率, 或固定值 (如 60, 120)
  --encoder-extra=EXTRA            高级自定义参数, 追加末尾并覆盖自动值
  --encoder-rc-mode=RC             CBR/VBR/AVBR (默认 CBR, 防马赛克)
  自动计算: VBR->minrate 50% / maxrate 150% / bufsize 2*max;
            AVBR->maxrate 150% / bufsize 2*max; level/QP 按分辨率与码率自动推导

音频参数:
  --audio-enable / --no-audio-enable   启用/关闭麦克风推流 (默认开启)
  --audio-device=DEVICE                ALSA 设备 (默认 default)
  --audio-samplerate=NUM               采样率 (默认 48000)
  --audio-channels=NUM                 声道数 (默认 1)
  --audio-bitrate=BITRATE              AAC 码率 (默认 128k)

OSD 文字参数 (推流):
  --osd-enable / --no-osd-enable       启用/关闭推流文字叠加 (默认开启)
  --osd-text=TEXT                       左上角固定文字 (默认 小宇智联)
  --osd-font=FILE                       中文字体文件路径 (drawtext 用)
  --osd-timestamp / --no-osd-timestamp  右上角时间戳开关 (默认开启)
  --osd-timestamp-format=FORMAT         strftime 格式 (默认 %Y年%m月%d日 %H：%M：%S, 用全角冒号)
  --osd-fontsize=NUM                    推流字号 (0=自动, 默认 0)

本地显示 OSD 参数 (独立, 与推流互不相干):
  --display-osd-enable / --no-display-osd-enable   启用/关闭本地显示文字叠加 (默认开启)
  --display-osd-text=TEXT                           本地显示固定文字 (默认 小宇智联)
  --display-osd-timestamp / --no-display-osd-timestamp  本地显示时间戳开关 (默认开启)
  --display-osd-timestamp-format=FORMAT             本地显示时间戳格式
  --display-osd-fontsize=NUM                        本地显示字号 (0=自动, 默认 0)
  --display-osd-font=FONT                           本地显示字体 (pango 字体名, 默认 Sans)
  本地显示 OSD 用 clockoverlay+textoverlay, 叠加在旋转前画面并随主画面一起旋转

其他:
  --rtsp-url=URL --force-modesetting=VAL   (VAL: true/false)
USAGE
    exit 0;
}

# ==============================================================================
# load_config
# ==============================================================================

sub load_config {
    my ($file, $cmdline) = @_;

    my %cfg = (
        GST_CAM_DEV          => "/dev/video25",
        FFMPEG_CAM_DEV       => "/dev/video24",
        DISPLAY_ENABLE       => 1,
        STREAM_ENABLE        => 1,
        RESTART_3A           => 0,
        WAIT_3A              => 1,
        DISPLAY_RES          => "480x800",
        DISPLAY_ROTATE       => "270",
        DISPLAY_CONNECTOR_ID => -1,
        DISPLAY_CONNECTOR_NAME => "",
        CAPTURE_RES          => "2560x1440",
        CAPTURE_FPS          => 30,
        STREAM_FPS           => "auto",
        ENCODER_CODEC        => "h264_rkmpp",
        ENCODER_BITRATE      => "16M",
        ENCODER_GOP          => "60",
        ENCODER_EXTRA        => "",
        ENCODER_RC_MODE      => "CBR",
        RTSP_URL             => "rtsp://127.0.0.1:8554/live/0",
        FORCE_MODESETTING    => "false",
        AUDIO_ENABLE         => 1,
        AUDIO_DEVICE         => "default",
        AUDIO_SAMPLERATE     => 48000,
        AUDIO_CHANNELS       => 1,
        AUDIO_BITRATE        => "128k",
        OSD_ENABLE           => 1,
        OSD_FONT             => "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        OSD_TEXT             => "小宇智联",
        OSD_TIMESTAMP        => 1,
        OSD_TIMESTAMP_FORMAT => "%Y年%m月%d日 %H：%M：%S",
        OSD_FONTSIZE         => 0,
        DISPLAY_OSD_ENABLE         => 1,
        DISPLAY_OSD_TEXT           => "小宇智联",
        DISPLAY_OSD_TIMESTAMP      => 1,
        DISPLAY_OSD_TIMESTAMP_FORMAT => "%Y年%m月%d日 %H：%M：%S",
        DISPLAY_OSD_FONTSIZE       => 0,
        DISPLAY_OSD_FONT           => "Sans",
);

    my %is_num  = map { $_ => 1 } qw(CAPTURE_FPS DISPLAY_CONNECTOR_ID AUDIO_SAMPLERATE AUDIO_CHANNELS DISPLAY_OSD_FONTSIZE OSD_FONTSIZE);
    my %is_bool = map { $_ => 1 } qw(DISPLAY_ENABLE STREAM_ENABLE RESTART_3A WAIT_3A AUDIO_ENABLE OSD_ENABLE OSD_TIMESTAMP DISPLAY_OSD_ENABLE DISPLAY_OSD_TIMESTAMP);

    if (-f $file) {
        open my $fh, '<', $file or die "无法打开 $file: $!";

        while (<$fh>) {
            chomp;
            next if /^\s*#/ || /^\s*$/;

            if (/^\s*(\w+)\s*=\s*"([^"]*)"\s*$/) {
                my ($k, $v) = ($1, $2);
                if (exists $cfg{$k}) {
                    $cfg{$k} = $is_bool{$k} ? ($v =~ /^(?:true|1|yes)$/i ? 1 : 0) : $is_num{$k} ? $v + 0 : $v;
                }
            } elsif (/^\s*(\w+)\s*=\s*(\S+)\s*$/) {
                my ($k, $v) = ($1, $2);
                if (exists $cfg{$k}) {
                    $cfg{$k} = $is_bool{$k} ? ($v =~ /^(?:true|1|yes)$/i ? 1 : 0) : $is_num{$k} ? $v + 0 : $v;
                }
            }
        }

        close $fh;
        print "ℹ️ 配置文件: $file\n";
    } else {
        print "⚠️ 无配置文件，使用内置默认值\n";
    }

    my %cli_map = (
        display_enable        => 'DISPLAY_ENABLE',
        stream_enable         => 'STREAM_ENABLE',
        restart_3a            => 'RESTART_3A',
        wait_3a               => 'WAIT_3A',
        gst_cam_dev           => 'GST_CAM_DEV',
        ffmpeg_cam_dev        => 'FFMPEG_CAM_DEV',
        display_res           => 'DISPLAY_RES',
        display_rotate        => 'DISPLAY_ROTATE',
        display_connector_id  => 'DISPLAY_CONNECTOR_ID',
        display_connector_name => 'DISPLAY_CONNECTOR_NAME',
        capture_res           => 'CAPTURE_RES',
        capture_fps           => 'CAPTURE_FPS',
        stream_fps            => 'STREAM_FPS',
        encoder_codec         => 'ENCODER_CODEC',
        encoder_bitrate       => 'ENCODER_BITRATE',
        encoder_gop           => 'ENCODER_GOP',
        encoder_extra         => 'ENCODER_EXTRA',
        encoder_rc_mode       => 'ENCODER_RC_MODE',
        rtsp_url              => 'RTSP_URL',
        force_modesetting     => 'FORCE_MODESETTING',
        audio_enable          => 'AUDIO_ENABLE',
        audio_device          => 'AUDIO_DEVICE',
        audio_samplerate      => 'AUDIO_SAMPLERATE',
        audio_channels        => 'AUDIO_CHANNELS',
        audio_bitrate         => 'AUDIO_BITRATE',
        osd_enable            => 'OSD_ENABLE',
        osd_text              => 'OSD_TEXT',
        osd_font              => 'OSD_FONT',
        osd_timestamp         => 'OSD_TIMESTAMP',
        osd_timestamp_format  => 'OSD_TIMESTAMP_FORMAT',
        osd_fontsize          => 'OSD_FONTSIZE',
        display_osd_enable    => 'DISPLAY_OSD_ENABLE',
        display_osd_text      => 'DISPLAY_OSD_TEXT',
        display_osd_timestamp => 'DISPLAY_OSD_TIMESTAMP',
        display_osd_timestamp_format => 'DISPLAY_OSD_TIMESTAMP_FORMAT',
        display_osd_fontsize  => 'DISPLAY_OSD_FONTSIZE',
        display_osd_font      => 'DISPLAY_OSD_FONT',
    );

    foreach my $ck (keys %$cmdline) {
        next unless exists $cli_map{$ck};
        my $cfg_k = $cli_map{$ck};
        my $v     = $cmdline->{$ck};
        next unless defined $v;

        $cfg{$cfg_k} = $is_bool{$cfg_k} ? ($v ? 1 : 0) : ($is_num{$cfg_k} ? $v + 0 : $v);

        my $display = $v;
        $display = '"' . $v . '"' if $v ne '' && !$is_num{$cfg_k};
        print "🔧 CLI覆盖: ${cfg_k}=$display\n";
    }

    return %cfg;
}

# 解析 "WxH" 分辨率字符串 -> (w, h); 失败返回空列表
sub parse_res {
    my ($res) = @_;
    return unless defined $res && $res =~ /^\s*(\d+)\s*[xX*]\s*(\d+)\s*$/;
    return ($1 + 0, $2 + 0);
}

# 调用 capture-enum.pl 并解析 JSON (失败返回 undef)
sub enum_json {
    my (@args) = @_;
    my $out = `@{[ENUM_PL]} @args 2>/dev/null`;
    return undef unless defined $out && $out ne "";
    my $j = eval { JSON::PP->new->decode($out) };
    return $j;
}

# 源类型识别 (isp/cif/uvc/hdmi_in/...)
sub detect_source_type {
    my ($dev) = @_;
    my $j = enum_json("--detect-type", $dev);
    return $j ? ($j->{type} || "generic") : "generic";
}

# 实测当前帧率 (capture-enum.pl --actual-fps; frames 可选, 高帧率模式切换后需较长抓帧)
sub actual_fps {
    my ($dev, $frames) = @_;
    my $j = ($frames && $frames > 0)
        ? enum_json("--actual-fps", $dev, "--frames", $frames)
        : enum_json("--actual-fps", $dev);
    return $j && $j->{fps} ? $j->{fps} + 0 : 0;
}

sub build_pattern {
    my ($b, $d) = @_;
    return "${b}.*" . quotemeta($d);
}

sub proc_find {
    my ($pat) = @_;
    my @pids;
    opendir my $dh, '/proc' or return @pids;

    while (my $pid = readdir $dh) {
        next unless $pid =~ /^\d+$/;
        my $f = "/proc/$pid/cmdline";
        next unless -r $f;
        open my $fh, '<', $f or next;
        my $cmd = <$fh>;
        close $fh;
        next unless defined $cmd;
        $cmd =~ s/\0/ /g;
        push @pids, $pid + 0 if $cmd =~ /$pat/;
    }

    closedir $dh;
    return @pids;
}

sub proc_kill_match {
    my ($sig, $pat) = @_;
    my @pids = proc_find($pat);
    my $cnt  = @pids ? kill($sig, @pids) : 0;
    return $cnt;
}

sub proc_spawn {
    my ($cmd, $errf) = @_;
    my $pid = fork();

    if ($pid == 0) {
        setsid();
        open STDOUT, '>/dev/null';
        if (defined $errf) {
            open STDERR, '>', $errf;
        } else {
            open STDERR, '>&STDOUT';
        }
        exec $cmd;
        exit 1;
    }

    return $pid;
}

sub proc_alive {
    my ($pid) = @_;
    return 0 unless defined $pid;
    waitpid($pid, 1);
    return kill(0, $pid);
}

sub display_calc_rotate {
    my ($pw, $ph, $rot) = @_;
    my ($vw, $vh) = ($pw, $ph);
    my ($flip, $dir) = ("", "");
    my $swap = 0;

    if    ($rot eq "90")  { $dir = "90r";  $swap = 1; }
    elsif ($rot eq "180") { $dir = "180"; }
    elsif ($rot eq "270") { $dir = "90l";  $swap = 1; }
    else                  { $dir = "identity"; }

    if ($swap) {
        print "📱 轴向旋转 (${pw}x${ph}) -> GST: [${dir}]\n";
        ($vw, $vh) = ($ph, $pw);
        $flip = "! videoflip video-direction=${dir} ! video/x-raw,format=NV12";
    } elsif ($dir eq "180") {
        print "🙃 180度翻转\n";
        $flip = "! videoflip video-direction=180 ! video/x-raw,format=NV12";
    } else {
        print "🖥️ 横屏直通\n";
    }

    return ($vw, $vh, $flip, $dir);
}

sub cpu_boost_temporary {
    my (@e, @s);
    opendir my $dh, '/sys/devices/system/cpu/cpufreq' or return;

    while (my $en = readdir $dh) {
        next unless $en =~ /^policy/;
        my $f = "/sys/devices/system/cpu/cpufreq/$en/scaling_governor";
        next unless -f $f;

        open my $fh, '<', $f or next;
        my $cur = <$fh>;
        chomp $cur;
        close $fh;

        open my $fw, '>', $f or next;
        print $fw "performance";
        close $fw;

        push @e, $f;
        push @s, $cur;
    }

    closedir $dh;
    return unless @e;

    defined(my $ch = fork()) or die "fork: $!";

    if ($ch == 0) {
        $SIG{INT} = 'IGNORE';
        sleep 30;
        for my $i (0 .. $#e) {
            open my $fr, '>', $e[$i] or next;
            print $fr $s[$i];
            close $fr;
        }
        exit 0;
    }
}

sub gst_display_start {
    my ($cmd, $max, $int) = @_;
    $max //= 5;
    $int //= 2;

    my $pid;
    my $start = sub { $pid = proc_spawn($cmd); };

    $start->();

    for my $try (1 .. $max) {
        sleep $int;
        waitpid($pid, 1);

        if (proc_alive($pid)) {
            print "✅ 本地显示已启动 (PID: $pid)\n";
            return ($pid, 1);
        }

        if ($try < $max) {
            print "⚠️ 第${try}/${max}次重试...\n";
            $start->();
        } else {
            print "❌ 本地显示启动失败\n";
        }
    }

    return ($pid, 0);
}

sub wait_display_stable {
    my ($timeout) = @_;
    $timeout //= 10;

    my $dri_dir = "/sys/kernel/debug/dri";
    my $card    = -1;

    opendir my $dh, $dri_dir or do {
        print "⚠️ DRM debugfs 不可用, 等待1秒\n";
        sleep 1;
        return 1;
    };

    while (my $d = readdir $dh) {
        next unless $d =~ /^\d+$/;
        if (-f "${dri_dir}/${d}/clients") {
            my $c = `cat ${dri_dir}/${d}/clients 2>/dev/null`;
            if ($c =~ /gst-launch/i) {
                $card = $d;
                last;
            }
        }
    }

    closedir $dh;

    if ($card < 0) {
        print "⚠️ 未找到 gst-launch 连接的 DRM 设备, 等待1秒\n";
        sleep 1;
        return 1;
    }

    my $state_file = "${dri_dir}/${card}/state";
    print "⏳ 等待本地显示输出稳定 (dri/${card})...\n";

    for my $i (1 .. $timeout) {
        my $state = `cat $state_file 2>/dev/null`;
        next unless defined $state;

        # DRM state 格式 (已在实际设备上验证):
        # plane[74]: VOP0-win0-0
        #         crtc=crtc-0
        #         fb=97
        #                 allocated by = queue0:src
        #                 format=NV12
        # 按 plane[ 分割成独立 plane 块, 查找非 fbcon 且 fb>0 的 plane
        my @planes = split(/\n(?=plane\[)/, $state);

        for (@planes) {
            my ($fb)    = /fb=(\d+)/;
            my ($alloc) = /allocated by\s*=\s*(\S+)/;

            # 跳过控制台 plane ([fbcon]), 只找视频输出 plane
            if ($fb && $fb > 0 && $alloc && $alloc !~ /^\[.*\]$/) {
                print "✅ 本地显示已稳定 (${i}s)\n";
                return 1;
            }
        }

        sleep 1;
    }

    print "⚠️ 本地显示未在 ${timeout} 秒内稳定\n";
    return 0;
}

sub detect_displays {
    my @displays;

    opendir my $dh, "/sys/class/drm" or return \@displays;
    my @entries = readdir($dh);
    closedir $dh;

    for my $entry (sort @entries) {
        next unless $entry =~ /^card\d+-(\S+)$/;
        my $conn = $1;
        my $base = "/sys/class/drm/$entry";

        my $sfile = "$base/status";
        next unless -f $sfile;
        my $status = `cat $sfile 2>/dev/null`;
        chomp $status if defined $status;

        my @modes;
        my $mfile = "$base/modes";

        if (-f $mfile) {
            open my $mfh, '<', $mfile or next;
            while (my $m = <$mfh>) {
                chomp $m;
                push @modes, $m if $m;
            }
            close $mfh;
        }

        push @displays, {
            name      => $conn,
            status    => $status // 'unknown',
            modes     => \@modes,
            connected => ($status && $status eq 'connected') ? 1 : 0,
        };
    }

    return \@displays;
}

sub resolve_display_connector {
    my ($displays_ref, $target_w, $target_h, $cfg_id, $cfg_name) = @_;
    my @displays  = @$displays_ref;
    my @connected = grep { $_->{connected} } @displays;

    unless (@connected) {
        print "🖥️ 未发现已连接的显示设备\n";
        return undef;
    }

    my $conn_str = join(', ', map { $_->{name} } @connected);
    print "🖥️ 发现已连接设备: ${conn_str}\n";

    # connector-id 优先: 不本地验证, 直接传 kmssink
    if (defined $cfg_id && $cfg_id >= 0) {
        print "📌 使用配置的 connector-id=${cfg_id} (由 kmssink 验证)\n";
        return undef;
    }

    # connector-name 次之
    if ($cfg_name && $cfg_name ne '') {
        my @match = grep { lc($_->{name}) eq lc($cfg_name) } @displays;
        if (@match && $match[0]->{connected}) {
            print "✅ 按名称选择: ${cfg_name}\n";
            return $match[0];
        }
        print "⚠️ 指定的 connector-name '${cfg_name}' 未连接或不存在, 回退自动选择\n";
    }

    # 按面积差异匹配分辨率
    my $match_res = sub {
        my ($modes, $tw, $th) = @_;
        return undef unless @$modes;

        my $target_area = $tw * $th;
        my $best        = undef;
        my $best_diff   = -1;

        for my $m (@$modes) {
            my ($mw, $mh) = $m =~ /^(\d+)x(\d+)$/;
            next unless $mw && $mh;

            my $diff = abs($mw * $mh - $target_area);

            if ($mw == $tw && $mh == $th) {
                return { mode => $m, w => $mw, h => $mh, exact => 1 };
            }

            if ($best_diff < 0 || $diff < $best_diff) {
                $best_diff = $diff;
                $best = { mode => $m, w => $mw, h => $mh, exact => 0, diff => $diff };
            }
        }

        return $best;
    };

    # 优先选完美匹配分辨率的, 否则选最接近的
    my $selected  = undef;
    my $best_diff = -1;

    for my $c (@connected) {
        my $match = $match_res->($c->{modes}, $target_w, $target_h);
        next unless $match;

        if ($match->{exact}) {
            $selected = $c;
            $c->{match} = $match;
            last;
        }

        if (!defined $selected || $match->{diff} < $best_diff) {
            $selected = $c;
            $c->{match}  = $match;
            $best_diff   = $match->{diff};
        }
    }

    unless ($selected) {
        $selected = $connected[0];
        $selected->{match} //= undef;
    }

    my $sname = $selected->{name};

    if ($selected->{match} && $selected->{match}->{exact}) {
        print "✅ 选择 ${sname}: 完美匹配 ${target_w}x${target_h}\n";
    } elsif ($selected->{match}) {
        my $smode = $selected->{match}->{mode};
        my $sdiff = $selected->{match}->{diff};
        print "✅ 选择 ${sname}: 最近似匹配 ${smode} (差异 ${sdiff})\n";
    } else {
        print "✅ 选择 ${sname} (无分辨率信息)\n";
    }

    return $selected;
}

# 自动读取当前显示刷新率 (Hz): 从 capture-enum.pl --drm (modetest) 取 connected connector 首个模式的刷新率
# 返回整数 Hz, 失败返回 0 (调用方据此决定是否限流)
sub display_refresh_hz {
    my ($cfg_id, $cfg_name) = @_;
    my $j = enum_json("--drm");
    return 0 unless $j && $j->{connectors};
    my @conn = grep { ($_->{status} // "") eq "connected" } @{ $j->{connectors} };
    return 0 unless @conn;
    my $sel;
    if (defined $cfg_id && $cfg_id >= 0) {
        ($sel) = grep { ($_->{id} // -1) == $cfg_id } @conn;
    }
    if (!$sel && $cfg_name && $cfg_name ne "") {
        ($sel) = grep { lc($_->{name} // "") eq lc($cfg_name) } @conn;
    }
    $sel //= $conn[0];
    my @modes = @{ $sel->{modes} || [] };
    return 0 unless @modes;
    my $refresh = $modes[0]->{refresh};
    return 0 unless defined $refresh && $refresh > 0;
    my $fps = int($refresh + 0.5);
    return $fps > 0 ? $fps : 0;
}

# ------------------------------------------------------------------------------
# 编码参数自动计算辅助子程序
# ------------------------------------------------------------------------------

# 解析目标码率字符串 -> kbps 数值 (如 "16M"->16000, "8000K"->8000, "8000"->8000)
sub parse_bitrate {
    my ($br) = @_;
    if ($br =~ /^(\d+)\s*([KkMm])$/) {
        my ($v, $u) = ($1, uc($2));
        return ($u eq "M") ? $v * 1000 : $v;
    }
    return $br + 0;   # 纯数字默认 Kbps
}

# kbps 数值格式化为可读单位 (整 M 用 M, 否则用 K)
sub fmt_kbps {
    my ($kbps) = @_;
    $kbps = int($kbps + 0.5);
    return ($kbps % 1000 == 0 && $kbps >= 1000) ? int($kbps / 1000) . "M" : "${kbps}K";
}

# H.264 level 按分辨率自动推导
sub h264_auto_level {
    my ($w, $h) = @_;
    return "4.0" if $w <= 1280 && $h <= 720;
    return "4.2" if $w <= 1920 && $h <= 1088;
    return "5.0" if $w <= 2560 && $h <= 1440;
    return "5.1";
}

# HEVC level 按分辨率自动推导
sub hevc_auto_level {
    my ($w, $h) = @_;
    return "4.1" if $w <= 1920 && $h <= 1080;
    return "5.0" if $w <= 2560 && $h <= 1440;
    return "5.1";
}

# QP 参数按目标码率档位自动推导 (防马赛克: qp_max 越小越防块效应)
sub auto_qp {
    my ($kbps) = @_;
    return (22, 10, 30) if $kbps >= 12000;   # 高质量档
    return (24, 10, 33) if $kbps >= 6000;    # 中高质量档
    return (26, 12, 36) if $kbps >= 3000;    # 标准档
    return (28, 14, 40);                      # 低码率档
}

sub encoder_build_params {
    my ($codec, $bitrate, $gop, $extra, $fps, $rcmode, $w, $h) = @_;

    # 码率模式归一化 (CBR/VBR/AVBR), 默认 CBR (防马赛克最稳)
    $rcmode = uc($rcmode || "CBR");
    $rcmode = "CBR" unless $rcmode =~ /^(?:CBR|VBR|AVBR)$/;

    my $target = parse_bitrate($bitrate);   # kbps
    $target = 12000 if $target <= 0;        # 兜底

    # ---- 码率边界自动计算 ----
    # VBR 真动态范围: maxrate 1.5x / bufsize 3x (bps_min 在 MPP VBR 中不作为硬下限, 静态温和降码率;
    # 放宽边界以保留动态头寸与静态压缩空间, 均值略高于目标)
    my ($min, $max, $buf);
    if ($rcmode eq "CBR") {
        ($min, $max, $buf) = ($target, $target, $target * 2);
    } elsif ($rcmode eq "VBR") {
        ($min, $max, $buf) = (int($target * 0.5), int($target * 1.5), int($target * 3));
    } else { # AVBR
        ($min, $max, $buf) = (0, int($target * 1.5), int($target * 3));
    }

    my $params = " -b:v " . fmt_kbps($target) . " -maxrate " . fmt_kbps($max) . " -bufsize " . fmt_kbps($buf);
    $params .= " -minrate " . fmt_kbps($min) if $min > 0;

    # ---- GOP: auto -> fps*2 (2 秒关键帧) ----
    my $gop_val = ($gop =~ /^\d+$/) ? $gop : $fps * 2;
    $params .= " -g $gop_val";

    # ---- QP / level / profile 自动推导 ----
    my ($qpi, $qpmn, $qpmx) = auto_qp($target);
    if ($rcmode eq "VBR") {
        # 真VBR动态范围 (实测 MPP VBR 为 QP 主导): qp_min+8 (16M档 10->16, 均值收敛到~16M)
        # / qp_max+3 (33, 允许静态压缩); -b:v/-q 均不主导, 勿依赖
        $qpmn = $qpmn + 8;
        $qpmn = 24 if $qpmn > 24;
        $qpmx = $qpmx + 5;
        $qpmx = 44 if $qpmx > 44;
    }

    if ($codec eq "h264_rkmpp") {
        my $lv = h264_auto_level($w, $h);
        $params .= " -rc_mode ${rcmode} -profile:v high -level $lv -qp_init $qpi -qp_min $qpmn -qp_max $qpmx";
    } elsif ($codec eq "hevc_rkmpp") {
        my $lv = hevc_auto_level($w, $h);
        $params .= " -rc_mode ${rcmode} -level $lv -tier main -qp_init $qpi -qp_min $qpmn -qp_max $qpmx";
    }

    my $lv = ($codec eq "hevc_rkmpp") ? hevc_auto_level($w, $h) : h264_auto_level($w, $h);
    print "📐 编码自动参数: rc=${rcmode} 目标=" . fmt_kbps($target)
        . " 边界=" . ($min > 0 ? fmt_kbps($min) . "-" : "~") . fmt_kbps($max)
        . " GOP=${gop_val} QP=${qpmn}/${qpi}/${qpmx} level=${lv}\n";

    # ---- 高级自定义参数: 追加末尾, 后出现的同名参数覆盖自动值 ----
    $params .= " $extra" if $extra;

    return $params;
}

our $AUDIO_DEV_USED = "";

# 探测可用的音频采集设备 (arecord):
# 部分发行版 (如 Debian12/bookworm + RV1126 ACodec) 下 "-D default" 会 SIGBUS 崩溃
# (WAV 只写 44B 头部即 "Bus error"), 而特定设备名 (如 mic4) 正常. 依次探测候选设备,
# 取第一个能采到实际数据 (退出码 0 且文件 > 100B) 且不崩溃/不挂起的.
sub audio_device_probe {
    my ($device, $rate, $ch) = @_;
    $rate //= 48000; $ch //= 1;
    my $probe = "/tmp/.arecord_probe.wav";

    my @cands = ($device);
    my $lst = `arecord -L 2>/dev/null`;
    for my $ln (split /\n/, $lst) {
        $ln =~ s/\s+$//;
        next unless $ln =~ /^[A-Za-z0-9_]+$/;   # 仅简单设备名 (排除 hw:/plughw:/sysdefault: 等易挂起项)
        next if $ln =~ /^(null|playback|speaker_downmix|default)$/;
        push @cands, $ln;
    }
    my %seen; my @uniq;
    for my $d (@cands) { push @uniq, $d unless $seen{$d}++; }

    for my $d (@uniq) {
        unlink $probe;
        system("timeout 3 arecord -D '$d' -f S16_LE -r $rate -c $ch -d 1 -q $probe 2>/dev/null");
        my $rc = $? >> 8;
        next unless $rc == 0;
        next unless -f $probe && -s $probe > 100;   # 有实际数据 (仅 44B 头部视为崩溃/无输出)
        unlink $probe;
        return $d;
    }
    unlink $probe if -e $probe;
    return "";
}

sub audio_build_params {
    my ($enable, $device, $samplerate, $channels, $bitrate) = @_;

    unless ($enable) {
        print "⏭️ 音频推流已关\n";
        $AUDIO_DEV_USED = "";
        return ("", "", "");
    }

    # 自动探测可用采集设备: 配置的 default 在部分发行版 (bookworm) 会 SIGBUS 崩溃,
    # 自动回退到可用设备 (如 mic4); 全部失败则禁用音频, 避免哑音轨拖垮 WebRTC 同步
    my $dev = audio_device_probe($device, $samplerate, $channels);
    unless ($dev) {
        print "⚠️ 未找到可用音频采集设备, 本次推流禁用音频 (避免哑音轨导致 WebRTC 缓冲)\n";
        $AUDIO_DEV_USED = "";
        return ("", "", "");
    }
    $AUDIO_DEV_USED = $dev;
    my $hint = ($dev ne $device) ? " (default 不可用, 自动回退)" : "";
    print "🎙️ 音频输入: ${dev} ${samplerate}Hz ${channels}ch (AAC ${bitrate})${hint}\n";

    my $pipe = "arecord -D ${dev} -f S16_LE -r ${samplerate} -c ${channels} | ";
    my $ain  = " -f s16le -ar ${samplerate} -ac ${channels} -i -";
    my $aout = " -c:a aac -b:a ${bitrate}";

    return ($pipe, $ain, $aout);
}

sub osd_build_vf {
    my ($enable, $font, $text, $ts_enable, $ts_format, $fontsize, $w, $h, $fps) = @_;

    # 基础帧率滤镜
    my $vf = "fps=${fps}";

    unless ($enable) {
        print "⏭️ OSD 文字叠加已关\n";
        return $vf;
    }

    # 字号: 0=自动 (推流高度 1/36, 最小 20px; 2K->40, 1080->30), >0 使用固定值
    $fontsize = ($fontsize && $fontsize > 0) ? $fontsize : int($h / 36);
    $fontsize = 20 if $fontsize < 20;

    my $pad = int($fontsize / 2);          # 边距 = 字号一半
    my $bw  = int($fontsize / 8) + 1;      # 描边宽度
    print "🖋️  OSD: 文字 \"${text}\" 字号=${fontsize}px 字体=${font}\n";

    # drawtext 的 %{localtime\:...} 只需转义 localtime 后的第一个冒号,
    # 格式串内部冒号作为 strftime 格式原样保留 (见 ffmpeg drawtext 官方示例)
    my $fts = $ts_format;

    my @draws;

    if ($text ne '') {
        push @draws, sprintf(
            "drawtext=fontfile='%s':text='%s':x=%d:y=%d:fontsize=%d:fontcolor=white:borderw=%d:bordercolor=black\@0.6",
            $font, $text, $pad, $pad, $fontsize, $bw,
        );
    }

    if ($ts_enable) {
        push @draws, sprintf(
            "drawtext=fontfile='%s':text='%%{localtime\\:%s}':x=w-tw-%d:y=%d:fontsize=%d:fontcolor=white:borderw=%d:bordercolor=black\@0.6",
            $font, $fts, $pad, $pad, $fontsize, $bw,
        );
    }

    # 组合滤镜链
    $vf .= "," . join(",", @draws) if @draws;

    return $vf;
}

sub gst_osd_build {
    my ($enable, $text, $ts_enable, $ts_format, $fontsize, $font, $w, $h) = @_;

    unless ($enable) {
        print "⏭️ 本地显示 OSD 已关\n";
        return "";
    }

    # 字号: 0=自动 (较短边/48, 最小10), >0 使用固定值
    my $short = $w < $h ? $w : $h;
    my $auto  = int($short / 48);
    $auto = 10 if $auto < 10;
    my $fs = ($fontsize && $fontsize > 0) ? $fontsize : $auto;

    my $gst = "";
    my $font_name = ($font && $font ne '') ? $font : "Sans";
    my $font_desc = "${font_name} ${fs}";

    # 说明: 本地显示主画面旋转 270 度 (videoflip 90l), OSD 叠加在旋转前画面并随画面旋转.
    # 经实机反馈与像素实测校准, 最终屏幕角位与 flip 前 valignment/halignment 直接对应
    # (top->上, bottom->下, left->左, right->右), 故:
    #   固定文字期望屏幕左上角 -> valignment=top halignment=left;
    #   时间戳期望屏幕右上角 -> valignment=top halignment=right.
    # deltay 负值=向上偏移 (旋转后方向), 用于把文字再上移约一个字高度贴近屏幕顶部.

    my $dy = -14;   # 上移约一个字高度 (字号10px时约1.4字高)

    # 右上角时间戳 (期望屏幕右上角)
    if ($ts_enable && $ts_format ne '') {
        $gst .= " ! clockoverlay valignment=top halignment=right "
              . "font-desc=\"${font_desc}\" time-format=\"${ts_format}\" shaded-background=true deltay=${dy}";
    }

    # 左上角固定文字 (期望屏幕左上角)
    if ($text ne '') {
        $gst .= " ! textoverlay text=\"${text}\" valignment=top halignment=left "
              . "font-desc=\"${font_desc}\" shaded-background=true deltay=${dy}";
    }

    if ($gst ne '') {
        print "🖥️  本地显示 OSD: 文字=\"${text}\" 时间戳=" . ($ts_enable ? "ON" : "OFF")
            . " 字号=${fs}px\n";
    }

    return $gst;
}

sub show_status {
    my ($gd, $fd, $de, $se) = @_;
    my $ff_p = build_pattern("ffmpeg", $fd);
    my $gs_p = build_pattern("gst-launch-1.0", $gd);
    my @ff   = proc_find($ff_p);
    my @gs   = proc_find($gs_p);

    print "📊 本地显示=" . ($de ? "ON" : "OFF") . " 推流=" . ($se ? "ON" : "OFF") . "\n";

    if ($de) {
        print @gs ? "✅ GStreamer (PID: @gs)\n" : "❌ GStreamer 未运行\n";
    } else {
        print "⏭️ 本地显示已关\n";
    }

    if ($se) {
        print @ff ? "✅ FFmpeg (PID: @ff)\n" : "❌ FFmpeg 未运行\n";
    } else {
        print "⏭️ 推流已关\n";
    }
}

# ==============================================================================
# 3A 算法服务管理
# ==============================================================================

sub restart_3a_service {
    print "🔄 重启 3A 算法服务...\n";
    system("systemctl restart rkaiq_3A.service 2>/dev/null");
    sleep 1;
}

sub wait_for_3a_ready {
    my ($timeout) = @_;
    $timeout //= 30;

    print "⏳ 等待 3A 算法就绪 (端口 4894)...\n";

    for my $i (1 .. $timeout) {
        my $r = system("ss -tln 2>/dev/null | grep -q ':4894'");
        if ($r == 0) {
            print "✅ 3A 算法就绪 (${i}s)\n";
            return 1;
        }
        print "." if $i % 2 == 0;
        sleep 1;
    }

    print "\n⚠️ 3A 算法未在 ${timeout} 秒内就绪，继续启动流程\n";
    return 0;
}

# ==============================================================================
# 主程序
# ==============================================================================

my %CFG = load_config($opt{config}, \%opt);

my ($DE, $SE)     = ($CFG{DISPLAY_ENABLE}, $CFG{STREAM_ENABLE});
my ($GST_DEV, $FF_DEV) = ($CFG{GST_CAM_DEV}, $CFG{FFMPEG_CAM_DEV});
my ($R3A, $W3A)   = ($CFG{RESTART_3A}, $CFG{WAIT_3A});
my ($DW, $DH)     = parse_res($CFG{DISPLAY_RES});
($DW, $DH)        = (480, 800) unless defined $DW && defined $DH;
my $DR            = $CFG{DISPLAY_ROTATE};
my ($DCI, $DCN)   = ($CFG{DISPLAY_CONNECTOR_ID}, $CFG{DISPLAY_CONNECTOR_NAME});
my ($CW, $CH)     = parse_res($CFG{CAPTURE_RES});
($CW, $CH)        = (2560, 1440) unless defined $CW && defined $CH;

die "❌ 本地显示和推流不能同时关闭\n" unless $DE || $SE;

my $LOCK = $opt{lockfile};
# ffmpeg stderr 日志: 存 /var/log/capture 并配 logrotate 轮转 (copytruncate), 避免 7x24 运行累积
my $FF_ERR_LOG = "/var/log/capture/ffmpeg_stderr.log";
system("mkdir -p /var/log/capture 2>/dev/null");
my $FF_PAT  = build_pattern("ffmpeg", $FF_DEV);
my $GST_PAT = build_pattern("gst-launch-1.0", $GST_DEV);
my ($AE, $ADEV, $ARATE, $ACH, $ABIT) = ($CFG{AUDIO_ENABLE}, $CFG{AUDIO_DEVICE}, $CFG{AUDIO_SAMPLERATE}, $CFG{AUDIO_CHANNELS}, $CFG{AUDIO_BITRATE});
my ($EC, $EB, $EG, $EE, $ERM) = ($CFG{ENCODER_CODEC}, $CFG{ENCODER_BITRATE}, $CFG{ENCODER_GOP}, $CFG{ENCODER_EXTRA}, $CFG{ENCODER_RC_MODE});
my ($RTSP, $FM)   = ($CFG{RTSP_URL}, $CFG{FORCE_MODESETTING});
my ($OE, $OFONT, $OTEXT, $OTS, $OTSF, $OFS) = ($CFG{OSD_ENABLE}, $CFG{OSD_FONT}, $CFG{OSD_TEXT}, $CFG{OSD_TIMESTAMP}, $CFG{OSD_TIMESTAMP_FORMAT}, $CFG{OSD_FONTSIZE});
my ($DOE, $DOTEXT, $DOTS, $DOTSF, $DOFS, $DOFONT) = ($CFG{DISPLAY_OSD_ENABLE}, $CFG{DISPLAY_OSD_TEXT}, $CFG{DISPLAY_OSD_TIMESTAMP}, $CFG{DISPLAY_OSD_TIMESTAMP_FORMAT}, $CFG{DISPLAY_OSD_FONTSIZE}, $CFG{DISPLAY_OSD_FONT});

# ---- 维护模式分派: 必须在任何 v4l2 触碰之前 ----
# 采集进程运行中执行 S_FMT / 流式测量会触发内核报错:
#   rkisp-vir0: rkisp_s_fmt_vid_cap_mplane queue busy
# (webui /api/status 每 5s 轮询调用 capture.pl --status)
if ($opt{stop})    { stop_apps("x");   print "已停止\n";    exit 0; }
if ($opt{status})  { show_status($GST_DEV, $FF_DEV, $DE, $SE); exit 0; }
if ($opt{restart}) { stop_apps("x");   sleep 2; }

# 源类型识别 + 采集帧率 (E1)
my $SRC_TYPE      = detect_source_type($FF_DEV);
my $CFPS;
if ($SRC_TYPE eq "isp") {
    # 指导值 -> 设定 ISP (sensor 模式 + mainpath 输出格式), 失败则沿用当前模式
    # conf 的 CAPTURE_RES/CAPTURE_FPS 仅为指导值, 实际以设定后的实测为准
    my $set = enum_json("--set-isp", $FF_DEV, "--size", $CFG{CAPTURE_RES}, "--fps", $CFG{CAPTURE_FPS});
    if ($set && $set->{ok}) {
        # 分辨率校正: 仅用 set-isp 返回的 corrected_res (请求超 sensor 原生上限才校正, 如 4K).
        # 不用 actual_res(mainpath 回读), 因 rkisp 回读不可靠会误报导致错误校正
        my $corr = $set->{corrected_res} || "";
        if ($corr =~ /^(\d+)x(\d+)$/ && $corr ne "${CW}x${CH}") {
            my ($aw, $ah) = ($1 + 0, $2 + 0);
            if ($aw > 0 && $ah > 0) {
                print "⚠️ 分辨率校正: 请求 ${CW}x${CH}, 实际为 ${aw}x${ah}, 已按实际分辨率推流\n";
                ($CW, $CH) = ($aw, $ah);
            }
        }
        my $tres = $set->{target_res} // "-";
        if ($set->{native}) {
            my ($sres, $tfps) = ($set->{sensor_mode} // "-", $set->{target_fps} // "-");
            print "🎯 ISP 设定: sensor ${sres} -> ${tres} @ ${tfps}fps (subdev " . ($set->{subdev} // "-") . ")\n";
            print "   ↳ 回读 sensor 模式: " . ($set->{actual_sensor_res} // "-")
                . ($set->{sensor_ok} ? " ✓" : " ✗ (未生效, 走实测校正)") . "\n";
        } else {
            print "⏩ ISP: ${tres}, 目标帧率非 sensor 原生模式 -> 沿用当前并实测校正\n";
        }
    } else {
        print "⚠️ ISP 设定失败: " . (($set && $set->{error}) || "unknown") . ", 沿用当前模式并实测校正\n";
    }
    # 3A 重同步: sensor 模式切换后(如 30fps->120fps), 长期运行的 rkaiq_3A 仍按旧模式
    # 设置曝光/VTS, 导致 sensor/ISP 时序错乱 -> mainpath STREAMON CIF_ISP_PIC_SIZE_ERROR -> EINVAL.
    # 切换完成后重启 3A, 令其按新模式重初始化 (实测: 重启后 mainpath 120fps 正常)
    if ($set && $set->{ok} && $set->{changed}) {
        print "🔄 sensor 模式已切换, 重启 3A 使其按新模式重初始化...\n";
        restart_3a_service();
        wait_for_3a_ready();
    }
    # 实测校正: 高帧率(>=90)模式切换过渡期需较长抓帧(900), 其余 60 帧即可
    my $frames = ($CFG{CAPTURE_FPS} >= 90) ? 900 : 60;
    my $actual = actual_fps($FF_DEV, $frames);
    $CFPS = $actual > 0 ? $actual : $CFG{CAPTURE_FPS};
    if ($CFG{CAPTURE_FPS} != $CFPS) {
        print "⚠️ 校正提示: 配置 $CFG{CAPTURE_RES}\@$CFG{CAPTURE_FPS}fps 有误, 实际为 ${CFPS}fps, 已自动按正确帧率推流\n";
    } else {
        print "ℹ️ 源类型 ISP: 采集帧率 ${CFPS}fps (实测一致)\n";
    }
} else {
    $CFPS = $CFG{CAPTURE_FPS};
    print "ℹ️ 源类型 ${SRC_TYPE}: 采集帧率 ${CFPS}fps (可调)\n";
}
# 输出帧率 (STREAM_FPS): auto 或空 = 跟随采集帧率, 数值 = 固定输出帧率
my $SFPS = (defined $CFG{STREAM_FPS} && $CFG{STREAM_FPS} =~ /^\d+$/) ? $CFG{STREAM_FPS} + 0 : $CFPS;

delete @ENV{qw(GST_V4L2_PREFERRED_FOURCC GST_VIDEO_CONVERT_PREFERRED_FORMAT)};
$ENV{GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC} = 1;
$ENV{GST_MPP_VIDEODEC_DEFAULT_FORMAT}   = 'NV12';
$ENV{GST_VIDEO_CONVERT_USE_RGA}         = 1;
$ENV{GST_VIDEO_FLIP_USE_RGA}            = 1;

# 信号升级阶梯: SIGINT(优雅) -> 轮询退出 -> SIGTERM -> 轮询 -> SIGKILL(兜底)
# 解决某些 sensor 下 ffmpeg/gst 收到 SIGINT 后阻塞在 streamoff/编码器排空导致卡死:
#   正常 sensor 走优雅关闭, 卡死 sensor 被限时保证 SIGKILL, 避免 --stop 无限挂起
sub stop_escalate {
    my ($pat, $grace_s) = @_;
    $grace_s //= 2;
    my @pids = proc_find($pat);
    return 0 unless @pids;

    # 1. SIGINT 优雅停止, 轮询等待退出 (proc_alive 内部回收已退出子进程)
    kill(2, @pids);
    my $dl = time() + $grace_s;
    while (time() < $dl) {
        @pids = grep { proc_alive($_) } @pids;
        last unless @pids;
        select(undef, undef, undef, 0.2);
    }
    return 1 unless @pids;

    # 2. SIGTERM, 再短轮询
    kill(15, @pids);
    $dl = time() + 1;
    while (time() < $dl) {
        @pids = grep { proc_alive($_) } @pids;
        last unless @pids;
        select(undef, undef, undef, 0.2);
    }
    return 1 unless @pids;

    # 3. SIGKILL 兜底 (不可捕获, 保证终止)
    kill(9, @pids);
    return 1;
}

sub stop_apps {
    my ($mode) = @_;
    print "⚠️ 停止后台进程...\n";

    open my $lfh, '>', $LOCK or warn "锁文件: $!";
    print $lfh "STOP";
    close $lfh;

    my $ffk = stop_escalate($FF_PAT, 2);
    if ($ffk) { print "1. 停止推流\n"; }

    my $gstk = stop_escalate($GST_PAT, 1);
    if ($gstk) { print "2. 停止本地显示\n"; }

    # 兜底清理音频采集进程 (arecord 由 ffmpeg 被杀后的 SIGPIPE 带出)
    if ($AE) { proc_kill_match(9, "arecord"); }

    print $ffk || $gstk ? "✅ 已清理\n" : "⚠️ 无进程\n";

    if ($mode eq "self") {
        unlink $LOCK;
        exit 0;
    }
}

$SIG{INT}  = sub { stop_apps("self"); };
$SIG{TERM} = sub { stop_apps("self"); };

# ---- 3A 管理 ----
if ($R3A) { restart_3a_service(); }
if ($W3A) { wait_for_3a_ready(); }

print "🚀 启动流程...\n";
unlink $LOCK;
proc_kill_match(9, $FF_PAT);
proc_kill_match(9, $GST_PAT);
sleep 1;
cpu_boost_temporary();

# ---- 显示设备检测 ----
my $KMSSINK_OPTS_EXTRA = "";

if ($DE) {
    my $displays = detect_displays();
    my $selected = resolve_display_connector($displays, $DW, $DH, $DCI, $DCN);

    if (defined $selected) {
        my $sname = $selected->{name};
        print "🔌 显示设备: ${sname}\n";
    } elsif ($DCI >= 0) {
        $KMSSINK_OPTS_EXTRA = " connector-id=${DCI}";
        print "🔌 强制显示设备: connector-id=${DCI}\n";
    } else {
        print "⚠️ 无可用显示设备, 禁用本地显示\n";
        $DE = 0;
    }
}

my ($VW, $VH, $FLIP, $DIR);

if ($DE) {
    ($VW, $VH, $FLIP, $DIR) = display_calc_rotate($DW, $DH, $DR);
} else {
    $DIR = "disabled";
    print "⏭️ 本地显示已关\n";
}

my ($pid_gst, $pid_ff);
my ($gst_cmd, $ff_cmd);
my $enc_params;

# ============================================================================
# 步骤 1: 启动本地显示 (rkisp_selfpath → kmssink)
# ============================================================================

if ($DE) {
    my $kmssink_opts = "sync=false force-modesetting=${FM}${KMSSINK_OPTS_EXTRA}";
    print "1. 启动本地显示路径 ($GST_DEV)...\n";

    # 显示帧率上限: 自动从 DRM 读刷新率; 仅当采集帧率 > 刷新率时用 videorate 纯丢帧限流
    # (CFPS<=刷新率时不加, 避免 videorate 把低帧率补帧造成 CPU 浪费)
    my $gst_rate = "";
    my $disp_fps = display_refresh_hz($DCI, $DCN);
    if ($disp_fps > 0 && defined $CFPS && $CFPS > $disp_fps) {
        $gst_rate = " ! videorate drop-only=true ! video/x-raw,framerate=${disp_fps}/1";
        print "⚡ 显示限流: 采集 ${CFPS}fps > 面板 ${disp_fps}Hz, videorate 纯丢帧降为 ${disp_fps}fps\n";
    }

    # 本地显示 OSD (独立配置, 与推流互不相干)
    my $gst_osd = gst_osd_build($DOE, $DOTEXT, $DOTS, $DOTSF, $DOFS, $DOFONT, $VW, $VH);

    # OSD 放在 videoflip 之前, 使文字随主画面一起旋转 (与画面方向一致)
    # 注意: $FLIP 前需保留空格, 避免与 OSD 滤镜串拼接成 "true! videoflip" 导致解析失败
    $gst_cmd = "gst-launch-1.0 v4l2src device=$GST_DEV io-mode=4 "
             . "! video/x-raw,width=$VW,height=$VH,format=NV12 "
             . $gst_rate
             . $gst_osd
             . " $FLIP"
             . " ! kmssink $kmssink_opts";

    ($pid_gst, undef) = gst_display_start($gst_cmd);

    if ($pid_gst) {
        wait_display_stable();
    }
} else {
    print "⏭️ 本地显示已关\n";
}

# ============================================================================
# 步骤 2: 启动推流 (rkisp_mainpath → FFmpeg → RTSP)
# ============================================================================

if ($SE) {
    print "2. 启动推流路径 ($FF_DEV)...\n";

    $enc_params = encoder_build_params($EC, $EB, $EG, $EE, $SFPS, $ERM, $CW, $CH);

    # 音频参数 (开关可控): arecord 采集经管道输入 ffmpeg
    my ($audio_pipe, $audio_in, $audio_out) = audio_build_params($AE, $ADEV, $ARATE, $ACH, $ABIT);

    # OSD 滤镜链: fps(=输出帧率 SFPS, 放最前端统一时间戳) + 左上角固定文字 + 右上角时间戳
    # 帧率统一由 -vf fps 控制 (实测 mpp 可从 PTS 正确识别 30/15), 不再使用输出端 -r
    my $vf = osd_build_vf($OE, $OFONT, $OTEXT, $OTS, $OTSF, $OFS, $CW, $CH, $SFPS);

    $ff_cmd = $audio_pipe
            . "ffmpeg -f v4l2 -framerate $CFPS -video_size \"${CW}x${CH}\" "
            . "-pix_fmt nv12 -i $FF_DEV"
            . $audio_in
            . " -vf \"${vf}\" "
            . "-vcodec $EC $enc_params"
            . $audio_out
            . " -f rtsp \"$RTSP\"";

    print "🎬 FFmpeg 命令: $ff_cmd\n";

    my $errf = $FF_ERR_LOG;
    unlink $errf;
    $pid_ff = proc_spawn($ff_cmd, $errf);
    sleep 2;

    if (proc_alive($pid_ff) && -f $errf) {
        if (open my $fh, '<', $errf) {
            my $c = do { local $/; <$fh> };
            close $fh;

            if ($c =~ /(?:Error|Failed|Cannot open|No such|Permission denied|Device or resource busy)/i) {
                print "⚠️ FFmpeg stderr有错误:\n";
                print "  | $_\n" for split "\n", $c;
            }
        } else {
            warn "⚠️ 无法读取 $errf: $!";
        }
    }
} else {
    print "⏭️ 推流已关\n";
}

print "🎉 启动完成\n";

if ($DE) {
    print "👉 本地显示: ${GST_DEV} ${VW}x${VH} [${DIR}]\n";
}

if ($SE) {
    print "👉 推流: ${FF_DEV} ${CW}x${CH} 采集${CFPS}fps 输出${SFPS}fps\n"
        . "👉 RTSP: ${RTSP}\n"
        . "👉 编码参数: ${enc_params}\n"
        . "👉 音频: " . ($AUDIO_DEV_USED ? "ON (${AUDIO_DEV_USED} ${ARATE}Hz)" : "OFF") . "\n"
        . "👉 OSD: " . ($OE ? "ON (文字=\"${OTEXT}\")" : "OFF") . "\n";
}

# ============================================================================
# 主循环: 监控进程状态, 异常时自动重启
# ============================================================================

while (1) {
    if (-f $LOCK) {
        open my $lfh, '<', $LOCK or next;
        my $c = <$lfh>;
        chomp $c;
        close $lfh;

        if ($c eq "STOP") {
            print "退出\n";
            unlink $LOCK;
            exit 0;
        }
    }

    if ($DE && !proc_alive($pid_gst)) {
        print "⚠️ 本地显示退出, 重启...\n";
        ($pid_gst, undef) = gst_display_start($gst_cmd);

        if ($pid_gst && $SE) {
            wait_display_stable();
        }
    }

    if ($SE && !proc_alive($pid_ff)) {
        print "⚠️ 推流退出, 重启...\n";
        my $errf = $FF_ERR_LOG;
        unlink $errf;
        $pid_ff = proc_spawn($ff_cmd, $errf);
    }

    my $fa = $SE ? proc_alive($pid_ff) : 1;
    my $ga = $DE ? proc_alive($pid_gst) : 1;

    if (!$fa && !$ga) {
        print "⚠️ 全链路终止\n";
        stop_apps("self");
    }

    sleep 1;
}
