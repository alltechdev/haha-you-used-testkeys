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

# Check for dtbo.img (optional)
DTBO_ARGS=""
if [ -f "$ROOT_DIR/firmware/dtbo.img" ]; then
    echo "Including dtbo.img..."
    DTBO_ARGS="--include_descriptors_from_image $ROOT_DIR/firmware/dtbo.img"
fi

# Create vbmeta.img
echo "Creating vbmeta.img..."
python3 "$AVB" make_vbmeta_image \
    --output "$OUTPUT/vbmeta.img" \
    --key "$KEYS/vbmeta.pem" \
    --algorithm SHA256_RSA2048 \
    --chain_partition boot:3:"$KEYS/boot.avbpubkey" \
    --chain_partition vbmeta_system:2:"$KEYS/vbmeta_system.avbpubkey" \
    --chain_partition vbmeta_vendor:4:"$KEYS/vbmeta_vendor.avbpubkey" \
    $DTBO_ARGS || { echo "ERROR: Failed to create vbmeta.img"; exit 1; }

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
