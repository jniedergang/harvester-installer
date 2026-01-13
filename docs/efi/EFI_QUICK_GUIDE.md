# Quick Guide: EFI Raw Image in 3 Steps

## ⚡ Ultra-Quick Method

```bash
# 1. Install OVMF
sudo zypper install qemu-ovmf-x86_64  # openSUSE
# OR
sudo apt-get install ovmf              # Debian/Ubuntu

# 2. Build the ISO (if not already done)
cd /path/to/harvester-installer
make

# 3. Create the EFI raw image
./build-efi-raw.sh
```

**That's it!** The image will be in `dist/artifacts/harvester-*-amd64.raw.zst`

## 📦 Alternative: With BUILD_QCOW

```bash
BUILD_QCOW=true make
```

## ✅ Quick Verification

```bash
# Verify that the EFI partition exists
sudo parted dist/artifacts/harvester-*-amd64.raw print | grep efi
```

## 🚨 Common Issues

| Issue | Solution |
|-------|----------|
| OVMF not found | `sudo zypper install qemu-ovmf-x86_64` |
| Permission /dev/kvm | `sudo usermod -aG kvm $USER` |
| Not enough RAM | Stop other containers/services |

## 📖 Complete Documentation

See `EFI_IMAGE_CREATION_GUIDE.md` for more details.
