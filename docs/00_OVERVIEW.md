# AVB Re-signer Overview

## What This Toolkit Does

This toolkit allows you to **modify Android partitions** (boot, system, vendor, product) and **re-sign them** so they boot with:
- **Locked bootloader**
- **Green verified boot state**

This is possible because some manufacturers ship devices with **AOSP test keys** instead of generating their own private keys. Since these test keys are publicly available, we can sign our modified partitions and the bootloader accepts them as valid.

---

## How Android Verified Boot (AVB) Works

### The Chain of Trust

```
┌─────────────────────────────────────────────────────────────────┐
│                        BOOTLOADER                                │
│                    (checks vbmeta.img)                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      vbmeta.img                                  │
│              Signed with: AOSP testkey                          │
│              SHA1: cdbb77177f731920bbe0a0f94f84d9038ae0617d     │
│                                                                  │
│   Contains chain descriptors pointing to:                       │
│   ├── boot (signed with boot.pem)                               │
│   ├── vbmeta_system (signed with vbmeta_system.pem)            │
│   └── vbmeta_vendor (signed with vbmeta_vendor.pem)            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌───────────┐  ┌─────────────┐  ┌─────────────┐
│ boot.img  │  │vbmeta_system│  │vbmeta_vendor│
│           │  │             │  │             │
│ Contains: │  │ Contains:   │  │ Contains:   │
│ - kernel  │  │ - system    │  │ - vendor    │
│ - ramdisk │  │   hashtree  │  │   hashtree  │
│           │  │ - product   │  │             │
│           │  │   hashtree  │  │             │
└───────────┘  └─────────────┘  └─────────────┘
```

### Key Concepts

1. **vbmeta.img** - The root of trust. Contains chain descriptors that point to other signed images. Signed with the device's root key (AOSP testkey in vulnerable devices).

2. **Chain Descriptors** - Tell the bootloader which key to expect for each partition. vbmeta.img says "boot partition should be signed with key SHA1 a9cc8a37..."

3. **Hashtree Footers** - Added to partition images (system, vendor, product). Contains a Merkle tree hash of the entire partition contents. Used by dm-verity to verify integrity at runtime.

4. **Hash Footers** - Simpler than hashtree. Used for boot.img. Just a hash of the entire image.

---

## Why This Works

### The Vulnerability

Manufacturers should generate unique private keys for each device model. Instead, many use the publicly available AOSP test keys:

```
AOSP testkey location: build/target/product/security/
Files: testkey.pk8, testkey.x509.pem
```

We have these keys in our `keys/` directory:
- `vbmeta.pem` - AOSP testkey (root of trust)
- `boot.pem` - Signs boot partition
- `vbmeta_system.pem` - Signs vbmeta_system (contains system/product hashtrees)
- `vbmeta_vendor.pem` - Signs vbmeta_vendor (contains vendor hashtree)

### What We Can Do

Since we have the private keys:
1. Modify any partition (system, vendor, product, boot)
2. Recalculate the hashtree/hash
3. Sign with the correct key
4. Update the chain (vbmeta_system, vbmeta_vendor, vbmeta)
5. Flash - bootloader accepts our signatures!

---

## Supported Devices

Any Android device that uses AOSP testkey for vbmeta signing.

### How to Check

```bash
./scripts/check_testkey.sh firmware/stock/vbmeta.img
```

If output shows:
```
Public key SHA1: cdbb77177f731920bbe0a0f94f84d9038ae0617d
VULNERABLE - Uses AOSP testkey!
```

The device is supported.

### Tested Devices

| Device | Chipset | Status |
|--------|---------|--------|
| M5 | MT6761 | Working |
| F21 Pro | MT6761 | Working |

---

## Directory Structure

```
m5_resigner/
├── scripts/                    # All operation scripts
│   ├── check_testkey.sh       # Verify device uses AOSP testkey
│   ├── unpack_super.sh        # Extract partitions from super.img
│   ├── modify_partition.sh    # Mount partition for editing
│   ├── unmount_partition.sh   # Unmount after editing
│   ├── repack_super.sh        # Rebuild super.img with signatures
│   ├── resign_boot.sh         # Re-sign boot.img
│   ├── rebuild_vbmeta.sh      # Rebuild vbmeta chain
│   ├── verify_chain.sh        # Verify all signatures
│   ├── cleanup.sh             # Clean output directory
│   ├── inject_file.sh         # Inject single file into partition
│   └── extract_partition.sh   # Extract files from partition
│
├── keys/                       # Signing keys
│   ├── vbmeta.pem             # AOSP testkey (root)
│   ├── boot.pem               # Boot partition key
│   ├── vbmeta_system.pem      # System/product vbmeta key
│   └── vbmeta_vendor.pem      # Vendor vbmeta key
│
├── tools/                      # Binary tools
│   ├── avb-tools/             # Google avbtool.py
│   ├── lpunpack_and_lpmake/   # Super.img pack/unpack
│   └── android-bins/          # e2fsck, resize2fs, bindfs
│
├── firmware/
│   └── stock/                 # YOUR STOCK FIRMWARE GOES HERE
│
├── output/                    # Generated files
│   ├── super_unpacked/        # Extracted partition images
│   └── mnt/                   # Mount points for editing
│
└── docs/                      # Documentation
```

---

## Workflow Overview

### Full System Modification

```
1. Copy stock firmware to firmware/stock/
                    │
                    ▼
2. ./scripts/check_testkey.sh
   (verify device is vulnerable)
                    │
                    ▼
3. ./scripts/unpack_super.sh
   (extract system_a, vendor_a, product_a)
                    │
                    ▼
4. ./scripts/modify_partition.sh --resize
   (mount partitions for editing)
                    │
                    ▼
5. Make your modifications
   (delete apps, edit configs, etc.)
                    │
                    ▼
6. ./scripts/unmount_partition.sh
   (unmount all partitions)
                    │
                    ▼
7. ./scripts/repack_super.sh
   (rebuild super.img + vbmeta_system + vbmeta_vendor)
                    │
                    ▼
8. ./scripts/rebuild_vbmeta.sh
   (rebuild root vbmeta.img)
                    │
                    ▼
9. ./scripts/verify_chain.sh
   (verify all signatures are correct)
                    │
                    ▼
10. Flash with SP Flash Tool
    (super, vbmeta, vbmeta_system, vbmeta_vendor)
```

### Boot Only (Magisk Root)

```
1. Patch boot.img with Magisk app
                    │
                    ▼
2. ./scripts/resign_boot.sh magisk_patched.img
                    │
                    ▼
3. ./scripts/rebuild_vbmeta.sh
                    │
                    ▼
4. ./scripts/verify_chain.sh
                    │
                    ▼
5. Flash boot_a + vbmeta_a
```
