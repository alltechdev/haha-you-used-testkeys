# Script Reference

## Overview

All scripts are located in `/path/to/haha-you-used-testkeys/scripts/`.

| Script | Purpose |
|--------|---------|
| check_testkey.sh | Verify device uses AOSP testkey |
| unpack_super.sh | Extract partitions from super.img |
| modify_partition.sh | Mount partition for editing |
| unmount_partition.sh | Unmount partition |
| repack_super.sh | Rebuild super.img with signatures |
| resign_boot.sh | Re-sign boot.img |
| rebuild_vbmeta.sh | Rebuild vbmeta chain |
| verify_chain.sh | Verify all AVB signatures |
| cleanup.sh | Clean output directory |
| inject_file.sh | Inject single file into partition |
| extract_partition.sh | Extract files from partition |

---

## check_testkey.sh

### Purpose
Checks if a device's vbmeta.img uses the AOSP testkey (making it vulnerable to re-signing).

### Usage
```bash
./scripts/check_testkey.sh <vbmeta.img>
```

### Example
```bash
./scripts/check_testkey.sh firmware/stock/vbmeta.img
```

### Output
```
Checking firmware/stock/vbmeta.img...
Public key SHA1: cdbb77177f731920bbe0a0f94f84d9038ae0617d

VULNERABLE - Uses AOSP testkey!
You can re-sign partitions for locked bootloader.
```

### Exit Codes
- 0 = Vulnerable (AOSP testkey)
- 1 = Not vulnerable (custom keys)

---

## unpack_super.sh

### Purpose
Extracts system_a, vendor_a, and product_a partition images from super.img.

### Usage
```bash
./scripts/unpack_super.sh <super.img>
```

### Example
```bash
./scripts/unpack_super.sh firmware/stock/super.img
```

### Output Location
```
output/super_unpacked/
├── system_a.img
├── system_b.img
├── vendor_a.img
├── vendor_b.img
├── product_a.img
└── product_b.img
```

### What It Does
1. Converts sparse to raw (simg2img)
2. Extracts partitions (lpunpack)
3. Cleans up temporary files

---

## modify_partition.sh

### Purpose
Mounts an ext4 partition image for editing with user-accessible permissions.

### Usage
```bash
sudo ./scripts/modify_partition.sh <partition.img> [--resize]
```

### Options
| Option | Description |
|--------|-------------|
| `--resize` | Add 50MB to partition before mounting |

### Example
```bash
sudo ./scripts/modify_partition.sh output/super_unpacked/system_a.img --resize
```

### Mount Points
| Partition | User Mount (edit here) | Loop Mount (internal) |
|-----------|------------------------|----------------------|
| system_a | output/mnt/system_a/ | output/mnt/.system_a_loop/ |
| vendor_a | output/mnt/vendor_a/ | output/mnt/.vendor_a_loop/ |
| product_a | output/mnt/product_a/ | output/mnt/.product_a_loop/ |

### What It Does
1. Erases AVB footer
2. Resizes partition (+50MB if --resize)
3. Runs e2fsck
4. Mounts with loop device (sudo)
5. Creates bindfs overlay for user access

---

## unmount_partition.sh

### Purpose
Unmounts a partition that was mounted with modify_partition.sh.

### Usage
```bash
./scripts/unmount_partition.sh <partition_name>
```

### Example
```bash
./scripts/unmount_partition.sh system_a
./scripts/unmount_partition.sh vendor_a
./scripts/unmount_partition.sh product_a
```

### What It Does
1. Unmounts bindfs overlay
2. Unmounts loop device
3. Removes mount point directories

---

## repack_super.sh

### Purpose
Rebuilds super.img from modified partitions with proper AVB signatures.

### Usage
```bash
./scripts/repack_super.sh
```

### Prerequisites
- Partitions in output/super_unpacked/ (from unpack_super.sh)
- Partitions must be unmounted
- Scatter file in firmware/stock/

### Output Files
```
output/
├── super.img          ← Repacked super partition
├── vbmeta_system.img  ← Signed system/product hashtrees
└── vbmeta_vendor.img  ← Signed vendor hashtree
```

### What It Does
1. Reads super partition size from scatter file
2. Erases existing AVB footers
3. Adds hashtree footers to system_a, vendor_a, product_a
4. Creates vbmeta_system.img with system+product descriptors
5. Creates vbmeta_vendor.img with vendor descriptor
6. Repacks into super.img using lpmake

---

## resign_boot.sh

