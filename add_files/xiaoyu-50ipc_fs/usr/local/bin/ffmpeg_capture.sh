#!/bin/bash
ffmpeg \
  -f v4l2 -input_format nv12 -video_size 1920x1080 -i /dev/video13 \
  -vf "fps=30" \
  -c:v h264_rkmpp -g 30 \
  -f rtsp -rtsp_transport tcp rtsp://localhost:8554/live/720p
