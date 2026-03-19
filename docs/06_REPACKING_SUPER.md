# Repacking Super.img

## Overview

After modifying partitions, we must:

1. Erase old AVB footers
2. Add new hashtree footers (for dm-verity)
3. Create new vbmeta_system.img (contains system + product hashtrees)
4. Create new vbmeta_vendor.img (contains vendor hashtree)
5. Repack all partitions into super.img

The `repack_super.sh` script handles all of this automatically.

---

## The Script: repack_super.sh

### Location
```
/path/to/m5_resigner/scripts/repack_super.sh
```

### What It Does

1. Reads super partition size from scatter file
2. Erases existing AVB footers from partition images
3. Calculates partition sizes with hashtree overhead
4. Adds hashtree footers to system_a, vendor_a, product_a
5. Creates signed vbmeta_system.img
6. Creates signed vbmeta_vendor.img
7. Repacks everything into super.img using lpmake

### Usage

```bash
./scripts/repack_super.sh
```

No arguments needed - it uses partitions from `output/super_unpacked/`.

---

## Step-by-Step Process

### Step 1: Ensure Partitions Are Unmounted

```bash
# Verify nothing is mounted
mount | grep m5_resigner
# Should return nothing
```

### Step 2: Run Repack Script

```bash
cd /path/to/m5_resigner
./scripts/repack_super.sh
```

### Step 3: Observe Output

```
=== Repacking Super.img ===
Super partition size from scatter: 5368709120 bytes (0x140000000)
system_a: 1992458240 bytes
vendor_a: 453365760 bytes
product_a: 1399762944 bytes

Erasing existing AVB footers...
system_a (clean): 1992458240 bytes
vendor_a (clean): 453365760 bytes
product_a (clean): 1399762944 bytes

Adding hashtree footers...
system_a (final): 2032308224 bytes
vendor_a (final): 462434304 bytes
product_a (final): 1427759104 bytes

Creating vbmeta_system.img...
Creating vbmeta_vendor.img...

Repacking super.img...
lpmake I ... Partition system_a will resize from 0 bytes to 2032308224 bytes
lpmake I ... Partition product_a will resize from 0 bytes to 1427759104 bytes
lpmake I ... Partition vendor_a will resize from 0 bytes to 462434304 bytes

Done! Output files:
-rw-r--r-- 1 user user 3.4G output/super.img
-rw-rw-r-- 1 user user 1.7K output/vbmeta_system.img
-rw-rw-r-- 1 user user 1.4K output/vbmeta_vendor.img

Flash these files:
  - super.img
  - vbmeta_system.img
  - vbmeta_vendor.img
```

---

## What Happens Internally

### 1. Read Super Partition Size from Scatter

```bash
SCATTER=$(find firmware/stock -name "*scatter*.txt" | head -1)
SUPER_SIZE_HEX=$(grep -A15 "partition_name: super" "$SCATTER" | grep "partition_size:" | head -1 | awk '{print $2}')
SUPER_SIZE=$((SUPER_SIZE_HEX))
```

**Why from scatter?** The super partition has a fixed size on the device. lpmake must know this exact size to create a compatible image.

### 2. Erase Existing AVB Footers

```bash
python3 tools/avb-tools/avbtool.py erase_footer --image output/super_unpacked/system_a.img
python3 tools/avb-tools/avbtool.py erase_footer --image output/super_unpacked/vendor_a.img
python3 tools/avb-tools/avbtool.py erase_footer --image output/super_unpacked/product_a.img
```

**Why?** Old footers have hashtrees for the old content. We need to recalculate for modified content.

### 3. Calculate Partition Sizes with Hashtree Overhead

```bash
# Raw size
SYSTEM_SIZE=$(stat -c%s output/super_unpacked/system_a.img)

# Add ~2% for hashtree, round to 4096 bytes
SYSTEM_PART_SIZE=$(( (SYSTEM_SIZE * 102 / 100 + 4095) / 4096 * 4096 ))
```

**Why overhead?** The hashtree (Merkle tree) is appended to the image. It needs extra space.

### 4. Add Hashtree Footers

```bash
python3 tools/avb-tools/avbtool.py add_hashtree_footer \
    --image output/super_unpacked/system_a.img \
    --partition_name system \
    --partition_size $SYSTEM_PART_SIZE \
    --hash_algorithm sha256 \
    --do_not_generate_fec
```

**What this does:**
- Calculates SHA256 hash of every 4096-byte block
- Builds a Merkle tree from those hashes
- Appends the tree to the image
- Adds AVB footer with root digest

**Repeated for:** vendor_a.img, product_a.img

### 5. Create vbmeta_system.img

