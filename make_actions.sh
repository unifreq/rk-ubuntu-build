#!/usr/bin/env bash
#==============================================================================================
#
# Description: Ubuntu Image and rootfs Builder
# Function: Use Flippy's kernel files and script to build Ubuntu
# Copyright (C) 2025 https://github.com/unifreq/rk-ubuntu-build
# Copyright (C) 2025 https://github.com/ophub/flippy-ubuntu-actions
#
#======================================= Functions list =======================================
#
# error_msg          : Output error message
# download_retry     : Download file with retry mechanism
# init_var           : Initialize all variables
# init_build_repo    : Initialize build ubuntu repository
# query_kernel       : Query the latest kernel version
# check_kernel       : Check kernel files integrity
# download_kernel    : Download the kernel
# make_rootfs        : Make Ubuntu rootfs
# make_image         : Make Ubuntu images
# out_github_env     : Output github.com variables
#
#=============================== Set make environment variables ===============================

# Set the SoC and kernel mapping configuration
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env
# https://github.com/unifreq/rk-ubuntu-build/tree/main/upstream/kernel
#
CONFIG_MAP="
#
# RK3588 kernel devices
#-----------------------+------------------+---------------------
# /env/machine/{*}.env  :/env/soc/{*}.env  :/upstream/kernel/{*}
#-----------------------+------------------+---------------------
h88k                    :rk3588            :rk3588
rock-5b                 :rk3588            :rk3588


# RK35XX kernel devices
#-----------------------+------------------+---------------------
# /env/machine/{*}.env  :/env/soc/{*}.env  :/upstream/kernel/{*}
#-----------------------+------------------+---------------------
100ask-dshanpi-a1       :rk3576-k61        :rk35xx
e20c                    :rk3528            :rk35xx
h28k                    :rk3528            :rk35xx
h29k                    :rk3528            :rk35xx
ht2                     :rk3528            :rk35xx
#-----------------------+------------------+---------------------
ht3                     :rk3528            :rk35xx
yixun-rs6pro            :rk3528            :rk35xx
netfusion               :rk3566-k61        :rk35xx


# Mainline kernel devices
#-----------------------+------------------+---------------------
# /env/machine/{*}.env  :/env/soc/{*}.env  :/upstream/kernel/{*}
#-----------------------+------------------+---------------------
e54c                    :rk3588s-ml        :mainline
h66k                    :rk3568            :mainline
h68k                    :rk3568            :mainline
h69k                    :rk3568            :mainline
h69k-max                :rk3568            :mainline
#-----------------------+------------------+---------------------
zcube1-max              :rk3399-ml         :mainline
#
"
# Set the list of devices to be packaged
BUILD_UBUNTU_LIST=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:" | cut -d: -f1))
# Set the list of devices using the [ rk3588 ] kernel
BUILD_UBUNTU_RK3588=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:rk3588$" | cut -d: -f1))
# Set the list of devices using the [ rk35xx ] kernel
BUILD_UBUNTU_RK35XX=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:rk35xx$" | cut -d: -f1))
# Set the list of devices using the [ mainline ] kernel
BUILD_UBUNTU_MAINLINE=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:mainline$" | cut -d: -f1))

# Set the default kernel download repository (kernel_stable, kernel_rk3588, kernel_rk35xx)
# https://github.com/breakingbadboy/OpenWrt/releases
KERNEL_REPO_URL_VALUE="breakingbadboy/OpenWrt"
# Set kernel tag: kernel_stable, kernel_rk3588, kernel_rk35xx
KERNEL_TAGS=("stable" "rk3588" "rk35xx")
STABLE_KERNEL=("6.12.y")
RK3588_KERNEL=("6.1.y")
RK35XX_KERNEL=("6.1.y")
# Set the flippy kernel tags of the ophub repository (kernel_flippy, kernel_rk3588, kernel_rk35xx)
# https://github.com/ophub/kernel/releases
FLIPPY_KERNEL=(${STABLE_KERNEL[@]})
# Set to automatically query the latest kernel version
KERNEL_AUTO_LATEST_VALUE="true"

