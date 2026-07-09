#!/usr/bin/perl
#
# test_scan_displays.pl - 枚举 DRM 显示设备并测试智能选择逻辑
#
# 用法: ./test_scan_displays.pl [目标宽度] [目标高度]
# 示例: ./test_scan_displays.pl 480 800
#
use strict;
use warnings;

my ($target_w, $target_h) = @ARGV;
$target_w //= 480;
$target_h //= 800;

print "=" x 60, "\n";
print "DRM 显示设备枚举\n";
print "目标分辨率: ${target_w}x${target_h}\n";
print "=" x 60, "\n\n";

# ======================================================================
# 第 1 步: 从 DRM state 文件建立 connector 名称 → ID 映射
# ======================================================================
print "--- 1. 读取 DRM state 提取 connector ID 映射 ---\n";
my %conn_id_by_name;  # name => id
my $dri_dirs = [];

opendir(my $dh, "/sys/kernel/debug/dri") or warn "⚠️ 无法访问 /sys/kernel/debug/dri: $!";
if ($dh) {
    while(my $d = readdir($dh)) {
        next unless $d =~ /^\d+$/;
        my $state_file = "/sys/kernel/debug/dri/$d/state";
        next unless -r $state_file;
        my $state = `cat $state_file 2>/dev/null`;
        next unless defined $state;
        # 提取 connector 块: connector[ID]: NAME \n crtc=CRTC_ID
        while($state =~ /^connector\[(\d+)\]:\s*(\S+).*?\ncrtc=(\S+)/gms) {
            my ($cid, $cname, $ccrtc) = ($1, $2, $3);
            $conn_id_by_name{$cname} = $cid;
            print "   connector[$cid] = $cname  (crtc=$ccrtc)\n";
        }
    }
    closedir($dh);
}
print "   名称→ID映射: " . (keys %conn_id_by_name ? "✅ 成功" : "⚠️ 空") . "\n\n";

# ======================================================================
# 第 2 步: 扫描 /sys/class/drm 枚举所有 connector
# ======================================================================
print "--- 2. 扫描 /sys/class/drm 枚举 connector ---\n";
my @connectors;

opendir($dh, "/sys/class/drm") or die "❌ 无法访问 /sys/class/drm: $!";
my @entries = readdir($dh);
closedir($dh);

for my $entry (sort @entries) {
    next unless $entry =~ /^card\d+-(\S+)$/;
    my $conn_name = $1;   # e.g. "DSI-1", "HDMI-A-1"
    my $base = "/sys/class/drm/$entry";
    
    # 读取状态
    my $status_file = "$base/status";
    next unless -f $status_file;
    my $status = `cat $status_file 2>/dev/null`;
    chomp $status if defined $status;
    
    # 读取分辨率
    my @modes;
    my $modes_file = "$base/modes";
    if (-f $modes_file) {
        open(my $mfh, '<', $modes_file) or next;
        while(my $m = <$mfh>) {
            chomp $m;
            next if $m eq '';
            push @modes, $m;
        }
        close($mfh);
    }
    
    # 从映射获取 connector-id
    my $conn_id = $conn_id_by_name{$conn_name} // -1;
    
    my %conn = (
        name   => $conn_name,
        id     => $conn_id,
        status => $status,
        modes  => \@modes,
        enabled=> ($status && $status eq 'connected') ? 1 : 0,
    );
    push @connectors, \%conn;
    
    printf "   %-15s  id=%-3d  status=%-12s  modes=%s\n",
        $conn_name, $conn_id, ($status // 'unknown'),
        @modes ? join(', ', @modes) : '(none)';
}

print "   共找到 " . scalar(@connectors) . " 个 connector\n\n";

# ======================================================================
# 第 3 步: 智能选择逻辑
# ======================================================================
print "--- 3. 智能选择 display connector ---\n";
print "   目标分辨率: ${target_w}x${target_h}\n\n";

sub try_match_resolution {
    my ($target_w, $target_h, $modes_ref) = @_;
    my @modes = @$modes_ref;
    return undef unless @modes;
    
    my $best_mode = undef;
    my $best_score = -1;
    my $target_area = $target_w * $target_h;
    
    for my $mode (@modes) {
        # 解析 "480x800" 格式
        my ($mw, $mh) = $mode =~ /^(\d+)x(\d+)$/;
        next unless $mw && $mh;
        
        # 评分: 越小越好
        my $area = $mw * $mh;
        my $diff = abs($area - $target_area);
        
        # 完全匹配优先
        if ($mw == $target_w && $mh == $target_h) {
            return { width => $mw, height => $mh, mode => $mode, score => 0, exact => 1 };
        }
        
        my $score = $diff;
        if ($best_score < 0 || $score < $best_score) {
            $best_score = $score;
            $best_mode = { width => $mw, height => $mh, mode => $mode, score => $score, exact => 0 };
        }
    }
    return $best_mode;
}

# 模拟选择
my $selected = undef;
my $reason = '';

# 过滤已连接的 connector
my @connected = grep { $_->{enabled} } @connectors;

if (!@connected) {
    print "   ❌ 没有 connected 的 display connector\n";
    print "   ⚠️ 建议: 禁用显示功能 (no-display-enable)\n";
} else {
    print "   已连接设备: " . join(', ', map { $_->{name} } @connected) . "\n";
    
    # 找第一个能完美匹配目标分辨率的
    for my $c (@connected) {
        my $match = try_match_resolution($target_w, $target_h, $c->{modes});
        if ($match && $match->{exact}) {
            $selected = $c;
            $reason = "完美匹配分辨率 ${target_w}x${target_h}";
            $c->{match} = $match;
            last;
        }
    }
    
    # 没有完美匹配，找最接近的
    if (!$selected) {
        my $best_conn = undef;
        my $best_diff = -1;
        
        for my $c (@connected) {
            my $match = try_match_resolution($target_w, $target_h, $c->{modes});
            next unless $match;
            if ($best_diff < 0 || $match->{score} < $best_diff) {
                $best_diff = $match->{score};
                $best_conn = $c;
                $c->{match} = $match;
            }
        }
        
        if ($best_conn) {
            $selected = $best_conn;
            $reason = sprintf("最近似匹配 %s (差异 %d)", $best_conn->{match}->{mode}, $best_diff);
        } else {
            # fallback: 直接选第一个 connected
            $selected = $connected[0];
            $reason = "降级选择（无分辨率信息）";
        }
    }
    
    if ($selected) {
        print "\n   ✅ 选择结果:\n";
        printf "      connector: %s (id=%d)\n", $selected->{name}, $selected->{id};
        printf "      分辨率:    %s\n", $selected->{match} ? $selected->{match}->{mode} : '(默认)';
        printf "      原因:      %s\n", $reason;
        
        # 给出 GStreamer 命令建议
        my $gst_conn = $selected->{id} > 0 ? " connector-id=$selected->{id}" : "";
        print "\n   💡 kmssink 参数建议:\n";
        print "      kmssink sync=false force-modesetting=false${gst_conn}\n";
        
        # 检查是否需要 swap 宽高（竖屏旋转）
        if ($selected->{match}) {
            my $actual_w = $selected->{match}->{width};
            my $actual_h = $selected->{match}->{height};
            if ($actual_w != $target_w || $actual_h != $target_h) {
                print "\n   ⚠️ 分辨率不匹配，建议调整 DISPLAY_WIDTH/DISPLAY_HEIGHT:\n";
                printf "      DISPLAY_WIDTH=%d  DISPLAY_HEIGHT=%d\n", $actual_w, $actual_h;
            }
        }
    }
}

print "\n" . "=" x 60 . "\n";