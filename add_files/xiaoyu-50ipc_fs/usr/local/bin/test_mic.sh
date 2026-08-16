#!/bin/bash

arecord -D default -d 4 -f S16_LE -r 16000 -c 1 /tmp/ok.wav

aplay -D default /tmp/ok.wav

/usr/local/bin/wav_spec.py /tmp/ok.wav 0.04
