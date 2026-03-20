# AVB Re-signer

Re-sign Android partitions for devices using AOSP testkey. Enables modifications while maintaining **locked bootloader** and **green verified boot**.

## Supported Devices

Any Android device that uses AOSP testkey (SHA1: `cdbb77177f731920bbe0a0f94f84d9038ae0617d`) for vbmeta signing.

**Tested:**
- Tiq Mini M5 (MT6761)
- Qin F21 Pro (MT6761)

**Untested (confirmed AOSP testkey):**
- Zinwa Q25
- Doov R77 (NC)

## How It Works

Some manufacturers ship devices with AOSP test keys instead of generating their own. Since the AOSP testkey is public, we can rebuild the entire AVB chain and the bootloader accepts it as valid.

```
Bootloader trusts AOSP testkey
         ↓
vbmeta.img (signed with AOSP testkey)
         ↓
chains to our own keys for boot/vbmeta_system/vbmeta_vendor
         ↓
All partitions signed with our keys
```

The toolkit **rebuilds the entire chain** - it doesn't need the device's original chain keys. Only `vbmeta.pem` must be the AOSP testkey (which the bootloader trusts). The other keys (`boot.pem`, `vbmeta_system.pem`, `vbmeta_vendor.pem`) are toolkit-generated and can be any valid RSA2048 keys.

## Prerequisites

```bash
sudo apt install android-sdk-libsparse-utils
```

## Setup

1. Copy your device's stock firmware to `firmware/stock/`:

```bash
mkdir -p firmware/stock
cp /path/to/your/firmware/* firmware/stock/
```

Required files from stock firmware:
- `MT6761_Android_scatter.txt` (or similar scatter file)
- `super.img`
- `boot.img`
- `vbmeta.img`
- `vbmeta_system.img`
- `vbmeta_vendor.img`

## Interactive TUI

For a guided experience, run the interactive TUI:

```bash
./resigner-tui.sh
```

## Quick Start

### 1. Check Device Vulnerability

```bash
./scripts/check_testkey.sh firmware/stock/vbmeta.img
```

### 2. Root with Magisk

```bash
# Patch boot.img with Magisk app, then re-sign:
./scripts/resign_boot.sh magisk_patched.img
./scripts/rebuild_vbmeta.sh

# Flash boot_a and vbmeta_a using SP Flash Tool
```

### 3. Re-sign Existing ROM

Already have a modified ROM? Re-sign it for locked bootloader:

```bash
# 1. Copy stock firmware (for scatter file and testkey)
cp -r /path/to/stock/firmware/* firmware/stock/

# 2. Copy custom ROM
cp /path/to/modified/super.img firmware/custom/
cp /path/to/modified/boot.img firmware/custom/  # optional

# 3. Run re-sign
./scripts/resign_existing_rom.sh
```

This automatically:
- Unpacks the modified super.img
- Shrinks partitions if they exceed device limit (using resize2fs -M)
- Adds AVB hashtrees and signs everything
- Verifies the chain

### 4. Modify System/Vendor/Product

```bash
# Unpack super.img
./scripts/unpack_super.sh firmware/stock/super.img

# Mount partitions for editing (no sudo needed for edits!)
./scripts/modify_partition.sh output/super_unpacked/system_a.img --resize
./scripts/modify_partition.sh output/super_unpacked/vendor_a.img --resize
./scripts/modify_partition.sh output/super_unpacked/product_a.img --resize

# Make changes (no sudo needed)
nano output/mnt/system_a/system/build.prop
rm -rf output/mnt/system_a/system/app/Bloatware

# Unmount all
./scripts/unmount_partition.sh system_a
./scripts/unmount_partition.sh vendor_a
./scripts/unmount_partition.sh product_a

# Repack with new signatures
./scripts/repack_super.sh
./scripts/rebuild_vbmeta.sh
```

## Scripts

| Script | Description |
|--------|-------------|
| `check_testkey.sh` | Verify device uses AOSP testkey |
| `unpack_super.sh` | Extract partitions from super.img (lpunpack) |
| `modify_partition.sh` | Mount partition for modification (bindfs, no sudo for edits) |
| `unmount_partition.sh` | Unmount partition after modifications |
| `inject_file.sh` | Inject single file into partition |
| `extract_partition.sh` | Copy all files from partition |
| `repack_super.sh` | Rebuild super.img with hashtrees (lpmake) |
| `resign_boot.sh` | Re-sign boot.img |
| `rebuild_vbmeta.sh` | Rebuild vbmeta chain |
| `verify_chain.sh` | Verify AVB signature chain |
| `resign_existing_rom.sh` | Re-sign an already modified ROM (auto-shrinks if needed) |
| `cleanup.sh` | Clean output directory and unmount partitions |

