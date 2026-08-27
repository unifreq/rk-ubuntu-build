#!/usr/bin/perl
#
# capture-enum.pl - 视频源类型识别与帧率/分辨率真实枚举工具
#
# 用途:
#   1. 识别视频源类型 (ISP / UVC / HDMI-IN原生 / HDMI-IN桥接CIF / generic)
#   2. 按源类型真实枚举帧率 (杜绝 ffmpeg 假升帧假象)
#   3. 按源类型真实枚举分辨率
#   4. 枚举 DRM 输出设备的多模式 (DSI/HDMI/DP)
#
# 供 capture.pl 与 capture-webui.py 共用。
# 输出 JSON (JSON::PP, Perl 标准库)。
#
# 用法:
#   capture-enum.pl --detect-type /dev/videoX     # 源类型识别
#   capture-enum.pl --source-fps /dev/videoX      # 帧率枚举
#   capture-enum.pl --source-res /dev/videoX      # 分辨率枚举
#   capture-enum.pl --drm                          # DRM connector/模式枚举
#   capture-enum.pl --source-all /dev/videoX      # 类型+帧率+分辨率一次性输出
#
use strict;
use warnings;
use utf8;      # 声明源码为 UTF-8, 使中文字面量带 UTF-8 标记, 防止 JSON::PP->utf8 双重编码
use JSON::PP;
use Getopt::Long;
binmode STDERR, ":utf8";   # 让中文提示(如分辨率校正警告)正常输出, 避免 Wide character 警告

use constant VERSION => 'v1.0.0';

my %opt = (
    version     => 0,
    detect_type => undef,
    source_fps  => undef,
    source_res  => undef,
    source_all  => undef,
    drm         => 0,
    actual_fps  => undef,
    iqfile      => undef,
    set_hdr     => undef,
    set_hdr_path => undef,
    hdr_value   => undef,
    sensors     => undef,
    set_isp     => undef,
    fps         => undef,
    frames      => undef,
);

GetOptions(
    'detect-type=s' => \$opt{detect_type},
    'source-fps=s'  => \$opt{source_fps},
    'source-res=s'  => \$opt{source_res},
    'source-all=s'  => \$opt{source_all},
    'drm'           => \$opt{drm},
    'size=s'        => \$opt{size},
    'actual-fps=s'  => \$opt{actual_fps},
    'iqfile=s'      => \$opt{iqfile},
    'set-hdr=s'     => \$opt{set_hdr},
    'set-hdr-path=s' => \$opt{set_hdr_path},
    'hdr-value=i'   => \$opt{hdr_value},
    'sensors'       => \$opt{sensors},
    'set-isp=s'     => \$opt{set_isp},
    'fps=i'         => \$opt{fps},
    'frames=i'      => \$opt{frames},
    'version'       => \$opt{version},
) or die "用法: $0 [--detect-type DEV] [--source-fps DEV] [--source-res DEV] [--source-all DEV] [--drm] [--size WxH] [--actual-fps DEV [--frames N]] [--iqfile DEV] [--set-hdr DEV --hdr-value 0|1] [--set-isp DEV --size WxH --fps N] [--sensors] [--version]\n";

my $json = JSON::PP->new->utf8->pretty->canonical;

sub sh {
    my ($cmd) = @_;
    my $out = `$cmd 2>/dev/null`;
    return defined $out ? $out : "";
}

# ==============================================================================
# 源类型识别
# ==============================================================================
sub detect_source_type {
    my ($dev) = @_;
    return { type => "none", error => "device $dev not given" } unless $dev;

    my $node = $dev;
    $node =~ s{^/dev/}{};
    my $name = sh("cat /sys/class/video4linux/$node/name 2>/dev/null");
    chomp $name;
    my $driver = sh("cat /sys/class/video4linux/$node/device/uevent 2>/dev/null | grep '^DRIVER='");
    $driver =~ s/^DRIVER=//;
    chomp $driver;

    my $type = "generic";
    my $desc = $name;

    if ($name =~ /rkisp|rkaiisp|rkisp_mainpath|rkisp_selfpath/i) {
        $type = "isp";
        $desc = "ISP 设备";
    } elsif ($driver =~ /uvcvideo/i || $name =~ /uvc|usb camera|usb 2\.0 camera/i) {
        $type = "uvc";
        $desc = "UVC (USB 摄像头)";
    } elsif ($name =~ /hdmi|rk_hdmirx|rk_hdmi_rx|hdmirx/i || $driver =~ /rk_hdmi/i) {
        $type = "hdmi_in";
        $desc = "HDMI-IN (原生 RX)";
    } elsif ($name =~ /rkcif/i && $driver =~ /tc358749|adv7180|adv7611|sii9022|video_bridge/i) {
        $type = "hdmi_bridge_cif";
        $desc = "HDMI-IN (桥接 CIF)";
    } elsif ($name =~ /rkcif/i || $driver =~ /rkcif/i) {
        $type = "cif";
        $desc = "CIF (无桥接)";
    } elsif ($name =~ /rkvpss|vpss/i) {
        $type = "vpss";
        $desc = "VPSS 通道";
    }

    return { type => $type, desc => $desc, driver => $driver, name => $name, device => $dev };
}

