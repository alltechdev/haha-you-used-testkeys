#!/bin/bash
# Repack super.img from modified partitions and re-sign vbmeta

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"
LPMAKE="$ROOT_DIR/tools/lpunpack_and_lpmake/binary/lpmake"
KEYS="$ROOT_DIR/keys"
OUTPUT="$ROOT_DIR/output"
UNPACKED="$OUTPUT/super_unpacked"
FIRMWARE="$ROOT_DIR/firmware/stock"

echo "=== Repacking Super.img ==="

# Check required files
[ ! -f "$UNPACKED/system_a.img" ] && echo "Error: system_a.img not found in $UNPACKED" && exit 1
[ ! -f "$UNPACKED/vendor_a.img" ] && echo "Error: vendor_a.img not found in $UNPACKED" && exit 1
[ ! -f "$UNPACKED/product_a.img" ] && echo "Error: product_a.img not found in $UNPACKED" && exit 1

# Get super partition size from scatter file
SCATTER=$(find "$FIRMWARE" -name "*scatter*.txt" 2>/dev/null | head -1)
if [ -n "$SCATTER" ] && [ -f "$SCATTER" ]; then
    # Extract partition_size for super partition (format: partition_size: 0x...)
    SUPER_SIZE_HEX=$(grep -A15 "partition_name: super" "$SCATTER" | grep "partition_size:" | head -1 | awk '{print $2}')
    if [ -n "$SUPER_SIZE_HEX" ]; then
        SUPER_SIZE=$((SUPER_SIZE_HEX))
        echo "Super partition size from scatter: $SUPER_SIZE bytes ($SUPER_SIZE_HEX)"
    fi
fi

# Fallback to default if not found
if [ -z "$SUPER_SIZE" ] || [ "$SUPER_SIZE" -eq 0 ]; then
    SUPER_SIZE=5368709120
    echo "Warning: Could not detect super size, using default: $SUPER_SIZE bytes"
fi

# Get sizes
SYSTEM_SIZE=$(stat -c%s "$UNPACKED/system_a.img")
VENDOR_SIZE=$(stat -c%s "$UNPACKED/vendor_a.img")
PRODUCT_SIZE=$(stat -c%s "$UNPACKED/product_a.img")

echo "system_a: $SYSTEM_SIZE bytes"
echo "vendor_a: $VENDOR_SIZE bytes"
echo "product_a: $PRODUCT_SIZE bytes"

# Erase any existing footers first
echo ""
echo "Erasing existing AVB footers..."
python3 "$AVB" erase_footer --image "$UNPACKED/system_a.img" 2>/dev/null || true
python3 "$AVB" erase_footer --image "$UNPACKED/vendor_a.img" 2>/dev/null || true
python3 "$AVB" erase_footer --image "$UNPACKED/product_a.img" 2>/dev/null || true

# Recalculate sizes after erasing footers
SYSTEM_SIZE=$(stat -c%s "$UNPACKED/system_a.img")
VENDOR_SIZE=$(stat -c%s "$UNPACKED/vendor_a.img")
PRODUCT_SIZE=$(stat -c%s "$UNPACKED/product_a.img")

echo "system_a (clean): $SYSTEM_SIZE bytes"
echo "vendor_a (clean): $VENDOR_SIZE bytes"
echo "product_a (clean): $PRODUCT_SIZE bytes"

# Calculate partition sizes with room for hashtree (data size + ~2% overhead, rounded to 4K)
SYSTEM_PART_SIZE=$(( (SYSTEM_SIZE * 102 / 100 + 4095) / 4096 * 4096 ))
VENDOR_PART_SIZE=$(( (VENDOR_SIZE * 102 / 100 + 4095) / 4096 * 4096 ))
PRODUCT_PART_SIZE=$(( (PRODUCT_SIZE * 102 / 100 + 4095) / 4096 * 4096 ))

# Add hashtree footers
echo ""
echo "Adding hashtree footers..."

