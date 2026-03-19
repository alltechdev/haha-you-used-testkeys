# AVB Re-signer Documentation

Complete guide for re-signing Android partitions on devices using AOSP testkey.

## Quick Start

1. [Prerequisites](01_PREREQUISITES.md) - Install dependencies, copy firmware
2. Run `./scripts/check_testkey.sh firmware/stock/vbmeta.img` - Verify device is vulnerable
3. Follow [Full Workflow](#full-workflow) below

---

## Documentation Index

| Doc | Description |
|-----|-------------|
| [00_OVERVIEW.md](00_OVERVIEW.md) | How AVB works, why this toolkit exists |
| [01_PREREQUISITES.md](01_PREREQUISITES.md) | System requirements, setup, firmware |
| [02_UNPACKING_SUPER.md](02_UNPACKING_SUPER.md) | Extract partitions from super.img |
| [03_MOUNTING_PARTITIONS.md](03_MOUNTING_PARTITIONS.md) | Mount partitions for editing |
| [04_MODIFYING_PARTITIONS.md](04_MODIFYING_PARTITIONS.md) | Common modifications (remove apps, edit configs) |
| [05_UNMOUNTING_PARTITIONS.md](05_UNMOUNTING_PARTITIONS.md) | Unmount before repacking |
| [06_REPACKING_SUPER.md](06_REPACKING_SUPER.md) | Rebuild super.img with signatures |
| [07_SIGNING_BOOT.md](07_SIGNING_BOOT.md) | Re-sign boot.img (Magisk root) |
| [08_REBUILDING_VBMETA.md](08_REBUILDING_VBMETA.md) | Rebuild root vbmeta chain |
| [09_VERIFICATION.md](09_VERIFICATION.md) | Verify all signatures |
| [10_FLASHING.md](10_FLASHING.md) | Flash with SP Flash Tool |
| [11_TROUBLESHOOTING.md](11_TROUBLESHOOTING.md) | Common issues and fixes |
| [12_SCRIPT_REFERENCE.md](12_SCRIPT_REFERENCE.md) | All scripts with usage |
| [13_RESIGN_EXISTING_ROM.md](13_RESIGN_EXISTING_ROM.md) | Re-sign an already modified ROM |

---

## Full Workflow

### Modify System/Vendor/Product

```bash
# 1. Check vulnerability
./scripts/check_testkey.sh firmware/stock/vbmeta.img

# 2. Unpack super.img
./scripts/unpack_super.sh firmware/stock/super.img

# 3. Mount partitions for editing
sudo ./scripts/modify_partition.sh output/super_unpacked/system_a.img --resize
sudo ./scripts/modify_partition.sh output/super_unpacked/vendor_a.img --resize
sudo ./scripts/modify_partition.sh output/super_unpacked/product_a.img --resize

# 4. Make modifications (no sudo needed)
rm -rf output/mnt/product_a/app/Bloatware
nano output/mnt/system_a/system/build.prop

# 5. Unmount
./scripts/unmount_partition.sh system_a
./scripts/unmount_partition.sh vendor_a
./scripts/unmount_partition.sh product_a

# 6. Repack with signatures
./scripts/repack_super.sh
./scripts/resign_boot.sh firmware/stock/boot.img
./scripts/rebuild_vbmeta.sh

# 7. Verify
./scripts/verify_chain.sh

# 8. Copy to firmware folder and flash
cp output/*.img firmware/stock/
# Use SP Flash Tool with original scatter file
```

### Root with Magisk

```bash
# 1. Patch boot.img with Magisk app
adb push firmware/stock/boot.img /sdcard/
# Use Magisk app to patch
adb pull /sdcard/Download/magisk_patched_*.img magisk_patched.img

# 2. Re-sign
./scripts/resign_boot.sh magisk_patched.img
./scripts/rebuild_vbmeta.sh

# 3. Verify
./scripts/verify_chain.sh

# 4. Flash boot_a and vbmeta_a
```

---

## Key Fingerprints

| Key | SHA1 | Purpose |
|-----|------|---------|
| vbmeta.pem | cdbb77177f731920bbe0a0f94f84d9038ae0617d | Root of trust (AOSP testkey) |
| boot.pem | a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc | Signs boot partition |
| vbmeta_system.pem | 565840a78763c9a3be92604f5aef14376ee45415 | Signs system/product vbmeta |
| vbmeta_vendor.pem | f013c089b7f6e86cabc32f3ab24559f01b327bbf | Signs vendor vbmeta |

---

## Directory Structure

```
m5_resigner/
├── scripts/           # Operation scripts
├── keys/              # Signing keys (AOSP testkey + derived)
├── tools/             # avbtool, lpunpack, lpmake, e2fsck, etc.
├── firmware/
│   ├── stock/         # Stock firmware (scatter, vbmeta, boot)
│   └── custom/        # Custom ROM to re-sign (super.img, boot.img)
├── output/            # Generated files (super.img, vbmeta.img, etc.)
└── docs/              # This documentation
```

---

## Output Files

| File | Flash To | When |
|------|----------|------|
| boot.img | boot_a | Modified boot (Magisk) |
| super.img | super | Modified system/vendor/product |
| vbmeta.img | vbmeta_a | Always (root of chain) |
| vbmeta_system.img | vbmeta_system_a | Modified system or product |
| vbmeta_vendor.img | vbmeta_vendor_a | Modified vendor |

---

## Verified Boot States

After flashing correctly:

```bash
adb shell getprop ro.boot.vbmeta.device_state
# Expected: locked

adb shell getprop ro.boot.verifiedbootstate
# Expected: green
```

- **locked + green** = Success! Device boots with locked bootloader and verified boot.
- **unlocked + yellow** = Bootloader was unlocked (not our method)
- **locked + orange** = AVB verification failed (something is wrong)
