# Diff of Changes for EFI Support

## Modified File

### `scripts/package-harvester-os`

This file has been modified to add EFI/UEFI boot support instead of legacy BIOS boot when creating raw images with `BUILD_QCOW=true`.

## Complete Diff

```diff
diff --git a/scripts/package-harvester-os b/scripts/package-harvester-os
index fdd4528f..79b692eb 100755
--- a/scripts/package-harvester-os
+++ b/scripts/package-harvester-os
@@ -187,15 +187,61 @@ rm -rf "${extract_dir}"
 if [ "${BUILD_QCOW}" == "true" ]; then
   echo "generating harvester install mode qcow"
   qemu-img create -f raw -o size=250G ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw
-  qemu-system-x86_64 --enable-kvm -nographic -cpu host -smp cores=2,threads=2,sockets=1 -m 8192 -serial mon:stdio \
-  -serial file:harvester-installer.log  -nic none \
-  -drive file=${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw,if=virtio,cache=writeback,discard=ignore,format=raw \
-  -boot d -cdrom ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.iso -kernel ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-amd64 \
-  -append "cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs \
-  console=ttyS1 rd.cos.disable net.ifnames=1 harvester.install.mode=install harvester.install.device=/dev/vda \
-  harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher \
-  harvester.scheme_version=1 harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true" \
-  -initrd ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-amd64 -boot once=d
+  
+  # Find OVMF firmware for UEFI boot
+  OVMF_CODE=""
+  OVMF_VARS=""
+  
+  # Try common OVMF firmware paths
+  if [ -f /usr/share/OVMF/OVMF_CODE.fd ] && [ -f /usr/share/OVMF/OVMF_VARS.fd ]; then
+    OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
+    OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"
+  elif [ -f /usr/share/qemu/ovmf-x86_64-code.bin ] && [ -f /usr/share/qemu/ovmf-x86_64-vars.bin ]; then
+    OVMF_CODE="/usr/share/qemu/ovmf-x86_64-code.bin"
+    OVMF_VARS="/usr/share/qemu/ovmf-x86_64-vars.bin"
+  elif [ -f /usr/share/OVMF/OVMF.fd ]; then
+    # Fallback to combined OVMF file
+    OVMF_CODE="/usr/share/OVMF/OVMF.fd"
+  fi
+  
+  # Build QEMU command with UEFI support
+  # Use q35 machine type for better UEFI support
+  QEMU_ARGS=(
+    -machine q35,accel=kvm
+    -cpu host
+    -smp cores=2,threads=2,sockets=1
+    -m 8192
+    -nographic
+    -serial mon:stdio
+    -serial file:harvester-installer.log
+    -nic none
+  )
+  
+  # Add UEFI firmware if found
+  if [ -n "${OVMF_CODE}" ] && [ -n "${OVMF_VARS}" ]; then
+    echo "Using UEFI firmware: ${OVMF_CODE} and ${OVMF_VARS}"
+    QEMU_ARGS+=(
+      -drive "if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
+      -drive "if=pflash,format=raw,file=${OVMF_VARS}"
+    )
+  elif [ -n "${OVMF_CODE}" ]; then
+    echo "Using UEFI firmware: ${OVMF_CODE}"
+    QEMU_ARGS+=(-bios "${OVMF_CODE}")
+  else
+    echo "Warning: OVMF firmware not found. Falling back to legacy BIOS boot."
+    echo "To enable UEFI, install OVMF package (e.g., 'apt-get install ovmf' or 'zypper install qemu-ovmf-x86_64')"
+  fi
+  
+  QEMU_ARGS+=(
+    -drive "file=${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw,if=virtio,cache=writeback,discard=ignore,format=raw"
+    -cdrom "${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.iso"
+    -kernel "${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-amd64"
+    -append "cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs console=ttyS1 rd.cos.disable net.ifnames=1 harvester.install.mode=install harvester.install.device=/dev/vda harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher harvester.scheme_version=1 harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true"
+    -initrd "${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-amd64"
+    -boot once=d
+  )
+  
+  qemu-system-x86_64 "${QEMU_ARGS[@]}"
   tail -100 harvester-installer.log
   echo "compressing raw image"
   zstd -T4 --rm ${ARTIFACTS_DIR}/${PROJECT_PREFIX}-amd64.raw
```

## Summary of Changes

### Before (Legacy BIOS)
- Used default machine type (legacy BIOS)
- No UEFI firmware specified
- QEMU command built in a single long line

### After (EFI/UEFI)
1. **Automatic OVMF firmware detection:**
   - Searches in `/usr/share/OVMF/` (Debian/Ubuntu)
   - Searches in `/usr/share/qemu/` (openSUSE/Fedora)
   - Supports both separate (CODE/VARS) and combined files

2. **Machine type changed:**
   - From: default (legacy BIOS)
   - To: `-machine q35,accel=kvm` (UEFI support)

3. **UEFI firmware configuration:**
   - Uses `-drive if=pflash` for separate CODE/VARS files (recommended method)
   - Uses `-bios` as fallback for combined files
   - Warns if OVMF is not found and uses legacy BIOS

4. **Code structure improvement:**
   - Uses bash array (`QEMU_ARGS`) instead of string concatenation
   - More readable and maintainable
   - Better error handling

## Added Files (Untracked)

These files were created for documentation and tools:

- `build-efi-raw.sh` - Automated script to create EFI raw images
- `MANUAL_EFI_BUILD.md` - Complete step-by-step manual guide
- `BUILD_STATUS.md` - Build monitoring guide
- `TESTING_SUMMARY.md` - Testing summary
- `FIX_DOCKER_SOCKET.md` - Documentation of Docker socket fix
- `DIFF_EFI_CHANGES.md` - This file

## Applying the Patch

To apply this patch to another copy of the repository:

```bash
cd /path/to/harvester-installer
git apply /tmp/diff-package-harvester-os.patch
```

Or to see the complete diff:

```bash
cd /root/harvester-installer
git diff scripts/package-harvester-os
```

## Reference Version

- **Base commit:** `085eda28` (Bump copyright year #1215)
- **Branch:** `master`
- **Remote:** `https://github.com/harvester/harvester-installer.git`
