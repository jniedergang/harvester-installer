# Build Status and Testing Guide

## Current Status

✅ **Prerequisites Installed:**
- QEMU (qemu-system-x86_64) - Version 10.1.3
- OVMF firmware - Located at `/usr/share/qemu/ovmf-x86_64-code.bin` and `/usr/share/qemu/ovmf-x86_64-vars.bin`
- Make - Installed
- Docker (via podman alias) - Configured
- Git, Go, Helm - Already available

✅ **Scripts Created:**
- `build-efi-raw.sh` - Automated EFI raw image builder
- `MANUAL_EFI_BUILD.md` - Complete manual procedure guide

🔄 **Build Process:**
- ISO build is currently running in the background
- This process will:
  1. Download dapper build tool
  2. Build harvester-installer binary
  3. Create Harvester and Rancher charts archive
  4. Create harvester-cluster-repo container image
  5. Build the ISO image using Elemental Toolkit

## Monitoring the Build

### Check Build Progress:
```bash
# Check if build is still running
ps aux | grep -E "make|dapper" | grep -v grep

# Check build output (if available)
tail -f /root/.cursor/projects/root/terminals/245928.txt

# Check for artifacts
ls -lh dist/artifacts/ 2>/dev/null
```

### Expected Build Time:
- Initial build: 30-60 minutes (depending on network speed and system resources)
- Subsequent builds: Faster (cached layers)

## After ISO Build Completes

Once the ISO is built, you'll find files in `dist/artifacts/`:
- `harvester-*-amd64.iso` - The ISO image
- `harvester-*-vmlinuz-amd64` - Kernel
- `harvester-*-initrd-amd64` - Initrd

### Then Build EFI Raw Image:

```bash
cd /root/harvester-installer

# Option 1: Use the automated script
./build-efi-raw.sh

# Option 2: Manual process (see MANUAL_EFI_BUILD.md)
```

## Verification Steps

### 1. Verify OVMF Detection:
```bash
./build-efi-raw.sh
# Should show: "Found: /usr/share/qemu/ovmf-x86_64-code.bin and ..."
```

### 2. Verify EFI Boot in Raw Image:
After building the raw image:
```bash
# Check partition table (should show EFI partition)
sudo parted dist/artifacts/harvester-*-amd64.raw print

# Or mount and check for EFI directory
sudo losetup -P /dev/loop0 dist/artifacts/harvester-*-amd64.raw
sudo mount /dev/loop0p1 /mnt
ls -la /mnt/EFI/
sudo umount /mnt
sudo losetup -d /dev/loop0
```

### 3. Test the Raw Image:
```bash
# Boot the raw image with QEMU to verify EFI boot
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/ovmf-x86_64-code.bin \
  -drive if=pflash,format=raw,file=/tmp/ovmf-vars.bin \
  -drive file=dist/artifacts/harvester-*-amd64.raw,if=virtio,format=raw \
  -nographic
```

## Troubleshooting

### Build Fails:
- Check podman/docker is working: `docker ps`
- Check disk space: `df -h`
- Check logs: Look for error messages in build output

### EFI Boot Not Working:
- Verify OVMF files exist: `ls -la /usr/share/qemu/ovmf-x86_64-*`
- Check QEMU command includes `-machine q35`
- Verify pflash drives are specified correctly

### Raw Image Creation Fails:
- Ensure ISO exists first
- Check disk space (raw image is 250GB uncompressed)
- Verify QEMU has KVM access: `ls -l /dev/kvm`

## Key Changes Made

1. **Updated `scripts/package-harvester-os`:**
   - Added OVMF firmware detection
   - Changed machine type to `q35` for UEFI support
   - Added pflash drive configuration for EFI boot

2. **Created `build-efi-raw.sh`:**
   - Automated script for building EFI raw images
   - Auto-detects version and OVMF firmware
   - Handles both separate CODE/VARS and combined OVMF files

3. **Created `MANUAL_EFI_BUILD.md`:**
   - Complete step-by-step manual procedure
   - Troubleshooting guide
   - Verification steps

## Next Steps

1. Wait for ISO build to complete
2. Run `./build-efi-raw.sh` to create EFI raw image
3. Verify the raw image has EFI partition
4. Test booting the image
