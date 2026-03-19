#!/bin/bash
# Re-sign an existing modified ROM for locked bootloader
#
# Setup:
#   firmware/stock/   - Stock firmware (scatter file, vbmeta for testkey check)
#   firmware/custom/  - Modified ROM (super.img, optionally boot.img)
#
# Usage: ./scripts/resign_existing_rom.sh [custom_dir]
#   custom_dir defaults to firmware/custom/

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="$ROOT_DIR/output"
STOCK="$ROOT_DIR/firmware/stock"
CUSTOM="${1:-$ROOT_DIR/firmware/custom}"
TOOLS="$ROOT_DIR/tools"

# Validate stock firmware
if [ ! -d "$STOCK" ] || [ -z "$(ls -A "$STOCK" 2>/dev/null)" ]; then
    echo "Error: Stock firmware not found in firmware/stock/"
    echo ""
    echo "Copy stock firmware first:"
    echo "  cp -r /path/to/stock/firmware/* firmware/stock/"
    exit 1
fi

# Validate custom ROM
if [ ! -f "$CUSTOM/super.img" ]; then
    echo "Error: Modified super.img not found in $CUSTOM/"
    echo ""
    echo "Copy modified ROM:"
    echo "  mkdir -p firmware/custom"
    echo "  cp /path/to/modified/super.img firmware/custom/"
    echo "  cp /path/to/modified/boot.img firmware/custom/  # optional"
    exit 1
fi

# Determine boot image
if [ -f "$CUSTOM/boot.img" ]; then
    BOOT_PATH="$CUSTOM/boot.img"
elif [ -f "$CUSTOM/boot_a.img" ]; then
    BOOT_PATH="$CUSTOM/boot_a.img"
else
    BOOT_PATH="$STOCK/boot.img"
fi

echo "=== Re-sign Existing ROM ==="
echo ""
echo "Stock firmware: $STOCK"
echo "Modified ROM:   $CUSTOM"
echo "Super image:    $CUSTOM/super.img"
echo "Boot image:     $BOOT_PATH"
echo ""

# Step 1: Check testkey
echo "=== Step 1: Checking testkey ==="
"$SCRIPT_DIR/check_testkey.sh" "$STOCK/vbmeta.img"
echo ""

# Step 2: Unpack modified super
echo "=== Step 2: Unpacking modified super.img ==="
"$SCRIPT_DIR/unpack_super.sh" "$CUSTOM/super.img"
echo ""

# Step 3: Try repack, shrink if needed
echo "=== Step 3: Repacking super.img ==="
if ! "$SCRIPT_DIR/repack_super.sh" 2>&1; then
    echo ""
    echo "Repack failed - shrinking partitions..."
    echo ""

    for img in "$OUTPUT/super_unpacked/system_a.img" "$OUTPUT/super_unpacked/vendor_a.img" "$OUTPUT/super_unpacked/product_a.img"; do
        if [ -f "$img" ]; then
            echo "Shrinking $(basename $img)..."
            "$TOOLS/android-bins/e2fsck" -f -y "$img" 2>&1 | tail -1
            "$TOOLS/android-bins/resize2fs" -M "$img" 2>&1 | tail -1
        fi
    done

    echo ""
    echo "Retrying repack..."
    "$SCRIPT_DIR/repack_super.sh"
fi
echo ""

# Step 4: Sign boot
echo "=== Step 4: Signing boot.img ==="
"$SCRIPT_DIR/resign_boot.sh" "$BOOT_PATH"
echo ""

# Step 5: Rebuild vbmeta
echo "=== Step 5: Rebuilding vbmeta.img ==="
"$SCRIPT_DIR/rebuild_vbmeta.sh"
echo ""

# Step 6: Verify
echo "=== Step 6: Verifying chain ==="
"$SCRIPT_DIR/verify_chain.sh"
echo ""

# Done
echo "════════════════════════════════════════════════════════════════"
echo "  Re-sign complete!"
echo "  Output files: $OUTPUT/"
echo "════════════════════════════════════════════════════════════════"
echo ""
ls -lh "$OUTPUT"/*.img "$OUTPUT"/*.txt 2>/dev/null
echo ""
echo "After flashing with SP Flash Tool, do a factory reset from recovery."
