# Q25 Device Process Differences

This document explains the AVB structure differences discovered on the Q25 (Xelex10_Ultra / q20_v12_factory) device and why the standard boot-only resign process required modification.

## Problem

The original `resign_boot_only.sh` script caused bootloops on this device, even when:
- The device was running pristine stock firmware
- The AVB chain verification passed
- The boot.img was valid and previously working

## Root Cause

The Q25 has a **non-standard AVB partition layout**. The original scripts assumed:

```
vbmeta.img
├── chain → boot
├── chain → vbmeta_system
│             └── hashtree: system
│             └── hashtree: product
└── chain → vbmeta_vendor
              └── hashtree: vendor
```

But the Q25 actually uses:

```
vbmeta.img
├── chain → boot
├── chain → vbmeta_system
│             └── hashtree: system (ONLY)
├── chain → vbmeta_vendor
│             └── hashtree: vendor (ONLY)
├── hash: dtbo
├── hash: vendor_boot
├── hashtree: product        ← In vbmeta.img directly!
├── hashtree: system_ext     ← In vbmeta.img directly!
├── hashtree: odm_dlkm       ← In vbmeta.img directly!
└── hashtree: vendor_dlkm    ← In vbmeta.img directly!
```

## Key Differences

| Partition | Standard Location | Q25 Location |
|-----------|------------------|--------------|
| system | vbmeta_system | vbmeta_system |
| product | vbmeta_system | **vbmeta.img** |
| system_ext | vbmeta_system | **vbmeta.img** |
| vendor | vbmeta_vendor | vbmeta_vendor |
| odm_dlkm | vbmeta_vendor | **vbmeta.img** |
| vendor_dlkm | vbmeta_vendor | **vbmeta.img** |
| dtbo | vbmeta.img | vbmeta.img |
| vendor_boot | N/A | **vbmeta.img** |

## Fix Applied

### 1. resign_boot_only.sh

Changed vbmeta_system creation to only include `system_a.img`:

```bash
# Before (incorrect for Q25):
--include_descriptors_from_image "$UNPACKED/system_a.img" \
--include_descriptors_from_image "$UNPACKED/product_a.img"

# After (correct):
--include_descriptors_from_image "$UNPACKED/system_a.img"
```

### 2. rebuild_vbmeta.sh

Added inclusion of additional partition descriptors directly in vbmeta.img:

```bash
# From stock firmware
--include_descriptors_from_image firmware/stock/dtbo.img
--include_descriptors_from_image firmware/stock/vendor_boot.img

# From unpacked super
--include_descriptors_from_image output/super_unpacked/product_a.img
--include_descriptors_from_image output/super_unpacked/system_ext_a.img
--include_descriptors_from_image output/super_unpacked/odm_dlkm_a.img
--include_descriptors_from_image output/super_unpacked/vendor_dlkm_a.img
```

## How to Identify This Layout

Check the stock vbmeta.img structure:

```bash
python3 tools/avb-tools/avbtool.py info_image --image firmware/stock/vbmeta.img
```

If you see `Hashtree descriptor` entries for partitions like `product`, `system_ext`, `odm_dlkm`, `vendor_dlkm` directly in vbmeta.img (not just chain partitions), then this device uses the Q25-style layout.

## Device Info

- **Model:** Xelex10_Ultra
- **Firmware:** q20_v12_factory
- **SoC:** MediaTek MT6789
- **Android:** 14
- **AVB Key:** AOSP testkey (cdbb77177f731920bbe0a0f94f84d9038ae0617d)
- **Bootloader:** Locked (but testkey-vulnerable)
