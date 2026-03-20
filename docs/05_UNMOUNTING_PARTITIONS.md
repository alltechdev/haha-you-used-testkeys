# Unmounting Partitions

## Overview

After making modifications, partitions must be unmounted before repacking. The `unmount_partition.sh` script handles:

1. Unmounting the bindfs overlay (user-accessible mount)
2. Unmounting the loop device (actual mount)
3. Cleaning up mount point directories

---

## The Script: unmount_partition.sh

### Location
```
/path/to/haha-you-used-testkeys/scripts/unmount_partition.sh
```

### Usage

```bash
./scripts/unmount_partition.sh <partition_name>
```

Where `partition_name` is one of: `system_a`, `vendor_a`, `product_a`

---

## Step-by-Step Process

### Step 1: Unmount System Partition

```bash
cd /path/to/haha-you-used-testkeys
./scripts/unmount_partition.sh system_a
```

### Step 2: Observe Output

```
Unmounting system_a...
Done.
```

### Step 3: Unmount Remaining Partitions

```bash
./scripts/unmount_partition.sh vendor_a
./scripts/unmount_partition.sh product_a
```

---

## What Happens Internally

### 1. Unmount bindfs Overlay

```bash
fusermount -u output/mnt/system_a
# or
umount output/mnt/system_a
```

This removes the user-accessible FUSE mount.

### 2. Unmount Loop Device

```bash
sudo umount output/mnt/.system_a_loop
```

This detaches the loop device from the image file.

### 3. Cleanup Directories

```bash
rmdir output/mnt/system_a
rmdir output/mnt/.system_a_loop
```

---

## Verifying Unmount

### Check No Mounts Remain

```bash
mount | grep haha-you-used-testkeys
```

**Expected:** No output (nothing mounted)

### Check Mount Points Removed

```bash
ls output/mnt/
```

**Expected:** Empty or only contains unmounted directories

---

## Important: Unmount Before Repacking

**Critical:** If you run `repack_super.sh` while partitions are still mounted:

1. The image files may be in an inconsistent state
2. Changes may not be fully written to disk
3. Hashtree calculation will be incorrect
4. The resulting super.img will fail dm-verity

**Always unmount all partitions before repacking!**

---

## Troubleshooting

### Error: "Device or resource busy"

**Cause:** A process is using files in the mounted partition.

**Fix:**

1. Find what's using it:
```bash
lsof +D output/mnt/system_a/
```

2. Close those processes, then retry:
```bash
./scripts/unmount_partition.sh system_a
```

3. If still stuck, lazy unmount:
```bash
sudo umount -l output/mnt/.system_a_loop
fusermount -uz output/mnt/system_a
```

### Error: "not mounted" or "not found"

**Cause:** Partition wasn't mounted or already unmounted.

**This is OK:** The script handles this gracefully.

### Error: "fusermount: entry not found"

**Cause:** bindfs mount entry missing from mtab.

**Fix:** The script tries `umount` as fallback. Usually harmless.

### Directories Not Removed

**Cause:** Non-empty directories or permission issues.

**Fix:**
```bash
sudo rm -rf output/mnt/.system_a_loop output/mnt/system_a
```

---

## Batch Unmount

To unmount all partitions at once:

```bash
./scripts/unmount_partition.sh system_a
./scripts/unmount_partition.sh vendor_a
./scripts/unmount_partition.sh product_a
```

Or use the cleanup script (also removes output files):

```bash
./scripts/cleanup.sh
```

---

## Sync Before Unmount (Optional)

To ensure all writes are flushed to disk:

```bash
sync
./scripts/unmount_partition.sh system_a
```

---

## Next Steps

After unmounting all partitions:
- [06_REPACKING_SUPER.md](06_REPACKING_SUPER.md) - Repack super.img with signatures