# ==============================================================================
# sensor 能力库 (RV1126B ISP35 官方支持, 来自内核驱动 supported_modes 表)
# 结构: 型号 => { res => [分辨率], fps => { "WxH" => [帧率...] }, hdr => { "WxH@fps" => 模式 } }
# ==============================================================================
my %SENSOR_CAPS = (
    "sc450ai" => {
        res => ["2688x1520", "1344x760"],
        fps => { "2688x1520" => [30, 25], "1344x760" => [120] },
        hdr => { "2688x1520@25" => "HDR_X2" },
        note => "2lane: 2688x1520@30(linear)/25(HDR), 1344x760@120",
    },
    "gc8613" => {
        res => ["3840x2160"],
        fps => { "3840x2160" => [40, 30] },
        hdr => { "3840x2160@30" => "HDR_X2/linear" },
        note => "纯4K: 30fps(10bit/12bit), 40fps(10bit ya)",
    },
    "gc2093" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30, 25] },
        hdr => { "1920x1080@25" => "HDR_X2", "1920x1080@30" => "HDR_X2/linear" },
        note => "1080p: 30fps(linear/HDR), 25fps(HDR)",
    },
    "imx415" => {
        res => ["3864x2192", "1944x1097"],
        fps => { "3864x2192" => [50, 30], "1944x1097" => [30] },
        hdr => { "3864x2192@50" => "HDR_X3", "3864x2192@30" => "HDR_X2/linear" },
        note => "4K(4:3): 30fps, 50fps(HDR_X3); 1080p: 30fps",
    },
    "imx586" => {
        res => ["4000x3000", "8000x6000", "3968x2800"],
        fps => { "4000x3000" => [30], "8000x6000" => [9, 6], "3968x2800" => [30] },
        note => "4K(4:3):30fps, 8K:6.4/9.7fps慢拍, 3968x2800:30fps",
    },
    "sc200ai" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [60, 30] },
        hdr => { "1920x1080@30" => "HDR_X2/linear" },
        note => "1080p: 60fps(linear!), 30fps",
    },
    "sc635hai" => {
        res => ["3200x1800"],
        fps => { "3200x1800" => [60, 30] },
        note => "3200x1800: 60fps(4lane), 30fps",
    },
    "sc850sl" => {
        res => ["3840x2160"],
        fps => { "3840x2160" => [40, 30] },
        note => "4K: 40fps, 30fps",
    },
    "gc02m2" => {
        res => ["1600x1200"],
        fps => { "1600x1200" => [30] },
    },
    "gc05a2" => {
        res => ["2592x1944"],
        fps => { "2592x1944" => [30] },
    },
    "gc1084" => {
        res => ["1280x720"],
        fps => { "1280x720" => [30] },
    },
    "gc2053" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30] },
    },
    "gc2385" => {
        res => ["1600x1200"],
        fps => { "1600x1200" => [30] },
    },
    "gc4023" => {
        res => ["2560x1440"],
        fps => { "2560x1440" => [30] },
    },
    "gc4653" => {
        res => ["2560x1440"],
        fps => { "2560x1440" => [30] },
    },
    "gc4663" => {
        res => ["2560x1440"],
        fps => { "2560x1440" => [30] },
    },
    "gc5025" => {
        res => ["2592x1944"],
        fps => { "2592x1944" => [30] },
    },
    "gc5035" => {
        res => ["2592x1944"],
        fps => { "2592x1944" => [30] },
    },
    "gc8034" => {
        res => ["3264x2448", "1632x1224"],
        fps => { "3264x2448" => [30, 15], "1632x1224" => [30] },
    },
    "hi556" => {
        res => ["2592x1944"],
        fps => { "2592x1944" => [30] },
    },
    "hi846" => {
        res => ["1632x1224", "1280x720", "640x480"],
        fps => { "1632x1224" => [30], "1280x720" => [90], "640x480" => [120] },
    },
    "imx327" => {
        res => ["1948x1110", "1948x1098", "1948x1097", "1952x1089"],
        fps => { "1948x1110" => [25], "1948x1098" => [25], "1948x1097" => [25], "1952x1089" => [25] },
    },
    "imx464" => {
        res => ["2712x1538", "2712x1536"],
        fps => { "2712x1538" => [30, 15], "2712x1536" => [30, 15] },
    },
    "mis2032" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "os02h10" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "os02k10" => {
        res => ["1920x1080", "640x480"],
        fps => { "1920x1080" => [30], "640x480" => [120] },
    },
    "os04a10" => {
        res => ["2688x1520", "2560x1440"],
        fps => { "2688x1520" => [30, 22], "2560x1440" => [25] },
    },
    "os04a10hk" => {
        res => ["2688x1520"],
        fps => { "2688x1520" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "os08a10" => {
        res => ["3840x2160"],
        fps => { "3840x2160" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "ov02b10" => {
        res => ["1600x1200"],
        fps => { "1600x1200" => [30] },
    },
    "ov13850" => {
        res => ["4224x3136", "2112x1568"],
        fps => { "4224x3136" => [8], "2112x1568" => [30] },
    },
    "ov13855" => {
        res => ["4224x3136", "2112x1568"],
        fps => { "4224x3136" => [30, 15], "2112x1568" => [60] },
    },
    "ov16880" => {
        res => ["4672x3504"],
        fps => { "4672x3504" => [30] },
    },
    "ov50c40" => {
        res => ["8192x6144", "4096x3072"],
        fps => { "8192x6144" => [12, 3], "4096x3072" => [30, 15] },
    },
    "ov5648" => {
        res => ["2592x1944", "1296x972"],
        fps => { "2592x1944" => [15], "1296x972" => [30] },
    },
    "ov5670" => {
        res => ["2592x1944", "1296x960"],
        fps => { "2592x1944" => [30], "1296x960" => [30] },
    },
    "ov5695" => {
        res => ["2592x1944", "1920x1080", "1296x972", "1280x720", "640x480"],
        fps => { "2592x1944" => [30], "1920x1080" => [30], "1296x972" => [60], "1280x720" => [30], "640x480" => [120] },
    },
    "ov8858" => {
        res => ["3264x2448", "1632x1224"],
        fps => { "3264x2448" => [30, 15], "1632x1224" => [30] },
    },
    "ox03c10" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30] },
    },
    "s5k4h5yb" => {
        res => ["2688x1520"],
        fps => { "2688x1520" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "s5k5e9" => {
        res => ["2592x1944"],
        fps => { "2592x1944" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "s5kjn1" => {
        res => ["8128x6144", "4080x3072"],
        fps => { "8128x6144" => [10], "4080x3072" => [30] },
    },
    "sc031gs" => {
        res => ["640x480"],
        fps => { "640x480" => [30] },
    },
    "sc230ai" => {
        res => ["1920x1080", "640x480"],
        fps => { "1920x1080" => [25], "640x480" => [120] },
    },
    "sc231hai" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [60] },
    },
    "sc301iot" => {
        res => ["2048x1536", "1536x1536"],
        fps => { "2048x1536" => [30], "1536x1536" => [30] },
    },
    "sc3336" => {
        res => ["2304x1296"],
        fps => { "2304x1296" => [30, 25] },
    },
    "sc3338" => {
        res => ["2304x1296"],
        fps => { "2304x1296" => [25] },
    },
    "sc401ai" => {
        res => ["2560x1440"],
        fps => { "2560x1440" => [30] },
    },
    "sc4336" => {
        res => ["2560x1440"],
        fps => { "2560x1440" => [25] },
    },
    "sc500ai" => {
        res => ["2880x1620"],
        fps => { "2880x1620" => [30] },
    },
    "sc501ai" => {
        res => ["2880x1616"],
        fps => { "2880x1616" => [30] },
    },
    "sc530ai" => {
        res => ["2880x1620"],
        fps => { "2880x1620" => [30] },
    },
    "sp250a" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30] },
        note => "驱动不在内核树, 能力为通用估计",
    },
    "jx_f37" => {
        res => ["1920x1080"],
        fps => { "1920x1080" => [30, 15] },
    },
    "jx_h62" => {
        res => ["1280x720"],
        fps => { "1280x720" => [30] },
    },
    "jx_h65" => {
        res => ["1280x960", "1280x720"],
        fps => { "1280x960" => [30], "1280x720" => [30] },
    },
);

