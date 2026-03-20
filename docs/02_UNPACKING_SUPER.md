# Unpacking Super.img

## What is Super.img?

`super.img` is a **dynamic partition** container introduced in Android 10. It contains multiple logical partitions:

| Partition | Contents |
|-----------|----------|
| system_a | Android system files, framework, apps |
| system_b | Empty or minimal (A/B slot) |
| vendor_a | Hardware-specific drivers, HALs |
| vendor_b | Empty (A/B slot) |
| product_a | OEM customizations, additional apps |
| product_b | Empty (A/B slot) |

### Sparse vs Raw Format

Stock `super.img` is usually in **sparse format** (compressed). We need to convert it to **raw format** before unpacking.

```
Sparse format: Compressed, smaller file size, has sparse headers
Raw format: Uncompressed, actual partition data
```

---

## The Script: unpack_super.sh

### Location
```
/path/to/haha-you-used-testkeys/scripts/unpack_super.sh
```

### What It Does

1. Converts sparse super.img to raw format (simg2img)
2. Extracts all partitions using lpunpack
3. Lists extracted partitions with sizes

### Usage

```bash
./scripts/unpack_super.sh <path_to_super.img>
```

---

## Step-by-Step Process

### Step 1: Navigate to Repository

```bash
cd /path/to/haha-you-used-testkeys
```

### Step 2: Run Unpack Script

```bash
./scripts/unpack_super.sh firmware/stock/super.img
```

### Step 3: Observe Output

```
Converting sparse to raw...
Unpacking super.img...

Extracted partitions:
total 3.6G
-rw-r--r-- 1 user user 1.3G product_a.img
-rw-r--r-- 1 user user    0 product_b.img
-rw-r--r-- 1 user user 1.8G system_a.img
-rw-r--r-- 1 user user 162M system_b.img
-rw-r--r-- 1 user user 389M vendor_a.img
-rw-r--r-- 1 user user    0 vendor_b.img

To mount a partition for modification:
  ./scripts/modify_partition.sh /path/to/haha-you-used-testkeys/output/super_unpacked/system_a.img --resize
```

---

## What Happens Internally

### 1. Sparse to Raw Conversion

The script first converts the sparse image to raw:

```bash
simg2img firmware/stock/super.img /tmp/super_raw_$$.img
```

**Why?** lpunpack cannot read sparse format directly. The raw image is the actual block device data.

### 2. lpunpack Extraction

The script then extracts all partitions:

```bash
lpunpack /tmp/super_raw_$$.img output/super_unpacked/
```

**What lpunpack does:**
- Reads the super partition metadata (LpMetadata)
- Identifies all logical partitions and their extents
- Extracts each partition to a separate .img file

### 3. Cleanup

The temporary raw file is deleted to save space:

```bash
rm /tmp/super_raw_$$.img
```

---

## Output Directory Structure

After unpacking:

```
output/
└── super_unpacked/
    ├── system_a.img      ← Main system partition (ext4)
    ├── system_b.img      ← Usually minimal or empty
    ├── vendor_a.img      ← Vendor partition (ext4)
    ├── vendor_b.img      ← Empty
    ├── product_a.img     ← Product partition (ext4)
    └── product_b.img     ← Empty
```

---

## Verify Extracted Partitions

### Check File Types

```bash
file output/super_unpacked/*.img
```

**Expected Output:**
```
output/super_unpacked/product_a.img: Linux rev 1.0 ext4 filesystem data, ...
output/super_unpacked/product_b.img: empty
output/super_unpacked/system_a.img:  Linux rev 1.0 ext4 filesystem data, ...
output/super_unpacked/system_b.img:  Linux rev 1.0 ext4 filesystem data, ...
output/super_unpacked/vendor_a.img:  Linux rev 1.0 ext4 filesystem data, ...
output/super_unpacked/vendor_b.img:  empty
```

### Check Partition Sizes

```bash
ls -lh output/super_unpacked/
```

### Check AVB Footers (Optional)

Each partition may have an AVB footer with hashtree data:

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/super_unpacked/system_a.img
```

**Example Output:**
```
Footer version:           1.0
Image size:               1887436800 bytes
Original image size:      1853882368 bytes
VBMeta offset:            1853886464
VBMeta size:              33554432

Hashtree descriptor:
    Version:              1
    Image Size:           1853882368 bytes
    Tree Offset:          1853882368
    Tree Size:            14618624 bytes
    Data Block Size:      4096 bytes
    Hash Block Size:      4096 bytes
    FEC num roots:        0
    FEC offset:           0
    FEC size:             0 bytes
    Hash Algorithm:       sha256
    Partition Name:       system
    Salt:                 ...
    Root Digest:          ...
```

---

## Understanding Partition Contents

### system_a.img

Contains the core Android system:

```
/system/
├── app/              ← Pre-installed apps
├── priv-app/         ← Privileged system apps
├── framework/        ← Android framework JARs
├── lib/ & lib64/     ← Native libraries
├── bin/              ← System binaries
├── etc/              ← Configuration files
├── build.prop        ← System properties
└── ...
```

### vendor_a.img

Contains hardware-specific files:

```
/vendor/
├── app/              ← Vendor apps
├── bin/              ← Vendor binaries
├── lib/ & lib64/     ← Vendor native libraries
├── etc/              ← Vendor configs
├── firmware/         ← Device firmware blobs
├── build.prop        ← Vendor properties
└── ...
```

### product_a.img

Contains OEM customizations:

```
/product/
├── app/              ← OEM apps (often bloatware)
├── priv-app/         ← OEM privileged apps
├── overlay/          ← Resource overlays
├── media/            ← Ringtones, sounds
└── ...
```

---

## Troubleshooting

### Error: "Cannot open super.img"

**Cause:** File path is wrong or file doesn't exist.

**Fix:** Verify the path:
```bash
ls -la firmware/stock/super.img
```

### Error: "Invalid sparse file format"

**Cause:** super.img is already in raw format (not sparse).

**Fix:** The script handles this - it will try to unpack directly if sparse conversion fails.

### Error: "lpunpack failed"

**Cause:** Corrupted super.img or incompatible format.

**Fix:**
1. Re-download firmware
2. Check if super.img is complete (not truncated)

### Very Small Partition Sizes

**Cause:** A/B devices have minimal _b slots.

**Normal:** system_b, vendor_b, product_b are often empty or minimal. We only modify the _a partitions.

---

## Next Steps

After unpacking, proceed to:
- [03_MOUNTING_PARTITIONS.md](03_MOUNTING_PARTITIONS.md) - Mount partitions for editing