## Directory Structure

```
m5_resigner/
├── scripts/           # All operation scripts
├── keys/              # Signing keys (AOSP testkey + toolkit-generated)
├── tools/
│   ├── avb-tools/     # Google avbtool
│   ├── lpunpack_and_lpmake/  # Super.img tools
│   └── android-bins/  # e2fsck, resize2fs, bindfs, etc.
├── firmware/
│   ├── stock/         # Stock firmware (scatter, vbmeta, boot)
│   └── custom/        # Custom ROM to re-sign (super.img, boot.img)
├── output/            # Re-signed output files
│   ├── super_unpacked/  # Extracted partitions
│   └── mnt/           # Mount points for editing
└── docs/              # Additional documentation
```

## Output Files

After running scripts, flash these:

| Modification | Flash These |
|--------------|-------------|
| Boot only (Magisk) | boot.img, vbmeta.img |
| System only | super.img, vbmeta_system.img |
| Vendor only | super.img, vbmeta_vendor.img |
| Full | boot.img, super.img, vbmeta.img, vbmeta_system.img, vbmeta_vendor.img |

## Verification

```bash
adb shell getprop ro.boot.vbmeta.device_state
# Expected: locked

adb shell getprop ro.boot.verifiedbootstate
# Expected: green

adb shell su -c id
# Expected: uid=0(root)
```

## Key Fingerprints

| Key | SHA1 | Source |
|-----|------|--------|
| vbmeta.pem | cdbb77177f731920bbe0a0f94f84d9038ae0617d | **AOSP testkey** (required) |
| boot.pem | a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc | Toolkit-generated |
| vbmeta_system.pem | 565840a78763c9a3be92604f5aef14376ee45415 | Toolkit-generated |
| vbmeta_vendor.pem | f013c089b7f6e86cabc32f3ab24559f01b327bbf | Toolkit-generated |

> **Note:** Only `vbmeta.pem` must match the AOSP testkey. The other keys are arbitrary - the toolkit rebuilds the entire AVB chain using these keys, so they don't need to match the original firmware. You can generate your own keys with:
> ```bash
> openssl genrsa -out boot.pem 2048
> openssl genrsa -out vbmeta_system.pem 2048
> openssl genrsa -out vbmeta_vendor.pem 2048
> ```

## Flashing

**SP Flash Tool (MTK):**

Use the **original firmware's scatter file** - only replace the image files.

```bash
# Copy re-signed images to stock firmware folder
cp output/boot.img firmware/stock/
cp output/super.img firmware/stock/
cp output/vbmeta.img firmware/stock/
cp output/vbmeta_system.img firmware/stock/
cp output/vbmeta_vendor.img firmware/stock/
```

Then in SP Flash Tool:
1. Load `firmware/stock/MT6761_Android_scatter.txt`
2. Select partitions to flash (boot_a, super, vbmeta_a, etc.)
3. Download
4. After flashing, do a factory reset from recovery

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Yellow/orange boot | vbmeta not flashed or wrong key |
| dm-verity error | Rerun repack_super.sh |
| Boot loop | Factory reset required after system changes |
| "NOT VULNERABLE" | Device uses custom keys, cannot re-sign |

## Documentation

See [docs/](docs/) for detailed guides:

- [Overview](docs/00_OVERVIEW.md) - How AVB works, why this toolkit exists
- [Prerequisites](docs/01_PREREQUISITES.md) - Setup and requirements
- [Unpacking Super](docs/02_UNPACKING_SUPER.md) - Extract partitions
- [Mounting Partitions](docs/03_MOUNTING_PARTITIONS.md) - Mount for editing
- [Modifying Partitions](docs/04_MODIFYING_PARTITIONS.md) - Common modifications
- [Unmounting Partitions](docs/05_UNMOUNTING_PARTITIONS.md) - Unmount process
- [Repacking Super](docs/06_REPACKING_SUPER.md) - Rebuild with signatures
- [Signing Boot](docs/07_SIGNING_BOOT.md) - Magisk root workflow
- [Rebuilding vbmeta](docs/08_REBUILDING_VBMETA.md) - Chain descriptor creation
- [Verification](docs/09_VERIFICATION.md) - Verify signatures
- [Flashing](docs/10_FLASHING.md) - SP Flash Tool guide
- [Troubleshooting](docs/11_TROUBLESHOOTING.md) - Common issues
- [Script Reference](docs/12_SCRIPT_REFERENCE.md) - All scripts with usage
- [Re-sign Existing ROM](docs/13_RESIGN_EXISTING_ROM.md) - Convert unlocked ROM to locked
