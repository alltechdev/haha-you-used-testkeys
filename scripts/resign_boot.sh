#!/bin/bash
# Re-sign boot.img (e.g., after Magisk patching)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"
KEYS="$ROOT_DIR/keys"
OUTPUT="$ROOT_DIR/output"
FIRMWARE="$ROOT_DIR/firmware/stock"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <boot.img> [partition_size]"
    echo ""
    echo "partition_size: Boot partition size in bytes (auto-detected from scatter if not specified)"
    exit 1
fi

INPUT="$1"
PART_SIZE="${2:-}"

[ ! -f "$INPUT" ] && echo "Error: $INPUT not found" && exit 1

# Auto-detect boot partition size from scatter file if not specified
if [ -z "$PART_SIZE" ]; then
    SCATTER=$(find "$FIRMWARE" -name "*scatter*.txt" 2>/dev/null | head -1)
    if [ -n "$SCATTER" ] && [ -f "$SCATTER" ]; then
        PART_SIZE_HEX=$(grep -A15 "partition_name: boot_a" "$SCATTER" | grep "partition_size:" | head -1 | awk '{print $2}')
        if [ -n "$PART_SIZE_HEX" ]; then
            PART_SIZE=$((PART_SIZE_HEX))
            echo "Boot partition size from scatter: $PART_SIZE bytes"
        fi
    fi
fi

# Fallback to default
if [ -z "$PART_SIZE" ] || [ "$PART_SIZE" -eq 0 ]; then
    PART_SIZE=33554432
    echo "Using default boot partition size: $PART_SIZE bytes"
fi

mkdir -p "$OUTPUT"
cp "$INPUT" "$OUTPUT/boot.img"

echo "Re-signing boot.img..."

# Erase existing footer
python3 "$AVB" erase_footer --image "$OUTPUT/boot.img" 2>/dev/null || true

# Add new hash footer
python3 "$AVB" add_hash_footer \
    --image "$OUTPUT/boot.img" \
    --partition_name boot \
    --partition_size "$PART_SIZE" \
    --key "$KEYS/boot.pem" \
    --algorithm SHA256_RSA2048 || { echo "ERROR: Failed to sign boot.img"; exit 1; }

echo ""
echo "Signed boot.img public key:"
python3 "$AVB" info_image --image "$OUTPUT/boot.img" 2>/dev/null | grep "Public key"

echo ""
echo "Output: $OUTPUT/boot.img"
