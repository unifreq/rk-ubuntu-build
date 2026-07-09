#!/usr/bin/perl
#
# capture.pl - Rockchip RV1126B 摄像头采集与显示管线
#
# 版本:  v3.0.0
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
use constant VERSION => 'v3.0.0';
use constant AUTHOR  => 'flippy <flippy@sina.com>';
use constant LICENSE => 'GPL v2';
use warnings;
use POSIX qw(setsid);
use Getopt::Long;

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
    display_width        => undef,
    display_height       => undef,
    display_rotate       => undef,
    display_connector_id => undef,
    display_connector_name => undef,
    capture_width        => undef,
    capture_height       => undef,
    capture_fps          => undef,
    encoder_codec        => undef,
    encoder_bitrate      => undef,
    encoder_gop          => undef,
    encoder_extra        => undef,
    rtsp_url             => undef,
    force_modesetting    => undef,
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
    'display-width=i'     => \$opt{display_width},
    'display-height=i'    => \$opt{display_height},
    'display-rotate=s'    => \$opt{display_rotate},
    'display-connector-id=i'   => \$opt{display_connector_id},
    'display-connector-name=s' => \$opt{display_connector_name},
    'capture-width=i'     => \$opt{capture_width},
    'capture-height=i'    => \$opt{capture_height},
    'capture-fps=i'       => \$opt{capture_fps},
    'encoder-codec=s'     => \$opt{encoder_codec},
    'encoder-bitrate=s'   => \$opt{encoder_bitrate},
    'encoder-gop=s'       => \$opt{encoder_gop},
    'encoder-extra=s'     => \$opt{encoder_extra},
    'rtsp-url=s'          => \$opt{rtsp_url},
    'force-modesetting=s' => \$opt{force_modesetting},
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
  --restart-3a                     启动前重启 3A 算法服务
  --wait-3a / --no-wait-3a         等待 3A 就绪 (默认开启)

设备节点:
  --gst-cam-dev=PATH               本地显示路径 (selfpath, 默认 /dev/video25)
  --ffmpeg-cam-dev=PATH            推流路径 (mainpath, 默认 /dev/video24)

显示参数:
  --display-width=NUM --display-height=NUM --display-rotate=ANGLE
  --display-connector-id=NUM       DRM connector ID (优先级高于名称)
  --display-connector-name=NAME    DRM connector 名称 (如 DSI-1)

采集参数:
  --capture-width=NUM --capture-height=NUM --capture-fps=NUM

编码参数:
  --encoder-codec=CODEC            h264_rkmpp / hevc_rkmpp
  --encoder-bitrate=BITRATE        如 8M, 4M
  --encoder-gop=GOP                如 auto, 60, 120
  --encoder-extra=EXTRA            额外编码参数

其他:
  --rtsp-url=URL --force-modesetting=VAL
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
        DISPLAY_WIDTH        => 480,
        DISPLAY_HEIGHT       => 800,
        DISPLAY_ROTATE       => "270",
        DISPLAY_CONNECTOR_ID => -1,
        DISPLAY_CONNECTOR_NAME => "",
        CAPTURE_WIDTH        => 2560,
        CAPTURE_HEIGHT       => 1440,
        CAPTURE_FPS          => 60,
        ENCODER_CODEC        => "h264_rkmpp",
        ENCODER_BITRATE      => "8M",
        ENCODER_GOP          => "auto",
        ENCODER_EXTRA        => "",
        RTSP_URL             => "rtsp://127.0.0.1:8554/live/0",
        FORCE_MODESETTING    => "false",
    );

    my %is_num  = map { $_ => 1 } qw(DISPLAY_WIDTH DISPLAY_HEIGHT CAPTURE_WIDTH CAPTURE_HEIGHT CAPTURE_FPS DISPLAY_CONNECTOR_ID);
    my %is_bool = map { $_ => 1 } qw(DISPLAY_ENABLE STREAM_ENABLE RESTART_3A WAIT_3A);

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
        display_width         => 'DISPLAY_WIDTH',
        display_height        => 'DISPLAY_HEIGHT',
        display_rotate        => 'DISPLAY_ROTATE',
        display_connector_id  => 'DISPLAY_CONNECTOR_ID',
        display_connector_name => 'DISPLAY_CONNECTOR_NAME',
        capture_width         => 'CAPTURE_WIDTH',
        capture_height        => 'CAPTURE_HEIGHT',
        capture_fps           => 'CAPTURE_FPS',
        encoder_codec         => 'ENCODER_CODEC',
        encoder_bitrate       => 'ENCODER_BITRATE',
        encoder_gop           => 'ENCODER_GOP',
        encoder_extra         => 'ENCODER_EXTRA',
        rtsp_url              => 'RTSP_URL',
        force_modesetting     => 'FORCE_MODESETTING',
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

