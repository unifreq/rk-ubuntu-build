#!/bin/bash

export WORKDIR=$(dirname $(readlink -f "$0"))
cd ${WORKDIR}

if [ $# -lt 1 ];then
	echo "Usage: $0 dist [clean]"
	echo "dist: focal"
	exit 1
fi

dist=$1
if [ -f "./env/linux/${dist}.env" ];then
	source ./env/linux/${dist}.env
else
	echo "./env/linux/${dist}.env not exists!"
	if [ -f "./env/linux/private/${dist}.env" ];then
		echo "But the private environment file ${WORKDIR}/env/linux/private/${dist}.env has been found."
		source ./env/linux/private/${dist}.env
	else
		echo "./env/linux/private/${dist}.env not exists!"
		exit 1
	fi
fi

if [ ! -x "/usr/sbin/debootstrap" ];then
	echo "/usr/sbin/debootstrap not found, please install debootstrap!"
	echo "example: sudo apt install debootstrap"
	exit 1
fi

host_arch=$(uname -m)
if [ "${host_arch}" == "aarch64" ];then
	CROSS_FLAG=0
else
	CROSS_FLAG=1
fi

if [ $CROSS_FLAG -eq 1 ] && [ ! -x "/usr/bin/qemu-aarch64-static" ];then
	echo "/usr/bin/qemu-aarch64-static not found, please install qemu-aarch64-static!"
	echo "example: sudo apt install qemu-user-static"
	exit 1
fi

if [ ! -f "${CHROOT}" ];then
	echo "The chroot script is not exists! [${CHROOT}]"
	exit 1
fi

if [ -n "$OS_RELEASE" ];then
	os_release=$OS_RELEASE
else
	os_release=$dist
fi

if [ -n "$DIST_ALIAS" ];then
	output_dir=build/${DIST_ALIAS}
else
	output_dir=build/${dist}
fi

function bind() {
	cd ${WORKDIR}
	mount -o bind /dev ${output_dir}/dev
	mount -o bind /dev/pts ${output_dir}/dev/pts
	mount -o bind /proc ${output_dir}/proc
	mount -o bind /run ${output_dir}/run
	mount -o bind /sys ${output_dir}/sys
	which lsmount && lsmount | grep "${output_dir}" && echo -e "\033[0m" && sleep 5
}

function unbind() {
	local i
	cd ${WORKDIR}
	i=0
	while [ $i -le 5 ];do
		umount -f ${output_dir}/dev/pts 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -f ${output_dir}/dev/pts 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	i=0
	while [ $i -le 5 ];do
		umount -f ${output_dir}/dev 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -f ${output_dir}/proc 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -f ${output_dir}/sys 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -f ${output_dir}/run 2>/dev/null || break
		sleep 1
		i=$((i++))
	done
}

function on_trap() {
	unbind
	exit 0
}
trap "on_trap" 2 3 15

param=$2
if [ "$param" == "clean" ];then
    rm -rf ${output_dir}
    echo "${output_dir} cleaned"
    exit 0
fi

echo "Stage 1 ..."
# first stage
mkdir -p ${output_dir}
mkdir -p ${output_dir}/dev
mkdir -p ${output_dir}/proc
mkdir -p ${output_dir}/run
mkdir -p ${output_dir}/sys
bind

if [ $CROSS_FLAG -eq 1 ];then
	debootstrap --arch=arm64 --foreign ${os_release} ${output_dir} "$DEBOOTSTRAP_MIRROR" 
	mkdir -p ${output_dir}/usr/bin && cp -fv /usr/bin/qemu-aarch64-static "${output_dir}/usr/bin/"
else
	debootstrap --arch=arm64 ${os_release} ${output_dir} "$DEBOOTSTRAP_MIRROR" 
fi

# second stage
echo "Stage 2 ..."
if [ $CROSS_FLAG -eq 1 ];then
	chroot "${output_dir}" debootstrap/debootstrap --second-stage
fi
echo "done"

# third stage
echo "Stage 3 ..."
# 阻止服务启动
cat > ${output_dir}/usr/sbin/policy-rc.d <<'EOF'
#!/bin/sh
exit 101
EOF
chmod +x ${output_dir}/usr/sbin/policy-rc.d
cp ${SOURCES_LIST_WORK} ${output_dir}/etc/apt/sources.list

env_file="${output_dir}/tmp/chroot.env"
cat > ${env_file} <<EOF
CHROOT_DEFAULT_ROOT_PASSWORD="${CHROOT_DEFAULT_ROOT_PASSWORD}"
ENABLE_EXT_REPO="${CHROOT_ENABLE_EXT_REPO}"
EXT_REPOS="${CHROOT_EXT_REPOS}"
NECESSARY_PKGS="${CHROOT_NECESSARY_PKGS}"
OPTIONAL_PKGS="${CHROOT_OPTIONAL_PKGS}"
CUSTOM_PKGS="${CHROOT_CUSTOM_PKGS}"
INSTALL_LOCAL_DEBS="${CHROOT_INSTALL_LOCAL_DEBS}"
LOCAL_DEBS_HOME="/tmp/debs/"
LOCAL_DEBS_LIST="${CHROOT_LOCAL_DEBS_LIST}"
HAS_GRAPHICAL_DESKTOP="${CHROOT_HAS_GRAPHICAL_DESKTOP}"
DISPLAY_MANAGER="${CHROOT_DISPLAY_MANAGER}"
EOF

if [ "${CHROOT_INSTALL_LOCAL_DEBS}" == "yes" ];then
	if [ "${CHROOT_LOCAL_DEBS_HOME}" != "" ] && [ -d "${CHROOT_LOCAL_DEBS_HOME}" ];then
		mkdir -p ${output_dir}/tmp/debs && \
		cp -av ${CHROOT_LOCAL_DEBS_HOME}/* ${output_dir}/tmp/debs/
	fi
fi

if [ -f "${CHROOT}" ];then
    cp -v "${CHROOT}" "${output_dir}/tmp/chroot.sh"
else
    echo "${CHROOT} not exists!"
    unbind
    exit 1
fi

if [ $CROSS_FLAG -eq 1 ];then
	chroot ${output_dir} /usr/bin/qemu-aarch64-static /bin/bash /tmp/chroot.sh
else
	chroot ${output_dir} /bin/bash /tmp/chroot.sh
fi

echo "umount ... "
unbind
echo 'done'
echo

[ $CROSS_FLAG -eq 1 ] && rm ${output_dir}/usr/bin/qemu-aarch64-static
[ -f ${SOURCES_LIST_ORIG} ] && cp -v ${SOURCES_LIST_ORIG} ${output_dir}/etc/apt/sources.list
exit 0
