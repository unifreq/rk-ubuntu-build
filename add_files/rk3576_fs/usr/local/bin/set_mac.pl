#!/usr/bin/perl

use strict;
use warnings;
use Fcntl qw(:flock);
use Digest::SHA qw(sha256_hex);
use POSIX qw(strftime);
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use File::Copy;
use File::Basename;

my $version = "9.0";

# 命令行参数处理
if (@ARGV < 1 || @ARGV > 2) {
    print "Version: $version\n";
    print "Usage: $0 <network_interface> [id_method]\n";
    print "  id_method: 1 - 直接使用随机数 (默认)\n";
    print "             2 - 尝试硬件ID后使用随机数\n";
    exit 1;
}

# 获取接口名称
my $interface = $ARGV[0];

# 验证接口名称
unless ($interface =~ /^[a-z0-9_-]{1,15}$/i) {
    die "错误：无效的接口名称: $interface\n";
}

# ID生成方法
my $id_method = 1;
if (@ARGV == 2) {
    if ($ARGV[1] eq '1') {
        $id_method = 1;
    } elsif ($ARGV[1] eq '2') {
        $id_method = 2;
    } else {
        die "错误：无效的 ID 生成方法，请使用 1 或 2\n";
    }
}

# 配置文件位置
my $mac_prefix_config = "/etc/mac_prefix.conf";
my $mac_address_config = "/etc/mac_address.conf";
my $lock_file = "/var/lock/set_mac.lock";
my $log_file = "/var/log/set_mac.log";

# 创建必要的目录
make_path(dirname($mac_prefix_config), dirname($mac_address_config), dirname($lock_file), dirname($log_file));

# 打开日志文件
open(my $log_fh, '>>', $log_file) or die "无法打开日志文件: $!";
$log_fh->autoflush(1);  # 自动刷新日志

# 错误处理函数
sub die_with_error {
    my ($msg) = @_;
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    print $log_fh "$timestamp 错误：$msg\n";
    exit 1;
}

# 日志记录函数
sub log_message {
    my ($msg) = @_;
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    print $log_fh "$timestamp $msg\n";
}

# 开始处理
log_message("=== 开始处理接口 $interface ===");

# 文件锁句柄
my $lock_fh;

# MAC地址验证函数
sub validate_mac {
    my ($mac) = @_;
    unless ($mac =~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/) {
        die_with_error("无效的MAC地址格式：$mac");
    }
}

# 获取所有物理以太网接口
sub get_physical_interfaces {
    my @ifaces;
    opendir(my $dh, '/sys/class/net') or die_with_error("无法打开/sys/class/net: $!");
    
    while (my $iface = readdir($dh)) {
        # 过滤虚拟接口
        next if $iface =~ /^(\.|\.\.|lo|docker|virbr|vnet|wlan|wl|ww|tun|tap|br-|veth)/i;
        
        my $device_path = "/sys/class/net/$iface/device";
        if (-e $device_path) {
            push @ifaces, $iface;
        }
    }
    closedir($dh);
    
    return sort @ifaces;
}

# 获取唯一ID
sub get_unique_id {
    my $serial;
    
    if ($id_method == 2) {
        # 方法2: 按顺序尝试获取硬件ID
        log_message("尝试使用硬件ID方法获取唯一ID");
        
        if (-e '/sys/block/mmcblk1/device/cid') {
            open(my $fh, '<', '/sys/block/mmcblk1/device/cid') or warn "无法读取mmcblk1 cid";
            $serial = <$fh>;
            close($fh);
            chomp($serial);
            log_message("使用 mmcblk1 cid: " . $serial);
        } 
        elsif (-e '/sys/block/mmcblk0/device/cid') {
            open(my $fh, '<', '/sys/block/mmcblk0/device/cid') or warn "无法读取mmcblk0 cid";
            $serial = <$fh>;
            close($fh);
            chomp($serial);
            log_message("使用 mmcblk0 cid: " . $serial);
        } 
        elsif (-e '/etc/machine-id') {
            open(my $fh, '<', '/etc/machine-id') or warn "无法读取machine-id";
            $serial = <$fh>;
            close($fh);
            chomp($serial);
            log_message("使用 machine-id: $serial");
        }
    }
    
    # 如果以上方法都失败，使用urandom
    unless (defined $serial) {
        log_message("使用随机方法生成唯一ID");
        my $random_data;
        open(my $fh, '<', '/dev/urandom') or die_with_error("无法打开/dev/urandom: $!");
        read($fh, $random_data, 16);
        close($fh);
        $serial = unpack('H*', $random_data);
        log_message("生成随机ID: " . $serial);
    }

    # 转换为小写并去除0x前缀
    $serial = lc($serial);
    $serial =~ s/0x//g;
    
    return $serial;
}

