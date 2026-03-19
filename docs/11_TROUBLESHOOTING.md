# Troubleshooting Guide

## Boot Issues

### Device Doesn't Boot (Stuck on Logo)

**Symptoms:**
- Shows manufacturer logo indefinitely
- No Android boot animation

**Possible Causes:**
1. AVB verification failed
2. Corrupt boot.img
3. System partition issues

**Solutions:**

1. **Check AVB state** - If device shows any verification warning, AVB failed
2. **Re-flash stock** - Flash original firmware to recover
3. **Check serial output** - Connect via UART if available

---

### Boot Loop (Keeps Restarting)

**Symptoms:**
- Shows boot animation
- Restarts before reaching home screen
- May show "Android is starting" repeatedly

**Possible Causes:**
1. System modification broke something
2. SELinux policy violation
3. Missing critical system file

**Solutions:**

1. **Factory reset** - Wipe data in recovery mode
2. **Check modifications** - Revert last changes and re-run repack_super.sh

---

### Yellow/Orange Boot Warning

**Symptoms:**
- Boot screen shows yellow or orange warning
- Text about "bootloader unlocked" or "verification failed"

**Meaning:**
- **Yellow** = Custom OS, bootloader unlocked
- **Orange** = AVB verification failed

**Cause:** vbmeta.img not accepted by bootloader

**Solutions:**

1. **Verify chain** - Run `./scripts/verify_chain.sh`
2. **Check keys** - Ensure keys/vbmeta.pem is AOSP testkey
3. **Reflash vbmeta** - Flash all vbmeta images

```bash
# Check vbmeta key
python3 tools/avb-tools/avbtool.py info_image --image output/vbmeta.img | grep "Public key"
# Must show: cdbb77177f731920bbe0a0f94f84d9038ae0617d
```

---

### dm-verity Error

**Symptoms:**
- Device shows dm-verity corruption message
- May say "your device is corrupt"

**Cause:** Hashtree verification failed. The partition content doesn't match the hashtree.

**Possible Reasons:**
1. Partition modified after hashtree was calculated
2. Hashtree not added correctly
3. Wrong partition in vbmeta_system/vendor

**Solutions:**

1. **Rerun repack** - Run the full repack process again:
```bash
./scripts/repack_super.sh
./scripts/rebuild_vbmeta.sh
./scripts/verify_chain.sh
```

2. **Check partition state** - Ensure partitions weren't modified after repack

---

## Script Errors

### "Permission denied"

**Cause:** Script not executable or needs sudo.

**Fix:**
```bash
chmod +x scripts/*.sh
# Or run with sudo
sudo ./scripts/modify_partition.sh ...
```

---

### "Command not found: simg2img"

**Cause:** android-sdk-libsparse-utils not installed.

**Fix:**
```bash
sudo apt install android-sdk-libsparse-utils
```

---

### "user_allow_other only allowed..."

**Cause:** FUSE not configured for user mounts.

**Fix:**
```bash
sudo sh -c 'echo "user_allow_other" >> /etc/fuse.conf'
```

---

### "Device or resource busy"

**Cause:** Mount point still in use.

**Fix:**
```bash
# Find what's using it
lsof +D output/mnt/system_a/

# Force unmount
sudo umount -l output/mnt/.system_a_loop
```

---

### "Scatter file not found"

**Cause:** No scatter file in firmware/stock/.

**Fix:**
1. Copy scatter file from your firmware:
```bash
cp /path/to/MT6761_Android_scatter.txt firmware/stock/
```

2. Verify it's there:
```bash
ls firmware/stock/*scatter*
```

---

### "Boot partition size 0"

**Cause:** Script couldn't parse boot size from scatter.

**Fix:**
1. Check scatter file format
2. Specify size manually:
```bash
./scripts/resign_boot.sh boot.img 33554432
```

---

## Key Issues

### "Wrong key" or Key Mismatch

**Symptoms:**
- verify_chain.sh shows FAIL
- Public key SHA1 doesn't match expected

**Cause:** Incorrect key in keys/ directory.

**Solution:**

1. **Verify key fingerprints:**
```bash
for key in keys/*.pem; do
    echo "=== $key ==="
    openssl rsa -in "$key" -pubout 2>/dev/null | openssl dgst -sha1
done
```

2. **Expected fingerprints:**
```
vbmeta.pem:        cdbb77177f731920bbe0a0f94f84d9038ae0617d
boot.pem:          a9cc8a379101d07cbe9f4ab76f76fcbb2ac286cc
vbmeta_system.pem: 565840a78763c9a3be92604f5aef14376ee45415
vbmeta_vendor.pem: f013c089b7f6e86cabc32f3ab24559f01b327bbf
```

3. **If keys are wrong:** Get correct AOSP test keys

---

### Device Uses Custom Keys (NOT VULNERABLE)

**Symptoms:**
```
./scripts/check_testkey.sh firmware/stock/vbmeta.img
Public key SHA1: [different hash]
NOT VULNERABLE - Uses custom keys.
```

**Meaning:** This device CANNOT be re-signed with our keys. The manufacturer used their own private keys.

**No Solution:** You cannot use this toolkit on devices with custom keys.

---

## Flashing Issues

### SP Flash Tool: BROM Error

**Symptoms:**
- "BROM ERROR: S_FT_ENABLE_DRAM_FAIL"
- "BROM ERROR: S_CHIP_TYPE_NOT_MATCH"

**Solutions:**

1. **Check USB connection:**
   - Try different USB port (preferably USB 2.0)
   - Try different cable
   - Remove USB hubs

2. **Check driver:**
   - Install MTK USB drivers
   - Check Device Manager for unknown devices

3. **Enter BROM correctly:**
   - Device must be OFF
   - Try Vol Up, Vol Down, or no button while inserting USB (varies by device)

---

### SP Flash Tool: Signature Error

**Cause:** Image signature doesn't match scatter expectations.

**Solutions:**

1. **Use original scatter** - Never modify the scatter file
2. **Check image paths** - Ensure correct images are selected

---

### SP Flash Tool: PMT Changed

**Meaning:** Partition layout changed from expected.

**Usually OK:** Click "Yes" to continue. This is normal when flashing modified super.img.

---

## Getting Help

### Information to Collect

When asking for help, provide:

1. **Device model** - Exact model number
2. **What you did** - Which scripts you ran
3. **Error output** - Full terminal output
4. **verify_chain.sh output** - If verification fails
5. **Scatter file info** - Partition sizes from scatter

### Commands for Debugging

```bash
# Check what's mounted
mount | grep m5_resigner

# Check disk usage
df -h output/mnt/*/

# Check partition info
python3 tools/avb-tools/avbtool.py info_image --image output/boot.img

# Check super structure
python3 tools/lpunpack_and_lpmake/binary/lpdump output/super.img
```
