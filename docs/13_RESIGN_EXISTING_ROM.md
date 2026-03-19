# Re-signing an Existing Modified ROM

## Overview

If you have an already modified super.img (e.g., custom ROM, debloated stock, rooted system) that was built for **unlocked bootloader**, you can re-sign it to work with **locked bootloader + green verified boot**.

This process:
1. Unpacks the modified super.img
2. Shrinks filesystems to minimum size (if needed)
3. Adds AVB hashtree footers
4. Creates signed vbmeta images
5. Repacks into a new super.img

---

## When to Use This

- You have a custom ROM built for unlocked bootloader
- You want to convert it to locked bootloader
- The ROM doesn't have AVB signatures or has wrong signatures

---

## Requirements

1. **Stock firmware** for your device (need the scatter file)
2. **Modified super.img** you want to re-sign
3. **Modified boot.img** (if the ROM includes a modified boot)

---

## Quick Method (Automated)

```bash
# 1. Copy stock firmware
cp -r /path/to/stock/firmware/* firmware/stock/

# 2. Copy custom ROM
cp /path/to/modified/super.img firmware/custom/
cp /path/to/modified/boot.img firmware/custom/  # optional

# 3. Run re-sign script
./scripts/resign_existing_rom.sh
```

---

## Manual Process (Step-by-Step)

### Step 1: Copy Stock Firmware (for scatter file)

```bash
cp -r /path/to/stock/firmware/* firmware/stock/
```

### Step 2: Copy Custom ROM

```bash
cp /path/to/modified/super.img firmware/custom/
cp /path/to/modified/boot.img firmware/custom/  # if you have modified boot
```

### Step 3: Check Device Uses AOSP Testkey

```bash
./scripts/check_testkey.sh firmware/stock/vbmeta.img
```

Must show: `VULNERABLE - Uses AOSP testkey!`

### Step 4: Unpack the Modified Super.img

```bash
./scripts/unpack_super.sh firmware/custom/super.img
```

### Step 5: Check If Partitions Fit

The repack script will fail if partitions + hashtree overhead exceed the super partition size.

Check your device's super partition size:
```bash
grep -A15 "partition_name: super" firmware/stock/*scatter*.txt | grep "partition_size:"
```

Common sizes:
- M5: 5GB (0x140000000)
- F21 Pro: 4GB (0x100000000)

### Step 6: Shrink Partitions (If Needed)

If repack fails with "Not enough space", shrink the filesystems:

```bash
# Check and shrink each partition to minimum size
for img in output/super_unpacked/system_a.img output/super_unpacked/vendor_a.img output/super_unpacked/product_a.img; do
    tools/android-bins/e2fsck -f -y "$img"
    tools/android-bins/resize2fs -M "$img"
done
```

**What resize2fs -M does:**
- Shrinks the filesystem to its minimum size
- Only removes **unused blocks** (empty space)
- Does NOT delete any files
- Completely safe - verify with `e2fsck -n` after

### Step 7: Repack Super.img

```bash
./scripts/repack_super.sh
```

This:
- Erases any existing AVB footers
- Adds new hashtree footers signed with our keys
- Creates vbmeta_system.img and vbmeta_vendor.img
- Repacks into super.img

### Step 8: Sign Boot.img

If you have a modified boot in firmware/custom/:
```bash
./scripts/resign_boot.sh firmware/custom/boot.img
```

If using stock boot:
```bash
./scripts/resign_boot.sh firmware/stock/boot.img
```

### Step 9: Rebuild vbmeta.img

```bash
./scripts/rebuild_vbmeta.sh
```

### Step 10: Verify Chain

```bash
./scripts/verify_chain.sh
```

Must show: `=== ALL CHECKS PASSED ===`

### Step 11: Verify Filesystem Integrity (Optional)

```bash
for img in output/super_unpacked/*.img; do
    echo "=== $(basename $img) ==="
    tools/android-bins/e2fsck -n "$img" 2>&1 | tail -1
done
```

All should show "clean".

---

## Output Files

```
output/
├── boot.img              ← Re-signed boot
├── super.img             ← Re-signed super with hashtrees
├── vbmeta.img            ← Root of trust
├── vbmeta_system.img     ← System/product hashtrees
├── vbmeta_vendor.img     ← Vendor hashtree
└── MT6761_Android_scatter.txt  ← For SP Flash Tool
```

---

## Flash

Use SP Flash Tool with the scatter file in output/:

1. Load `output/MT6761_Android_scatter.txt`
2. Select: boot_a, super, vbmeta_a, vbmeta_system_a, vbmeta_vendor_a
3. Download
4. Factory reset (recommended for ROM changes)

---

## Example: F21 Pro Custom ROM

```bash
# Cleanup
./scripts/cleanup.sh

# Copy stock firmware (for scatter)
cp -r /path/to/f21pro/stock/* firmware/stock/

# Copy custom ROM
cp /path/to/custom/super.img firmware/custom/
cp /path/to/custom/boot.img firmware/custom/

# Run automated re-sign
./scripts/resign_existing_rom.sh
```

Or manually if you need to shrink partitions:

```bash
# Check testkey
./scripts/check_testkey.sh firmware/stock/vbmeta.img

# Unpack modified super
./scripts/unpack_super.sh firmware/custom/super.img

# Shrink partitions (F21 Pro has 4GB super, often needed)
for img in output/super_unpacked/system_a.img output/super_unpacked/vendor_a.img output/super_unpacked/product_a.img; do
    tools/android-bins/e2fsck -f -y "$img"
    tools/android-bins/resize2fs -M "$img"
done

# Repack
./scripts/repack_super.sh

# Sign boot
./scripts/resign_boot.sh firmware/custom/boot.img

# Rebuild vbmeta
./scripts/rebuild_vbmeta.sh

# Verify
./scripts/verify_chain.sh
```

---

## Troubleshooting

### "Not enough space" Error

**Cause:** Partitions + hashtree overhead exceed super partition size.

**Fix:** Run resize2fs -M on all partitions to shrink them.

### Filesystem Errors After Shrink

**Check:** Run `e2fsck -n` to verify.

**If errors:** Run `e2fsck -f -y` to fix, then resize again.

### Boot Loop After Flash

**Cause:** ROM incompatibility or missing files.

**Fix:** This is a ROM issue, not a signing issue. The AVB chain is correct if verify_chain.sh passed.

---

## Why This Works

Original modified super.img was likely built:
- Without AVB hashtree footers
- For unlocked bootloader use
- With different/no signatures

Our process:
1. Extracts the raw partition images
2. Adds proper AVB hashtree footers (for dm-verity)
3. Signs with AOSP testkey (which the bootloader trusts)
4. Creates proper vbmeta chain

Result: Same modified ROM, but now accepted by locked bootloader.
