#!/bin/bash

mv /etc/resolv.conf /etc/resolv.conf.orig
touch /etc/resolv.conf
echo "nameserver 8.8.4.4" | tee -a /etc/resolv.conf
echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf
alter_resolv=1

echo 'OS upgrade ...'
export DEBIAN_FRONTEND=noninteractive
apt clean
apt update || exit 1
apt upgrade -y || exit 1
echo 'done'
echo

echo 'Add kisak-mesa PPA repo ...'
echo 'https://launchpad.net/~kisak/+archive/ubuntu/kisak-mesa'
apt install -y software-properties-common || exit 1
# PPA repo: kisak-mesa stable
add-apt-repository -y ppa:kisak/turtle || exit 1
apt update || exit 1
echo 'done'
echo

echo 'Install custom packages ...'
apt install -y netplan.io linux-firmware openssh-server xfce4 lightdm \
	mesa-utils btrfs-progs xfsdump xfsprogs usbutils pciutils htop \
	hdparm lm-sensors iperf3 alsa-utils qasmixer pulsemixer ethtool || exit 1
apt remove -y gdm3
dpkg-reconfigure lightdm
echo 'done'
echo

echo 'Install extend packages ... '
deb_list=''
while read line;do
	deb_list="${deb_list} ${line}"
done < /tmp/debs/install.list
(cd /tmp/debs && apt install -y ${deb_list} || exit 1)
echo 'done'
echo

if ! grep linkstar /etc/group;then
	echo 'Add group linkstar and user linkstar ...'
	groupadd linkstar
	useradd -d /home/linkstar -m -s /bin/bash -g linkstar -G sudo,video,audio linkstar

	echo "Setup user linkstar default password ... "
	sed -e 's/linkstar:!:/linkstar:$6$89T2xLcKbqhYHKK0$hyRdexOFMR99FDKsjvbcq7hEkNB5hlhVmOK76yv1mGj6IveUKitDNvq0puBl9YmNAtvWen5L9aO6xA2G.qrL00:/' -i /etc/shadow || echo "change user linkstar password failed!"

	echo 'done'
	echo
fi

echo "Setup user root default password ... "
sed -e 's/root:\*:/root:$6$ZnwaOqOL3adT5SIU$tdEitdwCuFBXvrNgJQx2J3rKKMGFyIqMveIiXUXKtG6ecaXHOWF3lt9UPm.332t463sp60D78znq7qJjVWD6U.:/' -i /etc/shadow || echo "change user root password failed!"
echo 'done'
echo

echo "change some config files ... "
sed -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' -i /etc/ssh/sshd_config || echo "change sshd_config failed!"
sed -e 's/managed=false/managed=true/' -i /etc/NetworkManager/NetworkManager.conf || echo "change NetworkManager.conf failed!"
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