# 识别"喂给 $dev 的"active sensor 型号 (双目/多目按 rkcif-mipi-lvds<N> 实例区分)
# 1) 在含 $dev 的 media 图中找 ISP 输入实体 (rkcif-mipi-lvds<N>);
# 2) 在与该实体同图的 media 节点中匹配 Sensor 实体 (避免取到另一路 sensor)
sub detect_sensor_model {
    my ($dev) = @_;

    my $lvds = "";
    for my $mn (grep { -e $_ } glob "/dev/media*") {
        my $t = sh("media-ctl -d $mn -p 2>/dev/null");
        next unless $t =~ /device node name\s+\Q$dev\E/;
        if ($t =~ /rkisp-isp-subdev[\s\S]*?<- "([^"]+)"\s*:\d+\s*\[ENABLED\]/) {
            my $in = $1;
            $in =~ s/\s+$//;
            $lvds = $in if $in =~ /rkcif-mipi-lvds/;
        }
        last if $lvds;
    }

    for my $mn (grep { -e $_ } glob "/dev/media*") {
        my $t = sh("media-ctl -d $mn -p 2>/dev/null");
        next unless $t =~ /type V4L2 subdev subtype Sensor/i;
        # 限定到该 lvds 实例 (用 bus info platform:rkcif-mipi-lvds<N> 精确定位整行, 避免误配 lvds2)
        my $businfo = $lvds ne "" ? "platform:${lvds}" : "";
        next if $businfo ne "" && $t !~ /bus info\s+\Q$businfo\E\s*$/m;
        # 提取所有实体名 (到 '(' 之前), 逐个匹配能力库型号
        while ($t =~ /^-\s*entity\s+\d+:\s*([^(\n]+)\s+\(/mg) {
            my $ent = $1;
            $ent =~ s/\s+$//;
            for my $model (sort { length($b) <=> length($a) } keys %SENSOR_CAPS) {
                return ($model, $ent) if $ent =~ /\Q$model\E/i;
            }
        }
    }
    return ("", "");
}

# 判断能力库中是否有该 sensor
sub sensor_caps {
    my ($model) = @_;
    return $SENSOR_CAPS{$model} || undef;
}

# ==============================================================================
# 帧率枚举 (按源类型, 杜绝假象)
# ==============================================================================
# 按分辨率提取该分辨率下的帧率集合 (v4l2-ctl --list-formats-ext 中,
# "Size: Discrete WxH" 之后到下一个 Size 之前的 Interval 属于该分辨率)
sub fps_for_size {
    my ($out, $w, $h) = @_;
    my @fps;
    my $cur_size = "";
    for my $ln (split /\n/, $out) {
        if ($ln =~ /Size:\s+Discrete\s+(\d+)x(\d+)/) {
            $cur_size = "$1x$2";
        } elsif ($ln =~ /Size:\s+Stepwise\s+\S+\s+-\s+(\d+)x(\d+)/) {
            $cur_size = "";   # Stepwise 无逐分辨率 Interval, 不归属
        } elsif ($ln =~ /\(([\d.]+)\s*fps\)/ && $cur_size eq "${w}x${h}") {
            my $f = int($1 + 0.5);
            push @fps, $f if $f > 0;
        }
    }
    # 去重降序
    my %seen;
    my @uniq = grep { !$seen{$_}++ } @fps;
    return sort { $b <=> $a } @uniq;
}

sub enum_fps {
    my ($dev, $size) = @_;
    my $info = detect_source_type($dev);
    my $type = $info->{type};
    my ($sw, $sh) = $size && $size =~ /^(\d+)x(\d+)$/ ? ($1, $2) : (0, 0);

    my @fps;

    if ($type eq "isp" || $type eq "cif") {
        # CIF 是 sensor raw 通道, 帧率由 sensor 模式决定, 同样走能力库 (真实能力, 非假枚举)
        my ($model, $ent) = detect_sensor_model($dev);
        my $caps = sensor_caps($model);

        if ($caps) {
            # 能力库模式: 按 sensor 型号返回真实支持帧率 (杜绝假象)
            if ($sw && $sh) {
                my $key = "${sw}x${sh}";
                # 采集分辨率可能是 ISP scaler 缩放值, 对齐到 sensor 原生分辨率
                my @fps_list = @{ $caps->{fps}{$key} || [] };
                unless (@fps_list) {
                    # ISP scaler 从 sensor 当前 mode 缩放: 沿用面积最大的原生分辨率帧率
                    # (避免错误匹配到低分辨率高帧率 mode, 如 1344x760@120)
                    my ($best_key, $best_area) = ("", -1);
                    for my $rk (keys %{ $caps->{fps} }) {
                        my ($rw, $rh) = split /x/, $rk;
                        my $area = $rw * $rh;
                        if ($area > $best_area) { $best_area = $area; $best_key = $rk; }
                    }
                    @fps_list = @{ $caps->{fps}{$best_key} || [] };
                }
                push @fps, { fps => $_, supported => 1, current => 0,
                             note => "sensor ${model} ${key} 能力" } for @fps_list;
            } else {
                # 无指定分辨率: 汇总该 sensor 所有支持帧率
                my %seen;
                for my $rk (keys %{ $caps->{fps} }) {
                    push @fps, { fps => $_, supported => 1, current => 0,
                                 note => "sensor ${model} ${rk} 能力" }
                        for grep { !$seen{$_}++ } @{ $caps->{fps}{$rk} };
                }
            }
        } else {
            # 无能力库: 从 media-ctl 读当前实际帧率 (真实当前值), 其余标记候选
            my $cur = 0;
            for my $mn (grep { -e $_ } glob "/dev/media*") {
                my $t = sh("media-ctl -d $mn -p 2>/dev/null");
                next unless $t =~ /device node name\s+\Q$dev\E/;
                if ($t =~ /@(\d+)\/(\d+)/) {
                    my ($num, $den) = ($1, $2);
                    $cur = int($den / $num + 0.5) if $den > 0 && $num > 0;
                }
                last;
            }
            if ($cur > 0) {
                push @fps, { fps => $cur, supported => 1, current => 1, note => "sensor 当前实际帧率" };
            }
            push @fps, { fps => $_, supported => 0, current => 0, note => "候选未验证" }
                for grep { $_ != $cur } (30, 60, 25, 15);
        }

        # 标记当前生效帧率 (从 media-ctl 读当前值)
        my $cur = 0;
        for my $mn (grep { -e $_ } glob "/dev/media*") {
            my $t = sh("media-ctl -d $mn -p 2>/dev/null");
            next unless $t =~ /device node name\s+\Q$dev\E/;
            if ($t =~ /@(\d+)\/(\d+)/) {
                my ($num, $den) = ($1, $2);
                $cur = int($den / $num + 0.5) if $den > 0 && $num > 0;
            }
            last;
        }
        if ($cur > 0) {
            for my $f (@fps) {
                if ($f->{fps} == $cur) { $f->{current} = 1; $f->{note} .= " (当前)"; }
            }
        }
    } elsif ($type eq "uvc") {
        # UVC: 按分辨率枚举 Interval (真实)
        my $out = sh("v4l2-ctl -d $dev --list-formats-ext 2>/dev/null");
        my @list;
        if ($sw && $sh) {
            @list = fps_for_size($out, $sw, $sh);
        } else {
            my %seen;
            while ($out =~ /\(([\d.]+)\s*fps\)/g) {
                my $f = int($1 + 0.5);
                $seen{$f} = 1 if $f > 0;
            }
            @list = sort { $b <=> $a } keys %seen;
        }
        push @fps, { fps => $_, supported => 1, current => 0 } for @list;
        @fps = ({ fps => 30, supported => 1, current => 0, note => "UVC 默认" }) unless @fps;
    } elsif ($type =~ /^hdmi/) {
        # HDMI-IN: 固定输入时序
        my $fmt = sh("v4l2-ctl -d $dev --get-fmt-video 2>/dev/null");
        my $f = 0;
        if ($fmt =~ /Width\/Height\s*:\s*(\d+)\/(\d+)/) {
            my ($fw, $fh) = ($1, $2);
            if ($sw && $sh && $fw == $sw && $fh == $sh) { $f = 30; }
        }
        push @fps, { fps => $f || 30, supported => 1, current => 1, note => "hdmi 固定时序" };
    } else {
        # generic: 尝试 v4l2-ctl Interval, 否则常见帧率标记未验证
        my $out = sh("v4l2-ctl -d $dev --list-formats-ext 2>/dev/null");
        my @list;
        if ($sw && $sh) {
            @list = fps_for_size($out, $sw, $sh);
        } else {
            while ($out =~ /\(([\d.]+)\s*fps\)/g) {
                my $f = int($1 + 0.5);
                push @list, $f if $f > 0;
            }
        }
        if (@list) {
            push @fps, { fps => $_, supported => 1, current => 0 } for @list;
        } else {
            push @fps, { fps => $_, supported => 0, current => 0, note => "未验证" } for (30, 25, 60, 15);
        }
    }

    @fps = sort { $b->{fps} <=> $a->{fps} } @fps;
    my %ret = (type => $type, device => $dev, fps => \@fps);
    $ret{size} = $size if $size;
    return \%ret;
}

# ==============================================================================
# 分辨率枚举 (按源类型)
# ==============================================================================
sub enum_res {
    my ($dev) = @_;
    my $info = detect_source_type($dev);
    my $type = $info->{type};

    my @res;
    my $maxw = 0;
    my $maxh = 0;

    my $out = sh("v4l2-ctl -d $dev --list-formats-ext 2>/dev/null");

    # 收集 Discrete
    while ($out =~ /Size:\s+Discrete\s+(\d{2,5})x(\d{2,5})/g) {
        push @res, "$1x$2";
    }
    # 收集 Stepwise 最大
    while ($out =~ /Size:\s+Stepwise\s+\S+\s+-\s+(\d{2,5})x(\d{2,5})/g) {
        $maxw = $1 if $1 > $maxw;
        $maxh = $2 if $2 > $maxh;
    }

    my @order = ("3840x2160", "2560x1440", "1920x1080", "1280x720",
                 "960x540", "640x480", "480x800", "800x480");
    my %have = map { $_ => 1 } @res;

    if ($type eq "hdmi_in") {
        # HDMI-IN: 固定输入分辨率 (无缩放选择)
        my $fmt = sh("v4l2-ctl -d $dev --get-fmt-video 2>/dev/null");
        if ($fmt =~ /Width\/Height\s*:\s*(\d+)\/(\d+)/) {
            @res = ("$1x$2");
            return { type => $type, device => $dev, res => \@res, max => "$1x$2", fixed => 1 };
        }
    }

    # 标准表筛选 (Stepwise 上限内 或 Discrete 出现)
    my @filtered;
    for my $r (@order) {
        my ($w, $h) = split /x/, $r;
        if ($have{$r}) {
            push @filtered, $r;
        } elsif ($maxw && $maxh && $w <= $maxw && $h <= $maxh) {
            push @filtered, $r;
        }
    }
    # 补全 Discrete 中未覆盖的
    for my $r (@res) {
        push @filtered, $r unless grep { $_ eq $r } @filtered;
    }

    # ISP: 附加 sensor 原生分辨率 (来自能力库, 供 webui 标注真实能力)
    my $sensor_model = "";
    my @native_res;
    if ($type eq "isp") {
        (my $model, undef) = detect_sensor_model($dev);
        $sensor_model = $model;
        my $caps = sensor_caps($model);
        if ($caps) {
            @native_res = @{ $caps->{res} || [] };
            # 确保原生分辨率在列表中
            for my $nr (@native_res) {
                push @filtered, $nr unless grep { $_ eq $nr } @filtered;
            }
        }
    }

    return {
        type => $type, device => $dev, res => \@filtered,
        max => ($maxw && $maxh) ? "${maxw}x${maxh}" : "",
        sensor => $sensor_model, native_res => \@native_res,
    };
}

# ==============================================================================
# DRM 多模式枚举
# ==============================================================================
sub enum_drm {
    my @connectors;
    my @ids;

    my $mt = sh("modetest -M rockchip -c 2>/dev/null");
    $mt = sh("modetest -c 2>/dev/null") unless $mt;

    if ($mt) {
        my $cur_conn = undef;
        for my $ln (split /\n/, $mt) {
            if ($ln =~ /^\s*(\d+)\s+\d+\s+(connected|disconnected|unknown)\s+(\S+)/) {
                my ($id, $status, $name) = ($1, $2, $3);
                push @ids, $id;
                $cur_conn = { id => $id, name => $name, status => $status, modes => [] };
                push @connectors, $cur_conn;
            } elsif ($ln =~ /^\s*#\d+\s+(\d+)x(\d+)\s+([\d.]+)/ && $cur_conn) {
                push @{ $cur_conn->{modes} }, { w => $1, h => $2, refresh => $3, res => "$1x$2" };
            }
        }
    } else {
        # 回退: /sys/class/drm
        for my $e (sort grep { /^card\d+-/ } do { opendir my $dh, "/sys/class/drm"; readdir $dh; closedir $dh; () }) {
            my $status = sh("cat /sys/class/drm/$e/status 2>/dev/null");
            chomp $status;
            my ($name) = $e =~ /^card\d+-(.*)$/;
            my @modes = grep { $_ } split /\n/, sh("cat /sys/class/drm/$e/modes 2>/dev/null");
            push @connectors, { name => $name, status => $status || "unknown", modes => [ map { { res => $_, w => (/^(\d+)/ ? $1 : 0), h => (/x(\d+)/ ? $1 : 0) } } @modes ] };
        }
    }

    # 提取所有唯一模式 (供 webui 分辨率下拉)
    my %mode_seen;
    my @all_modes;
    for my $c (@connectors) {
        next unless $c->{status} eq "connected";
        for my $m (@{ $c->{modes} }) {
            next unless $m->{res};
            my $label = $m->{refresh} ? $m->{res} . "@" . int($m->{refresh}) : $m->{res};
            $mode_seen{$label} = 1 unless $mode_seen{$label};
        }
    }
    for my $m (sort keys %mode_seen) {
        push @all_modes, { value => $m, label => $m };
    }

    return { connectors => \@connectors, ids => \@ids, modes => \@all_modes };
}

# ==============================================================================
# 设备树属性读取与 iqfile 定位 (HDR 开关依赖)
# ==============================================================================
sub read_dt_prop {
    my ($path) = @_;
    my $v = sh("cat \"$path\" 2>/dev/null | tr -d '\\000'");
    $v =~ s/^\s+//;
    $v =~ s/\s+$//;
    return $v;
}

# 根据 sensor 型号 + 媒体实体名 (如 "m00_b_sc450ai 3-0030-1") 定位设备树 camera 节点
sub find_camera_dt_node {
    my ($model, $ent) = @_;
    my ($bus, $addr, $idx);
    if ($ent =~ /(\d+)-([0-9a-fA-F]+)(?:-(\d+))?\s*$/) {
        ($bus, $addr, $idx) = ($1, $2, $3);
    }
    my $addr_hex = lc(sprintf("%x", hex($addr || "0")));
    for my $i2c (glob "/proc/device-tree/i2c@*") {
        next unless -d $i2c;
        for my $node (glob "$i2c/*") {
            next unless -d $node;
            my $base = $node;
            $base =~ s{^.*/}{};
            # 节点名支持 model / model_N(模块索引, 如 imx415_0@37) / model-N
            next unless $base =~ /^([A-Za-z0-9_]+?)(?:_\d+)?(?:-\d+)?\@([0-9a-fA-F]+)$/;
            my ($nm, $ad) = ($1, lc($2));
            $nm =~ s/_\d+$//;
            $nm =~ s/-\d+$//;
            next unless lc($nm) eq lc($model);
            next unless $ad eq $addr_hex;
            if (defined $idx && $idx ne "") {
                next unless $base =~ /-$idx\@/;
            }
            return $node;
        }
    }
    return "";
}

# 读取 iqfile 的 sensor_calib.CISHdrSet.hdr_en / hdr_mode (逐行扫描, 避免解析超大 JSON)
sub read_iqfile_hdr {
    my ($iqfile) = @_;
    return (undef, undef) unless defined $iqfile && -f $iqfile;
    open my $fh, '<', $iqfile or return (undef, undef);
    my ($hdr_en, $hdr_mode);
    while (my $ln = <$fh>) {
        if (!defined $hdr_en && $ln =~ /"hdr_en"\s*:\s*(\d+)/) {
            $hdr_en = $1;
        }
        if (!defined $hdr_mode && $ln =~ /"hdr_mode"\s*:\s*"([^"]+)"/) {
            $hdr_mode = $1;
        }
        last if defined $hdr_en && defined $hdr_mode;
    }
    close $fh;
    return (defined $hdr_en ? $hdr_en + 0 : undef, $hdr_mode);
}

