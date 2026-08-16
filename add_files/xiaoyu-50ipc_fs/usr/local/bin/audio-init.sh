#!/bin/sh

rm -f /var/lib/alsa/asound.state

# 麦克风输入
amixer -c 0 cset numid=76 1 # Main Mic ON
amixer -c 0 cset numid=77 0 # Headset Mic OFF

# ACodec_LP 麦克风
amixer -c 0 cset numid=58 2 # ACodec_LP HPF Cutoff 243Hz
amixer -c 0 cset numid=59 1 # ACodec_LP HPF Switch ON
amixer -c 0 cset numid=60 127 # ACodec_LP 数字增益
amixer -c 0 cset numid=61 31 # ACodec_LP PGA
amixer -c 0 cset numid=62 1 # ACodec_LP ADC ON

# ACodec 扬声器回环
amixer -c 0 cset numid=63 2 # HPF Cutoff 243Hz
amixer -c 0 cset numid=64 1 # HPF ON
amixer -c 0 cset numid=65 127 # ACodec 数字增益
amixer -c 0 cset numid=66 31 # ACodec PGA
amixer -c 0 cset numid=67 1 # ACodec ADC ON

# 扬声器输出
amixer -c 0 cset numid=71 1 # Power Amplifier ON
amixer -c 0 cset numid=68 300,300 # DAC Digital Volume
amixer -c 0 cset numid=72 on # spk switch
amixer -c 0 cset numid=75 on # Speaker Switch

alsactl store
