# Rebuilding vbmeta.img

## Overview

`vbmeta.img` is the **root of the AVB trust chain**. It contains:

1. **Chain descriptors** pointing to:
   - boot (with expected public key)
   - vbmeta_system (with expected public key)
   - vbmeta_vendor (with expected public key)

2. **Signature** using the device's root key (AOSP testkey)

After modifying any partition, vbmeta.img must be rebuilt to update the chain.

---

## The Script: rebuild_vbmeta.sh

### Location
```
/path/to/m5_resigner/scripts/rebuild_vbmeta.sh
```

### What It Does

1. Creates vbmeta.img with chain descriptors for:
   - boot (referencing boot.pem public key)
   - vbmeta_system (referencing vbmeta_system.pem public key)
   - vbmeta_vendor (referencing vbmeta_vendor.pem public key)
2. Signs with AOSP testkey (vbmeta.pem)

### Usage

```bash
./scripts/rebuild_vbmeta.sh
```

No arguments needed.

---

## Step-by-Step Process

### Step 1: Ensure Required Files Exist

The script needs:
- `output/boot.img` - From resign_boot.sh
- `output/vbmeta_system.img` - From repack_super.sh
- `output/vbmeta_vendor.img` - From repack_super.sh

### Step 2: Run Rebuild Script

```bash
cd /path/to/m5_resigner
./scripts/rebuild_vbmeta.sh
```

### Step 3: Observe Output

```
=== Rebuilding vbmeta.img ===
Creating vbmeta.img...

vbmeta.img created:
Minimum libavb version:   1.0
Header Block:             256 bytes
Authentication Block:     320 bytes
Auxiliary Block:          2432 bytes
Public key (sha1):        cdbb77177f731920bbe0a0f94f84d9038ae0617d
Algorithm:                SHA256_RSA2048
Rollback Index:           0
Flags:                    0
Rollback Index Location:  0
Release String:           'avbtool 1.3.0'
Descriptors:
    Chain Partition descriptor:
      Partition Name:          boot
      Rollback Index Location: 3
      Public key (sha1):       a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc
      Flags:                   0
    Chain Partition descriptor:
      Partition Name:          vbmeta_system
      Rollback Index Location: 2
      Public key (sha1):       565840a78763c9a3be92604f5aef14376ee45415
    Chain Partition descriptor:
      Partition Name:          vbmeta_vendor
      Rollback Index Location: 1
      Public key (sha1):       f013c089b7f6e86cabc32f3ab24559f01b327bbf

Output: /path/to/m5_resigner/output/vbmeta.img
```

---

## What Happens Internally

### The avbtool Command

```bash
python3 tools/avb-tools/avbtool.py make_vbmeta_image \
    --output output/vbmeta.img \
    --key keys/vbmeta.pem \
    --algorithm SHA256_RSA2048 \
    --chain_partition boot:3:keys/boot.pem \
    --chain_partition vbmeta_system:2:keys/vbmeta_system.pem \
    --chain_partition vbmeta_vendor:1:keys/vbmeta_vendor.pem
```

### Parameter Breakdown

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--output` | output/vbmeta.img | Output file |
| `--key` | keys/vbmeta.pem | Signing key (AOSP testkey) |
| `--algorithm` | SHA256_RSA2048 | Signature algorithm |
| `--chain_partition` | boot:3:keys/boot.pem | Chain to boot partition |
| `--chain_partition` | vbmeta_system:2:keys/vbmeta_system.pem | Chain to vbmeta_system |
| `--chain_partition` | vbmeta_vendor:1:keys/vbmeta_vendor.pem | Chain to vbmeta_vendor |

### Chain Partition Format

```
partition_name:rollback_index_location:public_key_path
```

- **partition_name** - Name of the chained partition
- **rollback_index_location** - Slot for anti-rollback protection (we use 1, 2, 3)
- **public_key_path** - Path to the public key that signed that partition

---

## Understanding the Chain

```
┌─────────────────────────────────────────────────────────────────┐
│                        vbmeta.img                               │
│                                                                  │
│  Signed with: AOSP testkey (vbmeta.pem)                         │
│  Public key SHA1: cdbb77177f731920bbe0a0f94f84d9038ae0617d      │
│                                                                  │
│  Chain Descriptors:                                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ boot                                                         ││
│  │ Expected key: a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc      ││
│  │ → Bootloader will verify boot.img is signed with this key   ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ vbmeta_system                                                ││
│  │ Expected key: 565840a78763c9a3be92604f5aef14376ee45415      ││
│  │ → Bootloader loads vbmeta_system.img, verifies its key      ││
│  │ → vbmeta_system contains system/product hashtrees           ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ vbmeta_vendor                                                ││
│  │ Expected key: f013c089b7f6e86cabc32f3ab24559f01b327bbf      ││
│  │ → Bootloader loads vbmeta_vendor.img, verifies its key      ││
│  │ → vbmeta_vendor contains vendor hashtree                    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Output

After running:

```
output/
├── boot.img              ← From resign_boot.sh
├── super.img             ← From repack_super.sh
├── vbmeta.img            ← NEW: Root of trust
├── vbmeta_system.img     ← From repack_super.sh
└── vbmeta_vendor.img     ← From repack_super.sh
```

---

## Verifying vbmeta.img

### Check Public Key (Must Be AOSP Testkey)

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/vbmeta.img | grep "Public key"
```

**Expected:**
```
Public key (sha1):        cdbb77177f731920bbe0a0f94f84d9038ae0617d
```

This is the AOSP testkey fingerprint. The device's bootloader trusts this key.

### Check Chain Descriptors

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/vbmeta.img | grep -A3 "Chain Partition"
```

**Expected:** Three chain descriptors for boot, vbmeta_system, vbmeta_vendor.

---

## Troubleshooting

### Error: "boot.img not found"

**Cause:** resign_boot.sh wasn't run.

**Fix:**
```bash
./scripts/resign_boot.sh firmware/stock/boot.img
```

### Error: "vbmeta_system.img not found"

**Cause:** repack_super.sh wasn't run.

**Fix:**
```bash
./scripts/repack_super.sh
```

### Error: "Key file not found"

**Cause:** Keys missing from keys/ directory.

**Fix:** Verify keys exist:
```bash
ls keys/
# Should show: vbmeta.pem, boot.pem, vbmeta_system.pem, vbmeta_vendor.pem
```

### vbmeta Has Wrong Public Key

**Cause:** Wrong key file used.

**Fix:** Check keys/vbmeta.pem is the AOSP testkey:
```bash
openssl rsa -in keys/vbmeta.pem -pubout 2>/dev/null | openssl dgst -sha1
```
Should output: `cdbb77177f731920bbe0a0f94f84d9038ae0617d`

---

## Next Steps

After rebuilding vbmeta:
- [09_VERIFICATION.md](09_VERIFICATION.md) - Verify the complete AVB chain
- [10_FLASHING.md](10_FLASHING.md) - Flash to device
