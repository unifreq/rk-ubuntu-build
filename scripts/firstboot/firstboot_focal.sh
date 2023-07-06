#!/bin/bash

FIRSTBOOT=firstboot.service

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

function stop_service() {
	echo "stop service $1 ... "
	systemctl stop $1
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

function get_ifnames() {
	(
		cd /sys/class/net
		local eths=$(ls -d eth* 2>/dev/null)
		local ens=$(ls -d en* 2>/dev/null)
		echo "$eths $ens"
	)
}

function write_yml_head() {
	local yml=$1
	local renderer=$2
	if [ "$renderer" == "networkd" ];then
		cat > $yml <<EOF
network:
  version: 2
  renderer: $renderer
  ethernets:
EOF
	else
		cat > $yml <<EOF
network:
  version: 2
  renderer: NetworkManager
EOF
	fi
}

function write_yml_ifname() {
	local yml=$1
	local ifname=$2
	cat >> $yml <<EOF
    $ifname:
EOF
}

function write_yml_dhcp() {
	local yml=$1
	local dhcp_switch=$2
	cat >> $yml <<EOF
      dhcp4: $dhcp_switch
      dhcp6: $dhcp_switch
EOF
}

function write_yml_ipaddr() {
	local yml=$1
	local ips=$2
	cat >> $yml <<EOF
      addresses: [$ips]
EOF
}

function write_yml_routes() {
	local yml=$1
	local routes=$2
	cat >> $yml <<EOF
      routes:
EOF
	for to_via in "$routes";do
		to=$(echo $to_via | awk -F ':' '{print $1}')
		via=$(echo $to_via | awk -F ':' '{print $2}')
		cat >> $yml <<EOF
        - to: $to
          via: $via
EOF
	done
}

function write_yml_dns() {
	local yml=$1
	local dns=$2
	local search_domain=$3
	cat >> $yml <<EOF
      nameservers:
        addresses: [$DNS]
EOF
	if [ "$search_domain" != "" ];then
		cat >> $yml <<EOF
        search: [$search_domain]
EOF
	fi
}

function create_netplan_config() {
	local renderer=$1
	local yml="/etc/netplan/00-default-config.yaml"
	shift
	local if_idx
	local ips
	local routes

	write_yml_head "$yml" "$renderer"
	# networkd
	if [ "$renderer" == "networkd" ];then
		if_idx=1
		while [ "$1" != "" ];do
			# get variables
			case $if_idx in
				1) ips=$IF1_IPS
				   routes=$IF1_ROUTES
				   ;;
				2) ips=$IF2_IPS
				   routes=$IF2_ROUTES
				   ;;
				3) ips=$IF3_IPS
				   routes=$IF3_ROUTES
				   ;;
				4) ips=$IF4_IPS
				   routes=$IF4_ROUTES
				   ;;
				*) ips=""
				   routes=""
				   ;;
			esac # end get variables

			# ip address
			case $ips in
				dhcp)	write_yml_ifname "$yml" "$1"
					write_yml_dhcp "$yml" "true"
					;;
				  '')	echo "$1 do nothing";;
				   *)	write_yml_ifname "$yml" "$1"
					write_yml_dhcp "$yml" "false"
					write_yml_ipaddr "$yml" "$ips"
					# routes
					if [ "$routes" != "" ];then
						write_yml_routes "$yml" "$routes"
					fi # end routes
					# dns
					if [ "$DNS" != "" ];then
						write_yml_dns "$yml" "$DNS" "$SEARCH_DOMAIN"
					fi
					;;
			esac # end ip addr

			# next ifname
			shift
			let if_idx++
		done
	fi #networkd
	echo 'done'
	echo
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
	if [ -f "/usr/local/lib/systemd/system/rknn.service" ];then
		ldconfig
		systemctl enable rknn.service
		systemctl start rknn.service
	fi
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
	stop_service lightdm.service
	start_service lightdm.service
}

function reconfig_openssh_server() {
	rm -f /etc/ssh/ssh_host_*key*
	DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server
}

function modify_user_pswd() {
	local file=/etc/user_pswd
	if [ -f ${file} ];then
		ups=$(cat ${file})
		for up in ${ups};do
			u=$(echo ${up} | awk -F ':' '{print $1}')
			p=$(echo ${up} | awk -F ':' '{print $2}')
			g=$(echo ${up} | awk -F ':' '{print $3}')
			G=$(echo ${up} | awk -F ':' '{print $4}')

			# create new user if not exists
			if ! grep -e "^${u}:" /etc/passwd;then
				echo "create group ${g} ..."
				groupadd ${g}
				echo "create user ${u} ..."
				if [ -n "$G" ];then
					useradd -d /home/${u} -m -g ${g} -G ${G} -s /bin/bash ${u}
				else
					useradd -d /home/${u} -m -g ${g} -s /bin/bash ${u}
				fi
			fi

			# setup default password for user
			echo -n "change user ${u}'s password ..."
			if echo "${u}:${p}" | /usr/sbin/chpasswd -c SHA512; then
				echo "succeed"
			else
				echo "failed"
			fi
		done
		rm -f ${file}
		sync
	fi
}

reset_machine_id
reconfig_openssh_server
if [ -f /etc/firstboot_hostname ];then
	hostname=$(cat /etc/firstboot_hostname)
	if [ "$hostname" != "" ];then
		setup_hostname $hostname
	fi
fi

if [ -f /etc/firstboot_network.conf ];then
	source /etc/firstboot_network.conf
fi

disable_suspend

clean_logs
clean_debootstrap_dir

fix_partition
check_partition_count
resize_partition
resize_filesystem

modify_user_pswd

set_lightdm_default_xsession "xfce"

default_ifnames=$(get_ifnames)
if [ "$default_ifnames" != "" ];then
    [ -z "${NETPLAN_BACKEND}" ] && NETPLAN_BACKEND="NetworkManager"
    create_netplan_config ${NETPLAN_BACKEND} $default_ifnames
    case ${NETPLAN_BACKEND} in
	    NetworkManager)	stop_service NetworkManager.service
				stop_service systemd-networkd.service
				disable_service systemd-networkd.service
				enable_service NetworkManager.service
				start_service NetworkManager.service
				;;
	          networkd)	stop_service NetworkManager.service
				stop_service systemd-networkd.service
				disable_service NetworkManager.service
				enable_service systemd-networkd.service
				start_service systemd-networkd.service
				;;
    esac
    netplan apply
fi

enable_service ssh.service
start_service ssh.service

enable_rknpu

disable_service $FIRSTBOOT
