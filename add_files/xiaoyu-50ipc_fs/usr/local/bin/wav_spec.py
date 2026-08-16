#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# 纯 Python 版录音频谱/能量分析工具 (无 sox 依赖)
# 用法: wav_spec.sh <wav文件> [裁剪秒数, 默认0.02]
# 功能: 跳过开头 TRIM 秒后, 输出采样信息、峰值/RMS 与指定频率的 Goertzel 能量

import sys
import wave
import struct
import math


def main():
    if len(sys.argv) < 2:
        print('用法: wav_spec.sh <wav文件> [裁剪秒数]')
        sys.exit(1)

    path = sys.argv[1]
    trim = float(sys.argv[2]) if len(sys.argv) > 2 else 0.02

    w = wave.open(path, 'rb')
    sr = w.getframerate()
    ch = w.getnchannels()
    n = w.getnframes()

    # 等效于 sox trim: 跳过开头 trim 秒的采样帧
    skip = int(trim * sr)
    if skip >= n:
        skip = n
    w.setpos(skip)
    frames = n - skip
    d = w.readframes(frames)
    w.close()

    # 解析全部样本, 取第一声道
    v = struct.unpack('<%dh' % (frames * ch), d)[0::ch]

    def rms(x):
        return math.sqrt(sum(i * i for i in x) / len(x)) if x else 0.0

    def goertzel(x, rate, freq):
        N = len(x)
        if N < 4:
            return 0.0
        k = round(0.5 + N * freq / rate)
        w = 2 * math.pi * k / N
        c = 2 * math.cos(w)
        s0 = s1 = s2 = 0.0
        for xi in x:
            s0 = xi + c * s1 - s2
            s2 = s1
            s1 = s0
        return (s1 * s1 + s2 * s2 - c * s1 * s2) / N

    print('文件: %s' % path)
    print('采样率=%d 声道=%d 帧数=%d 时长=%.3fs' % (sr, ch, frames, frames / sr if frames else 0))
    print('peak=%d  rms=%.1f' % (max(abs(x) for x in v) if v else 0, rms(v)))
    print('频率能量(Goertzel):')
    for freq in [50, 100, 120, 250, 500, 1000, 2000, 4000, 6000, 8000]:
        print('  %5dHz: %.1f' % (freq, goertzel(v, sr, freq)))


if __name__ == '__main__':
    main()
