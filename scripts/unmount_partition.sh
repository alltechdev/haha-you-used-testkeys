#!/bin/bash
# Unmount a partition that was mounted with modify_partition.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <partition_name>"
    echo ""
    echo "Examples:"
    echo "  $0 system_a"
    echo "  $0 vendor_a"
    exit 1
fi

BASENAME="$1"
LOOP_MOUNT="$ROOT_DIR/output/mnt/.${BASENAME}_loop"
USER_MOUNT="$ROOT_DIR/output/mnt/$BASENAME"

echo "Unmounting $BASENAME..."

# Unmount bindfs first (try both methods)
umount "$USER_MOUNT" 2>/dev/null || fusermount -u "$USER_MOUNT" 2>/dev/null || true

# Unmount loop
sudo umount "$LOOP_MOUNT" 2>/dev/null || true

# Clean up directories
rmdir "$USER_MOUNT" 2>/dev/null || true
rmdir "$LOOP_MOUNT" 2>/dev/null || true

echo "Done."