sub encoder_build_params {
    my ($codec, $bitrate, $gop, $extra, $fps) = @_;
    my $params = "";

    # 比特率参数
    if ($bitrate =~ /^(\d+)([KkMm])$/) {
        my ($val, $unit) = ($1, $2);
        $unit = uc($unit);
        $params .= " -b:v ${val}${unit} -maxrate ${val}${unit} -bufsize " . (2 * $val) . "${unit}";
    } elsif ($bitrate =~ /^(\d+)$/) {
        $params .= " -b:v ${bitrate}K -maxrate ${bitrate}K -bufsize " . (2 * $bitrate) . "K";
    }

    # GOP - 必须为数值, h264_rkmpp 不支持 "auto"
    my $gop_val = 60;
    if ($gop =~ /^\d+$/)    { $gop_val = $gop; }
    elsif ($gop eq "auto")  { $gop_val = $fps * 2; }
    $params .= " -g $gop_val";

    # 编码器类型相关参数
    if ($codec eq "h264_rkmpp") {
        $params .= " -rc_mode VBR -level 4.2 -profile high -coder cabac -8x8dct 1";
    } elsif ($codec eq "hevc_rkmpp") {
        $params .= " -rc_mode VBR -level 5.1 -tier main";
    }

    # 额外参数
    $params .= " $extra" if $extra;

    return $params;
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
my ($DW, $DH, $DR) = ($CFG{DISPLAY_WIDTH}, $CFG{DISPLAY_HEIGHT}, $CFG{DISPLAY_ROTATE});
my ($DCI, $DCN)   = ($CFG{DISPLAY_CONNECTOR_ID}, $CFG{DISPLAY_CONNECTOR_NAME});
my ($CW, $CH, $CFPS) = ($CFG{CAPTURE_WIDTH}, $CFG{CAPTURE_HEIGHT}, $CFG{CAPTURE_FPS});
my ($EC, $EB, $EG, $EE) = ($CFG{ENCODER_CODEC}, $CFG{ENCODER_BITRATE}, $CFG{ENCODER_GOP}, $CFG{ENCODER_EXTRA});
my ($RTSP, $FM)   = ($CFG{RTSP_URL}, $CFG{FORCE_MODESETTING});
my $LOCK = $opt{lockfile};

my $FF_PAT  = build_pattern("ffmpeg", $FF_DEV);
my $GST_PAT = build_pattern("gst-launch-1.0", $GST_DEV);

die "❌ 本地显示和推流不能同时关闭\n" unless $DE || $SE;

delete @ENV{qw(GST_V4L2_PREFERRED_FOURCC GST_VIDEO_CONVERT_PREFERRED_FORMAT)};
$ENV{GST_MPP_VIDEODEC_DEFAULT_ARM_AFBC} = 1;
$ENV{GST_MPP_VIDEODEC_DEFAULT_FORMAT}   = 'NV12';
$ENV{GST_VIDEO_CONVERT_USE_RGA}         = 1;
$ENV{GST_VIDEO_FLIP_USE_RGA}            = 1;

sub stop_apps {
    my ($mode) = @_;
    print "⚠️ 停止后台进程...\n";

    open my $lfh, '>', $LOCK or warn "锁文件: $!";
    print $lfh "STOP";
    close $lfh;

    my $ffk = proc_kill_match(2, $FF_PAT);
    if ($ffk) {
        print "1. 停止推流\n";
        sleep 3;
        proc_kill_match(9, $FF_PAT);
    }

    my $gstk = proc_kill_match(2, $GST_PAT);
    if ($gstk) {
        print "2. 停止本地显示\n";
        sleep 1;
        proc_kill_match(9, $GST_PAT);
    }

    print $ffk || $gstk ? "✅ 已清理\n" : "⚠️ 无进程\n";

    if ($mode eq "self") {
        unlink $LOCK;
        exit 0;
    }
}

$SIG{INT}  = sub { stop_apps("self"); };
$SIG{TERM} = sub { stop_apps("self"); };

if ($opt{stop})    { stop_apps("x");   print "已停止\n";    exit 0; }
if ($opt{status})  { show_status($GST_DEV, $FF_DEV, $DE, $SE); exit 0; }
if ($opt{restart}) { stop_apps("x");   sleep 2; }

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

    $gst_cmd = "gst-launch-1.0 v4l2src device=$GST_DEV io-mode=4 "
             . "! video/x-raw,width=$VW,height=$VH,format=NV12 "
             . "$FLIP ! kmssink $kmssink_opts";

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

    $enc_params = encoder_build_params($EC, $EB, $EG, $EE, $CFPS);

    $ff_cmd = "ffmpeg -f v4l2 -framerate $CFPS -video_size \"${CW}x${CH}\" "
            . "-pix_fmt nv12 -i $FF_DEV -vf \"fps=${CFPS}\" "
            . "-vcodec $EC -r $CFPS $enc_params -f rtsp \"$RTSP\"";

    my $errf = "/tmp/ffmpeg_stderr.log";
    unlink $errf;
    $pid_ff = proc_spawn($ff_cmd, $errf);
    sleep 2;

    if (proc_alive($pid_ff) && -f $errf) {
        open my $fh, '<', $errf or next;
        my $c = do { local $/; <$fh> };
        close $fh;

        if ($c =~ /(?:Error|Failed|Cannot open|No such|Permission denied|Device or resource busy)/i) {
            print "⚠️ FFmpeg stderr有错误:\n";
            print "  | $_\n" for split "\n", $c;
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
    print "👉 推流: ${FF_DEV} ${CW}x${CH}\n"
        . "👉 RTSP: ${RTSP}\n"
        . "👉 编码参数: ${enc_params}\n";
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
        my $errf = "/tmp/ffmpeg_stderr.log";
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
