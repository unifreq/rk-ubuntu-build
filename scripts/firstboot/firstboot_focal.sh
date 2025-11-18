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

function daemon_reload() {
	echo "systemctl daemon-reload ... "
	systemctl daemon-reload
	echo "done"
	echo
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

function status_service() {
	echo "status of service $1 ... "
	systemctl status $1
	echo "done"
	echo
}

function restart_service() {
	echo "restart service $1 ... "
	systemctl restart $1
	echo "done"
	echo
}

function disable_service() {
	echo "disable service $1 ... "
	systemctl disable $1
	echo "done"
	echo
}

function setup_hostname() {
	local conf="/etc/firstboot_hostname"
	if [ -f $conf ];then
		hostname=$(cat $conf)
		# add random id
		random_id=$(openssl rand -base64 32 | tr -dc 'a-z0-9' | head -c 6)
		if [ "$hostname" == "" ];then
			hostname="host-${random_id}"
		else
			hostname="${hostname}-${random_id}"
		fi
		echo -n "setup hostname to $hostname ... "
		hostnamectl set-hostname $hostname
		echo $hostname > "${conf}.final"
		echo "done"
	else
		echo "$conf not exists, can't setup hostname!"
	fi
}

function reset_machine_id() {
	local conf="/etc/firstboot_machine_id.conf"
	if [ -f $conf ];then
		source $conf
		if [ "$RESET_MACHINE_ID" == "yes" ];then
			echo "resetting machine id ... "
			echo "the old machine-id is:"
			cat /etc/machine-id
			rm -f /etc/machine-id /var/lib/dbus/machine-id
			rm -rf /var/log/journal/*
			systemd-machine-id-setup
			echo "the new machine-id is:"
			cat /etc/machine-id
			cp -avf /etc/machine-id /var/lib/dbus/machine-id
			restart_service dbus
			restart_service system-journald
			echo "done"
		fi
		rm -f $conf
	fi
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
	chmod 600 $yml
	echo 'done'
	echo
}

function create_ifupdown_config() {
	local if_idx
	local ips
	local routes
	local ifs_home="/etc/network/interfaces.d"

	# ifupdown
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
			dhcp)	echo "auto $1" >> ${ifs_home}/$1
				echo "iface $1 inet dhcp" >> ${ifs_home}/$1
				;;
			  '')	echo "iface $1 inet manual" >> ${ifs_home}/$1
				;;
			   *)	echo "auto $1" >> ${ifs_home}/$1
				echo "iface $1 inet static" >> ${ifs_home}/$1
				# address
				echo "  address $ips" >> ${ifs_home}/$1

				# gateway
				if [ "$routes" != "" ];then
					echo "  gateway $routes" >> ${ifs_home}/$1
				fi # end routes

				# dns
				if [ "$DNS" != "" ];then
					# DNS split by space
					echo "  dns-nameservers $DNS" >> ${ifs_home}/$1
				fi
				;;
		esac # end ip addr

		# next ifname
		shift
		let if_idx++
	done

	echo 'done'
	echo
}

function config_network() {
	local conf="/etc/firstboot_network.conf"
	if [ -f $conf ];then
		source $conf
	fi

	local ifnames=$(get_ifnames)
	if [ "$ifnames" != "" ];then
		[ -z "${NETPLAN_BACKEND}" ] && NETPLAN_BACKEND="ifupdown"
		case ${NETPLAN_BACKEND} in
			NetworkManager)	# netplan with NetworkManager
					create_netplan_config ${NETPLAN_BACKEND} $ifnames
					stop_service NetworkManager.service
					stop_service systemd-networkd.service
					disable_service systemd-networkd.service
					enable_service NetworkManager.service
					start_service NetworkManager.service
					netplan apply
					;;
			networkd)	# netplan with networkd
					create_netplan_config ${NETPLAN_BACKEND} $ifnames
					stop_service NetworkManager.service
					stop_service systemd-networkd.service
					disable_service NetworkManager.service
					enable_service systemd-networkd.service
					start_service systemd-networkd.service
					netplan apply
					;;
			ifupdown*)	# ifupdown or ifupdown2
					create_ifupdown_config $ifnames
					stop_service systemd-networkd.service
					disable_service systemd-networkd.service
					enable_service networking.service
					stop_service networking.service
					start_service networking.service
					;;
		esac
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
	if [ -f "/usr/local/lib/systemd/system/rknn.service" ] && modinfo rknpu 2>/dev/null;then
		echo rknpu > /etc/modules-load.d/rknpu.conf
		echo "alias rknpu rknpu" > /etc/modprobe.d/rknpu.conf
		modprobe rknpu
		ldconfig
		systemctl enable rknn.service
		systemctl start rknn.service
	fi
}

function set_lightdm_default_xsession() {
	local installed=$(dpkg -l lightdm | tail -n1 | awk '{print $1}')
	if [ "$installed" != "ii" ];then
		echo "lightdm is not installed"
		return
	fi

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

function reset_sshd_key() {
	local switch=$1
	if [ "$switch" == "yes" ];then
		echo "Reset openssh keys ..."
		rm -f /etc/ssh/ssh_host_*key*
		DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server
		echo "done"
	fi
}

function change_sshd_port() {
	local port=$1
	local conf=/etc/ssh/sshd_config
	if [ "$port" != "" ] && [ $port -ge 1 ] && [ $port -le 65535 ];then
		echo "Change sshd port to $port"
		sed -e '/^Port/d' -i $conf || echo "Change $conf failed! [$port]"
		echo "Port $port" | tee -a $conf
		echo "done"
	fi
}

function change_sshd_permit_root_login() {
	local var=$1
	local conf=/etc/ssh/sshd_config
	if [ "$var" != "" ];then
		case $var in
			prohibit-password|forced-commands-only|yes|no)
				echo "Change PermitRootLogin to $var"
				sed -e '/^PermitRootLogin/d' -i $conf || echo "Change $conf failed! [$var]"
				echo "PermitRootLogin ${var}" | tee -a $conf
				echo "done"
				;;
			*)	echo "Illegal parameter value: $var"
				;;
		esac
	fi
}

function change_sshd_ciphers() {
	local ciphers=$1
	local conf=/etc/ssh/sshd_config

	if [ "$ciphers" != "" ];then
		echo "Change sshd ciphers to $ciphers"
		sed -e '/^Ciphers/d' -i $conf || echo "Change $conf failed! [$ciphers]"
		echo "Ciphers $ciphers" | tee -a $conf
		echo "done"
	fi
}

function change_ssh_ciphers() {
	local ciphers=$1
	local conf=/etc/ssh/ssh_config

	if [ "$ciphers" != "" ];then
		echo "Change ssh ciphers to $ciphers"
		sed -e '/^    Ciphers/d' -i $conf || echo "Change $conf failed! [$ciphers]"
		echo "    Ciphers $ciphers" | tee -a $conf
		echo "done"
	fi
}

function config_openssh_server() {
	local conf="/etc/firstboot_openssh.conf"
	stop_service "ssh.service"
	if [ -f $conf ];then
		source  $conf
		change_sshd_port "$SSHD_PORT"
		change_sshd_permit_root_login "$SSHD_PERMIT_ROOT_LOGIN"
		change_sshd_ciphers "$SSHD_CIPHERS"
		change_ssh_ciphers "$SSH_CIPHERS"
		reset_sshd_key "$RESET_SSH_KEYS"
		rm -f $conf
	fi
	enable_service "ssh.service"
	start_service "ssh.service"
}

function config_i18n() {
	local conf="/etc/firstboot_i18n.conf"
	if [ -f $conf ];then
		source $conf
		if [ -n "${LANGUAGE}" ];then
			echo "Change default language to ${LANGUAGE}"
			update-locale LANG=${LANGUAGE} && update-locale LC_ALL=${LANGUAGE} && \
				echo "done" || \
				echo "failed"
		fi

		if [ -n "${TIMEZONE}" ];then
			if [ -f "/usr/share/zoneinfo/${TIMEZONE}" ];then
				echo "Change default time zone to ${TIMEZONE}"
				ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
				dpkg-reconfigure -f noninteractive tzdata && echo "done" || echo "failed"
			else
				echo "Time zone [${TIMEZONE}] does not exists!"
			fi
		fi

		rm -f $conf
	fi
}

function restart_getty() {
	local i=1
	while [ $i -le 12 ];do
		local enabled=$(systemctl is-enabled getty@tty${i}.service)
		if [ "$enabled" == "enabled" ];then
			echo "stop getty@tty${i}.service"
			stop_service "getty@tty${i}.service"
			echo "start getty@tty${i}.service"
			start_service "getty@tty${i}.service"
		fi
		let i++
	done
}

function modify_user_pswd() {
	local file="/etc/user_pswd"
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
		restart_getty
	fi
}

function tunning_log_settings() {
	sed -e 's/^kern\.\*/#kern\.\*/' -i /etc/rsyslog.d/50-default.conf
	sed -e 's/#compress/compress/' -i /etc/logrotate.conf
	echo "maxsize 10M" >> /etc/logrotate.conf

	cat > /etc/logrotate.d/rsyslog <<EOF
/var/log/syslog
/var/log/mail.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
        rotate 4
        maxsize 10M
        weekly
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
EOF

	logrotate -vf /etc/logrotate.conf
	stop_service rsyslog.service
	start_service rsyslog.service
	rm -f /var/log/kern.*

	cat >> /etc/systemd/journald.conf <<EOF
SystemMaxUse=20M
RuntimeMaxUse=15M
MaxRetentionSec=1week
EOF

	stop_service systemd-journald.service
	start_service systemd-journald.service
}

modify_user_pswd

fix_partition
check_partition_count
resize_partition
resize_filesystem

setup_hostname
reset_machine_id
config_network
config_openssh_server
config_i18n
disable_suspend

tunning_log_settings
clean_logs
clean_debootstrap_dir

set_lightdm_default_xsession "xfce"
#enable_rknpu

if [ -f /usr/lib/systemd/system/ssd1306.service ];then
	enable_service ssd1306.service
	start_service ssd1306.service
fi

if [ -f /usr/lib/systemd/system/chrony.service ];then
	enable_service chrony.service
	start_service chrony.service
fi

if [ -f /usr/local/lib/systemd/system/mystartup.service ];then
	systemd daemon-reload
	enable_service mystartup.service
	start_service mystartup.service
	sleep 1
	systemctl status mystartup.service
	if [ $? -ne 0 ];then
	    stop_service mystartup.service
	    start_service mystartup.service
	fi
fi

if [ -f /boot/bootEnv.txt ];then
	sed -e 's/bootlogo=false/bootlogo=true/' -i /boot/bootEnv.txt
elif [ -f /boot/armbianEnv.txt ];then
	sed -e 's/bootlogo=false/bootlogo=true/' -i /boot/armbianEnv.txt
fi

disable_service $FIRSTBOOT

echo "sync ..."
sync && echo "sync done"
echo "rebooting ..."
reboot
exit 0
