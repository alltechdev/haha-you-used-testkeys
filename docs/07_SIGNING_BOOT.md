# Re-signing Boot.img

## Overview

The boot partition contains the kernel and ramdisk. Common reasons to modify boot:

1. **Root with Magisk** - Patch boot.img with Magisk app
2. **Custom kernel** - Replace stock kernel
3. **Modified ramdisk** - Add init scripts

After modification, boot.img must be re-signed with our boot.pem key so the vbmeta chain accepts it.

---

## The Script: resign_boot.sh

### Location
```
/path/to/haha-you-used-testkeys/scripts/resign_boot.sh
```

### What It Does

1. Reads boot partition size from scatter file
2. Erases existing AVB footer
3. Adds new hash footer signed with boot.pem

### Usage

```bash
./scripts/resign_boot.sh <boot.img> [partition_size]
```

- `boot.img` - Path to the boot image to sign
- `partition_size` - Optional, auto-detected from scatter if not specified

---

## Workflow A: Root with Magisk

### Step 1: Get Stock Boot Image

```bash
# Copy from firmware
cp firmware/stock/boot.img /tmp/stock_boot.img
```

### Step 2: Transfer to Device

```bash
adb push /tmp/stock_boot.img /sdcard/boot.img
```

### Step 3: Patch with Magisk App

On the device:
1. Open Magisk app
2. Tap "Install" next to Magisk
3. Select "Select and Patch a File"
4. Navigate to /sdcard/boot.img
5. Tap "LET'S GO"
6. Wait for patching to complete

The patched file is saved as `/sdcard/Download/magisk_patched_XXXXX.img`

### Step 4: Pull Patched Image

```bash
adb pull /sdcard/Download/magisk_patched_*.img magisk_patched.img
```

### Step 5: Re-sign with Our Key

```bash
cd /path/to/haha-you-used-testkeys
./scripts/resign_boot.sh magisk_patched.img
```

### Step 6: Observe Output

```
Boot partition size from scatter: 33554432 bytes
Re-signing boot.img...

Signed boot.img public key:
Public key (sha1):        a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc

Output: /path/to/haha-you-used-testkeys/output/boot.img
```

---

## Workflow B: Sign Stock Boot (for vbmeta chain)

If you only modified super partitions but not boot, you still need boot.img in output for the vbmeta chain:

```bash
./scripts/resign_boot.sh firmware/stock/boot.img
```

This re-signs the stock boot with our key so vbmeta.img can reference it.

---

## What Happens Internally

### 1. Read Boot Partition Size from Scatter

```bash
SCATTER=$(find firmware/stock -name "*scatter*.txt" | head -1)
PART_SIZE_HEX=$(grep -A15 "partition_name: boot_a" "$SCATTER" | grep "partition_size:" | head -1 | awk '{print $2}')
PART_SIZE=$((PART_SIZE_HEX))
```

**Why?** AVB requires knowing the exact partition size for the hash footer.

### 2. Copy to Output

```bash
cp input_boot.img output/boot.img
```

### 3. Erase Existing Footer

```bash
python3 tools/avb-tools/avbtool.py erase_footer --image output/boot.img
```

**Why?** Remove old signature so we can add new one.

### 4. Add Hash Footer

```bash
python3 tools/avb-tools/avbtool.py add_hash_footer \
    --image output/boot.img \
    --partition_name boot \
    --partition_size $PART_SIZE \
    --key keys/boot.pem \
    --algorithm SHA256_RSA2048
```

**What this does:**
- Calculates SHA256 hash of the entire boot image
- Signs the hash with boot.pem key
- Appends AVB footer with signature

**Note:** Boot uses `add_hash_footer` (simple hash), not `add_hashtree_footer` (Merkle tree). Hashtree is only needed for large partitions that need block-level verification (system/vendor/product).

---

## Output

After running:

```
output/
└── boot.img    ← Re-signed boot image
```

---

## Verifying the Signature

### Check Public Key

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/boot.img
```

**Expected Output:**
```
Minimum libavb version:   1.0
Header Block:             256 bytes
Authentication Block:     320 bytes
Auxiliary Block:          576 bytes
Public key (sha1):        a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc
Algorithm:                SHA256_RSA2048
...
Hash descriptor:
    Image Size:           33546240 bytes
    Hash Algorithm:       sha256
    Partition Name:       boot
    Salt:                 ...
    Digest:               ...
```

**Key SHA1 must be:** `a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc`

This matches what vbmeta.img expects for the boot partition.

---

## Understanding Boot.img Structure

### Before Signing

```
┌────────────────────────────────────┐
│         Boot Image Header          │
├────────────────────────────────────┤
│            Kernel                  │
├────────────────────────────────────┤
│            Ramdisk                 │
├────────────────────────────────────┤
│      Second Stage (optional)       │
├────────────────────────────────────┤
│          DTB (optional)            │
└────────────────────────────────────┘
```

### After Signing (with AVB)

```
┌────────────────────────────────────┐
│         Boot Image Header          │
├────────────────────────────────────┤
│            Kernel                  │
├────────────────────────────────────┤
│            Ramdisk                 │
├────────────────────────────────────┤
│            ...                     │
├────────────────────────────────────┤
│         Padding to Align           │
├────────────────────────────────────┤
│          VBMeta Footer             │  ← Added by avbtool
│  - Header                          │
│  - Authentication (signature)      │
│  - Hash descriptor                 │
│  - Public key                      │
└────────────────────────────────────┘
```

---

## Troubleshooting

### Error: "Boot partition size 0"

**Cause:** Couldn't find boot_a in scatter file.

**Fix:**
1. Check scatter file has `partition_name: boot_a`
2. Or specify size manually: `./scripts/resign_boot.sh boot.img 33554432`

### Error: "Failed to sign boot.img"

**Cause:** Key file missing or corrupt.

**Fix:** Verify key exists:
```bash
ls -la keys/boot.pem
```

### Magisk Patched Boot Doesn't Work

**Possible causes:**
1. Wrong Magisk version for device
2. AVB signature not updated
3. vbmeta.img not rebuilt

**Fix:** After resign_boot.sh, always run:
```bash
./scripts/rebuild_vbmeta.sh
./scripts/verify_chain.sh
```

### Boot Size Exceeds Partition

**Cause:** Magisk patch increased boot size beyond partition limit.

**Error:** `Image size exceeds partition size`

**Fix:** Use a smaller Magisk version or ensure boot.img fits within partition_size.

---

## Next Steps

After signing boot:
- [08_REBUILDING_VBMETA.md](08_REBUILDING_VBMETA.md) - Rebuild root vbmeta with updated chain
