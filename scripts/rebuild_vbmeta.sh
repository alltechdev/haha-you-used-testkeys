#!/bin/bash
# Rebuild vbmeta.img with chain descriptors pointing to our keys

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"
KEYS="$ROOT_DIR/keys"
OUTPUT="$ROOT_DIR/output"

echo "=== Rebuilding vbmeta.img ==="

mkdir -p "$OUTPUT"

# Extract public keys if not present
for key in boot vbmeta_system vbmeta_vendor; do
    if [ ! -f "$KEYS/${key}.avbpubkey" ]; then
        echo "Extracting ${key}.avbpubkey..."
        python3 "$AVB" extract_public_key --key "$KEYS/${key}.pem" --output "$KEYS/${key}.avbpubkey"
    fi
done

# Build list of additional images to include descriptors from
# These partitions have their hashtrees directly in vbmeta.img (not in vbmeta_system/vendor)
EXTRA_ARGS=""
STOCK="$ROOT_DIR/firmware/stock"
UNPACKED="$OUTPUT/super_unpacked"

# From stock firmware
for img in dtbo.img vendor_boot.img; do
    if [ -f "$STOCK/$img" ]; then
        echo "Including $img from stock..."
        EXTRA_ARGS="$EXTRA_ARGS --include_descriptors_from_image $STOCK/$img"
    fi
done

# From unpacked super (product, system_ext, odm_dlkm, vendor_dlkm)
for part in product_a system_ext_a odm_dlkm_a vendor_dlkm_a; do
    if [ -f "$UNPACKED/${part}.img" ]; then
        echo "Including ${part}.img from unpacked super..."
        EXTRA_ARGS="$EXTRA_ARGS --include_descriptors_from_image $UNPACKED/${part}.img"
    fi
done

# Create vbmeta.img
echo "Creating vbmeta.img..."
python3 "$AVB" make_vbmeta_image \
    --output "$OUTPUT/vbmeta.img" \
    --key "$KEYS/vbmeta.pem" \
    --algorithm SHA256_RSA2048 \
    --chain_partition boot:3:"$KEYS/boot.avbpubkey" \
    --chain_partition vbmeta_system:2:"$KEYS/vbmeta_system.avbpubkey" \
    --chain_partition vbmeta_vendor:4:"$KEYS/vbmeta_vendor.avbpubkey" \
    $EXTRA_ARGS || { echo "ERROR: Failed to create vbmeta.img"; exit 1; }

echo ""
echo "vbmeta.img created:"
python3 "$AVB" info_image --image "$OUTPUT/vbmeta.img" 2>/dev/null | head -20

echo ""
echo "Output: $OUTPUT/vbmeta.img"

# Copy scatter file to output for easy flashing
SCATTER=$(find "$ROOT_DIR/firmware/stock" -name "*scatter*.txt" 2>/dev/null | head -1)
if [ -n "$SCATTER" ] && [ -f "$SCATTER" ]; then
    cp "$SCATTER" "$OUTPUT/"
    echo ""
    echo "Copied scatter file: $(basename "$SCATTER")"
fi
