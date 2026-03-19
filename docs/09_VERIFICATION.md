# Verifying the AVB Chain

## Overview

Before flashing, verify that all signatures are correct and the chain is complete. The `verify_chain.sh` script checks:

1. vbmeta.img is signed with AOSP testkey
2. boot.img is signed with boot.pem
3. vbmeta_system.img is signed with vbmeta_system.pem
4. vbmeta_vendor.img is signed with vbmeta_vendor.pem
5. Chain descriptors point to correct partitions

---

## The Script: verify_chain.sh

### Location
```
/path/to/m5_resigner/scripts/verify_chain.sh
```

### What It Does

1. Extracts public key SHA1 from each image
2. Compares against expected key fingerprints
3. Displays chain relationships
4. Reports pass/fail for each check

### Usage

```bash
./scripts/verify_chain.sh
```

---

## Step-by-Step Process

### Run Verification

```bash
cd /path/to/m5_resigner
./scripts/verify_chain.sh
```

### Expected Output (All Passing)

```
=== AVB Chain Verification ===

Checking vbmeta.img (root of trust)...
  OK: AOSP testkey (cdbb77177f731920bbe0a0f94f84d9038ae0617d)

Checking boot.img...
  OK: boot.pem (a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc)

Checking vbmeta_system.img...
  OK: vbmeta_system.pem (565840a78763c9a3be92604f5aef14376ee45415)

Checking vbmeta_vendor.img...
  OK: vbmeta_vendor.pem (f013c089b7f6e86cabc32f3ab24559f01b327bbf)

=== Chain Descriptors ===

vbmeta.img chains to:
  - boot
  - vbmeta_system
  - vbmeta_vendor

vbmeta_system.img contains hashtrees for:
  - system
  - product

vbmeta_vendor.img contains hashtrees for:
  - vendor

=== ALL CHECKS PASSED ===
```

---

## Understanding the Output

### Key Verification

Each image's public key SHA1 is compared against expected values:

| Image | Expected Key SHA1 | Key Name |
|-------|------------------|----------|
| vbmeta.img | cdbb77177f731920bbe0a0f94f84d9038ae0617d | AOSP testkey |
| boot.img | a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc | boot.pem |
| vbmeta_system.img | 565840a78763c9a3be92604f5aef14376ee45415 | vbmeta_system.pem |
| vbmeta_vendor.img | f013c089b7f6e86cabc32f3ab24559f01b327bbf | vbmeta_vendor.pem |

### Chain Verification

The script also verifies:

1. **vbmeta.img → boot, vbmeta_system, vbmeta_vendor**
   - vbmeta contains chain descriptors pointing to these three partitions
   - Each descriptor includes the expected public key for that partition

2. **vbmeta_system.img → system, product**
   - Contains hashtree descriptors for system and product partitions
   - These hashtrees are verified by dm-verity at runtime

3. **vbmeta_vendor.img → vendor**
   - Contains hashtree descriptor for vendor partition

---

## Visualizing the Verified Chain

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVICE BOOTLOADER                            │
│              Trusts: AOSP testkey (hardcoded)                   │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Verifies signature
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      vbmeta.img                                 │
│  Signed with: AOSP testkey ✓                                    │
│  Contains chains to: boot, vbmeta_system, vbmeta_vendor        │
└───────┬───────────────────┬─────────────────────┬───────────────┘
        │                   │                     │
        ▼                   ▼                     ▼
┌───────────────┐  ┌────────────────┐  ┌─────────────────┐
│   boot.img    │  │ vbmeta_system  │  │ vbmeta_vendor   │
│ Key: boot.pem │  │ Key: vbmeta_   │  │ Key: vbmeta_    │
│      ✓        │  │ system.pem ✓   │  │ vendor.pem ✓    │
└───────────────┘  └───────┬────────┘  └────────┬────────┘
                           │                    │
              ┌────────────┴────────┐           │
              ▼                     ▼           ▼
       ┌────────────┐        ┌───────────┐ ┌──────────┐
       │ system_a   │        │ product_a │ │ vendor_a │
       │ (hashtree) │        │ (hashtree)│ │(hashtree)│
       │     ✓      │        │    ✓      │ │    ✓     │
       └────────────┘        └───────────┘ └──────────┘
```

---

## Common Failures

### FAIL: vbmeta.img Key Mismatch

```
Checking vbmeta.img (root of trust)...
  FAIL: AOSP testkey
        Expected: cdbb77177f731920bbe0a0f94f84d9038ae0617d
        Got:      1234567890abcdef...
```

**Cause:** Wrong key used to sign vbmeta.img

**Fix:** Ensure keys/vbmeta.pem is the correct AOSP testkey

### FAIL: boot.img Key Mismatch

```
Checking boot.img...
  FAIL: boot.pem
        Expected: a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc
        Got:      (different hash)
```

**Cause:** boot.img signed with wrong key

**Fix:** Re-run resign_boot.sh with correct key

### MISSING: File Not Found

```
Checking boot.img...
  MISSING: output/boot.img
```

**Cause:** resign_boot.sh wasn't run

**Fix:** Run the missing script:
```bash
./scripts/resign_boot.sh firmware/stock/boot.img
```

---

## Manual Verification

### Check Individual Image

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/vbmeta.img
```

### Extract Just the Key Hash

```bash
python3 tools/avb-tools/avbtool.py info_image --image output/boot.img 2>/dev/null | grep "Public key (sha1):"
```

### Compare Keys to Files

```bash
# Get hash from key file
openssl rsa -in keys/boot.pem -pubout 2>/dev/null | openssl dgst -sha1

# Get hash from signed image
python3 tools/avb-tools/avbtool.py info_image --image output/boot.img | grep "Public key"

# They should match!
```

---

## What If Verification Fails?

### 1. Identify Which Image Failed

Look at the script output to see which check failed.

### 2. Re-run the Appropriate Script

| Failed Image | Re-run Script |
|--------------|---------------|
| vbmeta.img | rebuild_vbmeta.sh |
| boot.img | resign_boot.sh |
| vbmeta_system.img | repack_super.sh |
| vbmeta_vendor.img | repack_super.sh |

### 3. Verify Again

```bash
./scripts/verify_chain.sh
```

### 4. Check Keys Are Correct

If verification keeps failing, verify your keys:

```bash
for key in keys/*.pem; do
    echo "=== $key ==="
    openssl rsa -in "$key" -pubout 2>/dev/null | openssl dgst -sha1
done
```

---

## Important: Don't Flash Without Verification

**If verify_chain.sh shows ANY errors, DO NOT FLASH.**

Flashing with an incorrect chain will result in:
- Boot failure
- Yellow/orange verified boot state
- dm-verity errors
- Potential soft-brick

Always see `=== ALL CHECKS PASSED ===` before proceeding.

---

## Next Steps

After verification passes:
- [10_FLASHING.md](10_FLASHING.md) - Flash to device with SP Flash Tool
