#!/bin/bash

sudo apt-get update && \
sudo apt-get install -y locales-all language-pack-zh-hans* && \
sudo apt-get install -y $(check-language-support) && \
sudo update-locale LANG=zh_CN.UTF-8 && \
sudo update-locale LC_ALL=zh_CN.UTF-8 && \
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
sudo dpkg-reconfigure -f noninteractive tzdata && \
echo "Installation is complete, please logout user and login again."
