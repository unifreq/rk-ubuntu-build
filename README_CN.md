# Rockchip RK35xx 设备 Ubuntu 镜像构建工具

[English Documentation](README.md) | [中文文档](README_CN.md)

## 🖥️ 系统要求

### 宿主环境
| 类别              | 要求                                                                         |
|-------------------|-----------------------------------------------------------------------------|
| 架构              | **x86_64** 或 **arm64(推荐)**                                                     |
| 操作系统          | Ubuntu 20.04+/Debian 11+ 或 Armbian (arm64设备)                             |
| 存储空间          | 最小16GB (桌面版建议50GB以上)                                               |

### 核心工具
安装基础依赖：
```bash
sudo apt update && sudo apt install -y \
    losetup \
    binfmt-support \
    fdisk \
    parted \
    dosfstools \
    wget \
    curl
```

### debootstrap 安装

已强制采用本地debootstrap源码安装，来自https://git.launchpad.net/ubuntu/+source/debootstrap

### 文件系统工具
镜像创建所需软件包：
```bash
sudo apt install -y \
    e2fsprogs \    # ext4支持
    xfsprogs \     # XFS支持
    btrfs-progs \  # Btrfs支持
    f2fs-tools     # F2FS支持
```

### 跨架构支持 (仅x86)
启用ARM64模拟：
```bash
sudo apt install -y qemu-user-static
sudo update-binfmts --enable qemu-aarch64
```

### 内核处理
自定义内核集成工具：
```bash
sudo apt install -y \
    u-boot-tools \
    device-tree-compiler \
    kmod
```

### 验证工具 (可选)
```bash
sudo apt install -y \
    tree \         # 目录可视化
    pv \           # 进度监控
    md5sum         # 校验和验证
```

![结构](https://img.shields.io/badge/项目结构-层级清晰-009688?logo=files&style=flat)

## 📂 文件结构
```
env/
├── custom/          # 自定义配置
│   ├── boot256-ext4root.env
│   ├── boot256-xfsroot.env
│   └── ...
├── linux/           # Linux发行版配置
│   ├── focal.env    # Ubuntu 20.04
│   ├── jammy-xfce.env  # Ubuntu 22.04 XFCE桌面版
│   └── ...
├── machine/         # 设备型号
│   ├── h68k.env     # H68K开发板
│   ├── h69k-max.env # H69K-MAX开发板
│   └── ...
└── soc/             # 芯片配置
    ├── rk3568.env   # RK3568芯片
    ├── rk3588.env   # RK3588芯片
    └── ...
```

![组件](https://img.shields.io/badge/核心组件-需手动上传-009688?logo=archive&style=flat)

## 📂 核心组件管理

### Upstream 目录结构
```
upstream/
├── bootfs/           # 启动文件系统
│   └── <machine>/    # 按设备分类的启动资源
│       ├── boot.bmp  # 启动Logo
│       ├── boot.cmd  # U-Boot命令脚本
│       └── boot.scr  # 编译后的启动脚本
├── bootloader/       # 引导加载程序
│   └── <machine>/    # 设备专用二进制文件
│       ├── idbloader.img
│       └── u-boot.itb
└── kernel/           # 内核包
    ├── mainline/     # 主线内核
    ├── rk3588/       # RK3588专用内核
    └── rk35xx/       # RK35xx系列专用内核
```

### 内核准备 (手动操作)
1. **下载内核包** 从内核维护者处获取
2. **上传文件** 到对应目录:
```bash
# 示例：上传 RK35xx 内核
cp boot-5.10.160-rk35xx*.tar.gz upstream/kernel/rk35xx/
cp dtb-rockchip-5.10.160-rk35xx*.tar.gz upstream/kernel/rk35xx/
cp modules-5.10.160-rk35xx*.tar.gz upstream/kernel/rk35xx/
```

📦 **所需内核包清单**:
| 包类型              | 文件名模式                      |
|---------------------|-------------------------------|
| 启动文件            | `boot-<版本>.tar.gz`           |
| 设备树文件          | `dtb-rockchip-<版本>.tar.gz`   |
| 内核头文件          | `header-<版本>.tar.gz`         |
| 内核模块            | `modules-<版本>.tar.gz`        |

❗ **重要提示**：  
内核包版本必须严格匹配，例如有效组合：  
```
boot-5.10.160-rk35xx-flippy-2412a.tar.gz
dtb-rockchip-5.10.160-rk35xx-flippy-2412a.tar.gz
modules-5.10.160-rk35xx-flippy-2412a.tar.gz
```

## 🛠️ 构建指南

### 1. 创建根文件系统
```bash
# 语法: ./mkrootfs.sh <系统版本>
sudo ./mkrootfs.sh focal          # Ubuntu 20.04
sudo ./mkrootfs.sh jammy-xfce     # Ubuntu 22.04 XFCE桌面版
```

🔍 **参数解析**  
`<系统版本>` 对应 `env/linux/` 目录下的 `.env` 文件，例如：
- `focal` → `env/linux/focal.env`
- `jammy-xfce` → `env/linux/jammy-xfce.env`

### 2. 生成目标镜像
```bash
# 语法: ./mkimg.sh <芯片> <设备> <系统版本> [自定义]
sudo ./mkimg.sh rk3568 h68k focal           # 基础用法
sudo ./mkimg.sh rk3588 h69k-max jammy-xfce boot256-ext4root  # 带自定义配置
```

🔍 **参数详解**  
| 参数          | 文件位置               | 示例文件              | 必选     |
|--------------|-----------------------|-----------------------|----------|
| `<芯片>`      | `env/soc/`            | rk3568.env            | 是       |
| `<设备>`      | `env/machine/`        | h68k.env              | 是       |
| `<系统版本>`  | `env/linux/`          | jammy-xfce.env        | 是       |
| `[自定义]`    | `env/custom/`         | boot256-ext4root.env  | 可选     |

## 🧩 配置文件说明
所有 `.env` 文件采用键值对格式：
```ini
# env/linux/focal.env 示例
export DEBOOTSTRAP_MIRROR="http://mirrors.ustc.edu.cn/ubuntu-ports/"
export SOURCES_LIST_WORK="${WORKDIR}/conf/focal/sources.list.work"
export SOURCES_LIST_ORIG="${WORKDIR}/conf/focal/sources.list"
export OS_RELEASE="focal"
export DIST_ALIAS="focal"
```

## Actions 使用说明

在 `.github/workflows/*.yml` 云编译脚本中引入此 Actions 即可使用，例如 [build-ubuntu.yml](.github/workflows/build-ubuntu.yml)。更多 Actions 使用参数说明请参考：[README.ACTIONS.md](README.ACTIONS.md)。

推荐使用 ARM64 架构的 runner 进行编译：`runs-on: ubuntu-24.04-arm`

```yaml
- name: Build Ubuntu
  uses: unifreq/rk-ubuntu-build@main
  env:
    BUILD_TARGET: image
    ENV_MACHINE: e20c_h28k
    ENV_LINUX_FLAVOR: noble-xfce
    ENV_CUSTOM_BOOT: boot256-ext4root
    KERNEL_VERSION_NAME: 6.1.y_6.12.y
```


[Switch to English](README.md)