```bash
python3 tools/avb-tools/avbtool.py make_vbmeta_image \
    --output output/vbmeta_system.img \
    --key keys/vbmeta_system.pem \
    --algorithm SHA256_RSA2048 \
    --include_descriptors_from_image output/super_unpacked/system_a.img \
    --include_descriptors_from_image output/super_unpacked/product_a.img
```

**What this does:**
- Creates a vbmeta image containing hashtree descriptors for system and product
- Signs with vbmeta_system.pem key
- The descriptors include partition name, size, and root digest

### 6. Create vbmeta_vendor.img

```bash
python3 tools/avb-tools/avbtool.py make_vbmeta_image \
    --output output/vbmeta_vendor.img \
    --key keys/vbmeta_vendor.pem \
    --algorithm SHA256_RSA2048 \
    --include_descriptors_from_image output/super_unpacked/vendor_a.img
```

### 7. Repack Super.img with lpmake

```bash
tools/lpunpack_and_lpmake/binary/lpmake \
    --device-size=$SUPER_SIZE \
    --metadata-size=65536 \
    --metadata-slots=3 \
    --group=main_a:$GROUP_SIZE \
    --group=main_b:0 \
    --partition=system_a:readonly:$SYSTEM_SIZE:main_a \
    --partition=system_b:readonly:0:main_b \
    --partition=product_a:readonly:$PRODUCT_SIZE:main_a \
    --partition=product_b:readonly:0:main_b \
    --partition=vendor_a:readonly:$VENDOR_SIZE:main_a \
    --partition=vendor_b:readonly:0:main_b \
    --image=system_a=output/super_unpacked/system_a.img \
    --image=product_a=output/super_unpacked/product_a.img \
    --image=vendor_a=output/super_unpacked/vendor_a.img \
    --sparse \
    --output=output/super.img
```

**lpmake parameters:**
- `--device-size` - Total size of super partition (from scatter)
- `--metadata-size` - Size of LpMetadata structure
- `--metadata-slots` - Number of metadata copies (for A/B)
- `--group` - Partition group and its maximum size
- `--partition` - Define partition: name:attributes:size:group
- `--image` - Map partition to image file
- `--sparse` - Output sparse format (smaller file)

---

## Output Files

After running, these files are created in `output/`:

| File | Size | Description |
|------|------|-------------|
| super.img | ~3-4GB | Sparse super partition with all partitions |
| vbmeta_system.img | ~2KB | Signed hashtrees for system + product |
| vbmeta_vendor.img | ~1.5KB | Signed hashtree for vendor |

---

## Verifying Output

### Check Files Exist

```bash
ls -lh output/*.img
```

### Inspect vbmeta_system.img

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/vbmeta_system.img
```

**Expected Output:**
```
Minimum libavb version:   1.0
Header Block:             256 bytes
Authentication Block:     320 bytes
Auxiliary Block:          1216 bytes
Public key (sha1):        565840a78763c9a3be92604f5aef14376ee45415
Algorithm:                SHA256_RSA2048
...
Descriptors:
    Hashtree descriptor:
      Partition Name:       system
      ...
      Root Digest:          [hash of system]
    Hashtree descriptor:
      Partition Name:       product
      ...
      Root Digest:          [hash of product]
```

### Inspect vbmeta_vendor.img

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/vbmeta_vendor.img
```

---

## Troubleshooting

### Error: "Cannot find scatter file"

**Cause:** No scatter file in `firmware/stock/`.

**Fix:** Copy your device's scatter file (e.g., `MT6761_Android_scatter.txt`) to `firmware/stock/`.

### Error: "super partition size 0"

**Cause:** Couldn't parse super size from scatter file.

**Fix:** Check scatter file format. The script looks for:
```
partition_name: super
...
partition_size: 0x140000000
```

### Error: "Failed to add hashtree"

**Cause:** Partition image is corrupt or wrong format.

**Fix:**
1. Re-extract from stock super.img
2. Check image is valid ext4: `file output/super_unpacked/system_a.img`

### Error: "lpmake: group size too small"

**Cause:** Total partition sizes exceed super partition capacity.

**Fix:** Remove more files from partitions to reduce size.

### Output super.img is Very Small

**Cause:** Sparse format compresses empty space.

**Normal:** A 3.4GB sparse file might only contain 2.5GB of actual data.

---

## Next Steps

After repacking super:
- [07_SIGNING_BOOT.md](07_SIGNING_BOOT.md) - Re-sign boot.img (if modified)
- [08_REBUILDING_VBMETA.md](08_REBUILDING_VBMETA.md) - Rebuild root vbmeta