python3 "$AVB" add_hashtree_footer \
    --image "$UNPACKED/system_a.img" \
    --partition_name system \
    --partition_size "$SYSTEM_PART_SIZE" \
    --hash_algorithm sha256 \
    --do_not_generate_fec || { echo "ERROR: Failed to add hashtree to system_a.img"; exit 1; }

python3 "$AVB" add_hashtree_footer \
    --image "$UNPACKED/vendor_a.img" \
    --partition_name vendor \
    --partition_size "$VENDOR_PART_SIZE" \
    --hash_algorithm sha256 \
    --do_not_generate_fec || { echo "ERROR: Failed to add hashtree to vendor_a.img"; exit 1; }

python3 "$AVB" add_hashtree_footer \
    --image "$UNPACKED/product_a.img" \
    --partition_name product \
    --partition_size "$PRODUCT_PART_SIZE" \
    --hash_algorithm sha256 \
    --do_not_generate_fec || { echo "ERROR: Failed to add hashtree to product_a.img"; exit 1; }

# Get final sizes after adding hashtree
SYSTEM_SIZE=$(stat -c%s "$UNPACKED/system_a.img")
VENDOR_SIZE=$(stat -c%s "$UNPACKED/vendor_a.img")
PRODUCT_SIZE=$(stat -c%s "$UNPACKED/product_a.img")

echo "system_a (final): $SYSTEM_SIZE bytes"
echo "vendor_a (final): $VENDOR_SIZE bytes"
echo "product_a (final): $PRODUCT_SIZE bytes"

# Create vbmeta_system
echo ""
echo "Creating vbmeta_system.img..."
python3 "$AVB" make_vbmeta_image \
    --output "$OUTPUT/vbmeta_system.img" \
    --key "$KEYS/vbmeta_system.pem" \
    --algorithm SHA256_RSA2048 \
    --include_descriptors_from_image "$UNPACKED/system_a.img" \
    --include_descriptors_from_image "$UNPACKED/product_a.img" || { echo "ERROR: Failed to create vbmeta_system.img"; exit 1; }

# Create vbmeta_vendor
echo "Creating vbmeta_vendor.img..."
python3 "$AVB" make_vbmeta_image \
    --output "$OUTPUT/vbmeta_vendor.img" \
    --key "$KEYS/vbmeta_vendor.pem" \
    --algorithm SHA256_RSA2048 \
    --include_descriptors_from_image "$UNPACKED/vendor_a.img" || { echo "ERROR: Failed to create vbmeta_vendor.img"; exit 1; }

# Repack super.img
echo ""
echo "Repacking super.img..."
GROUP_SIZE=$((SYSTEM_SIZE + VENDOR_SIZE + PRODUCT_SIZE + 4194304))

"$LPMAKE" \
    --device-size=$SUPER_SIZE \
    --metadata-size=65536 \
    --metadata-slots=3 \
    --group=main_a:$GROUP_SIZE \
    --group=main_b:0 \
    --partition=system_a:readonly:$SYSTEM_SIZE:main_a \
    --partition=system_b:readonly:0:main_b \
    --partition=product_a:readonly:$PRODUCT_SIZE:main_a \
    --partition=product_b:readonly:0:main_b \
    --partition=vendor_a:readonly:$VENDOR_SIZE:main_a \
    --partition=vendor_b:readonly:0:main_b \
    --image=system_a="$UNPACKED/system_a.img" \
    --image=product_a="$UNPACKED/product_a.img" \
    --image=vendor_a="$UNPACKED/vendor_a.img" \
    --sparse \
    --output="$OUTPUT/super.img" 2>&1 | grep -v "Invalid sparse file format" || true

# Verify super.img was created
[ ! -f "$OUTPUT/super.img" ] && echo "ERROR: Failed to create super.img" && exit 1

echo ""
echo "Done! Output files:"
ls -lh "$OUTPUT"/*.img

echo ""
echo "Flash these files:"
echo "  - super.img"
echo "  - vbmeta_system.img"
echo "  - vbmeta_vendor.img"
