#!/bin/bash

if [ -f "/tmp/chroot.env" ];then
	source "/tmp/chroot.env"
fi

export DEBIAN_FRONTEND=noninteractive

mv /etc/resolv.conf /etc/resolv.conf.orig
touch /etc/resolv.conf
echo "nameserver 8.8.4.4" | tee -a /etc/resolv.conf
echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf
alter_resolv=1

echo 'OS upgrade ...'
apt-get clean && apt-get update && apt-get upgrade -y
if [ $? -eq 0 ];then
	echo 'done'
	echo
else
	echo "The execution of the apt-get command failed, the task cannot continue."
	mv /etc/resolv.conf.orig /etc/resolv.conf
	exit 1
fi

if [ "${ENABLE_EXT_REPO}" == "yes" ];then
	echo "Add exend apt reposotorys ..."
	apt-get install -y software-properties-common
	for repo in "${EXT_REPOS}";do
		echo "Add repo: $repo"
		add-apt-repository -y "$repo"
	done
	apt update
	echo "done"
	echo
fi

if [ "${NECESSARY_PKGS}" != "" ] || [ "${OPTIONAL_PKGS}" != "" ] || [ "${CUSTOM_PKGS}" != "" ];then
	echo "Installing preconfigured packages ..."
	apt-get install -y ${NECESSARY_PKGS} ${OPTIONAL_PKGS} ${CUSTOM_PKGS}
	echo "done"
	echo
fi

if [ "${INSTALL_LOCAL_DEBS}" == "yes" ];then
	if [ -f "${LOCAL_DEBS_HOME}/${LOCAL_DEBS_LIST}" ];then
		deb_list=""
		while read line; do
			deb_list="${deb_list} ${line}"
		done < "${LOCAL_DEBS_HOME}/${LOCAL_DEBS_LIST}"

		if [ "$deb_list" != "" ];then
			echo "Installing preconfigured local packages ... "
			( cdl ${LOCAL_DEBS_HOME} && apt install -y ${deb_list} )
			echo "done"
			echo
		fi
	fi
fi

if [ "${HAS_GRAPHICAL_DESKTOP}" == "yes" ];then
	echo "Change default display manager to ${DISPLAY_MANAGER} ..."
	if [ "${DISPLAY_MANAGER}" == "lightdm" ];then
		apt remove -y gdm3 2>/dev/null
	fi
	dpkg-reconfigure "${DISPLAY_MANAGER}"
	echo "done"
	echo
fi

echo "Change some config files ... "
# setup default hostname
echo "ubuntu" > /etc/hostname
if [ -f "/etc/NetworkManager/NetworkManager.conf" ];then
	sed -e 's/managed=false/managed=true/' -i /etc/NetworkManager/NetworkManager.conf || echo "Change NetworkManager.conf failed!"
fi
echo 'done'
echo

echo 'Clean ... '
apt autoremove -y
apt clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
if [ $alter_resolv -eq 1 ];then
	mv /etc/resolv.conf.orig /etc/resolv.conf
fi
echo 'done'
exit 0