### Purpose
Re-signs a boot.img (stock or Magisk-patched) with our boot.pem key.

### Usage
```bash
./scripts/resign_boot.sh <boot.img> [partition_size]
```

### Arguments
| Argument | Description |
|----------|-------------|
| `boot.img` | Path to boot image to sign |
| `partition_size` | Optional, auto-detected from scatter |

### Example
```bash
# Sign Magisk-patched boot
./scripts/resign_boot.sh magisk_patched.img

# Sign stock boot (for vbmeta chain)
./scripts/resign_boot.sh firmware/stock/boot.img
```

### Output
```
output/boot.img  ← Re-signed boot image
```

### What It Does
1. Reads boot partition size from scatter file
2. Copies input to output/boot.img
3. Erases existing AVB footer
4. Adds new hash footer signed with boot.pem

---

## rebuild_vbmeta.sh

### Purpose
Rebuilds the root vbmeta.img with chain descriptors for boot, vbmeta_system, vbmeta_vendor.

### Usage
```bash
./scripts/rebuild_vbmeta.sh
```

### Prerequisites
- output/boot.img (from resign_boot.sh)
- output/vbmeta_system.img (from repack_super.sh)
- output/vbmeta_vendor.img (from repack_super.sh)

### Output
```
output/vbmeta.img  ← Root of AVB trust chain
```

### What It Does
Creates vbmeta.img containing:
- Chain descriptor for boot (key: boot.pem)
- Chain descriptor for vbmeta_system (key: vbmeta_system.pem)
- Chain descriptor for vbmeta_vendor (key: vbmeta_vendor.pem)
- Signed with AOSP testkey (vbmeta.pem)

---

## verify_chain.sh

### Purpose
Verifies that all AVB signatures are correct and the chain is complete.

### Usage
```bash
./scripts/verify_chain.sh
```

### What It Checks
1. vbmeta.img signed with AOSP testkey
2. boot.img signed with boot.pem
3. vbmeta_system.img signed with vbmeta_system.pem
4. vbmeta_vendor.img signed with vbmeta_vendor.pem
5. Chain descriptors reference correct partitions

### Exit Codes
- 0 = All checks passed
- 1+ = Number of failed checks

---

## cleanup.sh

### Purpose
Cleans output directory and unmounts any mounted partitions.

### Usage
```bash
./scripts/cleanup.sh
```

### What It Does
1. Unmounts all partitions in output/mnt/
2. Removes all files in output/
3. Recreates empty output directory

---

## inject_file.sh

### Purpose
Injects a single file into a partition without full repack.

### Usage
```bash
./scripts/inject_file.sh <partition.img> <dest_path> <source_file>
```

### Example
```bash
./scripts/inject_file.sh output/super_unpacked/system_a.img /system/build.prop modified_build.prop
```

### What It Does
1. Mounts partition temporarily
2. Copies file to destination
3. Unmounts partition

---

## extract_partition.sh

### Purpose
Extracts all files from a partition to a directory.

### Usage
```bash
./scripts/extract_partition.sh <partition.img> <output_dir>
```

### Example
```bash
./scripts/extract_partition.sh output/super_unpacked/system_a.img /tmp/system_extracted/
```

---

## Typical Workflow

### Full System Modification

```bash
# 1. Check device
./scripts/check_testkey.sh firmware/stock/vbmeta.img

# 2. Unpack
./scripts/unpack_super.sh firmware/stock/super.img

# 3. Mount
sudo ./scripts/modify_partition.sh output/super_unpacked/system_a.img --resize
sudo ./scripts/modify_partition.sh output/super_unpacked/vendor_a.img --resize
sudo ./scripts/modify_partition.sh output/super_unpacked/product_a.img --resize

# 4. Edit (no sudo needed)
rm -rf output/mnt/product_a/app/Bloatware
nano output/mnt/system_a/system/build.prop

# 5. Unmount
./scripts/unmount_partition.sh system_a
./scripts/unmount_partition.sh vendor_a
./scripts/unmount_partition.sh product_a

# 6. Repack
./scripts/repack_super.sh

# 7. Sign boot
./scripts/resign_boot.sh firmware/stock/boot.img

# 8. Build vbmeta
./scripts/rebuild_vbmeta.sh

# 9. Verify
./scripts/verify_chain.sh

# 10. Flash output files
```

### Boot Only (Magisk)

```bash
./scripts/resign_boot.sh magisk_patched.img
./scripts/rebuild_vbmeta.sh
./scripts/verify_chain.sh
# Flash boot.img and vbmeta.img
```
