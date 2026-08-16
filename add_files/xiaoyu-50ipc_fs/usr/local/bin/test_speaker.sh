#!/bin/bash
vol=${1:-300}                         # 默认 300

amixer -c 0 cset numid=71 1           # Power Amplifier = On
amixer -c 0 cset numid=68 $vol,$vol   # DAC Digital Volume = 300,300
amixer -c 0 cset numid=72 on          # spk switch = on
amixer -c 0 cset numid=75 on          # Speaker Switch = on

# 设置后验证（关键）
amixer -c 0 cget numid=68
amixer -c 0 cget numid=71
amixer -c 0 cget numid=72
amixer -c 0 cget numid=75

speaker-test -D default -c 2 -t wav -l 1
