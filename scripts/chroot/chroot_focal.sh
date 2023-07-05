#!/bin/bash

mv /etc/resolv.conf /etc/resolv.conf.orig
touch /etc/resolv.conf
echo "nameserver 8.8.4.4" | tee -a /etc/resolv.conf
echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf
alter_resolv=1

echo 'OS upgrade ...'
export DEBIAN_FRONTEND=noninteractive
apt clean
apt update
apt upgrade -y
echo 'done'
echo

echo 'Add kisak-mesa PPA repo ...'
echo 'https://launchpad.net/~kisak/+archive/ubuntu/kisak-mesa'
apt install -y software-properties-common
# PPA repo: kisak-mesa stable
add-apt-repository -y ppa:kisak/turtle
apt update
echo 'done'
echo

echo 'Install custom packages ...'
apt install -y netplan.io linux-firmware openssh-server xfce4 lightdm \
	mesa-utils btrfs-progs xfsdump xfsprogs usbutils pciutils htop \
	hdparm lm-sensors iperf3 alsa-utils qasmixer pulsemixer ethtool
apt remove -y gdm3
dpkg-reconfigure lightdm
echo 'done'
echo

if [ -f "/tmp/debs/install.list" ];then
	deb_list=''
	while read line;do
		deb_list="${deb_list} ${line}"
	done < /tmp/debs/install.list
	if [ "$deb_list" != "" ];then
		echo 'Install extend packages ... '
		(cd /tmp/debs && apt install -y ${deb_list})
		echo 'done'
		echo
	fi
fi

echo "Change some config files ... "
sed -e 's/managed=false/managed=true/' -i /etc/NetworkManager/NetworkManager.conf || echo "Change NetworkManager.conf failed!"

if [ -f "/tmp/sshd_permit_root_login" ];then
	permit_root_login=$(cat /tmp/sshd_permit_root_login)
	echo "Change PermitRootLogin to $permit_root_login"
	sed -e '/^PermitRootLogin/d' -i /etc/ssh/sshd_config || echo "Change sshd_config failed! [$permit_root_login]"
	echo "PermitRootLogin ${permit_root_login}" | tee -a /etc/ssh/sshd_config
fi

if [ -f "/tmp/sshd_ciphers" ];then
	sshd_ciphers=$(cat /tmp/sshd_ciphers)
	echo "Change sshd ciphers to $sshd_ciphers"
	sed -e '/^Ciphers/d' -i /etc/ssh/sshd_config || echo "Change sshd_config failed! [$sshd_ciphers]"
	echo "Ciphers $sshd_ciphers" | tee -a /etc/ssh/sshd_config
fi

if [ -f "/tmp/ssh_ciphers" ];then
	ssh_ciphers=$(cat /tmp/ssh_ciphers)
	echo "Change ssh ciphers to $ssh_ciphers"
	sed -e '/^\s+Ciphers/d' -i /etc/ssh/ssh_config || echo "Change ssh_config failed! [$ssh_ciphers]"
	echo "    Ciphers $ssh_ciphers" | tee -a /etc/ssh/ssh_config
fi

if [ -f "/tmp/language" ];then
	default_language=$(cat /tmp/language)
	echo "Change default language to ${default_language}"
	update-locale LANG=${default_language} && update-locale LC_ALL=${default_language}
fi

if [ -f "/tmp/timezone" ];then
	default_timezone=$(cat /tmp/timezone)
	echo "Change default timezone to ${default_timezone}"
	echo "${default_timezone}" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata
fi

echo 'done'
echo

echo 'Clean ... '
apt autoremove -y
apt clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
if [ $alter_resolv -eq 1 ];then
	rm -f /etc/resolv.conf
	mv /etc/resolv.conf.orig /etc/resolv.conf
fi
echo 'done'
echo

exit 0
