#!/bin/bash
# Mount an ext4 partition for modification (user-accessible via bindfs)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
AVB="$ROOT_DIR/tools/avb-tools/avbtool.py"
E2FSCK="$ROOT_DIR/tools/android-bins/e2fsck"
RESIZE2FS="$ROOT_DIR/tools/android-bins/resize2fs"
BINDFS="$ROOT_DIR/tools/android-bins/bindfs"

RESIZE=false
IMAGE=""

# Parse args
for arg in "$@"; do
    case $arg in
        --resize) RESIZE=true ;;
        -*) echo "Unknown option: $arg"; exit 1 ;;
        *)
            if [ -z "$IMAGE" ]; then
                IMAGE="$arg"
            fi
            ;;
    esac
done

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <partition.img> [--resize]"
    echo ""
    echo "Mounts partition for modification within the repo."
    echo "When done, run:"
    echo "  ./scripts/unmount_partition.sh <partition>"
    echo "  ./scripts/repack_super.sh"
    echo ""
    echo "Options:"
    echo "  --resize    Add 50MB to partition before mounting"
    exit 1
fi

IMAGE="$(realpath "$IMAGE")"
[ ! -f "$IMAGE" ] && echo "Error: $IMAGE not found" && exit 1

BASENAME=$(basename "$IMAGE" .img)
LOOP_MOUNT="$ROOT_DIR/output/mnt/.${BASENAME}_loop"
USER_MOUNT="$ROOT_DIR/output/mnt/$BASENAME"

# Remove AVB footer if present
echo "Removing AVB footer..."
python3 "$AVB" erase_footer --image "$IMAGE" 2>/dev/null || true

# Resize if requested
if [ "$RESIZE" = true ]; then
    echo "Resizing partition (+50MB)..."
    truncate -s +50M "$IMAGE"
    "$E2FSCK" -f -y "$IMAGE" 2>&1 | tail -2
    "$RESIZE2FS" "$IMAGE" 2>&1 | tail -1
fi

# Mount with loop, then bindfs for user access
echo "Mounting $IMAGE..."
mkdir -p "$LOOP_MOUNT" "$USER_MOUNT"
sudo mount -o loop,rw "$IMAGE" "$LOOP_MOUNT"

# bindfs with force-user/group to make all files appear owned by current user
"$BINDFS" -u $(id -u) -g $(id -g) -p 0755,a+rw "$LOOP_MOUNT" "$USER_MOUNT"

echo ""
echo "=== Partition mounted at: $USER_MOUNT ==="
echo ""
ls "$USER_MOUNT"
echo ""
df -h "$LOOP_MOUNT"
echo ""
echo "Make your modifications (no sudo needed), then run:"
echo "  ./scripts/unmount_partition.sh $BASENAME"
echo "  ./scripts/repack_super.sh"
