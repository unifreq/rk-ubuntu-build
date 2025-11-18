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
			( cd ${LOCAL_DEBS_HOME} && apt install -y ${deb_list} )
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

# Get OS-RELEASE
source /etc/os-release

# setup default hostname
hostname=${ID:-linux}
echo "${ID}" > /etc/hostname

# If debian
if [ "$ID" == "debian" ];then
	cat >> /etc/bash.bashrc <<EOF

# You may uncomment the following lines if you want 'ls' to be colorized:
export LS_OPTIONS='--color=auto'
eval "\$(dircolors)"
alias ls='ls \$LS_OPTIONS'
alias ll='ls \$LS_OPTIONS -l'
alias l='ls \$LS_OPTIONS -lA'
#
# Some more alias to avoid making mistakes:
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'
EOF
fi

# If ubuntu
if [ "$ID" == "ubuntu" ];then
	# set snapd preferences
	cat > /etc/apt/preferences.d/no-snapd << EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

	# set mozilla preferences
	cat > /etc/apt/preferences.d/mozilla <<EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
	# Create install firefox script
	cat > /usr/local/bin/install_firefox.sh <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo add-apt-repository ppa:mozillateam/ppa
# sed -e 's/ppa.launchpad.net/launchpad.proxy.ustclug.org/' -i /etc/apt/sources.list.d/*mozilla*
apt update && apt install firefox
EOF
	chmod a+x /usr/local/bin/install_firefox.sh
fi

if [ -f "/etc/NetworkManager/NetworkManager.conf" ];then
	sed -e 's/managed=false/managed=true/' -i /etc/NetworkManager/NetworkManager.conf || echo "Change NetworkManager.conf failed!"
fi
echo 'done'
echo

root_password=${CHROOT_DEFAULT_ROOT_PASSWORD:-1234}
echo -ne "Setup the default password \033[1m${root_password}\033[0m for user root ... "
echo "root:${root_password}" | chpasswd
echo "done"
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
