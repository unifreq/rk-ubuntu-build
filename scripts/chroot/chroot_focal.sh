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

srcfile="/tmp/sshd_port"
dstfile="/etc/ssh/sshd_config"
if [ -f $srcfile ];then
	sshd_port=$(cat $srcfile)
	if [ "$sshd_port" != "" ] && [ $sshd_port -ne 22 ];then
		echo "Change sshd port to $sshd_port"
		sed -e '/^Port/d' -i $dstfile || echo "Change $destfile failed! [$sshd_port]"
		echo "Port $sshd_port" | tee -a $dstfile
	fi
fi

srcfile="/tmp/sshd_permit_root_login"
dstfile="/etc/ssh/sshd_config"
if [ -f $srcfile ];then
	permit_root_login=$(cat $srcfile)
	if [ "$permit_root_login" != "" ];then
		echo "Change PermitRootLogin to $permit_root_login"
		sed -e '/^PermitRootLogin/d' -i $dstfile || echo "Change $dstfile failed! [$permit_root_login]"
		echo "PermitRootLogin ${permit_root_login}" | tee -a $dstfile
	fi
fi

srcfile="/tmp/sshd_ciphers"
dstfile="/etc/ssh/sshd_config"
if [ -f $srcfile ];then
	sshd_ciphers=$(cat $srcfile)
	if [ "$sshd_ciphers" != "" ];then
		echo "Change sshd ciphers to $sshd_ciphers"
		sed -e '/^Ciphers/d' -i $dstfile || echo "Change $dstfile failed! [$sshd_ciphers]"
		echo "Ciphers $sshd_ciphers" | tee -a $dstfile
	fi
fi

srcfile="/tmp/ssh_ciphers"
dstfile="/etc/ssh/ssh_config"
if [ -f $srcfile ];then
	ssh_ciphers=$(cat $srcfile)
	if [ "$ssh_ciphers" != "" ];then
		echo "Change ssh ciphers to $ssh_ciphers"
		sed -e '/^    Ciphers/d' -i $dstfile || echo "Change $dstfile failed! [$ssh_ciphers]"
		echo "    Ciphers $ssh_ciphers" | tee -a $dstfile
	fi
fi

srcfile="/tmp/language"
if [ -f $srcfile ];then
	default_language=$(cat $srcfile)
	echo "Change default language to ${default_language}"
	update-locale LANG=${default_language} && update-locale LC_ALL=${default_language}
fi

srcfile="/tmp/timezone"
dstfile="/etc/timezone"
if [ -f $srcfile ];then
	default_timezone=$(cat $srcfile)
	echo "Change default timezone to ${default_timezone}"
	echo "${default_timezone}" > $dstfile && dpkg-reconfigure -f noninteractive tzdata
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
