#!/bin/bash
# Capture a photo from the USB camera
# Usage: capture.sh [output_path]

set -euo pipefail

OUTPUT="${1:-/tmp/camera.jpg}"

if [ ! -e /dev/video0 ]; then
    echo "ERROR: /dev/video0 not found. Re-attach camera:" >&2
    echo "  Windows (admin): usbipd attach --wsl --busid <ID>" >&2
    echo "  WSL: sudo chmod 666 /dev/video0 /dev/video1" >&2
    exit 1
fi

ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
    -i /dev/video0 -frames:v 1 -update 1 "$OUTPUT" -y \
    -loglevel error

SIZE=$(stat -c%s "$OUTPUT" 2>/dev/null || echo "0")
if [ "$SIZE" -lt 1000 ]; then
    echo "ERROR: Capture produced empty/tiny file ($SIZE bytes)" >&2
    exit 1
fi

echo "📷 Captured: $OUTPUT ($(( SIZE / 1024 ))KB)"
