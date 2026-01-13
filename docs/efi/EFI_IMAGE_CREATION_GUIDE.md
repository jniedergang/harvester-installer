# Simple Guide: Creating a Raw Image with EFI Boot

This guide explains how to create a pre-installed Harvester raw disk image configured for EFI/UEFI boot.

## 📋 Prerequisites

Before starting, make sure you have:

1. **QEMU installed**
   ```bash
   # openSUSE/SLES
   sudo zypper install qemu qemu-ovmf-x86_64
   
   # Debian/Ubuntu
   sudo apt-get install qemu-system-x86 ovmf
   
   # Fedora/RHEL
   sudo dnf install qemu-system-x86 edk2-ovmf
   ```

2. **Harvester ISO built**
   ```bash
   cd /path/to/harvester-installer
   make
   ```

3. **KVM enabled** (verification)
   ```bash
   ls -l /dev/kvm
   # If error, add your user to the kvm group:
   sudo usermod -aG kvm $USER
   ```

## 🚀 Method 1: Automated Script (Recommended)

The simplest method is to use the automated script:

```bash
cd /path/to/harvester-installer
./build-efi-raw.sh
```

The script will:
- ✅ Automatically detect your ISO version
- ✅ Find OVMF firmware (UEFI)
- ✅ Create the 250GB raw image
- ✅ Automatically install Harvester
- ✅ Compress the image (250GB → ~20GB)

**Result:** `dist/artifacts/harvester-*-amd64.raw.zst`

## 🔧 Method 2: With BUILD_QCOW (Integrated into Makefile)

If you prefer to use the integrated build system:

```bash
cd /path/to/harvester-installer
BUILD_QCOW=true make
```

This method uses the same code but integrates into the main build process.

## 📝 Method 3: Manual (To understand the process)

If you want to understand each step:

### Step 1: Verify required files

```bash
cd /path/to/harvester-installer
ls -lh dist/artifacts/harvester-*-amd64.iso
ls -lh dist/artifacts/harvester-*-vmlinuz-amd64
ls -lh dist/artifacts/harvester-*-initrd-amd64
```

### Step 2: Verify OVMF

```bash
# openSUSE/Fedora
ls -lh /usr/share/qemu/ovmf-x86_64-code.bin
ls -lh /usr/share/qemu/ovmf-x86_64-vars.bin

# Debian/Ubuntu
ls -lh /usr/share/OVMF/OVMF_CODE.fd
ls -lh /usr/share/OVMF/OVMF_VARS.fd
```

### Step 3: Create the raw image

```bash
VERSION="v1.7.0"  # Replace with your version
qemu-img create -f raw -o size=250G dist/artifacts/harvester-${VERSION}-amd64.raw
```

### Step 4: Launch installation with QEMU

```bash
# Create a temporary copy of the VARS file
TEMP_VARS=$(mktemp)
cp /usr/share/qemu/ovmf-x86_64-vars.bin $TEMP_VARS

# Launch QEMU with EFI boot
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m 8192 \
  -nographic \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/ovmf-x86_64-code.bin \
  -drive if=pflash,format=raw,file=$TEMP_VARS \
  -drive file=dist/artifacts/harvester-${VERSION}-amd64.raw,if=virtio,format=raw \
  -cdrom dist/artifacts/harvester-${VERSION}-amd64.iso \
  -kernel dist/artifacts/harvester-${VERSION}-vmlinuz-amd64 \
  -initrd dist/artifacts/harvester-${VERSION}-initrd-amd64 \
  -append "cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs console=ttyS1 harvester.install.mode=install harvester.install.device=/dev/vda harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true" \
  -boot once=d

# Clean up
rm -f $TEMP_VARS
```

### Step 5: Compress the image

```bash
zstd -T4 --rm dist/artifacts/harvester-${VERSION}-amd64.raw
```

## ✅ Verification

To verify that the image uses EFI boot:

```bash
# Check the partition table (should show an EFI partition)
sudo parted dist/artifacts/harvester-*-amd64.raw print

# You should see a partition with:
# - File system: fat16
# - Name: efi
# - Flags: boot, esp
```

## 🎯 Using the Image

### Decompress the image

```bash
zstd -d dist/artifacts/harvester-*-amd64.raw.zst
```

### Boot the image with QEMU

```bash
# Create a temporary VARS file
TEMP_VARS=$(mktemp)
cp /usr/share/qemu/ovmf-x86_64-vars.bin $TEMP_VARS

# Boot
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m 8192 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/ovmf-x86_64-code.bin \
  -drive if=pflash,format=raw,file=$TEMP_VARS \
  -drive file=dist/artifacts/harvester-*-amd64.raw,if=virtio,format=raw \
  -nographic
```

## 🔍 Troubleshooting

### Error: "OVMF firmware not found"

**Solution:** Install the OVMF package for your distribution (see Prerequisites)

### Error: "Permission denied" on /dev/kvm

**Solution:**
```bash
sudo usermod -aG kvm $USER
# Then reconnect or use: newgrp kvm
```

### Error: "Out of memory" during build

**Solution:** 
- Stop other containers/services
- Or use gzip compression instead of xz (already configured in the code)

### Image boots in BIOS instead of EFI

**Checks:**
1. OVMF is properly installed and detected
2. The QEMU command includes `-machine q35`
3. The pflash or -bios options are present

## 📊 File Summary

After creation, you will have:

- **Compressed image:** `dist/artifacts/harvester-*-amd64.raw.zst` (~20GB)
- **Raw image:** `dist/artifacts/harvester-*-amd64.raw` (250GB, deleted after compression)

## 💡 Tips

1. **Installation time:** Allow 10-20 minutes depending on your system
2. **Disk space:** Make sure you have at least 300GB free space
3. **Memory:** The process requires ~8GB of available RAM
4. **Compression:** The compressed image is ~20x smaller than the original

## 🔗 See Also

- `MANUAL_EFI_BUILD.md` - Detailed manual guide with all options
- `DIFF_EFI_CHANGES.md` - Differences with the original version
- `build-efi-raw.sh` - Automated script with comments
