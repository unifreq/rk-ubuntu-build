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

# install debootstrap
if [ -f ${WORKDIR}/src/debootstrap.tar.gz ];then
	(
		echo "========================================================"
		echo "Install bootstrap ..."
		cd /tmp && \
			tar xf ${WORKDIR}/src/debootstrap.tar.gz && \
			cd /tmp/debootstrap && \
			make install
	)
fi

if [ ! -x /usr/sbin/debootstrap ];then
	echo "debootstrap is not exists, please install it first!"
	exit 1
else
	echo "The deboostrap version is:"
	/usr/sbin/debootstrap --version
	echo "========================================================"
	echo
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

param=$2
if [ "$param" == "clean" ];then
    rm -rf ${output_dir}
    echo "${output_dir} cleaned"
    exit 0
fi

function ask_force_pass() {
    local stage_name="$1"
    local ok_file="$2"

    # 检查是否在交互式环境中
    if [ -t 0 ] && [ -t 1 ]; then
        # 交互式：提示用户
        read -p "Stage ${stage_name} failed. Force mark as passed? (y/N): " -r reply
        case "$reply" in
            [yY])
                touch "$ok_file"
                echo "Forced stage ${stage_name} to pass."
                return 0
                ;;
        esac
    else
        # 非交互式（如 GitHub Actions）：自动拒绝
        echo "Non-interactive environment detected. Cannot force pass stage ${stage_name}."
    fi

    # 默认行为：不强制跳过
    return 1
}

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
		umount -l ${output_dir}/dev/pts 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -l ${output_dir}/dev/pts 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	i=0
	while [ $i -le 5 ];do
		umount -l ${output_dir}/dev 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -l ${output_dir}/proc 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -l ${output_dir}/sys 2>/dev/null || break
		sleep 1
		i=$((i++))
	done

	i=0
	while [ $i -le 5 ];do
		umount -l ${output_dir}/run 2>/dev/null || break
		sleep 1
		i=$((i++))
	done
}

function on_trap() {
	unbind
	exit 0
}
trap "on_trap" 2 3 15

# first stage
echo "Stage 1 ..."
if [ -f "${output_dir}/stage1-ok" ];then
	echo "Stage 1 has been skipped."
else
	if [ $CROSS_FLAG -eq 1 ];then
		/usr/sbin/debootstrap --arch=arm64 --foreign ${os_release} ${output_dir} "$DEBOOTSTRAP_MIRROR"
		ret=$?
	else
		/usr/sbin/debootstrap --arch=arm64 ${os_release} ${output_dir} "$DEBOOTSTRAP_MIRROR"
		ret=$?
	fi

	if [ $ret -ne 0 ]; then
		echo "Stage 1 failed! Exit code: $ret"
		if ask_force_pass "1" "${output_dir}/stage1-ok"; then
			if [ $CROSS_FLAG -eq 1 ];then
				mkdir -p ${output_dir}/usr/bin && cp -fv /usr/bin/qemu-aarch64-static "${output_dir}/usr/bin/"
			fi
		else
			exit 1
		fi
	else
		touch "${output_dir}/stage1-ok"
	fi
	echo "Stage 1 pass"
fi

mkdir -p ${output_dir}
mkdir -p ${output_dir}/dev
mkdir -p ${output_dir}/dev/pts
mkdir -p ${output_dir}/proc
mkdir -p ${output_dir}/run
mkdir -p ${output_dir}/sys
bind

# second stage
echo "Stage 2 ... "

if [ $CROSS_FLAG -eq 0 ];then
	echo "Stage 2 is not required in the native environment and has been skipped."
else
	if [ -f "${output_dir}/stage2-ok" ];then
		echo "Stage2 has been skipped."
	else
		chroot "${output_dir}" debootstrap/debootstrap --second-stage
		ret=$?

		if [ $ret -ne 0 ]; then
			echo "Stage 2 failed! Exit code: $ret"
			if ! ask_force_pass "2" "${output_dir}/stage2-ok"; then
				exit 1
			fi
		else
			touch "${output_dir}/stage2-ok"
		fi
		echo "Stage 2 pass"
	fi
fi

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
	chroot ${output_dir} /usr/bin/qemu-aarch64-static /bin/bash /tmp/chroot.sh || \
		{ echo "Stage 3 failed!"; unbind; exit 1; }
else
	chroot ${output_dir} /bin/bash /tmp/chroot.sh || \
		{ echo "Stage 3 failed!"; unbind; exit 1; }
fi

echo "umount ... "
unbind
echo 'done'
echo

[ $CROSS_FLAG -eq 1 ] && rm ${output_dir}/usr/bin/qemu-aarch64-static
[ -f ${SOURCES_LIST_ORIG} ] && cp -v ${SOURCES_LIST_ORIG} ${output_dir}/etc/apt/sources.list
exit 0
