# Flashing to Device

## Overview

After creating and verifying all images, flash them to the device using **SP Flash Tool** (for MediaTek devices).

---

## Output Files to Flash

After running all scripts, you have these files in `output/`:

| File | Description | Flash To |
|------|-------------|----------|
| boot.img | Kernel + ramdisk | boot_a |
| super.img | System/vendor/product partitions | super |
| vbmeta.img | Root of trust | vbmeta_a |
| vbmeta_system.img | System/product hashtrees | vbmeta_system_a |
| vbmeta_vendor.img | Vendor hashtree | vbmeta_vendor_a |

---

## What to Flash (Based on Modifications)

| Modification | Flash These Files |
|--------------|------------------|
| Boot only (Magisk root) | boot.img, vbmeta.img, vbmeta_system.img, vbmeta_vendor.img |
| System/Vendor/Product only | super.img, vbmeta.img, vbmeta_system.img, vbmeta_vendor.img |
| Boot + System (full) | boot.img, super.img, vbmeta.img, vbmeta_system.img, vbmeta_vendor.img |

---

## SP Flash Tool (MediaTek)

### Step 1: Copy Output Files to Firmware Directory

```bash
cd /path/to/haha-you-used-testkeys

# Copy re-signed images to stock firmware folder
cp output/boot.img firmware/stock/
cp output/super.img firmware/stock/
cp output/vbmeta.img firmware/stock/
cp output/vbmeta_system.img firmware/stock/
cp output/vbmeta_vendor.img firmware/stock/
```

### Step 2: Open SP Flash Tool

```bash
# Linux
./flash_tool

# Or Windows
flash_tool.exe
```

### Step 3: Load Scatter File

1. Click **"Choose"** next to Scatter-loading File
2. Navigate to `firmware/stock/`
3. Select `MT6761_Android_scatter.txt` (or your device's scatter file)

### Step 4: Select Partitions to Flash

1. Click the checkbox column to **uncheck ALL** partitions
2. Check ONLY the partitions you need to flash:

For boot + vbmeta:
- [x] boot_a
- [x] vbmeta_a

For full system:
- [x] super
- [x] vbmeta_a
- [x] vbmeta_system_a
- [x] vbmeta_vendor_a

For everything:
- [x] boot_a
- [x] super
- [x] vbmeta_a
- [x] vbmeta_system_a
- [x] vbmeta_vendor_a

### Step 5: Verify Image Paths

For each checked partition, verify the **Location** column shows your modified image:

```
boot_a        → firmware/stock/boot.img (your modified one)
super         → firmware/stock/super.img
vbmeta_a      → firmware/stock/vbmeta.img
vbmeta_system_a → firmware/stock/vbmeta_system.img
vbmeta_vendor_a → firmware/stock/vbmeta_vendor.img
```

### Step 6: Set Download Mode

- Select **"Download Only"** (not Format All + Download)

### Step 7: Flash

1. Click **"Download"** button
2. A popup appears: "Waiting for USB device"
3. Connect device in BROM mode (method varies by device):
   - Device must be OFF before connecting
   - Common methods: Hold Vol+, Vol-, or no button while inserting USB
   - Consult your device's documentation for BROM entry
4. Wait for flashing to complete
5. Green checkmark = Success

### Step 8: Reboot

Disconnect USB and power on device normally.

---

## Post-Flash Verification

### Check Boot State

After device boots:

```bash
adb shell getprop ro.boot.vbmeta.device_state
```

**Expected:** `locked`

### Check Verified Boot State

```bash
adb shell getprop ro.boot.verifiedbootstate
```

**Expected:** `green`

### Check Root (If Magisk Installed)

```bash
adb shell su -c id
```

**Expected:** `uid=0(root) gid=0(root)`

### Full Verification

```bash
adb shell "echo '=== Device Status ===' && \
    echo 'Bootloader:' \$(getprop ro.boot.vbmeta.device_state) && \
    echo 'Verified Boot:' \$(getprop ro.boot.verifiedbootstate) && \
    echo 'Build:' \$(getprop ro.build.display.id)"
```

**Expected Output:**
```
=== Device Status ===
Bootloader: locked
Verified Boot: green
Build: [your build ID]
```

---

## Troubleshooting Flash Issues

### SP Flash Tool: "BROM ERROR"

**Cause:** Device not entering BROM mode correctly.

**Fix:**
1. Ensure device is completely OFF
2. Try holding Vol Up or Vol Down while inserting USB (device-specific)
3. Try different USB port/cable
4. Some devices enter BROM with no button held - just insert USB while off

### SP Flash Tool: "PMT changed"

**Cause:** Partition layout changed.

**Fix:** This is usually OK for super/vbmeta. Click "Yes" to continue.

### SP Flash Tool: "Signature error"

**Cause:** Image doesn't match scatter expectations.

**Fix:** Ensure you're using the ORIGINAL scatter file from your firmware.

### Device Doesn't Boot After Flash

**Symptoms:**
- Stuck on boot logo
- Boot loop
- Shows "Android" then restarts

**Diagnosis:**
1. Check if boot screen shows verification state
2. Yellow/orange = AVB verification failed

**Fix:**
1. Re-flash stock vbmeta.img first
2. Verify chain with verify_chain.sh
3. Re-run the full process

### Yellow/Orange Boot Warning

**Cause:** AVB verification failed. Either:
- vbmeta.img not flashed
- Wrong keys used
- Chain mismatch

**Fix:**
1. Flash vbmeta_a with your output/vbmeta.img
2. Ensure all vbmeta_* images are your signed versions
3. Run verify_chain.sh before flashing

### dm-verity Error on Boot

**Cause:** Hashtree mismatch. Partition was modified after hashtree was calculated.

**Fix:**
1. Don't modify partitions after running repack_super.sh
2. If needed, re-run the full repack process

---

## Best Practices

### 1. Backup First

Before flashing, backup your current firmware using SP Flash Tool readback.

### 2. Use Original Scatter

Always use the scatter file from your ORIGINAL stock firmware, not a modified one.

### 3. Flash Incrementally

For first-time setup:
1. Flash boot + vbmeta first
2. Verify device boots with locked/green
3. Then flash super + vbmeta_system + vbmeta_vendor
4. Verify again

### 4. Verify Before Flash

Always run verify_chain.sh before flashing. Never flash with errors.

---

## Next Steps

- [11_TROUBLESHOOTING.md](11_TROUBLESHOOTING.md) - Detailed troubleshooting guide