# 加载MAC前缀
sub load_mac_prefixes {
    my @mac_groups;
    
    unless (-f $mac_prefix_config) {
        log_message("创建默认MAC前缀配置文件");
        
        my @default_prefixes = (
            '00:0e:8e', '00:14:22', '00:18:8c', '00:1b:77', '00:1d:92',
            '00:20:18', '00:4f:49', '00:60:52', '00:e0:4c', '52:54:ab',
            'd4:3d:7f', 'f0:25:b7', '28:6a:8d', 'b0:7b:d5', 'd8:0d:26'
        );
        
        make_path(dirname($mac_prefix_config));
        open(my $fh, '>', $mac_prefix_config) or die_with_error("无法创建前缀配置文件: $!");
        print $fh join("\n", @default_prefixes) . "\n";
        close($fh);
        chmod 0644, $mac_prefix_config;
    }
    
    open(my $fh, '<', $mac_prefix_config) or die_with_error("无法读取前缀配置文件: $!");
    while (my $line = <$fh>) {
        chomp $line;
        # 跳过空行和注释
        next if $line =~ /^\s*$/ || $line =~ /^#/;
        push @mac_groups, $line;
    }
    close($fh);
    
    log_message("加载 " . scalar(@mac_groups) . " 个MAC前缀");
    return @mac_groups;
}

# 生成基准MAC地址
sub generate_base_mac {
    my @mac_groups = load_mac_prefixes();
    my $unique_id = get_unique_id();
    
    log_message("生成基准MAC地址，唯一ID: " . $unique_id);

    my $raw_hash = sha256_hex($unique_id);
    log_message("SHA256哈希: " . $raw_hash);

    # 计算MAC前缀数组索引
    my $bitfield_index = hex(substr($raw_hash, 8, 4)) % scalar(@mac_groups);
    my $prefix = $mac_groups[$bitfield_index];
    log_message("选择MAC前缀: $prefix (索引: $bitfield_index)");

    # 计算MAC后缀在哈希中的起始位置
    my $start_pos = hex(substr($raw_hash, 16, 4)) % (length($raw_hash) - 6);
    log_message("MAC后缀起始位置: $start_pos");

    # 从哈希中提取6个字符（3字节）
    my $mac_tail = substr($raw_hash, $start_pos, 6);
    $mac_tail = join(':', $mac_tail =~ /(..)/g);
    log_message("初始MAC后缀: $mac_tail");

    # 分解MAC尾部
    my @tail_parts = split /:/, $mac_tail;
    
    # 强制设置本地管理位（第2位为1）
    my $octet4 = sprintf("%02x", (hex($tail_parts[0]) & 0xFE) | 0x02);
    $tail_parts[0] = $octet4;
    
    # 重新组合MAC尾部
    $mac_tail = join(':', @tail_parts);
    
    my $base_mac = "$prefix:$mac_tail";
    log_message("生成基准MAC地址: $base_mac");
    
    return $base_mac;
}

# 获取或创建基准MAC
sub get_or_create_base_mac {
    # 检查是否已有基准MAC
    if (-f $mac_address_config) {
        log_message("检查现有MAC配置文件");
        
        open(my $fh, '<', $mac_address_config) or die_with_error("无法读取MAC配置文件: $!");
        while (my $line = <$fh>) {
            chomp $line;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            
            if ($line =~ /^BASE\s+([0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5})$/) {
                my $base_mac = $1;
                close($fh);
                log_message("使用现有基准MAC地址: $base_mac");
                return $base_mac;
            }
        }
        close($fh);
    }
    
    # 生成新的基准MAC
    log_message("生成新的基准MAC地址");
    my $new_mac = generate_base_mac();
    
    # 确保生成的MAC是有效的
    unless ($new_mac =~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/) {
        log_message("生成的MAC地址无效，使用备用方法: $new_mac");
        
        my $random_data;
        open(my $fh, '<', '/dev/urandom') or die_with_error("无法打开/dev/urandom: $!");
        read($fh, $random_data, 3);
        close($fh);
        $new_mac = '00:0e:8e:' . join(':', unpack('H2H2H2', $random_data));
        log_message("备用MAC地址: $new_mac");
    }

    # 创建配置文件备份
    if (-f $mac_address_config) {
        my $backup_file = $mac_address_config . ".bak";
        copy($mac_address_config, $backup_file) or log_message("无法创建配置文件备份");
        log_message("创建配置文件备份: $backup_file");
    }

    # 创建或更新配置文件 - 只写数据，不添加注释
    make_path(dirname($mac_address_config));
    open(my $fh, '>', $mac_address_config) or die_with_error("无法写入MAC配置文件: $!");
    print $fh "BASE $new_mac\n";
    close($fh);
    chmod 0600, $mac_address_config;
    
    log_message("保存基准MAC地址到配置文件: $new_mac");
    return $new_mac;
}

