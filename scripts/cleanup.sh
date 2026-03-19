#!/bin/bash
# Clean up output directory and unmount any mounted partitions
#
# Usage: ./scripts/cleanup.sh [--all]
#   --all  Also clean firmware/stock and firmware/custom

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="$ROOT_DIR/output"
FIRMWARE_STOCK="$ROOT_DIR/firmware/stock"
FIRMWARE_CUSTOM="$ROOT_DIR/firmware/custom"

CLEAN_ALL=false
[ "$1" = "--all" ] && CLEAN_ALL=true

echo "=== Cleanup ==="

# Unmount any mounted partitions
echo "Unmounting any mounted partitions..."
for mount in "$OUTPUT/mnt"/*; do
    if [ -d "$mount" ] && [[ ! "$mount" == *"_loop" ]]; then
        name=$(basename "$mount")
        "$SCRIPT_DIR/unmount_partition.sh" "$name" 2>/dev/null || true
    fi
done

# Force lazy unmount any stubborn mounts
for mount in "$OUTPUT/mnt"/*; do
    if [ -d "$mount" ]; then
        sudo umount -l "$mount" 2>/dev/null || true
    fi
done

# Force unmount loop devices by explicit paths
sudo umount -l "$OUTPUT/mnt/.system_a_loop" 2>/dev/null || true
sudo umount -l "$OUTPUT/mnt/.vendor_a_loop" 2>/dev/null || true
sudo umount -l "$OUTPUT/mnt/.product_a_loop" 2>/dev/null || true
sudo umount -l "$OUTPUT/mnt/system_a" 2>/dev/null || true
sudo umount -l "$OUTPUT/mnt/vendor_a" 2>/dev/null || true
sudo umount -l "$OUTPUT/mnt/product_a" 2>/dev/null || true
sleep 1

# Remove mnt directory explicitly
sudo rm -rf "$OUTPUT/mnt" 2>/dev/null || true

# Remove output files
echo "Removing output files..."
sudo rm -rf "$OUTPUT"/* 2>/dev/null || rm -rf "$OUTPUT"/* 2>/dev/null || true

# Optionally clean firmware directories
if [ "$CLEAN_ALL" = true ]; then
    echo "Removing firmware/stock files..."
    rm -rf "$FIRMWARE_STOCK"/* 2>/dev/null || true
    echo "Removing firmware/custom files..."
    rm -rf "$FIRMWARE_CUSTOM"/* 2>/dev/null || true
fi

# Recreate empty directories
mkdir -p "$OUTPUT"
mkdir -p "$FIRMWARE_STOCK"
mkdir -p "$FIRMWARE_CUSTOM"

echo ""
if [ "$CLEAN_ALL" = true ]; then
    echo "Done. Output and firmware directories are clean."
else
    echo "Done. Output directory is clean. (Use --all to also clean firmware/)"
fi
ls -la "$OUTPUT"
