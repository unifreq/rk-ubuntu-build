#!/bin/bash

SERVICE=firstboot.service

function get_root_partition_name() {
	local root_ptname=$(df / | tail -n1 | awk '{print $1}' | awk -F '/' '{print $3}')
	if [ "$root_ptname" == "" ];then
    		echo "找不到根文件系统对应的分区!"
    		destory_myself
    		exit 1
	fi
	echo $root_ptname
}

function get_root_disk_name() {
	local root_ptname=$(get_root_partition_name)
	local disk_name
	case $root_ptname in 
		mmcblk?p[1-4]) disk_name=$(echo $root_ptname | awk '{print substr($1, 1, length($1)-2)}');;
		    nvme?n?p?) disk_name=$(echo $root_ptname | awk '{print substr($1, 1, length($1)-2)}');;
	    [hsv]d[a-z][1-9]*) disk_name=$(echo $root_ptname | awk '{print substr($1, 1, length($1)-1)}');;
		            *) echo "无法识别 $root_ptname 的磁盘类型!"
			       disable_service
			       exit 1
			       ;;
	esac
	echo "$disk_name"
}

function fix_partition() {
	local disk_name=$(get_root_disk_name)
	# 第一次运行，需要修复磁盘大小
	echo "fix partiton ... "
	printf 'f\n' | parted ---pretend-input-tty /dev/${disk_name} unit Mib print || fail=1
	if [ "$fail" == "1" ];then
		echo "分区表未修复！需要手动执行 $MYSELF"
		exit 1
	fi
	echo "done"
	echo
}

function check_partition_count() {
	local disk_name=$(get_root_disk_name)
	local current_pt_cnt=$(parted -s /dev/${disk_name} print | awk '$1~/[1-9]+/ {print $1}' | wc -l)
	if [ "$current_pt_cnt" != "2" ];then
    		echo "现存分区数量不为2,放弃!"
    		disable_service
        	exit 1
	fi
	echo "Current partition count is valid: $current_pt_cnt"
}

function resize_partition() {
	local disk_name=$(get_root_disk_name)
	echo "resize partition /dev/${disk_name} ... "
	printf 'Yes\n-1\n' | parted ---pretend-input-tty /dev/${disk_name} resizepart 2 100%
	if [ $? -ne 0 ];then
		echo "分区扩展失败!"
		exit 1
	fi
	echo "done"
	echo
}

function resize_filesystem() {
	local part_name=$(get_root_partition_name)
	local fstype=$(df -T / | tail -n1 | awk '{print $2}')
	echo "resize / at /dev/${part_name} ... "
	case $fstype in 
		btrfs) btrfs filesystem resize max /
		       ;;
		 ext4) resize2fs /dev/${part_name}
		       ;;
		  xfs) xfs_growfs -d /
		       ;;
	esac
	echo "done"
	echo 
}

function setup_hostname() {
	hostnamectl set-hostname $1
}

function enable_service() {
	echo "disable service $1 ... "
	systemctl enable $1
	echo "done"
	echo
}

function start_service() {
	echo "start service $1 ... "
	systemctl start $1
	echo "done"
	echo
}

function disable_service() {
	echo "disable service $1 ... "
	systemctl disable $1
	echo "done"
	echo
}

function reset_machine_id() {
	rm -f /etc/machine-id
	rm -rf /var/log/journal/*
	systemd-machine-id-setup
}

function create_netplan_config() {
	local renderer=$1
	shift
	if [ "$renderer" == "networkd" ];then 
		cat > /etc/netplan/00-default-config.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
EOF
		while [ "$1" != "" ];do
			cat >> /etc/netplan/00-default-config.yaml <<EOF
    $1:
      dhcp4: true
      dhcp6: true
EOF
			shift
		done
		echo 'done'
		echo
	elif [ "$renderer" == "NetworkManager" ];then
		cat > /etc/netplan/00-default-config.yaml <<EOF
network:
  version: 2
  renderer: NetworkManager
EOF
		echo 'done'
		echo
	fi
}

function disable_suspend() {
	systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
}

function clean_logs() {
	find /var/log -name '*log*' -type f -exec rm {} \;
}

function clean_debootstrap_dir() {
	rm -rf /debootstrap
}

function enable_rknpu() {
	echo rknpu > /etc/modules-load.d/rknpu.conf
	echo "alias rknpu rknpu" > /etc/modprobe.d/rknpu.conf
	modprobe rknpu
}

function set_lightdm_default_xsession() {
	if [ "$1" == "xfce" ];then
		cat > /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf <<EOF
[Seat:*]
user-session=xfce
EOF
	elif [ "$1" == "ubuntu" ];then
		cat > /usr/share/lightdm/lightdm.conf.d/50-ubuntu.conf <<EOF
[Seat:*]
user-session=ubuntu
EOF
	fi
}

function reconfig_openssh_server() {
	rm -f /etc/ssh/ssh_host_*key*
	DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server
}

reset_machine_id
if [ "$machine_hostname" != "" ];then
    setup_hostname $machine_hostname
fi
if [ "$default_ifnames" != "" ];then
    create_netplan_config "NetworkManager" $default_ifnames
    netplan apply
fi
disable_suspend
clean_logs
clean_debootstrap_dir
set_lightdm_default_xsession "xfce"
fix_partition
check_partition_count
resize_partition
resize_filesystem
reconfig_openssh_server
enable_service ssh.service
start_service ssh.service
enable_service NetworkManager.service
start_service NetworkManager.service
enable_rknpu
disable_service $SERVICE
