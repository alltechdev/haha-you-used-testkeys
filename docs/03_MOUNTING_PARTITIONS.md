# Mounting Partitions for Modification

## Overview

To modify partition contents, we need to mount the ext4 images. The `modify_partition.sh` script handles:

1. Removing existing AVB footer (so we can resize)
2. Optionally resizing the partition (+50MB headroom)
3. Running filesystem check (e2fsck)
4. Mounting with loop device (requires sudo)
5. Creating user-accessible mount via bindfs (no sudo needed for edits)

---

## The Script: modify_partition.sh

### Location
```
/path/to/haha-you-used-testkeys/scripts/modify_partition.sh
```

### Usage

```bash
sudo ./scripts/modify_partition.sh <partition.img> [--resize]
```

### Options

| Option | Description |
|--------|-------------|
| `--resize` | Add 50MB to partition (recommended for adding files) |
| (no option) | Mount without resizing |

---

## Step-by-Step Process

### Step 1: Mount System Partition

```bash
cd /path/to/haha-you-used-testkeys
sudo ./scripts/modify_partition.sh output/super_unpacked/system_a.img --resize
```

### Step 2: Observe Output

```
Removing AVB footer...
Resizing partition (+50MB)...
Pass 5: Checking group summary information
/: 3538/3840 files (0.5% non-contiguous), 446709/460840 blocks

Mounting /path/to/haha-you-used-testkeys/output/super_unpacked/system_a.img...

=== Partition mounted at: /path/to/haha-you-used-testkeys/output/mnt/system_a ===

acct
apex
bin
bugreports
...
system
vendor
...

Filesystem      Size  Used Avail Use% Mounted on
/dev/loop7      1.9G  1.8G  140M  93% /path/to/haha-you-used-testkeys/output/mnt/.system_a_loop

Make your modifications (no sudo needed), then run:
  ./scripts/unmount_partition.sh system_a
  ./scripts/repack_super.sh
```

### Step 3: Mount Vendor and Product (if needed)

```bash
sudo ./scripts/modify_partition.sh output/super_unpacked/vendor_a.img --resize
sudo ./scripts/modify_partition.sh output/super_unpacked/product_a.img --resize
```

---

## What Happens Internally

### 1. Remove AVB Footer

Before resizing, the AVB hashtree footer must be removed:

```bash
python3 tools/avb-tools/avbtool.py erase_footer --image partition.img
```

**Why?** The footer is at the end of the file. If we resize without removing it, the footer data becomes corrupted.

### 2. Resize Partition (if --resize)

The script adds 50MB to the partition:

```bash
# Add 50MB to file size
truncate -s +50M partition.img

# Check filesystem integrity
tools/android-bins/e2fsck -f -y partition.img

# Expand filesystem to fill new space
tools/android-bins/resize2fs partition.img
```

**Why resize?**
- Stock partitions are tightly packed
- Adding files (apps, configs) needs free space
- 50MB provides comfortable headroom

### 3. Create Mount Points

```bash
mkdir -p output/mnt/.system_a_loop    # For sudo mount
mkdir -p output/mnt/system_a          # For user access
```

### 4. Mount with Loop Device

```bash
sudo mount -o loop,rw partition.img output/mnt/.system_a_loop
```

**What this does:**
- Creates a loop device (/dev/loopN) pointing to the image file
- Mounts the loop device as an ext4 filesystem
- Requires sudo because mounting is a privileged operation

### 5. Create User-Accessible Mount (bindfs)

```bash
tools/android-bins/bindfs -u $(id -u) -g $(id -g) -p 0755,a+rw \
    output/mnt/.system_a_loop output/mnt/system_a
```

**What bindfs does:**
- Creates a FUSE filesystem overlay
- Remaps all file ownership to current user
- Sets permissions to allow read/write
- **Result:** You can edit files in `output/mnt/system_a/` without sudo!

---

## Mount Point Structure

After mounting all three partitions:

```
output/mnt/
├── .system_a_loop/     ← Actual mount (root-owned, sudo mount)
├── system_a/           ← User-accessible (bindfs overlay)
│   └── system/
│       ├── app/
│       ├── priv-app/
│       ├── build.prop
│       └── ...
│
├── .vendor_a_loop/     ← Actual mount
├── vendor_a/           ← User-accessible
│   ├── app/
│   ├── build.prop
│   └── ...
│
├── .product_a_loop/    ← Actual mount
└── product_a/          ← User-accessible
    ├── app/
    ├── priv-app/
    └── ...
```

---

## Verifying Mount

### Check Mount Points

```bash
mount | grep haha-you-used-testkeys
```

**Expected Output:**
```
/dev/loop7 on /home/.../output/mnt/.system_a_loop type ext4 (rw,relatime)
bindfs on /home/.../output/mnt/system_a type fuse.bindfs (rw,nosuid,nodev,...)
...
```

### Check User Access

```bash
# Should work without sudo
ls output/mnt/system_a/system/
cat output/mnt/system_a/system/build.prop | head -5
```

### Check Available Space

```bash
df -h output/mnt/system_a/
```

**Example Output:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop7      1.9G  1.8G  140M  93% /home/.../output/mnt/.system_a_loop
```

---

## Common Operations While Mounted

### View Build Properties

```bash
cat output/mnt/system_a/system/build.prop
cat output/mnt/vendor_a/build.prop
```

### List Pre-installed Apps

```bash
ls output/mnt/system_a/system/app/
ls output/mnt/system_a/system/priv-app/
ls output/mnt/product_a/app/
ls output/mnt/product_a/priv-app/
```

### Check Disk Usage

```bash
du -sh output/mnt/system_a/system/app/*
du -sh output/mnt/product_a/app/*
```

---

## Troubleshooting

### Error: "a terminal is required to read the password"

**Cause:** Script needs sudo but password prompt can't be displayed.

**Fix:** Run with `echo "password" | sudo -S ./scripts/modify_partition.sh ...`

Or run `sudo -v` first to cache credentials.

### Error: "user_allow_other only allowed if set in /etc/fuse.conf"

**Cause:** FUSE not configured to allow user mounts.

**Fix:**
```bash
sudo sh -c 'echo "user_allow_other" >> /etc/fuse.conf'
```

### Error: "is already mounted"

**Cause:** Previous mount wasn't cleaned up.

**Fix:**
```bash
./scripts/unmount_partition.sh system_a
# Then try again
```

### Error: "e2fsck: Cannot continue, aborting"

**Cause:** Filesystem has errors that need manual intervention.

**Fix:**
```bash
sudo tools/android-bins/e2fsck -f -y output/super_unpacked/system_a.img
```

### Files Still Owned by Root

**Cause:** bindfs not working correctly.

**Verify bindfs is running:**
```bash
mount | grep bindfs
```

**If not mounted:** Check that `user_allow_other` is in /etc/fuse.conf.

---

## Next Steps

After mounting, proceed to:
- [04_MODIFYING_PARTITIONS.md](04_MODIFYING_PARTITIONS.md) - Make your modifications