# 就地修改 iqfile 的 hdr_en (保留文件原格式, 不做整份 JSON 重写)
sub set_iqfile_hdr {
    my ($iqfile, $value) = @_;
    return (0, "iqfile 不存在") unless -f $iqfile;

    open my $fh, '<', $iqfile or return (0, "无法打开: $!");
    local $/;
    my $raw = <$fh>;
    close $fh;

    return (0, "未找到 hdr_en 字段") unless $raw =~ /"hdr_en"\s*:\s*\d+/;

    my $bak = "$iqfile.hdr_bak";
    $bak = "$iqfile.hdr_bak." . time if -f $bak;
    my $cp = system("cp -a \"$iqfile\" \"$bak\"");
    return (0, "备份失败") if $cp != 0;

    $raw =~ s/("hdr_en"\s*:\s*)\d+/$1$value/;

    open my $out, '>', $iqfile or return (0, "无法写入: $!");
    print $out $raw;
    close $out;

    return (1, $bak);
}

# 设备 -> sensor 型号 + 设备树 module/lens -> 完整 iqfile 路径 + hdr 状态
sub iqfile_for_device {
    my ($dev) = @_;
    return { error => "device $dev not given" } unless $dev;
    my $vnode = $dev;
    $vnode =~ s{^/dev/}{};
    return { error => "device $dev 不存在" } unless -e "/sys/class/video4linux/$vnode";

    my ($model, $ent) = detect_sensor_model($dev);
    return { sensor => "", entity => "", error => "sensor 未识别" } unless $model;

    my $node = find_camera_dt_node($model, $ent);
    return { sensor => $model, entity => $ent, error => "设备树 camera 节点未找到" } unless $node;

    my $module = read_dt_prop("$node/rockchip,camera-module-name");
    my $lens   = read_dt_prop("$node/rockchip,camera-module-lens-name");

    my @parts = ($model);
    push @parts, $module if $module ne "";
    push @parts, $lens   if $lens ne "";
    my $iqfile = "/etc/iqfiles/" . join("_", @parts) . ".json";

    my ($hdr_en, $hdr_mode) = read_iqfile_hdr($iqfile);

    return {
        sensor   => $model,
        entity   => $ent,
        module   => $module,
        lens     => $lens,
        iqfile   => $iqfile,
        exists   => (-f $iqfile) ? 1 : 0,
        hdr_en   => $hdr_en,
        hdr_mode => $hdr_mode,
    };
}

