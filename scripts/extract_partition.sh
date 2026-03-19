#!/bin/bash
# Extract files from ext4 partition image

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="$ROOT_DIR/output"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <partition.img> [output_dir]"
    echo ""
    echo "Examples:"
    echo "  $0 output/super_unpacked/system_a.img"
    echo "  $0 output/super_unpacked/vendor_a.img vendor_files"
    exit 1
fi

INPUT="$(realpath "$1")"
[ ! -f "$INPUT" ] && echo "Error: $INPUT not found" && exit 1

# Default output dir based on input name
BASENAME=$(basename "$INPUT" .img)
OUTPUT_DIR="${2:-$OUTPUT/${BASENAME}_extracted}"

# Verify ext4
MAGIC=$(od -A n -t x1 -N 2 -j 1080 "$INPUT" | tr -d ' ')
if [ "$MAGIC" != "53ef" ]; then
    echo "Error: Not a valid ext4 image (magic: $MAGIC)"
    exit 1
fi

MOUNT_POINT="/tmp/m5_extract_$$"

echo "Mounting $INPUT..."
mkdir -p "$MOUNT_POINT"
sudo mount -o loop,ro "$INPUT" "$MOUNT_POINT"

echo "Copying files to $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR"
sudo cp -a "$MOUNT_POINT"/* "$OUTPUT_DIR/" 2>/dev/null || true
sudo chown -R $(id -u):$(id -g) "$OUTPUT_DIR"
sudo chmod -R u+rwX "$OUTPUT_DIR"

echo "Unmounting..."
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo ""
echo "Done! Files extracted to: $OUTPUT_DIR"
ls -la "$OUTPUT_DIR" | head -20
