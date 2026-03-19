#!/bin/bash
# Inject a file into an ext4 partition image

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <partition.img> <local_file> <path_in_image>"
    echo ""
    echo "Examples:"
    echo "  $0 system_a.img build.prop /system/build.prop"
    echo "  $0 vendor_a.img build.prop /build.prop"
    exit 1
fi

IMAGE="$(realpath "$1")"
LOCAL_FILE="$(realpath "$2")"
IMAGE_PATH="$3"

[ ! -f "$IMAGE" ] && echo "Error: $IMAGE not found" && exit 1
[ ! -f "$LOCAL_FILE" ] && echo "Error: $LOCAL_FILE not found" && exit 1

MOUNT_POINT="/tmp/m5_inject_$$"

echo "Mounting $IMAGE..."
mkdir -p "$MOUNT_POINT"
sudo mount -o loop,rw "$IMAGE" "$MOUNT_POINT"

TARGET_FULL="$MOUNT_POINT$IMAGE_PATH"
TARGET_DIR=$(dirname "$TARGET_FULL")

echo "Injecting $LOCAL_FILE -> $IMAGE_PATH"
sudo mkdir -p "$TARGET_DIR"
sudo cp "$LOCAL_FILE" "$TARGET_FULL"

# Verify
INJECTED_SIZE=$(stat -c%s "$TARGET_FULL")
LOCAL_SIZE=$(stat -c%s "$LOCAL_FILE")

echo "Unmounting..."
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

if [ "$INJECTED_SIZE" = "$LOCAL_SIZE" ]; then
    echo "Verified: $LOCAL_SIZE bytes written"
else
    echo "ERROR: Size mismatch! Expected $LOCAL_SIZE, got $INJECTED_SIZE"
    exit 1
fi