# Set the default package source download repository
SCRIPT_REPO_URL_VALUE="https://github.com/unifreq/rk-ubuntu-build"
SCRIPT_REPO_BRANCH_VALUE="main"
# Set the working directory under /opt
SELECT_PACKITPATH_VALUE="rk-ubuntu-build"
SELECT_OUTPUTPATH_VALUE="output"
# Set the default building script
SCRIPT_MKIMG_FILE="mkimg.sh"
SCRIPT_MKROOTFS_FILE="mkrootfs.sh"

# Set the build machine name (e20c, h28k, etc. all = build all devices)
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env/machine
ENV_MACHINE_VALUE="all"
# Set the default Linux flavor
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env/linux
ENV_LINUX_FLAVOR_VALUE="noble-rk-media"
# Set the default custom boot mode
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env/custom
ENV_CUSTOM_BOOT_VALUE="boot256-ext4root"
# Set the default make target (image, rootfs)
# image = build image & rootfs file; rootfs = build only the rootfs file
BUILD_TARGET_VALUE="image"
# Set the default image compression format(7z, xz, zip, zst, gz, auto)
GZIP_IMGS_VALUE="auto"

# Set font color
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
NOTE="[\033[93m NOTE \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#==============================================================================================

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

download_retry() {
    local url="${1}"
    local dest="${2}"
    for i in {1..10}; do
        curl -fsSL "${url}" -o "${dest}" && return 0
        sleep 20
    done
    return 1
}

