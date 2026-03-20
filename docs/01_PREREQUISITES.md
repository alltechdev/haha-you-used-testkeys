# Prerequisites and Setup

## System Requirements

- Linux (tested on Ubuntu 22.04+)
- Python 3.6+
- Root access (sudo) for mounting partitions

---

## Install System Dependencies

```bash
# Required for sparse image conversion (simg2img)
sudo apt install android-sdk-libsparse-utils
```

### Verify Installation

```bash
# Check simg2img is available
which simg2img
# Expected: /usr/bin/simg2img
```

---

## Obtain Stock Firmware

You need the stock firmware for your device. This typically comes as a folder containing:

### Required Files

| File | Description |
|------|-------------|
| `MT6761_Android_scatter.txt` | Partition layout (MTK devices) |
| `super.img` | Contains system, vendor, product partitions |
| `boot.img` | Kernel and ramdisk |
| `vbmeta.img` | Root of AVB trust chain |
| `vbmeta_system.img` | System/product hashtrees |
| `vbmeta_vendor.img` | Vendor hashtree |

### Where to Get Firmware

1. **Official sources** - Manufacturer support sites
2. **Firmware databases** - Device-specific forums
3. **Extract from device** - Using SP Flash Tool readback or MTK Client

---

## Copy Firmware to Repository

```bash
# Create firmware directory if needed
mkdir -p /path/to/m5_resigner/firmware/stock

# Copy all firmware files
cp /path/to/your/firmware/* /path/to/m5_resigner/firmware/stock/
```

### Verify Firmware

```bash
cd /path/to/m5_resigner

# List firmware files
ls -la firmware/stock/

# Expected output (example):
# -rw-r--r-- 1 user user   33554432 boot.img
# -rw-r--r-- 1 user user      20043 MT6761_Android_scatter.txt
# -rw-r--r-- 1 user user 3777092920 super.img
# -rw-r--r-- 1 user user       4096 vbmeta.img
# -rw-r--r-- 1 user user       4096 vbmeta_system.img
# -rw-r--r-- 1 user user       4096 vbmeta_vendor.img
```

---

## Directory Structure After Setup

```
m5_resigner/
├── firmware/
│   └── stock/
│       ├── MT6761_Android_scatter.txt    ← Partition layout
│       ├── super.img                      ← System/vendor/product
│       ├── boot.img                       ← Kernel + ramdisk
│       ├── vbmeta.img                     ← Root vbmeta
│       ├── vbmeta_system.img              ← System vbmeta
│       ├── vbmeta_vendor.img              ← Vendor vbmeta
│       └── (other firmware files...)
├── keys/
│   ├── vbmeta.pem                         ← Already included
│   ├── boot.pem                           ← Already included
│   ├── vbmeta_system.pem                  ← Already included
│   └── vbmeta_vendor.pem                  ← Already included
├── tools/
│   ├── avb-tools/avbtool.py              ← Already included
│   ├── lpunpack_and_lpmake/binary/       ← Already included
│   └── android-bins/                      ← Already included
├── scripts/
│   └── (all scripts)                      ← Already included
└── output/
    └── (empty - will be populated)
```

---

## Verify Keys Are Present

```bash
cd /path/to/m5_resigner

# Check key fingerprints
for key in keys/*.pem; do
    echo "=== $key ==="
    openssl rsa -in "$key" -pubout 2>/dev/null | openssl dgst -sha1 | awk '{print $2}'
done
```

### Expected Key Fingerprints

| Key File | SHA1 Fingerprint | Note |
|----------|------------------|------|
| vbmeta.pem | cdbb77177f731920bbe0a0f94f84d9038ae0617d | **Must be AOSP testkey** |
| boot.pem | a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc | Toolkit default (can be any RSA2048) |
| vbmeta_system.pem | 565840a78763c9a3be92604f5aef14376ee45415 | Toolkit default (can be any RSA2048) |
| vbmeta_vendor.pem | f013c089b7f6e86cabc32f3ab24559f01b327bbf | Toolkit default (can be any RSA2048) |

> Only `vbmeta.pem` must match the AOSP testkey. The other keys are arbitrary - the toolkit rebuilds the entire AVB chain, so they don't need to match the original firmware or any specific fingerprint.

---

## Verify Tools Are Present

```bash
cd /path/to/m5_resigner

# Check avbtool
python3 tools/avb-tools/avbtool.py version
# Expected: avbtool 1.3.0

# Check lpunpack
ls -la tools/lpunpack_and_lpmake/binary/
# Expected: lpunpack, lpmake

# Check android-bins
ls -la tools/android-bins/
# Expected: e2fsck, resize2fs, bindfs
```

---

## Enable FUSE user_allow_other (Required for Mount)

The mount script uses `bindfs` to make mounted files accessible without sudo. This requires enabling `user_allow_other` in FUSE config:

```bash
# Check current config
cat /etc/fuse.conf

# If user_allow_other is commented out or missing, enable it:
sudo sh -c 'grep -q "^user_allow_other" /etc/fuse.conf || echo "user_allow_other" >> /etc/fuse.conf'

# Verify
grep "user_allow_other" /etc/fuse.conf
# Expected: user_allow_other (uncommented)
```

---

## Test Setup

Run the testkey check on your firmware:

```bash
cd /path/to/m5_resigner
./scripts/check_testkey.sh firmware/stock/vbmeta.img
```

### Expected Output (Vulnerable Device)

```
Checking firmware/stock/vbmeta.img...
Public key SHA1: cdbb77177f731920bbe0a0f94f84d9038ae0617d

VULNERABLE - Uses AOSP testkey!
You can re-sign partitions for locked bootloader.
```

### If NOT Vulnerable

```
Checking firmware/stock/vbmeta.img...
Public key SHA1: [different hash]

NOT VULNERABLE - Uses custom keys.
Cannot re-sign partitions without manufacturer's private key.
```

If your device shows NOT VULNERABLE, this toolkit cannot help - the manufacturer used their own keys.

---

## Ready to Proceed

Once you see "VULNERABLE - Uses AOSP testkey!", proceed to:
- [02_UNPACKING_SUPER.md](02_UNPACKING_SUPER.md) - Extract partitions
- [06_ROOTING_BOOT.md](06_ROOTING_BOOT.md) - Root with Magisk
