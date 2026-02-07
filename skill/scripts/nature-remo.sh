#!/bin/bash
# Nature Remo CLI wrapper
# Usage: nature-remo.sh <command> [args]
#
# Commands:
#   list                          - List all appliances
#   light <id> <on|off|night>     - Control light
#   ac <id> <mode> <temp>         - Control AC (mode: warm|cool|auto|off)
#   tv <id> <power>               - Control TV

set -euo pipefail

TOKEN_FILE="${HOME}/.config/nature-remo/token"

if [ ! -f "$TOKEN_FILE" ]; then
    echo "ERROR: Token not found at $TOKEN_FILE" >&2
    echo "Get one at https://home.nature.global/" >&2
    exit 1
fi

TOKEN=$(cat "$TOKEN_FILE")
API="https://api.nature.global/1"

case "${1:-help}" in
    list)
        curl -s -H "Authorization: Bearer $TOKEN" "$API/appliances" | \
            python3 -c "
import json, sys
for a in json.load(sys.stdin):
    state = ''
    if a.get('light'):
        state = f\" [{a['light']['state'].get('last_button', '?')}]\"
    elif a.get('aircon') and a.get('settings'):
        s = a['settings']
        state = f\" [{s.get('mode','?')} {s.get('temp','?')}°C]\"
    print(f\"{a['type']:6} | {a['nickname']:20} | {a['id']}{state}\")
"
        ;;
    light)
        ID="${2:?Usage: nature-remo.sh light <id> <on|off|night>}"
        BUTTON="${3:?Usage: nature-remo.sh light <id> <on|off|night>}"
        RESULT=$(curl -s -X POST "$API/appliances/$ID/light" \
            -H "Authorization: Bearer $TOKEN" \
            -d "button=$BUTTON")
        echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"💡 {d.get('last_button','?')}\")"
        ;;
    ac)
        ID="${2:?Usage: nature-remo.sh ac <id> <mode> <temp>}"
        MODE="${3:?Usage: nature-remo.sh ac <id> <mode> <temp>}"
        if [ "$MODE" = "off" ]; then
            curl -s -X POST "$API/appliances/$ID/aircon_settings" \
                -H "Authorization: Bearer $TOKEN" \
                -d "button=power-off" | python3 -c "import json,sys; print('❄️ OFF')"
        else
            TEMP="${4:?Usage: nature-remo.sh ac <id> <mode> <temp>}"
            curl -s -X POST "$API/appliances/$ID/aircon_settings" \
                -H "Authorization: Bearer $TOKEN" \
                -d "operation_mode=$MODE&temperature=$TEMP" | \
                python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"❄️ {d.get('mode','?')} {d.get('temp','?')}°C\")"
        fi
        ;;
    tv)
        ID="${2:?Usage: nature-remo.sh tv <id> <button>}"
        BUTTON="${3:-power}"
        curl -s -X POST "$API/appliances/$ID/tv" \
            -H "Authorization: Bearer $TOKEN" \
            -d "button=$BUTTON" > /dev/null
        echo "📺 $BUTTON"
        ;;
    help|*)
        echo "Usage: nature-remo.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list                          List all appliances"
        echo "  light <id> <on|off|night>     Control light"
        echo "  ac <id> <mode> <temp>         Control AC"
        echo "  tv <id> <button>              Control TV"
        ;;
esac