# 实测当前实际帧率:
#   media 拓扑 @num/den 只是 sensor 标称帧率 (HDR 开关都显示 30),
#   实际出帧率由 3A 驱动 (如 sc450ai HDR 开时实际仅 25fps),
#   因此需真实抓 N 帧: v4l2-ctl --stream-mmap 会在 stderr 打印平均 "NN.NN fps".
#   设备被占用(服务运行中)抓帧失败时, 回退按 HDR 状态 + 能力库推导.
sub actual_fps {
    my ($dev, $size, $frames) = @_;
    my $count = ($frames && $frames > 0) ? $frames : 60;

    my $out = `v4l2-ctl -d $dev --stream-mmap --stream-count=$count --stream-to=/dev/null 2>&1`;
    my @fpsm = ($out =~ /([\d.]+)\s*fps/g);
    my $fps  = @fpsm ? nearest_nominal($fpsm[-1]) : 0;
    my $method = $fps ? "measured" : "";

    # 回退: 设备被占用(服务运行中)无法抓帧时, 用 media 拓扑标称值 (该设备标称与实测一致)
    if (!$fps) {
        for my $mn (grep { -e $_ } glob "/dev/media*") {
            my $t = sh("media-ctl -d $mn -p 2>/dev/null");
            next unless $t =~ /device node name\s+\Q$dev\E/;
            if ($t =~ /@(\d+)\/(\d+)/) {
                my ($num, $den) = ($1, $2);
                $fps = int($den / $num + 0.5) if $den > 0 && $num > 0;
            }
            last;
        }
        $method = "nominal";
    }

    return {
        device => $dev,
        size   => $size,
        fps    => $fps,
        method => $method,
        count  => $count,
    };
}