# MAC地址偏移计算
sub mac_offset {
    my ($mac_address, $offset) = @_;
    validate_mac($mac_address);
    
    log_message("计算MAC地址偏移: $mac_address + $offset");
    
    my @bytes = split /:/, $mac_address;
    my $mac_dec = (hex($bytes[0]) << 40) | 
                  (hex($bytes[1]) << 32) | 
                  (hex($bytes[2]) << 24) | 
                  (hex($bytes[3]) << 16) | 
                  (hex($bytes[4]) << 8) | 
                  hex($bytes[5]);
    
    $mac_dec += $offset;
    
    # 处理后24位溢出
    my $tail = $mac_dec & 0xFFFFFF;
    
    my $new_mac = sprintf("%02x:%02x:%02x:%02x:%02x:%02x",
        ($mac_dec >> 40) & 0xFF,
        ($mac_dec >> 32) & 0xFF,
        ($mac_dec >> 24) & 0xFF,
        ($tail >> 16) & 0xFF,
        ($tail >> 8) & 0xFF,
        $tail & 0xFF);
    
    log_message("偏移后MAC地址: $new_mac");
    return $new_mac;
}

# 获取当前MAC地址
sub get_current_mac {
    my ($iface) = @_;
    
    # 使用安全方式执行命令
    open(my $fh, '-|', 'ip', '-o', 'link', 'show', $iface) 
        or die_with_error("无法执行ip命令: $!");
    
    while (my $line = <$fh>) {
        if ($line =~ /link\/ether\s+(([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2})/) {
            close($fh);
            return $1;
        }
    }
    close($fh);
    
    die_with_error("无法获取接口 $iface 的MAC地址");
}

# 设置MAC地址
sub set_mac_address {
    my ($iface, $new_mac) = @_;
    
    log_message("设置接口 $iface MAC地址为: $new_mac");
    
    # 保存原始MAC地址用于恢复
    my $original_mac = get_current_mac($iface);
    
    # 尝试设置新MAC地址
    my $success = 0;
    for my $attempt (1..3) {
        log_message("尝试 $attempt: 设置MAC地址");
        
        system('ip', 'link', 'set', 'dev', $iface, 'down') == 0
            or (log_message("无法关闭接口") && next);
        
        system('ip', 'link', 'set', 'dev', $iface, 'address', $new_mac) == 0
            or (log_message("设置MAC地址失败") && next);
        
        system('ip', 'link', 'set', 'dev', $iface, 'up') == 0
            or (log_message("无法启动接口") && next);
        
        # 验证新MAC地址
        my $current_mac = get_current_mac($iface);
        if ($current_mac eq $new_mac) {
            $success = 1;
            last;
        }
        
        log_message("验证失败: 当前 $current_mac, 预期 $new_mac");
        
        # 恢复原始MAC地址
        system('ip', 'link', 'set', 'dev', $iface, 'down');
        system('ip', 'link', 'set', 'dev', $iface, 'address', $original_mac);
        system('ip', 'link', 'set', 'dev', $iface, 'up');
    }
    
    unless ($success) {
        # 恢复原始MAC地址
        system('ip', 'link', 'set', 'dev', $iface, 'down');
        system('ip', 'link', 'set', 'dev', $iface, 'address', $original_mac);
        system('ip', 'link', 'set', 'dev', $iface, 'up');
        
        die_with_error("无法设置接口 $iface 的MAC地址");
    }
    
    return 1;
}

# 更新配置文件中的MAC地址
sub update_mac_config {
    my ($interface, $new_mac) = @_;
    
    my $temp_file = "/tmp/mac_temp_$$";
    my $found = 0;
    
    # 读取现有配置，更新当前接口的MAC
    if (-f $mac_address_config) {
        open(my $in_fh, '<', $mac_address_config) or die_with_error("[$interface] 无法读取配置文件: $!");
        open(my $out_fh, '>', $temp_file) or die_with_error("[$interface] 无法创建临时文件: $!");
        
        while (my $line = <$in_fh>) {
            chomp $line;
            
            # 更新当前接口的MAC
            if ($line =~ /^(\s*$interface\s+)([0-9a-f:]+)/i) {
                print $out_fh "$interface $new_mac\n";
                $found = 1;
            }
            # 保留BASE行和其他接口
            else {
                print $out_fh "$line\n";
            }
        }
        close($in_fh);
        close($out_fh);
        
        # 如果当前接口不在配置文件中，添加它
        unless ($found) {
            open(my $out_fh, '>>', $temp_file) or die_with_error("[$interface] 无法追加到临时文件: $!");
            print $out_fh "$interface $new_mac\n";
            close($out_fh);
        }
        
        # 替换原配置文件
        move($temp_file, $mac_address_config) or die_with_error("[$interface] 无法更新配置文件: $!");
        chmod 0600, $mac_address_config;
        log_message("[$interface] 配置文件更新完成");
    } else {
        # 如果配置文件不存在，创建新文件
        open(my $out_fh, '>', $mac_address_config) or die_with_error("[$interface] 无法创建配置文件: $!");
        print $out_fh "$interface $new_mac\n";
        close($out_fh);
        chmod 0600, $mac_address_config;
        log_message("[$interface] 创建新配置文件");
    }
    
    unlink($temp_file) if -e $temp_file;
}

# 主过程
{
    # === 文件锁处理 ===
    make_path(dirname($lock_file));
    open($lock_fh, '>', $lock_file) or die_with_error("[$interface] 无法创建锁文件: $!");
    chmod 0644, $lock_file;
    
    # 等待最多30秒获取排他锁
    my $lock_acquired = 0;
    for my $attempt (1..30) {
        if (flock($lock_fh, LOCK_EX | LOCK_NB)) {
            $lock_acquired = 1;
            last;
        }
        
        log_message("[$interface] 等待文件锁... ($attempt/30)");
        sleep 1;
    }
    
    unless ($lock_acquired) {
        close($lock_fh);
        die_with_error("[$interface] 无法获取文件锁");
    }
    
    log_message("[$interface] 成功获取文件锁");
    
    # 获取当前MAC地址
    my $current_mac = get_current_mac($interface);
    log_message("[$interface] 当前MAC地址: $current_mac");

    # 获取物理接口列表
    my @interfaces = get_physical_interfaces();
    log_message("[$interface] 找到物理接口: " . join(', ', @interfaces));
    
    # 验证接口有效性
    unless (grep { $_ eq $interface } @interfaces) {
        die_with_error("[$interface] 不存在或不是物理以太网接口\n可用接口: " . join(' ', @interfaces));
    }

    # 生成或获取基准MAC
    my $base_mac = get_or_create_base_mac();
    validate_mac($base_mac);
    log_message("[$interface] 基准MAC地址: $base_mac");

    # 确定接口索引
    my $interface_index = 0;
    for my $i (0..$#interfaces) {
        if ($interfaces[$i] eq $interface) {
            $interface_index = $i;
            last;
        }
    }
    log_message("[$interface] 索引: $interface_index");

    # 计算最终MAC地址
    my $final_mac = mac_offset($base_mac, $interface_index);
    validate_mac($final_mac);
    log_message("[$interface] 目标MAC地址: $final_mac");

    # 更新配置文件中的MAC地址
    update_mac_config($interface, $final_mac);

    # 设置MAC地址（如果需要）
    if ($current_mac ne $final_mac) {
        set_mac_address($interface, $final_mac);
        log_message("[$interface] MAC地址更新成功: $current_mac -> $final_mac");
    } else {
        log_message("[$interface] MAC地址无需变更");
    }

    # 确保退出时释放锁
    END {
        if ($lock_fh) {
            flock($lock_fh, LOCK_UN);
            close($lock_fh);
            log_message("[$interface] 释放文件锁") if $lock_acquired;
        }
    }

    log_message("[$interface] 处理完成");
    exit 0;
}
