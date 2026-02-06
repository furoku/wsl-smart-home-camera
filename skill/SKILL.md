---
name: smart-home
description: Control smart home devices via USB camera + Nature Remo on WSL2. Capture room photos with ffmpeg, analyze with vision, operate lights/AC/TV via Nature Remo Cloud API. Use when asked to check the room, turn lights on/off, adjust AC temperature, or manage home appliances. Also handles the capture→analyze→operate→verify loop.
---

# Smart Home (Camera + Nature Remo)

## Prerequisites

- USB camera attached to WSL via usbipd (`/dev/video0`)
- ffmpeg installed
- Nature Remo token at `~/.config/nature-remo/token`
- Camera permissions: `sudo chmod 666 /dev/video0 /dev/video1`

Check TOOLS.md for device IDs, camera position mapping, and appliance list.

## Camera Capture

```bash
ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
  -i /dev/video0 -frames:v 1 -update 1 /tmp/camera.jpg -y
```

- Use `-vf "vflip"` only if camera is mounted upside-down
- If `/dev/video0` missing: camera disconnected, needs re-attach from Windows
- If permission denied: `sudo chmod 666 /dev/video0 /dev/video1`

## Nature Remo API

Token: `TOKEN=$(cat ~/.config/nature-remo/token)`

### List appliances
```bash
curl -s -H "Authorization: Bearer $TOKEN" https://api.nature.global/1/appliances
```

### Light control
```bash
curl -s -X POST "https://api.nature.global/1/appliances/{ID}/light" \
  -H "Authorization: Bearer $TOKEN" -d "button={on|off|night|on-100}"
```

### AC control
```bash
curl -s -X POST "https://api.nature.global/1/appliances/{ID}/aircon_settings" \
  -H "Authorization: Bearer $TOKEN" \
  -d "operation_mode={warm|cool|auto}&temperature={temp}"
```

### TV control
```bash
curl -s -X POST "https://api.nature.global/1/appliances/{ID}/tv" \
  -H "Authorization: Bearer $TOKEN" -d "button=power"
```

## Operate→Verify Loop

After any operation, capture a photo to verify the result:

1. Execute Nature Remo command
2. Wait 1-2 seconds
3. Capture photo
4. Analyze: confirm the expected change (e.g., "left side darker" = bed light off)

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `/dev/video0` not found | USB detached | Windows admin: `usbipd attach --wsl --busid {ID}` |
| Permission denied | Missing permissions | `sudo chmod 666 /dev/video0 /dev/video1` |
| Purple/magenta noise | Wrong pixel format | Use `-input_format mjpeg` |
| Image upside down | Camera orientation | Add/remove `-vf "vflip"` |
| Nature Remo 404 | Wrong appliance ID | Re-fetch appliance list |

## Setup Script

Run `scripts/setup-check.sh` to verify all prerequisites are met.