# 就近归纳到标准帧率 (29.4->30, 25.x->25; 避免输出 29/24 这类非标值)
sub nearest_nominal {
    my ($f) = @_;
    $f += 0;
    my @nom = (120, 90, 60, 50, 30, 25, 20, 15, 10, 5);
    my ($best, $bd) = ($nom[0], abs($f - $nom[0]));
    for my $n (@nom) {
        my $d = abs($f - $n);
        if ($d < $bd) { $bd = $d; $best = $n; }
    }
    return $best;
}

# 从所有 media 拓扑定位 sensor 实体的 subdev 设备节点 (/dev/v4l-subdevN)
sub find_subdev_node {
    my ($ent) = @_;
    for my $mn (grep { -e $_ } glob "/dev/media*") {
        my $t = sh("media-ctl -d $mn -p 2>/dev/null");
        for my $b (split(/^- entity /m, $t)) {
            next unless $b =~ /^\d+:\s*([^\n(]+?)\s+\(/;
            my $ename = $1;
            $ename =~ s/\s+$//;
            next unless $ename =~ /\Q$ent\E/;
            return $1 if $b =~ /device node name\s+(\/dev\/v4l-subdev\d+)/;
        }
    }
    return "";
}

# 读取 sensor 实体当前模式分辨率 (从 media 拓扑, 如 "1344x760")
sub sensor_fmt_now {
    my ($ent) = @_;
    for my $mn (grep { -e $_ } glob "/dev/media*") {
        my $t = sh("media-ctl -d $mn -p 2>/dev/null");
        for my $b (split(/^- entity /m, $t)) {
            next unless $b =~ /^\d+:\s*([^\n(]+?)\s+\(/ && $1 =~ /\Q$ent\E/;
            return "$1x$2" if $b =~ /\/(\d+)x(\d+)(?:@|$)/;
        }
    }
    return "";
}

# 读取 ISP mainpath 实际输出分辨率 (从 v4l2-ctl --get-fmt-video, 如 "2560x1440")
sub mainpath_fmt_now {
    my ($dev) = @_;
    my $out = sh("v4l2-ctl -d $dev --get-fmt-video 2>/dev/null");
    return "$1x$2" if $out =~ /Width\s*\/\s*Height\s*:\s*(\d+)\s*\/\s*(\d+)/;
    return "";
}

# ==============================================================================
# ISP 分辨率/帧率设定 (conf 为指导值): --set-isp DEV --size WxH --fps N
# 仅当目标帧率精确匹配能力库原生模式时才切 sensor 模式 (如 120->1344x760, 30/25->2688x1520);
# 目标帧率非原生模式时不切, 仅设 ISP mainpath 输出, 交给后续实测校正.
# 设定后回读校验 (CLIENT_CAP 探测告警为良性, 以实际模式为准).
# ==============================================================================
sub set_isp_fmt {
    my ($dev, $size, $fps) = @_;
    my ($w, $h) = $size =~ /^\s*(\d+)\s*[xX*]\s*(\d+)\s*$/ ? ($1 + 0, $2 + 0) : (0, 0);
    return { ok => 0, error => "size 格式须为 WxH" } unless $w > 0 && $h > 0;
    return { ok => 0, error => "fps 缺失或非法" } unless defined $fps && $fps > 0;

    my ($model, $ent) = detect_sensor_model($dev);
    return { ok => 0, error => "sensor 未识别" } unless $model;
    my $caps = sensor_caps($model);
    return { ok => 0, sensor => $model, error => "能力库无该 sensor: $model" } unless $caps;

    # 1. 精确匹配目标帧率的 sensor 原生模式 (无精确匹配则不切换, 交由实测校正)
    #    同一帧率可能对应多个原生模式(如 imx415 30fps 对应 3864x2192 与 1944x1097),
    #    必须按与请求分辨率面积最接近者确定, 避免 Perl 哈希 keys 无序迭代导致随机选择
    my $smode = "";
    my $req_area = $w * $h;
    my $best_diff = -1;
    for my $rk (keys %{ $caps->{fps} }) {
        next unless grep { $_ == $fps } @{ $caps->{fps}{$rk} };
        my ($rw, $rh) = split /x/, $rk;
        next unless $rw && $rh;
        my $diff = abs($rw * $rh - $req_area);
        if ($best_diff < 0 || $diff < $best_diff) {
            $best_diff = $diff;
            $smode = $rk;
        }
    }

    # 1.5 分辨率上限: ISP 输出不能超过 sensor 原生最大 (只能下缩放), 超限则校正 (如 4K 请求)
    my $sw_max = 0; my $sh_max = 0;
    for my $rk (@{ $caps->{res} || [] }) {
        my ($rw, $rh) = split /x/, $rk;
        ($sw_max, $sh_max) = ($rw, $rh) if $rw * $rh > $sw_max * $sh_max;
    }
    my $corr_res = "";
    if ($sw_max > 0 && $sh_max > 0 && ($w > $sw_max || $h > $sh_max)) {
        my $cw = ($w > $sw_max) ? $sw_max : $w;
        my $ch = ($h > $sh_max) ? $sh_max : $h;
        $corr_res = "${cw}x${ch}";
        print STDERR "⚠️ 请求 ${size} 超出 sensor 原生 (${sw_max}x${sh_max}), 校正为 ${cw}x${ch}\n";
        ($w, $h) = ($cw, $ch);
    }

    my ($subdev, $sensor_ok, $actual_res) = ("", 0, "");
    my $mode_before = $smode ? sensor_fmt_now($ent) : "";

    # 2. 先切 sensor 原生模式 (顺序关键: 须让 CIF/ISP 输入先就绪, 再设 mainpath 输出.
    #    反向顺序会让 ISP 按旧输入(如 2560x1440)计算输出配置, STREAMON 触发
    #    CIF_ISP_PIC_SIZE_ERROR -> EINVAL, 且 sensor 可能停在 ~60fps 而非目标 120fps)
    if ($smode) {
        my ($sw, $sh) = split /x/, $smode;
        $subdev = find_subdev_node($ent);
        if ($subdev) {
            # 设 sensor 模式 (code 0x2007 = SBGGR10_1X10, sc450ai 2-lane raw)
            sh("v4l2-ctl -d $subdev --set-subdev-fmt pad=0,width=${sw},height=${sh},code=0x2007 2>&1");
            sleep 2;   # 模式切换过渡期 (120fps 模式切换后给足稳定时间, 避免旧 VTS 滞留)
            # 回读校验
            $actual_res = sensor_fmt_now($ent);
            $sensor_ok = ($actual_res eq $smode) ? 1 : 0;
        }
    }

    # 3. 设 ISP mainpath 输出分辨率 (始终, sensor 已就绪后用校正后值)
    my $r2 = sh("v4l2-ctl -d $dev --set-fmt-video=width=${w},height=${h},pixelformat=NV12 2>&1");
    # 回读 mainpath 实际输出分辨率 (rkisp 可能钳制到 sensor 能力范围, 供分辨率校正)
    my $actual_out = mainpath_fmt_now($dev);

    return {
        ok           => 1,
        native       => $smode ? 1 : 0,
        # sensor 模式是否真的变化 (供上层判断是否需要重启 rkaiq_3A 重新初始化)
        changed      => ($smode && $sensor_ok && $mode_before && $mode_before ne $actual_res) ? 1 : 0,
        sensor       => $model,
        sensor_mode  => $smode || "",
        sensor_ok    => $sensor_ok,
        actual_sensor_res => $actual_res,
        corrected_res => $corr_res,
        actual_res   => $actual_out,
        target_res   => "${w}x${h}",
        target_fps   => $fps,
        subdev       => $subdev,
        set_isp      => ($r2 =~ /not|failed|Unable|error/i ? 0 : 1),
        note         => $smode ? "" : "目标帧率 ${fps}fps 非 sensor 原生模式, 沿用当前模式并实测校正",
    };
}


# ==============================================================================
# 枚举所有激活的 sensor (多 sensor 支持) 及其 iqfile/HDR 信息
# ==============================================================================
sub list_sensors {
    my @sensors;
    for my $mn (grep { -e $_ } glob "/dev/media*") {
        my $t = sh("media-ctl -d $mn -p 2>/dev/null");
        next unless $t =~ /type V4L2 subdev subtype Sensor/i;
        while ($t =~ /^-\s*entity\s+\d+:\s*([^(\n]+)\s+\(/mg) {
            my $ent = $1;
            $ent =~ s/\s+$//;
            for my $model (sort { length($b) <=> length($a) } keys %SENSOR_CAPS) {
                if ($ent =~ /\Q$model\E/i) {
                    my $dup = 0;
                    for my $s (@sensors) { $dup = 1 if $s->{entity} eq $ent; }
                    push @sensors, { model => $model, entity => $ent } unless $dup;
                    last;
                }
            }
        }
    }

    my @out;
    for my $s (@sensors) {
        my $node   = find_camera_dt_node($s->{model}, $s->{entity});
        my $module = $node ? read_dt_prop("$node/rockchip,camera-module-name") : "";
        my $lens   = $node ? read_dt_prop("$node/rockchip,camera-module-lens-name") : "";
        my @parts = ($s->{model});
        push @parts, $module if $module ne "";
        push @parts, $lens   if $lens ne "";
        my $iqfile = "/etc/iqfiles/" . join("_", @parts) . ".json";
        my ($hdr_en, $hdr_mode) = read_iqfile_hdr($iqfile);
        push @out, {
            sensor   => $s->{model},
            entity   => $s->{entity},
            module   => $module,
            lens     => $lens,
            iqfile   => $iqfile,
            exists   => (-f $iqfile) ? 1 : 0,
            hdr_en   => $hdr_en,
            hdr_mode => $hdr_mode,
        };
    }
    return { sensors => \@out };
}

# ==============================================================================
# 主流程
# ==============================================================================
if ($opt{version}) {
    print "capture-enum.pl " . VERSION . "\n";
    exit 0;
} elsif ($opt{detect_type}) {
    print $json->encode(detect_source_type($opt{detect_type}));
} elsif ($opt{source_fps}) {
    print $json->encode(enum_fps($opt{source_fps}, $opt{size}));
} elsif ($opt{source_res}) {
    print $json->encode(enum_res($opt{source_res}));
} elsif ($opt{source_all}) {
    my %r;
    $r{source} = detect_source_type($opt{source_all});
    $r{fps}    = enum_fps($opt{source_all}, $opt{size});
    $r{res}    = enum_res($opt{source_all});
    print $json->encode(\%r);
} elsif ($opt{drm}) {
    print $json->encode(enum_drm());
} elsif ($opt{actual_fps}) {
    print $json->encode(actual_fps($opt{actual_fps}, $opt{size}, $opt{frames}));
} elsif ($opt{set_isp}) {
    print $json->encode(set_isp_fmt($opt{set_isp}, $opt{size}, $opt{fps}));
} elsif ($opt{sensors}) {
    print $json->encode(list_sensors());
} elsif ($opt{iqfile}) {
    print $json->encode(iqfile_for_device($opt{iqfile}));
} elsif ($opt{set_hdr_path}) {
    # 直接修改指定 iqfile (多 sensor 场景)
    my $val = defined $opt{hdr_value} ? $opt{hdr_value} : -1;
    if ($val != 0 && $val != 1) {
        print $json->encode({ ok => 0, error => "hdr-value 必须是 0 或 1" });
    } elsif (!-f $opt{set_hdr_path}) {
        print $json->encode({ ok => 0, error => "iqfile 不存在: $opt{set_hdr_path}" });
    } else {
        my ($ok, $bak) = set_iqfile_hdr($opt{set_hdr_path}, $val);
        my ($hdr_en, $hdr_mode) = read_iqfile_hdr($opt{set_hdr_path});
        print $json->encode({
            ok      => $ok,
            error   => $ok ? undef : $bak,
            iqfile  => $opt{set_hdr_path},
            hdr_en  => $hdr_en,
            hdr_mode => $hdr_mode,
            backup  => $ok ? $bak : undef,
        });
    }
} elsif ($opt{set_hdr}) {
    my $info = iqfile_for_device($opt{set_hdr});
    my $val  = defined $opt{hdr_value} ? $opt{hdr_value} : -1;
    if (!$info->{iqfile}) {
        print $json->encode({ ok => 0, error => $info->{error} });
    } elsif ($val != 0 && $val != 1) {
        print $json->encode({ ok => 0, error => "hdr-value 必须是 0 或 1" });
    } else {
        my ($ok, $bak) = set_iqfile_hdr($info->{iqfile}, $val);
        my ($hdr_en, $hdr_mode) = read_iqfile_hdr($info->{iqfile});
        print $json->encode({
            ok      => $ok,
            error   => $ok ? undef : $bak,
            iqfile  => $info->{iqfile},
            hdr_en  => $hdr_en,
            hdr_mode => $hdr_mode,
            backup  => $ok ? $bak : undef,
        });
    }
} else {
    print "用法: $0 [--detect-type DEV] [--source-fps DEV] [--source-res DEV] [--source-all DEV] [--drm] [--size WxH] [--actual-fps DEV] [--iqfile DEV] [--set-hdr DEV --hdr-value 0|1]\n";
    exit 1;
}
