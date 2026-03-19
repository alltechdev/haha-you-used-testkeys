#!/bin/bash
# Verify AVB chain of all signed images

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"
OUTPUT="$ROOT_DIR/output"
KEYS="$ROOT_DIR/keys"

# Expected key fingerprints
VBMETA_KEY="cdbb77177f731920bbe0a0f94f84d9038ae0617d"
BOOT_KEY="a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc"
VBMETA_SYSTEM_KEY="565840a78763c9a3be92604f5aef14376ee45415"
VBMETA_VENDOR_KEY="f013c089b7f6e86cabc32f3ab24559f01b327bbf"

ERRORS=0

check_key() {
    local img="$1"
    local expected="$2"
    local name="$3"

    if [ ! -f "$img" ]; then
        echo "  MISSING: $img"
        return 1
    fi

    local actual=$(python3 "$AVB" info_image --image "$img" 2>/dev/null | grep "Public key (sha1):" | head -1 | awk '{print $4}')

    if [ "$actual" = "$expected" ]; then
        echo "  OK: $name ($actual)"
        return 0
    else
        echo "  FAIL: $name"
        echo "        Expected: $expected"
        echo "        Got:      $actual"
        return 1
    fi
}

echo "=== AVB Chain Verification ==="
echo ""

echo "Checking vbmeta.img (root of trust)..."
check_key "$OUTPUT/vbmeta.img" "$VBMETA_KEY" "AOSP testkey" || ((ERRORS++))

echo ""
echo "Checking boot.img..."
check_key "$OUTPUT/boot.img" "$BOOT_KEY" "boot.pem" || ((ERRORS++))

echo ""
echo "Checking vbmeta_system.img..."
check_key "$OUTPUT/vbmeta_system.img" "$VBMETA_SYSTEM_KEY" "vbmeta_system.pem" || ((ERRORS++))

echo ""
echo "Checking vbmeta_vendor.img..."
check_key "$OUTPUT/vbmeta_vendor.img" "$VBMETA_VENDOR_KEY" "vbmeta_vendor.pem" || ((ERRORS++))

echo ""
echo "=== Chain Descriptors ==="
echo ""

echo "vbmeta.img chains to:"
python3 "$AVB" info_image --image "$OUTPUT/vbmeta.img" 2>/dev/null | grep -A2 "Chain Partition" | grep "Partition Name:" | awk '{print "  - " $3}'

echo ""
echo "vbmeta_system.img contains hashtrees for:"
python3 "$AVB" info_image --image "$OUTPUT/vbmeta_system.img" 2>/dev/null | grep "Partition Name:" | awk '{print "  - " $3}'

echo ""
echo "vbmeta_vendor.img contains hashtrees for:"
python3 "$AVB" info_image --image "$OUTPUT/vbmeta_vendor.img" 2>/dev/null | grep "Partition Name:" | awk '{print "  - " $3}'

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=== ALL CHECKS PASSED ==="
    exit 0
else
    echo "=== $ERRORS ERROR(S) FOUND ==="
    exit 1
fi
