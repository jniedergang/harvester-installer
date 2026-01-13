# Manual Procedure: Building Harvester Raw Image with EFI Boot

This guide provides step-by-step instructions to manually build a Harvester raw image with EFI/UEFI boot support instead of legacy BIOS.

## Prerequisites

1. **Build the ISO first** (if not already done):
   ```bash
   cd /path/to/harvester-installer
   make
   ```

2. **Install OVMF firmware** (UEFI firmware for QEMU):
   
   **On Debian/Ubuntu:**
   ```bash
   sudo apt-get update
   sudo apt-get install ovmf
   ```
   
   **On openSUSE/SLES:**
   ```bash
   sudo zypper install qemu-ovmf-x86_64
   ```
   
   **On Fedora/RHEL/CentOS:**
   ```bash
   sudo dnf install edk2-ovmf
   ```

3. **Verify OVMF installation:**
   ```bash
   # Check for OVMF firmware files
   ls -la /usr/share/OVMF/OVMF_CODE.fd /usr/share/OVMF/OVMF_VARS.fd
   # OR
   ls -la /usr/share/qemu/ovmf-x86_64-code.bin /usr/share/qemu/ovmf-x86_64-vars.bin
   ```

## Step-by-Step Manual Procedure

### Step 1: Set Environment Variables

```bash
cd /path/to/harvester-installer

# Set version prefix (adjust based on your build)
export VERSION="v1.7.0"  # or your version
export PROJECT_PREFIX="harvester-${VERSION}"
export ARCH="amd64"
export ARTIFACTS_DIR="dist/artifacts"
```

### Step 2: Locate Required Files

After building the ISO, you should have these files in `dist/artifacts/`:

```bash
# List the required files
ls -lh ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.iso
ls -lh ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-amd64
ls -lh ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-amd64
```

### Step 3: Create the Raw Disk Image

```bash
# Create a 250GB raw disk image
qemu-img create -f raw -o size=250G ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw

# Verify it was created
ls -lh ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw
```

### Step 4: Locate OVMF Firmware Files

```bash
# Method 1: Check for separate CODE and VARS files (preferred)
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"

# Method 2: Alternative location
if [ ! -f "$OVMF_CODE" ]; then
  OVMF_CODE="/usr/share/qemu/ovmf-x86_64-code.bin"
  OVMF_VARS="/usr/share/qemu/ovmf-x86_64-vars.bin"
fi

# Method 3: Fallback to combined file
if [ ! -f "$OVMF_CODE" ]; then
  OVMF_CODE="/usr/share/OVMF/OVMF.fd"
  OVMF_VARS=""
fi

# Verify OVMF files exist
if [ -f "$OVMF_CODE" ]; then
  echo "Found OVMF firmware: $OVMF_CODE"
  if [ -n "$OVMF_VARS" ] && [ -f "$OVMF_VARS" ]; then
    echo "Found OVMF vars: $OVMF_VARS"
  fi
else
  echo "ERROR: OVMF firmware not found. Please install it first."
  exit 1
fi
```

### Step 5: Create a Temporary OVMF VARS File (if using separate CODE/VARS)

If you're using separate CODE and VARS files, create a writable copy of the VARS file:

```bash
# Create a temporary writable copy of OVMF_VARS
TEMP_OVMF_VARS=$(mktemp)
cp "$OVMF_VARS" "$TEMP_OVMF_VARS"
chmod 644 "$TEMP_OVMF_VARS"
```

### Step 6: Build the QEMU Command

#### Option A: Using Separate CODE and VARS Files (Recommended)

```bash
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -smp cores=2,threads=2,sockets=1 \
  -m 8192 \
  -nographic \
  -serial mon:stdio \
  -serial file:harvester-installer.log \
  -nic none \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${TEMP_OVMF_VARS}" \
  -drive file=${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw,if=virtio,cache=writeback,discard=ignore,format=raw \
  -cdrom ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.iso \
  -kernel ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-amd64 \
  -append "cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs console=ttyS1 rd.cos.disable net.ifnames=1 harvester.install.mode=install harvester.install.device=/dev/vda harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher harvester.scheme_version=1 harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true" \
  -initrd ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-amd64 \
  -boot once=d
```

