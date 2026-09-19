#!/bin/bash

/usr/bin/amixer -c 0 cset numid=68 268,268
/usr/bin/ffplay -nodisp -autoexit /usr/local/share/media/sample.m4a
