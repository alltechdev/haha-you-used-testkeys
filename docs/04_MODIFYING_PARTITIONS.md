# Modifying Partition Contents

## Overview

With partitions mounted at `output/mnt/`, you can make modifications **without sudo**. The bindfs overlay handles permission mapping.

---

## Mount Points

| Partition | Mount Point | Contains |
|-----------|-------------|----------|
| system_a | `output/mnt/system_a/` | Android system, framework, system apps |
| vendor_a | `output/mnt/vendor_a/` | Hardware drivers, vendor apps |
| product_a | `output/mnt/product_a/` | OEM apps, customizations |

---

## Common Modifications

### 1. Remove Bloatware Apps

#### Find the App

```bash
# Search in all partitions
find output/mnt/*/app output/mnt/*/priv-app -name "*AppName*" 2>/dev/null

# List all product apps (common bloatware location)
ls output/mnt/product_a/app/
ls output/mnt/product_a/priv-app/
```

#### Delete the App

```bash
# Remove from product partition
rm -rf output/mnt/product_a/app/Facebook
rm -rf output/mnt/product_a/app/TikTok
rm -rf output/mnt/product_a/priv-app/GMS  # Example

# Remove from system partition
rm -rf output/mnt/system_a/system/app/Browser
rm -rf output/mnt/system_a/system/priv-app/SetupWizard
```

#### Common Bloatware Locations

```
output/mnt/product_a/app/
├── com.google.mainline.telemetry    ← Google telemetry
├── com.google.mainline.adservices   ← Ad services
├── GoogleLocationHistory            ← Location tracking
├── Maps                             ← If you don't need maps
└── ...

output/mnt/system_a/system/app/
├── Browser                          ← Stock browser
├── Email                            ← Stock email
└── ...
```

---

### 2. Add Custom Apps

#### Create App Directory

```bash
mkdir -p output/mnt/system_a/system/app/MyApp
```

#### Copy APK

```bash
cp /path/to/MyApp.apk output/mnt/system_a/system/app/MyApp/
```

#### Set Permissions (Important!)

```bash
chmod 644 output/mnt/system_a/system/app/MyApp/MyApp.apk
```

**Note:** On mounted filesystem, permissions are handled by bindfs. The actual permissions will be set correctly when repacking.

#### For Privileged Apps

```bash
mkdir -p output/mnt/system_a/system/priv-app/MyPrivApp
cp MyPrivApp.apk output/mnt/system_a/system/priv-app/MyPrivApp/
chmod 644 output/mnt/system_a/system/priv-app/MyPrivApp/MyPrivApp.apk
```

---

### 3. Modify Build Properties

#### Edit System Build.prop

```bash
nano output/mnt/system_a/system/build.prop
```

#### Common Modifications

```properties
# Change device name
ro.product.model=Custom Device

# Change fingerprint (may help with app compatibility)
ro.build.fingerprint=google/walleye/walleye:8.1.0/OPM1.171019.011:user/release-keys

# Enable ADB by default
persist.sys.usb.config=mtp,adb

# Disable logging
logcat.live=disable
```

#### Edit Vendor Build.prop

```bash
nano output/mnt/vendor_a/build.prop
```

---

### 4. Replace System Files

#### Replace a Configuration File

```bash
cp my_custom_config.xml output/mnt/system_a/system/etc/permissions/
```

#### Replace Framework Files

```bash
cp modified_services.jar output/mnt/system_a/system/framework/
```

**Warning:** Modifying framework files can cause bootloops. Test carefully!

---

### 5. Modify Permissions

#### Add Custom Permissions

```bash
nano output/mnt/system_a/system/etc/permissions/custom-permissions.xml
```

Example content:
```xml
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <privapp-permissions package="com.my.app">
        <permission name="android.permission.WRITE_SECURE_SETTINGS"/>
    </privapp-permissions>
</permissions>
```

---

### 6. Disable Components

#### Disable an App Without Removing

Create an overlay to disable:

```bash
mkdir -p output/mnt/product_a/overlay/DisableBloat
```

---

## Verification Before Unmounting

### Check Changes Were Applied

```bash
# Verify file was deleted
ls output/mnt/product_a/app/ | grep -i telemetry
# Should return nothing if deleted

# Verify file was added
ls output/mnt/system_a/system/app/MyApp/
# Should show your APK

# Verify build.prop was modified
grep "your_modification" output/mnt/system_a/system/build.prop
```

### Check Disk Usage

```bash
df -h output/mnt/system_a
df -h output/mnt/vendor_a
df -h output/mnt/product_a
```

**Important:** If any partition shows 100% usage, you need to remove more files or resize larger.

---

## What NOT to Modify

### Critical Files (Will Cause Bootloop)

- `/system/bin/init` - Init binary
- `/system/etc/selinux/` - SELinux policies (unless you know what you're doing)
- `/vendor/etc/fstab.*` - Filesystem mount table
- `/system/framework/framework.jar` - Core framework (risky)

### Files That Will Be Regenerated

- `/system/etc/hosts` - Often regenerated on boot
- Cache directories
- Dalvik cache (regenerated on first boot)

---

## Tips

### 1. Make Incremental Changes

Don't change everything at once. Make one change, test boot, then make more changes.

### 2. Keep a Log

```bash
# Before modifications
ls -la output/mnt/product_a/app/ > before_mods.txt

# After modifications
ls -la output/mnt/product_a/app/ > after_mods.txt

# See what changed
diff before_mods.txt after_mods.txt
```

### 3. Backup Original Files

```bash
# Before modifying build.prop
cp output/mnt/system_a/system/build.prop output/mnt/system_a/system/build.prop.bak
```

### 4. Test on Emulator First (if possible)

If your changes are portable, test on an Android emulator before flashing to device.

---

## Troubleshooting

### "Permission denied" When Writing

**Cause:** bindfs not working or wrong mount point.

**Fix:** Make sure you're writing to `output/mnt/system_a/` not `output/mnt/.system_a_loop/`

### Changes Not Appearing After Reboot

**Cause:**
1. Wrong partition (editing system_b instead of system_a)
2. File overwritten by overlay
3. dm-verity failure (hashtree mismatch)

**Fix:**
1. Verify you're editing `*_a` partitions
2. Check `verify_chain.sh` output after repacking

### Bootloop After Modifications

**Cause:** Invalid modification broke Android.

**Fix:**
1. Restore stock firmware
2. Make smaller changes and test incrementally

---

## Next Steps

After making modifications:
- [05_UNMOUNTING_PARTITIONS.md](05_UNMOUNTING_PARTITIONS.md) - Unmount partitions
- [06_REPACKING_SUPER.md](06_REPACKING_SUPER.md) - Repack super.img