#### Option B: Using Combined OVMF File (Fallback)

```bash
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -smp cores=2,threads=2,sockets=1 \
  -m 8192 \
  -nographic \
  -serial mon:stdio \
  -serial file:harvester-installer.log \
  -nic none \
  -bios "${OVMF_CODE}" \
  -drive file=${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw,if=virtio,cache=writeback,discard=ignore,format=raw \
  -cdrom ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.iso \
  -kernel ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-amd64 \
  -append "cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs console=ttyS1 rd.cos.disable net.ifnames=1 harvester.install.mode=install harvester.install.device=/dev/vda harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher harvester.scheme_version=1 harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true" \
  -initrd ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-amd64 \
  -boot once=d
```

### Step 7: Monitor the Installation

The installation will run automatically. You can monitor progress:

```bash
# In another terminal, watch the log file
tail -f harvester-installer.log

# Or check the QEMU console output
```

### Step 8: Wait for Completion

The installation will:
1. Boot from the ISO
2. Automatically install Harvester to the raw disk
3. Power off the VM when complete

Wait until QEMU exits (the process will terminate automatically).

### Step 9: Verify the Raw Image

```bash
# Check the raw image was created and has content
ls -lh ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw

# Check the partition table (should show EFI partition)
parted ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw print

# You should see an EFI System Partition (ESP) if UEFI boot was successful
```

### Step 10: Compress the Image (Optional)

```bash
# Compress the raw image
zstd -T4 --rm ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw

# This creates: ${PROJECT_PREFIX}-amd64.raw.zst
```

### Step 11: Clean Up Temporary Files

```bash
# Remove temporary OVMF VARS file if created
if [ -n "$TEMP_OVMF_VARS" ] && [ -f "$TEMP_OVMF_VARS" ]; then
  rm -f "$TEMP_OVMF_VARS"
fi

# Remove installation log if desired
rm -f harvester-installer.log
```

## Key Differences: EFI vs Legacy BIOS

### EFI Boot (This Procedure):
- Uses `-machine q35` (modern chipset with UEFI support)
- Uses `-drive if=pflash` with OVMF firmware files
- Creates an EFI System Partition (ESP) on the disk
- Boots via UEFI firmware

### Legacy BIOS (Old Method):
- Uses default machine type (pc or i440fx)
- No firmware specification (uses built-in BIOS)
- Creates MBR partition table
- Boots via legacy BIOS

## Verification: Confirming EFI Boot

After installation, you can verify the image uses EFI:

```bash
# Check partition table
parted ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw print

# Mount and check for EFI directory (if you have a loop device)
sudo losetup -P /dev/loop0 ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw
sudo mount /dev/loop0p1 /mnt  # Usually partition 1 is ESP
ls -la /mnt/EFI/
sudo umount /mnt
sudo losetup -d /dev/loop0
```

You should see an `/EFI/` directory with boot files if EFI boot was successful.

## Troubleshooting

### Issue: OVMF firmware not found
**Solution:** Install the OVMF package for your distribution (see Prerequisites)

### Issue: QEMU fails to start
**Solution:** 
- Ensure KVM is enabled: `lsmod | grep kvm`
- Check you have permission: `ls -l /dev/kvm`
- Add your user to kvm group: `sudo usermod -aG kvm $USER`

### Issue: Installation hangs
**Solution:**
- Check the log file: `tail -f harvester-installer.log`
- Ensure sufficient disk space
- Verify ISO file is not corrupted

### Issue: Image still boots with BIOS
**Solution:**
- Verify OVMF files are accessible
- Check QEMU command includes `-machine q35`
- Ensure pflash drives are specified correctly

## Complete Example Script

Here's a complete script combining all steps:

