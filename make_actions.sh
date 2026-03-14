#!/usr/bin/env bash
#==============================================================================================
#
# Description: Automated Ubuntu image and rootfs builder for Rockchip devices
# Function: Build Ubuntu using Flippy's kernel files and packaging scripts
# Copyright (C) 2025 https://github.com/unifreq/rk-ubuntu-build
# Copyright (C) 2025 https://github.com/ophub/flippy-ubuntu-actions
#
#======================================= Functions list =======================================
#
# error_msg          : Print error message and exit
# download_retry     : Download file with automatic retry (up to 10 attempts)
# init_var           : Initialize all build variables and configuration
# init_build_repo    : Clone and prepare the build repository
# query_kernel       : Query the latest kernel version from release page
# check_kernel       : Verify kernel file integrity via SHA256 checksums
# download_kernel    : Download and extract kernel files
# make_rootfs        : Build the Ubuntu rootfs filesystem
# make_image         : Build Ubuntu images for target devices
# out_github_env     : Export build results as GitHub Actions environment variables
#
#=============================== Set make environment variables ===============================

# Device-to-SoC and kernel mapping configuration
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
tl3562-minievm          :rk3562-k61        :rk35xx
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
# Extract the full list of supported devices from the config map
BUILD_UBUNTU_LIST=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:" | cut -d: -f1))
# Extract the list of devices using the [ rk3588 ] kernel
BUILD_UBUNTU_RK3588=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:rk3588$" | cut -d: -f1))
# Extract the list of devices using the [ rk35xx ] kernel
BUILD_UBUNTU_RK35XX=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:rk35xx$" | cut -d: -f1))
# Extract the list of devices using the [ mainline ] kernel
BUILD_UBUNTU_MAINLINE=($(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^[^#].*:mainline$" | cut -d: -f1))

# Default kernel download repository (tags: kernel_stable, kernel_rk3588, kernel_rk35xx)
# https://github.com/breakingbadboy/OpenWrt/releases
KERNEL_REPO_URL_VALUE="breakingbadboy/OpenWrt"
# Kernel tags: kernel_stable, kernel_rk3588, kernel_rk35xx
KERNEL_TAGS=("stable" "rk3588" "rk35xx")
STABLE_KERNEL=("6.12.y")
RK3588_KERNEL=("6.1.y")
RK35XX_KERNEL=("6.1.y")
# Flippy kernel versions from the ophub repository (kernel_flippy, kernel_rk3588, kernel_rk35xx)
# https://github.com/ophub/kernel/releases
FLIPPY_KERNEL=(${STABLE_KERNEL[@]})
# Whether to automatically query and use the latest kernel version
KERNEL_AUTO_LATEST_VALUE="true"

# Default build script repository
SCRIPT_REPO_URL_VALUE="https://github.com/unifreq/rk-ubuntu-build"
SCRIPT_REPO_BRANCH_VALUE="main"
# Working directory names under /opt
SELECT_PACKITPATH_VALUE="rk-ubuntu-build"
SELECT_OUTPUTPATH_VALUE="output"
# Default build script filenames
SCRIPT_MKIMG_FILE="mkimg.sh"
SCRIPT_MKROOTFS_FILE="mkrootfs.sh"

# Target device name (e20c, h28k, etc.; "all" = build for all supported devices)
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env/machine
ENV_MACHINE_VALUE="all"
# Default Linux flavor (Ubuntu variant)
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env/linux
ENV_LINUX_FLAVOR_VALUE="noble-rk-media"
# Default custom boot configuration
# https://github.com/unifreq/rk-ubuntu-build/tree/main/env/custom
ENV_CUSTOM_BOOT_VALUE="boot384-ext4root"
# Default build target (image, rootfs)
# image = build both image and rootfs; rootfs = build rootfs only
BUILD_TARGET_VALUE="image"
# Default image compression format (7z, xz, zip, zst, gz, auto)
GZIP_IMGS_VALUE="auto"

# Log level color formatting
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
    echo -e "${STEPS} Initializing build variables..."

    # Install required build dependencies
    sudo apt-get -qq update
    sudo apt-get -qq install -y curl git coreutils p7zip p7zip-full zip unzip gzip xz-utils pigz zstd jq tar

    # Apply user-defined repository settings
    SCRIPT_REPO_URL="${SCRIPT_REPO_URL:-${SCRIPT_REPO_URL_VALUE}}"
    [[ "${SCRIPT_REPO_URL,,}" =~ ^http ]] || SCRIPT_REPO_URL="https://github.com/${SCRIPT_REPO_URL}"
    SCRIPT_REPO_BRANCH="${SCRIPT_REPO_BRANCH:-${SCRIPT_REPO_BRANCH_VALUE}}"
    SELECT_PACKITPATH="${SELECT_PACKITPATH:-${SELECT_PACKITPATH_VALUE}}"
    SELECT_OUTPUTPATH="${SELECT_OUTPUTPATH:-${SELECT_OUTPUTPATH_VALUE}}"
    GZIP_IMGS="${GZIP_IMGS:-${GZIP_IMGS_VALUE}}"

    # Apply user-defined device and kernel settings
    ENV_MACHINE="${ENV_MACHINE:-${ENV_MACHINE_VALUE}}"
    KERNEL_REPO_URL="${KERNEL_REPO_URL:-${KERNEL_REPO_URL_VALUE}}"
    KERNEL_AUTO_LATEST="${KERNEL_AUTO_LATEST:-${KERNEL_AUTO_LATEST_VALUE}}"

    BUILD_TARGET="${BUILD_TARGET:-${BUILD_TARGET_VALUE}}"
    # Accept user-defined Linux flavor
    ENV_LINUX_FLAVOR="${ENV_LINUX_FLAVOR:-${ENV_LINUX_FLAVOR_VALUE}}"
    ENV_LINUX_FLAVOR="${ENV_LINUX_FLAVOR/.env/}"
    # Accept user-defined custom boot configuration
    ENV_CUSTOM_BOOT="${ENV_CUSTOM_BOOT:-${ENV_CUSTOM_BOOT_VALUE}}"
    ENV_CUSTOM_BOOT="${ENV_CUSTOM_BOOT/.env/}"

    # Accept user-defined build script filenames
    SCRIPT_MKIMG="${SCRIPT_MKIMG:-${SCRIPT_MKIMG_FILE}}"
    SCRIPT_MKROOTFS="${SCRIPT_MKROOTFS:-${SCRIPT_MKROOTFS_FILE}}"

    # Apply user-specified device list if not "all"
    [[ "${ENV_MACHINE}" != "all" ]] && {
        oldIFS="${IFS}"
        IFS="_"
        BUILD_UBUNTU_LIST=(${ENV_MACHINE})
        IFS="${oldIFS}"
    }

    # Deduplicate device list and strip .env suffix
    BUILD_UBUNTU_LIST=($(echo "${BUILD_UBUNTU_LIST[@]//.env/}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Convert kernel repository URL to API format
    echo -e "${INFO} Kernel repository: [ ${KERNEL_REPO_URL} ]"
    [[ "${KERNEL_REPO_URL}" =~ ^https: ]] && KERNEL_REPO_URL="$(echo ${KERNEL_REPO_URL} | awk -F'/' '{print $4"/"$5}')"
    kernel_api="https://github.com/${KERNEL_REPO_URL}"

    # Determine required kernel tags based on device list
    KERNEL_TAGS_TMP=()
    for kt in "${BUILD_UBUNTU_LIST[@]}"; do
        if [[ " ${BUILD_UBUNTU_RK3588[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk3588")
        elif [[ " ${BUILD_UBUNTU_RK35XX[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk35xx")
        else
            # Default to stable kernel; use flippy kernel when ophub repository is specified
            if [[ "${KERNEL_REPO_URL}" == "ophub/kernel" ]]; then
                KERNEL_TAGS_TMP+=("flippy")
            else
                KERNEL_TAGS_TMP+=("stable")
            fi
        fi
    done
    # Deduplicate kernel tags
    KERNEL_TAGS=($(echo "${KERNEL_TAGS_TMP[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    echo -e "${INFO} Build working directory: [ /opt/${SELECT_PACKITPATH} ]"
    echo -e "${INFO} Build target: [ ${BUILD_TARGET} ]"
    echo -e "${INFO} Target devices: [ $(echo ${BUILD_UBUNTU_LIST[@]} | xargs) ]"
    echo -e "${INFO} RK3588 kernel devices: [ $(echo ${BUILD_UBUNTU_RK3588[@]} | xargs) ]"
    echo -e "${INFO} RK35XX kernel devices: [ $(echo ${BUILD_UBUNTU_RK35XX[@]} | xargs) ]"
    echo -e "${INFO} Mainline kernel devices: [ $(echo ${BUILD_UBUNTU_MAINLINE[@]} | xargs) ]"
    echo -e "${INFO} Linux flavor: [ ${ENV_LINUX_FLAVOR} ]"
    echo -e "${INFO} Custom boot mode: [ ${ENV_CUSTOM_BOOT} ]"
    echo -e "${INFO} Kernel tags: [ $(echo ${KERNEL_TAGS[@]} | xargs) ]"
    echo -e "${INFO} Kernel release page: [ ${kernel_api} ]"

    # Override STABLE & FLIPPY kernel versions if user-specified
    [[ -n "${KERNEL_VERSION_NAME}" && " ${KERNEL_TAGS[@]} " =~ (stable|flippy) ]] && {
        oldIFS="${IFS}"
        IFS="_"
        STABLE_KERNEL=(${KERNEL_VERSION_NAME})
        FLIPPY_KERNEL=(${KERNEL_VERSION_NAME})
        IFS="${oldIFS}"
        echo -e "${INFO} Custom kernel version specified: [ $(echo ${STABLE_KERNEL[@]} | xargs) ]"
    }
}

init_build_repo() {
    cd /opt

    # Clone the repository into the build directory (retry up to 10 times with 60s intervals on failure)
    [[ -d "${SELECT_PACKITPATH}" ]] || {
        echo -e "${STEPS} Cloning repository [ ${SCRIPT_REPO_URL} ], branch [ ${SCRIPT_REPO_BRANCH} ] into [ ${SELECT_PACKITPATH} ]..."
        for i in {1..10}; do
            git clone -q --single-branch --depth=1 --branch=${SCRIPT_REPO_BRANCH} ${SCRIPT_REPO_URL} ${SELECT_PACKITPATH}
            [[ "${?}" -eq "0" ]] && break || sleep 60
        done
        [[ -d "${SELECT_PACKITPATH}" ]] || error_msg "Failed to clone the repository after 10 attempts."
    }

    # Create the output directory
    OUTPUT_DIR="/opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}"
    [[ -d "${OUTPUT_DIR}" ]] || mkdir -p ${OUTPUT_DIR}
    # Set the build temporary directory path
    BUILD_TMP_DIR="/opt/${SELECT_PACKITPATH}/build"
}

query_kernel() {
    echo -e "${STEPS} Querying the latest kernel versions..."

    # Check the latest kernel version for each tag
    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Select the kernel list for the current tag
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            elif [[ "${vb,,}" == "flippy" ]]; then
                down_kernel_list=(${FLIPPY_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Query the latest version for each kernel series
            TMP_ARR_KERNELS=()
            i=1
            for kernel_var in "${down_kernel_list[@]}"; do
                echo -e "${INFO} (${i}) Querying latest version in the same series for [ ${vb} - ${kernel_var} ]"

                # Extract kernel VERSION.PATCHLEVEL (e.g., 6.1)
                kernel_verpatch="$(echo ${kernel_var} | awk -F '.' '{print $1"."$2}')"

                # Fetch the latest kernel version from the release page
                latest_version="$(
                    curl -fsSL \
                        ${kernel_api}/releases/expanded_assets/kernel_${vb} |
                        grep -oP "${kernel_verpatch}\.[0-9]+.*?(?=\.tar\.gz)" |
                        sort -urV | head -n 1
                )"

                if [[ "$?" -eq "0" && -n "${latest_version}" ]]; then
                    TMP_ARR_KERNELS[${i}]="${latest_version}"
                else
                    TMP_ARR_KERNELS[${i}]="${kernel_var}"
                fi

                echo -e "${INFO} (${i}) [ ${vb} - ${TMP_ARR_KERNELS[$i]} ] is the latest kernel version."

                ((i++))
            done

            # Update the kernel array with the latest versions
            if [[ "${vb,,}" == "rk3588" ]]; then
                RK3588_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest RK3588 kernel version: [ ${RK3588_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                RK35XX_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest RK35XX kernel version: [ ${RK35XX_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "flippy" ]]; then
                FLIPPY_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest Flippy kernel version: [ ${FLIPPY_KERNEL[@]} ]"
            else
                STABLE_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest Stable kernel version: [ ${STABLE_KERNEL[@]} ]"
            fi

            ((x++))
        }
    done
}

check_kernel() {
    [[ -n "${1}" ]] && check_path="${1}" || error_msg "No kernel path specified for integrity check."
    check_files=($(cat "${check_path}/sha256sums" | awk '{print $2}'))
    m="1"
    for cf in "${check_files[@]}"; do
        {
            # Verify that the file exists
            [[ -s "${check_path}/${cf}" ]] || error_msg "Required kernel file [ ${cf} ] is missing."
            # Verify the file SHA256 checksum
            tmp_sha256sum="$(sha256sum "${check_path}/${cf}" | awk '{print $1}')"
            tmp_checkcode="$(cat ${check_path}/sha256sums | grep ${cf} | awk '{print $1}')"
            [[ "${tmp_sha256sum,,}" == "${tmp_checkcode,,}" ]] || error_msg "[ ${cf} ]: SHA256 checksum verification failed."
            ((m++))
        }
    done
    echo -e "${INFO} All [ ${#check_files[@]} ] kernel files passed SHA256 integrity check.\n"
}

download_kernel() {
    echo -e "${STEPS} Downloading kernel files..."

    cd /opt

    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Select the kernel download list for the current tag
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            elif [[ "${vb,,}" == "flippy" ]]; then
                down_kernel_list=(${FLIPPY_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Create kernel storage directory if not exists
            kernel_path="rk-ubuntu-build/upstream/kernel/backup/${vb}"
            [[ -d "${kernel_path}" ]] || mkdir -p ${kernel_path}

            # Download each kernel version
            i="1"
            for kernel_var in "${down_kernel_list[@]}"; do
                if [[ ! -d "${kernel_path}/${kernel_var}" ]]; then
                    kernel_down_from="https://github.com/${KERNEL_REPO_URL}/releases/download/kernel_${vb}/${kernel_var}.tar.gz"
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Downloading kernel from [ ${kernel_down_from} ]"

                    # Download the kernel file (retry up to 10 times on failure)
                    download_retry "${kernel_down_from}" "${kernel_path}/${kernel_var}.tar.gz"
                    [[ "${?}" -eq "0" ]] || error_msg "Failed to download kernel file after 10 attempts."

                    # Extract the kernel archive
                    tar -mxf "${kernel_path}/${kernel_var}.tar.gz" -C "${kernel_path}"
                    [[ "${?}" -eq "0" ]] || error_msg "Failed to extract [ ${kernel_var} ] kernel archive."
                else
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Kernel already exists locally, skipping download."
                fi

                # Verify kernel file integrity if sha256sums is available
                [[ -f "${kernel_path}/${kernel_var}/sha256sums" ]] && check_kernel "${kernel_path}/${kernel_var}"

                ((i++))
            done

            # Clean up downloaded kernel archive files
            rm -f ${kernel_path}/*.tar.gz
            sync

            ((x++))
        }
    done
}

make_rootfs() {
    echo -e "${STEPS} Building Ubuntu rootfs..."
    cd /opt/${SELECT_PACKITPATH}

    [[ -d "build/${ENV_LINUX_FLAVOR}" ]] && sudo rm -rf build/${ENV_LINUX_FLAVOR}
    # Build the Ubuntu rootfs
    sudo ./${SCRIPT_MKROOTFS_FILE} ${ENV_LINUX_FLAVOR}
    [[ "${?}" -eq "0" ]] && echo -e "${SUCCESS} Ubuntu rootfs built successfully."
}

make_image() {
    echo -e "${STEPS} Building Ubuntu images..."

    i="1"
    for machine_var in "${BUILD_UBUNTU_LIST[@]}"; do
        {
            # Select the appropriate kernel based on device type
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
                    # Check available disk space
                    now_remaining_space="$(df -Tk /opt/${SELECT_PACKITPATH} | tail -n1 | awk '{print $5}' | echo $(($(xargs) / 1024 / 1024)))"
                    [[ "${now_remaining_space}" -le "3" ]] && {
                        echo -e "${WARNING} Insufficient disk space (< 3 GB remaining), skipping build. \n"
                        break
                    }

                    cd /opt/rk-ubuntu-build/upstream/kernel

                    # Determine the kernel directory from the config map
                    kernel_dir="$(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^${machine_var}:.*" | cut -d: -f3)"
                    [[ -z "${kernel_dir}" ]] && error_msg "Unable to determine kernel directory for [ ${machine_var} ]."
                    echo -e "${INFO} Kernel directory: [ ${kernel_dir} ] for device [ ${machine_var} ]"

                    # Copy kernel files to the target kernel directory
                    rm -f ${kernel_dir}/*
                    cp -f backup/${vb}/${kernel_var}/* ${kernel_dir}/

                    # Extract kernel version from the boot file name
                    boot_kernel_file="$(basename $(ls ${kernel_dir}/boot-${kernel_var}* 2>/dev/null | head -n 1))"
                    KERNEL_VERSION="${boot_kernel_file:5:-7}"
                    [[ -z "${KERNEL_VERSION}" ]] && error_msg "Unable to extract kernel version for [ ${machine_var} - ${vb} - ${kernel_var} ]."
                    echo -e "${STEPS} (${i}.${k}) Building Ubuntu image: [ ${machine_var} ], Kernel tag: [ ${vb} ], Kernel version: [ ${KERNEL_VERSION} ]"

                    cd /opt/${SELECT_PACKITPATH}

                    # Update the kernel version in the SoC environment config
                    ENV_SOC="$(echo "${CONFIG_MAP}" | tr -d ' ' | grep -E "^${machine_var}:.*" | cut -d: -f2)"
                    [[ -z "${ENV_SOC}" ]] && error_msg "Unable to determine SoC environment config for [ ${machine_var} ]."
                    sed -i "s|^export kernel_version=.*|export kernel_version=${KERNEL_VERSION}|g" env/soc/${ENV_SOC}.env

                    # sudo /mkimg.sh <soc> <machine> <linux-flavor> [custom]
                    sudo ./${SCRIPT_MKIMG_FILE} ${ENV_SOC/.env/} ${machine_var} ${ENV_LINUX_FLAVOR} ${ENV_CUSTOM_BOOT}

                    # Compress the generated image files
                    img_num="$(ls ${BUILD_TMP_DIR}/*.img 2>/dev/null | wc -l)"
                    [[ "${img_num}" -ne "0" ]] && {
                        echo -e "${STEPS} (${i}.${k}) Compressing image files in the [ build ] directory."
                        cd ${BUILD_TMP_DIR}
                        case "${GZIP_IMGS}" in
                            7z | .7z) ls *.img | xargs -I % sh -c 'sudo 7z a -t7z -r %.7z % && sudo rm -f %' ;;
                            xz | .xz) sudo xz -z *.img ;;
                            zip | .zip) ls *.img | xargs -I % sh -c 'sudo zip %.zip % && sudo rm -f %' ;;
                            zst | .zst) sudo zstd --rm *.img ;;
                            gz | .gz | *) sudo pigz -f *.img ;;
                        esac

                        # Move compressed files to the output directory
                        sudo mv -f *.{7z,xz,zip,zst,gz} -t ${OUTPUT_DIR} 2>/dev/null || true
                    }

                    echo -e "${SUCCESS} (${i}.${k}) Ubuntu image built successfully: [ ${machine_var} - ${vb} - ${kernel_var} ] \n"
                    sync

                    ((k++))
                }
            done

            ((i++))
        }
    done

    echo -e "${SUCCESS} All device images built successfully. \n"
}

out_github_env() {
    echo -e "${STEPS} Exporting GitHub Actions environment variables..."
    if [[ -d "${OUTPUT_DIR}" ]]; then
        cd "${OUTPUT_DIR}"

        # Package rootfs directories into tar.gz archives
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
        echo -e "${INFO} Output directory file listing:"
        echo -e "$(ls -lh . 2>/dev/null) \n"
    else
        echo -e "${ERROR} Build failed, output directory not found. \n"
        echo "BUILD_STATUS=failure" >>${GITHUB_ENV}
    fi
}
# Show welcome message
echo -e "${STEPS} Welcome to the Ubuntu Image Builder! \n"
echo -e "${INFO} Server disk usage before build:\n$(df -hT /opt) \n"

# Initialize build variables
init_var
init_build_repo

# Build the Ubuntu rootfs
make_rootfs

# Build Ubuntu images for target devices
[[ "${BUILD_TARGET}" == "image" ]] && {
    # Query the latest kernel version if auto-update is enabled
    [[ "${KERNEL_AUTO_LATEST,,}" =~ ^(true|yes)$ ]] && query_kernel
    # Download the required kernel files
    download_kernel
    # Build Ubuntu images
    make_image
}

# Export build results as GitHub Actions environment variables
out_github_env

# Show server end information
echo -e "${INFO} Server disk usage after build:\n$(df -hT /opt) \n"
echo -e "${SUCCESS} Build process completed successfully. \n"
