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

# Unmount bindfs first (mounted by root, so needs sudo). Try both helpers.
sudo umount "$USER_MOUNT" 2>/dev/null || sudo fusermount -u "$USER_MOUNT" 2>/dev/null || true

# Unmount loop
sudo umount "$LOOP_MOUNT" 2>/dev/null || true

# Verify it actually unmounted before claiming success
if mountpoint -q "$USER_MOUNT" || mountpoint -q "$LOOP_MOUNT"; then
    echo "Error: $BASENAME is still mounted (something is using it)."
    echo "Close any file managers or shells inside output/mnt/$BASENAME, then retry."
    echo "Force unmount with:"
    echo "  sudo fusermount -uz $USER_MOUNT"
    echo "  sudo umount -l $LOOP_MOUNT"
    exit 1
fi

# Clean up directories
rmdir "$USER_MOUNT" 2>/dev/null || true
rmdir "$LOOP_MOUNT" 2>/dev/null || true

echo "Done."
