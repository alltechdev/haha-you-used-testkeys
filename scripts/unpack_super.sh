#!/bin/bash
# Unpack super.img to extract system, vendor, product partitions

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LPUNPACK="$ROOT_DIR/tools/lpunpack_and_lpmake/binary/lpunpack"
OUTPUT="$ROOT_DIR/output"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <super.img>"
    exit 1
fi

SUPER="$1"
[ ! -f "$SUPER" ] && echo "Error: $SUPER not found" && exit 1

mkdir -p "$OUTPUT/super_unpacked"

# Check if sparse
MAGIC=$(od -A n -t x4 -N 4 "$SUPER" | tr -d ' ')
if [ "$MAGIC" = "ed26ff3a" ]; then
    echo "Converting sparse to raw..."
    simg2img "$SUPER" "$OUTPUT/super.raw"
    SUPER="$OUTPUT/super.raw"
fi

echo "Unpacking super.img..."
"$LPUNPACK" "$SUPER" "$OUTPUT/super_unpacked/" || { echo "ERROR: lpunpack failed"; exit 1; }

# Verify extraction
if [ ! -f "$OUTPUT/super_unpacked/system_a.img" ]; then
    echo "ERROR: system_a.img not found after unpacking"
    exit 1
fi

echo ""
echo "Extracted partitions:"
ls -lh "$OUTPUT/super_unpacked/"

echo ""
echo "To mount a partition for modification:"
echo "  ./scripts/modify_partition.sh $OUTPUT/super_unpacked/system_a.img --resize"
