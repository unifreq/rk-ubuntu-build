# 功能说明

查看英文说明 | [View English description](README.md)

支持 Rockchip 系列设备，例如 `rock-5b`, `h28k` 等。可以制作 Ubuntu 和 Debian 系统的 img 镜像和 rootfs 文件。

## 系统默认账号信息

| 默认账号 | 默认密码  | SSH 端口 | IP 地址 |
| ------- | ------- | ------- | ------- |
| root | root | 22 | 从路由器获取 IP |

## 使用方法

在 `.github/workflows/*.yml` 云编译脚本中引入此 Actions 即可使用，例如 [build-ubuntu.yml](.github/workflows/build-ubuntu.yml)。代码如下：

推荐使用 ARM64 架构的 runner 进行编译：`runs-on: ubuntu-24.04-arm`

```yaml
- name: Build Ubuntu
  uses: unifreq/rk-ubuntu-build@main
  env:
    MAKE_TARGET: img
    UBUNTU_SOC: e20c_h28k
    ENV_LINUX_FLAVOR: noble-xfce
    ENV_CUSTOM_BOOT: boot256-ext4root
    KERNEL_VERSION_NAME: 6.1.y_6.12.y
```

## 可选参数说明

根据构建脚本，可以对 `选择内核版本`、`选择设备SoC` 等参数进行配置。

| 参数                   | 默认值                  | 说明                                            |
|------------------------|------------------------|------------------------------------------------|
| SCRIPT_REPO_URL        | unifreq/rk-ubuntu-build | 设置构建脚本源码仓库的 `<owner>/<repo>` |
| SCRIPT_REPO_BRANCH     | main                   | 设置构建脚本源码仓库的分支                        |
| KERNEL_REPO_URL        | breakingbadboy/OpenWrt | 设置内核下载仓库的 `<owner>/<repo>`，默认从 breakingbadboy 维护的[内核 Releases](https://github.com/breakingbadboy/OpenWrt/releases/tag/kernel_stable)里下载。 |
| KERNEL_VERSION_NAME    | 6.12.y                 | 设置[主线内核版本](https://github.com/breakingbadboy/OpenWrt/releases/tag/kernel_stable)，可以查看并选择指定。可指定单个内核如 `6.1.y` ，可选择多个内核用`_`连接如 `6.1.y_6.12.y` |
| KERNEL_AUTO_LATEST     | true                   | 设置是否自动采用同系列最新版本内核。当为 `true` 时，将自动在内核库中查找在 `KERNEL_VERSION_NAME` 中指定的内核如 `6.1.y` 的同系列是否有更新的版本，如有更新版本时，将自动更换为最新版。设置为 `false` 时将编译指定版本内核。 |
| UBUNTU_SOC             | all                    | 设置构建设备的 `SOC` ，默认 `all` 构建全部设备，可指定单个设备如 `e20c` ，可选择多个设备用`_`连接如 `e20c_e54c` 。可选值参考：[env/machine](https://github.com/unifreq/rk-ubuntu-build/tree/main/env/machine) |
| MAKE_TARGET            | img                    | 设置构建 img 镜像或者 rootfs 文件。可选值 `img` / `rootfs`。默认值 `img` |
| ENV_LINUX_FLAVOR       | noble-rk-media         | 设置构建镜像或 rootfs 的 Linux 发行版风格。默认值 `noble-rk-media`，可选值参考：[env/linux](https://github.com/unifreq/rk-ubuntu-build/tree/main/env/linux) |
| ENV_CUSTOM_BOOT        | boot256-ext4root       | 设置自定义启动模式。默认值 `boot256-ext4root`，可选值参考：[env/custom](https://github.com/unifreq/rk-ubuntu-build/tree/main/env/custom) |
| GZIP_IMGS              | auto                   | 设置构建完毕后文件压缩的格式，可选值 `.gz`（默认） / `.xz` / `.zip` / `.zst` / `.7z` |
| SELECT_PACKITPATH      | rk-ubuntu-build        | 设置 `/opt` 下的构建目录名称                     |
| SELECT_OUTPUTPATH      | output                 | 设置 `${SELECT_PACKITPATH}` 目录中固件输出的目录名称 |
| SCRIPT_MKIMG           | mkimg.sh               | 设置制作镜像的脚本文件名                         |
| SCRIPT_MKROOTFS        | mkrootfs.sh            | 设置制作 rootfs 的脚本文件名                     |


## 输出参数说明

根据 github.com 的标准输出了 3 个变量，方便编译步骤后续使用。由于 github.com 最近修改了 fork 仓库的设置，默认关闭了 Workflow 的读写权限，请启用仓库中的 [Workflow 读写权限](https://user-images.githubusercontent.com/68696949/167585338-841d3b05-8d98-4d73-ba72-475aad4a95a9.png)。

| 参数                         | 默认值                       | 说明               |
|-----------------------------|-----------------------------|--------------------|
| ${{ env.BUILD_OUTPUTPATH }} | /opt/rk-ubuntu-build/output | 构建输出路径         |
| ${{ env.BUILD_OUTPUTDATE }} | 07.15.1058                  | 构建日期            |
| ${{ env.BUILD_STATUS }}     | success / failure           | 构建状态。成功 / 失败 |

## 内核仓库链接
- [breakingbadboy/OpenWrt](https://github.com/breakingbadboy/OpenWrt)
- [ophub/kernel](https://github.com/ophub/kernel)