```bash
#!/bin/bash
set -e

# Configuration
VERSION="v1.7.0"  # Adjust to your version
PROJECT_PREFIX="harvester-${VERSION}"
ARCH="amd64"
ARTIFACTS_DIR="dist/artifacts"

# Step 1: Find OVMF firmware
if [ -f /usr/share/OVMF/OVMF_CODE.fd ] && [ -f /usr/share/OVMF/OVMF_VARS.fd ]; then
  OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
  OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"
  USE_SEPARATE_VARS=true
elif [ -f /usr/share/qemu/ovmf-x86_64-code.bin ] && [ -f /usr/share/qemu/ovmf-x86_64-vars.bin ]; then
  OVMF_CODE="/usr/share/qemu/ovmf-x86_64-code.bin"
  OVMF_VARS="/usr/share/qemu/ovmf-x86_64-vars.bin"
  USE_SEPARATE_VARS=true
elif [ -f /usr/share/OVMF/OVMF.fd ]; then
  OVMF_CODE="/usr/share/OVMF/OVMF.fd"
  USE_SEPARATE_VARS=false
else
  echo "ERROR: OVMF firmware not found. Please install it first."
  exit 1
fi

echo "Using OVMF firmware: $OVMF_CODE"

# Step 2: Create raw image
echo "Creating raw disk image..."
qemu-img create -f raw -o size=250G ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw

# Step 3: Create temporary VARS file if needed
if [ "$USE_SEPARATE_VARS" = true ]; then
  TEMP_OVMF_VARS=$(mktemp)
  cp "$OVMF_VARS" "$TEMP_OVMF_VARS"
  chmod 644 "$TEMP_OVMF_VARS"
  echo "Created temporary OVMF VARS: $TEMP_OVMF_VARS"
fi

# Step 4: Build QEMU command
QEMU_CMD="qemu-system-x86_64"
QEMU_CMD="$QEMU_CMD -machine q35,accel=kvm"
QEMU_CMD="$QEMU_CMD -cpu host"
QEMU_CMD="$QEMU_CMD -smp cores=2,threads=2,sockets=1"
QEMU_CMD="$QEMU_CMD -m 8192"
QEMU_CMD="$QEMU_CMD -nographic"
QEMU_CMD="$QEMU_CMD -serial mon:stdio"
QEMU_CMD="$QEMU_CMD -serial file:harvester-installer.log"
QEMU_CMD="$QEMU_CMD -nic none"

# Add UEFI firmware
if [ "$USE_SEPARATE_VARS" = true ]; then
  QEMU_CMD="$QEMU_CMD -drive if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
  QEMU_CMD="$QEMU_CMD -drive if=pflash,format=raw,file=${TEMP_OVMF_VARS}"
else
  QEMU_CMD="$QEMU_CMD -bios ${OVMF_CODE}"
fi

# Add disk and boot options
QEMU_CMD="$QEMU_CMD -drive file=${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw,if=virtio,cache=writeback,discard=ignore,format=raw"
QEMU_CMD="$QEMU_CMD -cdrom ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.iso"
QEMU_CMD="$QEMU_CMD -kernel ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-amd64"
QEMU_CMD="$QEMU_CMD -append \"cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs console=ttyS1 rd.cos.disable net.ifnames=1 harvester.install.mode=install harvester.install.device=/dev/vda harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher harvester.scheme_version=1 harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true\""
QEMU_CMD="$QEMU_CMD -initrd ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-amd64"
QEMU_CMD="$QEMU_CMD -boot once=d"

# Step 5: Run QEMU
echo "Starting QEMU with EFI boot..."
echo "Command: $QEMU_CMD"
eval $QEMU_CMD

# Step 6: Show log tail
echo "Installation log (last 100 lines):"
tail -100 harvester-installer.log

# Step 7: Compress image
echo "Compressing raw image..."
zstd -T4 --rm ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw

# Step 8: Cleanup
if [ "$USE_SEPARATE_VARS" = true ] && [ -n "$TEMP_OVMF_VARS" ]; then
  rm -f "$TEMP_OVMF_VARS"
fi

echo "Done! Raw image: ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw.zst"
```

Save this as `build-efi-raw.sh`, make it executable, and run it:

```bash
chmod +x build-efi-raw.sh
./build-efi-raw.sh
```
