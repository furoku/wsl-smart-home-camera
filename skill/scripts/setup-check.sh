#!/bin/bash
# Smart Home Setup Checker
# Verifies all prerequisites for camera + Nature Remo integration

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo "🏠 Smart Home Setup Check"
echo "========================="
echo ""

ERRORS=0

# 1. Check camera device
echo "📷 Camera:"
if [ -e /dev/video0 ]; then
    pass "/dev/video0 exists"
    if [ -r /dev/video0 ] && [ -w /dev/video0 ]; then
        pass "/dev/video0 is readable/writable"
    else
        fail "/dev/video0 permission denied — run: sudo chmod 666 /dev/video0 /dev/video1"
        ((ERRORS++))
    fi
else
    fail "/dev/video0 not found — attach camera: usbipd attach --wsl --busid <ID>"
    ((ERRORS++))
fi
echo ""

# 2. Check ffmpeg
echo "🎬 ffmpeg:"
if command -v ffmpeg &>/dev/null; then
    pass "ffmpeg installed ($(ffmpeg -version 2>&1 | head -1 | cut -d' ' -f3))"
else
    fail "ffmpeg not installed — run: sudo apt install -y ffmpeg"
    ((ERRORS++))
fi
echo ""

# 3. Check Nature Remo token
echo "🏠 Nature Remo:"
TOKEN_FILE="$HOME/.config/nature-remo/token"
if [ -f "$TOKEN_FILE" ]; then
    pass "Token file exists at $TOKEN_FILE"
    
    TOKEN=$(cat "$TOKEN_FILE")
    if [ -n "$TOKEN" ]; then
        # Test API connection
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $TOKEN" \
            https://api.nature.global/1/appliances 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            APPLIANCE_COUNT=$(curl -s -H "Authorization: Bearer $TOKEN" \
                https://api.nature.global/1/appliances 2>/dev/null | \
                python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
            pass "API connected — $APPLIANCE_COUNT appliances found"
        elif [ "$HTTP_CODE" = "401" ]; then
            fail "Token invalid or expired — regenerate at https://home.nature.global/"
            ((ERRORS++))
        else
            warn "API unreachable (HTTP $HTTP_CODE) — check network"
        fi
    else
        fail "Token file is empty"
        ((ERRORS++))
    fi
else
    fail "Token not found — create: mkdir -p ~/.config/nature-remo && echo -n 'TOKEN' > $TOKEN_FILE"
    ((ERRORS++))
fi
echo ""

# 4. Camera capture test
echo "📸 Capture test:"
if [ -e /dev/video0 ] && command -v ffmpeg &>/dev/null; then
    TEST_FILE="/tmp/smart-home-test-$$.jpg"
    if ffmpeg -f v4l2 -input_format mjpeg -video_size 1920x1080 \
        -i /dev/video0 -frames:v 1 -update 1 "$TEST_FILE" -y &>/dev/null; then
        SIZE=$(stat -c%s "$TEST_FILE" 2>/dev/null || echo "0")
        if [ "$SIZE" -gt 1000 ]; then
            pass "Capture successful ($(( SIZE / 1024 ))KB)"
        else
            fail "Capture produced empty/tiny file"
            ((ERRORS++))
        fi
        rm -f "$TEST_FILE"
    else
        fail "Capture failed — check camera connection"
        ((ERRORS++))
    fi
else
    warn "Skipping capture test (missing camera or ffmpeg)"
fi
echo ""

# Summary
echo "========================="
if [ "$ERRORS" -eq 0 ]; then
    pass "All checks passed! Ready to go 🏠👻"
else
    fail "$ERRORS issue(s) found. Fix them and run again."
fi

exit $ERRORS
