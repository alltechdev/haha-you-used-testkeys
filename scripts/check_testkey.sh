#!/bin/bash
# Check if vbmeta uses AOSP testkey

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <vbmeta.img>"
    exit 1
fi

VBMETA="$1"
[ ! -f "$VBMETA" ] && echo "Error: $VBMETA not found" && exit 1

echo "Checking $VBMETA..."
PUBKEY=$(python3 "$AVB" info_image --image "$VBMETA" 2>/dev/null | grep "Public key (sha1):" | head -1 | awk '{print $4}')

echo "Public key SHA1: $PUBKEY"

if [ "$PUBKEY" = "cdbb77177f731920bbe0a0f94f84d9038ae0617d" ]; then
    echo ""
    echo "VULNERABLE - Uses AOSP testkey!"
    echo "You can re-sign partitions for locked bootloader."
    exit 0
else
    echo ""
    echo "NOT VULNERABLE - Uses custom key."
    echo "Cannot re-sign without manufacturer's private key."
    exit 1
fi
