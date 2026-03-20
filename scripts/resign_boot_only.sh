#!/bin/bash
# Re-sign ONLY boot.img (e.g., Magisk root) without modifying system/vendor/product
#
# This script:
# 1. Unpacks stock super to extract partition images (with existing hashtree footers)
# 2. Creates vbmeta_system/vendor signed with our keys (using existing hashtrees)
# 3. Re-signs the patched boot.img
# 4. Rebuilds vbmeta.img
#
# Use this ONLY when modifying boot and NOT touching system/vendor/product.
# If you're modifying system/vendor/product, use repack_super.sh instead.
#
# Usage: ./scripts/resign_boot_only.sh <patched_boot.img>

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"
KEYS="$ROOT_DIR/keys"
OUTPUT="$ROOT_DIR/output"
STOCK="$ROOT_DIR/firmware/stock"
UNPACKED="$OUTPUT/super_unpacked"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <patched_boot.img>"
    echo ""
    echo "This script re-signs ONLY boot.img without modifying system/vendor/product."
    echo "Use this for Magisk root when you're not changing system partitions."
    exit 1
fi

BOOT_IMG="$1"

if [ ! -f "$BOOT_IMG" ]; then
    echo "Error: $BOOT_IMG not found"
    exit 1
fi

if [ ! -f "$STOCK/super.img" ]; then
    echo "Error: Stock super.img not found in firmware/stock/"
    echo "Copy stock firmware first: cp -r /path/to/firmware/* firmware/stock/"
    exit 1
fi

echo "=== Boot-Only Re-sign ==="
echo ""
echo "Boot image: $BOOT_IMG"
echo "Stock firmware: $STOCK"
echo ""

# Step 1: Unpack stock super (if not already unpacked)
if [ ! -f "$UNPACKED/system_a.img" ]; then
    echo "=== Step 1: Unpacking stock super.img ==="
    "$SCRIPT_DIR/unpack_super.sh" "$STOCK/super.img"
else
    echo "=== Step 1: Using existing unpacked partitions ==="
    echo "  (Delete output/super_unpacked/ to force re-unpack)"
fi
echo ""

# Step 2: Create vbmeta_system from existing hashtree footers
echo "=== Step 2: Creating vbmeta_system.img (from existing hashtrees) ==="
python3 "$AVB" make_vbmeta_image \
    --output "$OUTPUT/vbmeta_system.img" \
    --key "$KEYS/vbmeta_system.pem" \
    --algorithm SHA256_RSA2048 \
    --include_descriptors_from_image "$UNPACKED/system_a.img" \
    --include_descriptors_from_image "$UNPACKED/product_a.img" || { echo "ERROR: Failed to create vbmeta_system.img"; exit 1; }
echo ""

# Step 3: Create vbmeta_vendor from existing hashtree footers
echo "=== Step 3: Creating vbmeta_vendor.img (from existing hashtrees) ==="
python3 "$AVB" make_vbmeta_image \
    --output "$OUTPUT/vbmeta_vendor.img" \
    --key "$KEYS/vbmeta_vendor.pem" \
    --algorithm SHA256_RSA2048 \
    --include_descriptors_from_image "$UNPACKED/vendor_a.img" || { echo "ERROR: Failed to create vbmeta_vendor.img"; exit 1; }
echo ""

# Step 4: Re-sign boot
echo "=== Step 4: Re-signing boot.img ==="
"$SCRIPT_DIR/resign_boot.sh" "$BOOT_IMG"
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
echo "========================================================================"
echo "  Boot-only re-sign complete!"
echo ""
echo "  Flash these partitions with SP Flash Tool:"
echo "    - boot_a       (output/boot.img)"
echo "    - vbmeta_a     (output/vbmeta.img)"
echo "    - vbmeta_system_a (output/vbmeta_system.img)"
echo "    - vbmeta_vendor_a (output/vbmeta_vendor.img)"
echo ""
echo "  Do NOT flash super - it was not modified."
echo "========================================================================"
echo ""
echo "After flashing, do a factory reset from recovery."