init_var() {
    echo -e "${STEPS} Start Initializing Variables..."

    # Install the compressed package
    sudo apt-get -qq update
    sudo apt-get -qq install -y curl git coreutils p7zip p7zip-full zip unzip gzip xz-utils pigz zstd jq tar

    # Accept user-defined repository parameters
    SCRIPT_REPO_URL="${SCRIPT_REPO_URL:-${SCRIPT_REPO_URL_VALUE}}"
    [[ "${SCRIPT_REPO_URL,,}" =~ ^http ]] || SCRIPT_REPO_URL="https://github.com/${SCRIPT_REPO_URL}"
    SCRIPT_REPO_BRANCH="${SCRIPT_REPO_BRANCH:-${SCRIPT_REPO_BRANCH_VALUE}}"
    SELECT_PACKITPATH="${SELECT_PACKITPATH:-${SELECT_PACKITPATH_VALUE}}"
    SELECT_OUTPUTPATH="${SELECT_OUTPUTPATH:-${SELECT_OUTPUTPATH_VALUE}}"
    GZIP_IMGS="${GZIP_IMGS:-${GZIP_IMGS_VALUE}}"

    # Accept user-defined SoC and kernel parameters
    ENV_MACHINE="${ENV_MACHINE:-${ENV_MACHINE_VALUE}}"
    KERNEL_REPO_URL="${KERNEL_REPO_URL:-${KERNEL_REPO_URL_VALUE}}"
    KERNEL_AUTO_LATEST="${KERNEL_AUTO_LATEST:-${KERNEL_AUTO_LATEST_VALUE}}"

    BUILD_TARGET="${BUILD_TARGET:-${BUILD_TARGET_VALUE}}"
    # Accept user-defined Linux flavor parameter
    ENV_LINUX_FLAVOR="${ENV_LINUX_FLAVOR:-${ENV_LINUX_FLAVOR_VALUE}}"
    ENV_LINUX_FLAVOR="${ENV_LINUX_FLAVOR/.env/}"
    # Accept user-defined custom boot mode parameter
    ENV_CUSTOM_BOOT="${ENV_CUSTOM_BOOT:-${ENV_CUSTOM_BOOT_VALUE}}"
    ENV_CUSTOM_BOOT="${ENV_CUSTOM_BOOT/.env/}"

    # Accept user-defined building script parameters
    SCRIPT_MKIMG="${SCRIPT_MKIMG:-${SCRIPT_MKIMG_FILE}}"
    SCRIPT_MKROOTFS="${SCRIPT_MKROOTFS:-${SCRIPT_MKROOTFS_FILE}}"

    # Confirm package object
    [[ "${ENV_MACHINE}" != "all" ]] && {
        oldIFS="${IFS}"
        IFS="_"
        BUILD_UBUNTU_LIST=(${ENV_MACHINE})
        IFS="${oldIFS}"
    }

    # Remove duplicate package drivers
    BUILD_UBUNTU_LIST=($(echo "${BUILD_UBUNTU_LIST[@]//.env/}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Convert kernel library address to api format
    echo -e "${INFO} Kernel download repository: [ ${KERNEL_REPO_URL} ]"
    [[ "${KERNEL_REPO_URL}" =~ ^https: ]] && KERNEL_REPO_URL="$(echo ${KERNEL_REPO_URL} | awk -F'/' '{print $4"/"$5}')"
    kernel_api="https://github.com/${KERNEL_REPO_URL}"

    # Reset required kernel tags
    KERNEL_TAGS_TMP=()
    for kt in "${BUILD_UBUNTU_LIST[@]}"; do
        if [[ " ${BUILD_UBUNTU_RK3588[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk3588")
        elif [[ " ${BUILD_UBUNTU_RK35XX[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk35xx")
        else
            # The stable kernel is used by default, and the flippy kernel is used with the ophub repository.
            if [[ "${KERNEL_REPO_URL}" == "ophub/kernel" ]]; then
                KERNEL_TAGS_TMP+=("flippy")
            else
                KERNEL_TAGS_TMP+=("stable")
            fi
        fi
    done
    # Remove duplicate kernel tags
    KERNEL_TAGS=($(echo "${KERNEL_TAGS_TMP[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    echo -e "${INFO} Build directory: [ /opt/${SELECT_PACKITPATH} ]"
    echo -e "${INFO} Build target: [ ${BUILD_TARGET} ]"
    echo -e "${INFO} Build devices: [ $(echo ${BUILD_UBUNTU_LIST[@]} | xargs) ]"
    echo -e "${INFO} The RK3588 kernel devices: [ $(echo ${BUILD_UBUNTU_RK3588[@]} | xargs) ]"
    echo -e "${INFO} The RK35XX kernel devices: [ $(echo ${BUILD_UBUNTU_RK35XX[@]} | xargs) ]"
    echo -e "${INFO} The Mainline kernel devices: [ $(echo ${BUILD_UBUNTU_MAINLINE[@]} | xargs) ]"
    echo -e "${INFO} Linux flavor: [ ${ENV_LINUX_FLAVOR} ]"
    echo -e "${INFO} Custom boot mode: [ ${ENV_CUSTOM_BOOT} ]"
    echo -e "${INFO} Kernel tags: [ $(echo ${KERNEL_TAGS[@]} | xargs) ]"
    echo -e "${INFO} Kernel Query API: [ ${kernel_api} ]"

    # Reset STABLE & FLIPPY kernel options
    [[ -n "${KERNEL_VERSION_NAME}" && " ${KERNEL_TAGS[@]} " =~ (stable|flippy) ]] && {
        oldIFS="${IFS}"
        IFS="_"
        STABLE_KERNEL=(${KERNEL_VERSION_NAME})
        FLIPPY_KERNEL=(${KERNEL_VERSION_NAME})
        IFS="${oldIFS}"
        echo -e "${INFO} Use custom kernel: [ $(echo ${STABLE_KERNEL[@]} | xargs) ]"
    }
}

init_build_repo() {
    cd /opt

    # Clone the repository into the building directory. If it fails, wait 1 minute and try again, try 10 times.
    [[ -d "${SELECT_PACKITPATH}" ]] || {
        echo -e "${STEPS} Start cloning repository [ ${SCRIPT_REPO_URL} ], branch [ ${SCRIPT_REPO_BRANCH} ] into [ ${SELECT_PACKITPATH} ]"
        for i in {1..10}; do
            git clone -q --single-branch --depth=1 --branch=${SCRIPT_REPO_BRANCH} ${SCRIPT_REPO_URL} ${SELECT_PACKITPATH}
            [[ "${?}" -eq "0" ]] && break || sleep 60
        done
        [[ -d "${SELECT_PACKITPATH}" ]] || error_msg "Failed to clone the repository."
    }

    # Create output directory
    OUTPUT_DIR="/opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}"
    [[ -d "${OUTPUT_DIR}" ]] || mkdir -p ${OUTPUT_DIR}
    # Set build output directory
    BUILD_TMP_DIR="/opt/${SELECT_PACKITPATH}/build"
}

query_kernel() {
    echo -e "${STEPS} Start querying the latest kernel..."

    # Check the version on the kernel library
    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Select the corresponding kernel directory and list
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            elif [[ "${vb,,}" == "flippy" ]]; then
                down_kernel_list=(${FLIPPY_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Query the name of the latest kernel version
            TMP_ARR_KERNELS=()
            i=1
            for kernel_var in "${down_kernel_list[@]}"; do
                echo -e "${INFO} (${i}) Auto query the latest kernel version of the same series for [ ${vb} - ${kernel_var} ]"

                # Identify the kernel <VERSION> and <PATCHLEVEL>, such as [ 6.1 ]
                kernel_verpatch="$(echo ${kernel_var} | awk -F '.' '{print $1"."$2}')"

                # Query the latest kernel version
                latest_version="$(
                    curl -fsSL \
                        ${kernel_api}/releases/expanded_assets/kernel_${vb} |
                        grep -oE "${kernel_verpatch}\.[0-9]+.*\.tar\.gz" | sed 's/.tar.gz//' |
                        sort -urV | head -n 1
                )"

                if [[ "$?" -eq "0" && -n "${latest_version}" ]]; then
                    TMP_ARR_KERNELS[${i}]="${latest_version}"
                else
                    TMP_ARR_KERNELS[${i}]="${kernel_var}"
                fi

                echo -e "${INFO} (${i}) [ ${vb} - ${TMP_ARR_KERNELS[$i]} ] is latest kernel."

                ((i++))
            done

            # Reset the kernel array to the latest kernel version
            if [[ "${vb,,}" == "rk3588" ]]; then
                RK3588_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the rk3588 kernel: [ ${RK3588_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                RK35XX_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the rk35xx kernel: [ ${RK35XX_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "flippy" ]]; then
                FLIPPY_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the flippy kernel: [ ${FLIPPY_KERNEL[@]} ]"
            else
                STABLE_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the stable kernel: [ ${STABLE_KERNEL[@]} ]"
            fi

            ((x++))
        }
    done
}

check_kernel() {
    [[ -n "${1}" ]] && check_path="${1}" || error_msg "Invalid kernel path to check."
    check_files=($(cat "${check_path}/sha256sums" | awk '{print $2}'))
    m="1"
    for cf in "${check_files[@]}"; do
        {
            # Check if file exists
            [[ -s "${check_path}/${cf}" ]] || error_msg "The [ ${cf} ] file is missing."
            # Check if the file sha256sum is correct
            tmp_sha256sum="$(sha256sum "${check_path}/${cf}" | awk '{print $1}')"
            tmp_checkcode="$(cat ${check_path}/sha256sums | grep ${cf} | awk '{print $1}')"
            [[ "${tmp_sha256sum,,}" == "${tmp_checkcode,,}" ]] || error_msg "[ ${cf} ]: sha256sum verification failed."
            ((m++))
        }
    done
    echo -e "${INFO} All [ ${#check_files[@]} ] kernel files are sha256sum checked to be complete.\n"
}

download_kernel() {
    echo -e "${STEPS} Start downloading the kernel..."

    cd /opt

    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Set the kernel download list
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            elif [[ "${vb,,}" == "flippy" ]]; then
                down_kernel_list=(${FLIPPY_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Kernel storage directory
            kernel_path="rk-ubuntu-build/upstream/kernel/backup/${vb}"
            [[ -d "${kernel_path}" ]] || mkdir -p ${kernel_path}

            # Download the kernel to the storage directory
            i="1"
            for kernel_var in "${down_kernel_list[@]}"; do
                if [[ ! -d "${kernel_path}/${kernel_var}" ]]; then
                    kernel_down_from="https://github.com/${KERNEL_REPO_URL}/releases/download/kernel_${vb}/${kernel_var}.tar.gz"
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Kernel download from [ ${kernel_down_from} ]"

                    # Download the kernel file. If the download fails, try again 10 times.
                    download_retry "${kernel_down_from}" "${kernel_path}/${kernel_var}.tar.gz"
                    [[ "${?}" -eq "0" ]] || error_msg "Failed to download the kernel files from the server."

                    # Decompress the kernel file
                    tar -mxf "${kernel_path}/${kernel_var}.tar.gz" -C "${kernel_path}"
                    [[ "${?}" -eq "0" ]] || error_msg "[ ${kernel_var} ] kernel decompression failed."
                else
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Kernel is in the local directory."
                fi

                # If the kernel contains the sha256sums file, check the files integrity
                [[ -f "${kernel_path}/${kernel_var}/sha256sums" ]] && check_kernel "${kernel_path}/${kernel_var}"

                ((i++))
            done

            # Delete downloaded kernel temporary files
            rm -f ${kernel_path}/*.tar.gz
            sync

            ((x++))
        }
    done
}

make_rootfs() {
    echo -e "${STEPS} Start building Ubuntu rootfs..."
    cd /opt/${SELECT_PACKITPATH}

    [[ -d "build/${ENV_LINUX_FLAVOR}" ]] && sudo rm -rf build/${ENV_LINUX_FLAVOR}
    # Make the Ubuntu rootfs
    sudo ./${SCRIPT_MKROOTFS_FILE} ${ENV_LINUX_FLAVOR}
    [[ "${?}" -eq "0" ]] && echo -e "${SUCCESS} Ubuntu rootfs building succeeded."
}

make_image() {
    echo -e "${STEPS} Start building Ubuntu image..."

    i="1"
    for machine_var in "${BUILD_UBUNTU_LIST[@]}"; do
        {
            # Distinguish between different Ubuntu and use different kernel
            if [[ " ${BUILD_UBUNTU_RK3588[@]} " =~ " ${machine_var} " ]]; then
                build_kernel=(${RK3588_KERNEL[@]})
                vb="rk3588"
            elif [[ " ${BUILD_UBUNTU_RK35XX[@]} " =~ " ${machine_var} " ]]; then
                build_kernel=(${RK35XX_KERNEL[@]})
                vb="rk35xx"
            else
                if [[ "${KERNEL_REPO_URL}" == "ophub/kernel" ]]; then
                    build_kernel=(${FLIPPY_KERNEL[@]})
                    vb="flippy"
                else
                    build_kernel=(${STABLE_KERNEL[@]})
                    vb="stable"
                fi
            fi

            k="1"
            for kernel_var in "${build_kernel[@]}"; do
                {
                    # Check the available size of server space
                    now_remaining_space="$(df -Tk /opt/${SELECT_PACKITPATH} | tail -n1 | awk '{print $5}' | echo $(($(xargs) / 1024 / 1024)))"
                    [[ "${now_remaining_space}" -le "3" ]] && {
                        echo -e "${WARNING} If the remaining space is less than 3G, exit this building. \n"
                        break
                    }

                    cd /opt/rk-ubuntu-build/upstream/kernel

                    # Copy the kernel to the building directory
                    kernel_dir="$(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^${machine_var}:.*" | cut -d: -f3)"
                    [[ -z "${kernel_dir}" ]] && error_msg "Failed to get the kernel directory for [ ${machine_var} ]."
                    echo -e "${INFO} Use kernel directory: [ ${kernel_dir} ] for [ ${machine_var} ]"

                    # Copy the kernel files to the kernel directory
                    rm -f ${kernel_dir}/*
                    cp -f backup/${vb}/${kernel_var}/* ${kernel_dir}/

                    # Get the kernel version from the boot file
                    boot_kernel_file="$(basename $(ls ${kernel_dir}/boot-${kernel_var}* 2>/dev/null | head -n 1))"
                    KERNEL_VERSION="${boot_kernel_file:5:-7}"
                    [[ -z "${KERNEL_VERSION}" ]] && error_msg "Failed to get the kernel version for [ ${machine_var} - ${vb} - ${kernel_var} ]."
                    echo -e "${STEPS} (${i}.${k}) Start building Ubuntu: [ ${machine_var} ], Kernel directory: [ ${vb} ], Kernel version: [ ${KERNEL_VERSION} ]"

                    cd /opt/${SELECT_PACKITPATH}

                    # Modify the kernel version in the environment configuration file
                    ENV_SOC="$(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^${machine_var}:.*" | cut -d: -f2)"
                    [[ -z "${ENV_SOC}" ]] && error_msg "Failed to get the environment file for [ ${machine_var} ]."
                    sed -i "s|^export kernel_version=.*|export kernel_version=${KERNEL_VERSION}|g" env/soc/${ENV_SOC}.env

                    # sudo /mkimg.sh <soc> <machine> <linux-flavor> [custom]
                    sudo ./${SCRIPT_MKIMG_FILE} ${ENV_SOC/.env/} ${machine_var} ${ENV_LINUX_FLAVOR} ${ENV_CUSTOM_BOOT}

                    # Generate compressed file
                    img_num="$(ls ${BUILD_TMP_DIR}/*.img 2>/dev/null | wc -l)"
                    [[ "${img_num}" -ne "0" ]] && {
                        echo -e "${STEPS} (${i}.${k}) Start making compressed files in the [ build ] directory."
                        cd ${BUILD_TMP_DIR}
                        case "${GZIP_IMGS}" in
                            7z | .7z) ls *.img | xargs -I % sh -c 'sudo 7z a -t7z -r %.7z % && sudo rm -f %' ;;
                            xz | .xz) sudo xz -z *.img ;;
                            zip | .zip) ls *.img | xargs -I % sh -c 'sudo zip %.zip % && sudo rm -f %' ;;
                            zst | .zst) sudo zstd --rm *.img ;;
                            gz | .gz | *) sudo pigz -f *.img ;;
                        esac

                        # Move the compressed package to the output directory
                        sudo mv -f *.{7z,xz,zip,zst,gz} -t ${OUTPUT_DIR} 2>/dev/null || true
                    }

                    echo -e "${SUCCESS} (${i}.${k}) Ubuntu building succeeded: [ ${machine_var} - ${vb} - ${kernel_var} ] \n"
                    sync

                    ((k++))
                }
            done

            ((i++))
        }
    done

    echo -e "${SUCCESS} All packaged completed. \n"
}

out_github_env() {
    echo -e "${STEPS} Output github.com environment variables..."
    if [[ -d "${OUTPUT_DIR}" ]]; then
        cd "${OUTPUT_DIR}"

        # Package the rootfs and img files
        for r in "${BUILD_TMP_DIR}"/*; do
            [[ -d "${r}" ]] && sudo tar -czf "${r##*/}.tar.gz" -C "${BUILD_TMP_DIR}" "${r##*/}"
        done
        sync

        echo "BUILD_OUTPUTPATH=${PWD}" >>${GITHUB_ENV}
        echo "BUILD_OUTPUTDATE=$(date +"%m.%d.%H%M")" >>${GITHUB_ENV}
        echo "BUILD_STATUS=success" >>${GITHUB_ENV}
        echo -e "BUILD_OUTPUTPATH: ${PWD}"
        echo -e "BUILD_OUTPUTDATE: $(date +"%m.%d.%H%M")"
        echo -e "BUILD_STATUS: success"
        echo -e "${INFO} BUILD_OUTPUTPATH files list:"
        echo -e "$(ls -lh . 2>/dev/null) \n"
    else
        echo -e "${ERROR} Building failed. \n"
        echo "BUILD_STATUS=failure" >>${GITHUB_ENV}
    fi
}
# Show welcome message
echo -e "${STEPS} Welcome to use the Ubuntu building tool! \n"
echo -e "${INFO} Server space usage before starting to build:\n$(df -hT /opt) \n"

# Start initializing variables
init_var
init_build_repo

# Make the Ubuntu rootfs
make_rootfs

# Make the Ubuntu process
[[ "${BUILD_TARGET}" == "image" ]] && {
    # Query the latest kernel version if enabled
    [[ "${KERNEL_AUTO_LATEST,,}" =~ ^(true|yes)$ ]] && query_kernel
    # Download the kernel files
    download_kernel
    # Make the Ubuntu image
    make_image
}

# Output the github.com environment variables
out_github_env

# Show server end information
echo -e "${INFO} Server space usage after building:\n$(df -hT /opt) \n"
echo -e "${SUCCESS} The building process has been completed. \n"
