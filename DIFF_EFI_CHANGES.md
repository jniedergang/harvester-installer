# Diff des modifications pour le support EFI

## Fichier modifié

### `scripts/package-harvester-os`

Ce fichier a été modifié pour ajouter le support du boot EFI/UEFI au lieu du boot BIOS legacy lors de la création d'images raw avec `BUILD_QCOW=true`.

## Diff complet

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

## Résumé des changements

### Avant (BIOS Legacy)
- Utilisait le type de machine par défaut (BIOS legacy)
- Pas de firmware UEFI spécifié
- Commande QEMU construite en une seule ligne longue

### Après (EFI/UEFI)
1. **Détection automatique du firmware OVMF:**
   - Cherche dans `/usr/share/OVMF/` (Debian/Ubuntu)
   - Cherche dans `/usr/share/qemu/` (openSUSE/Fedora)
   - Supporte les fichiers séparés (CODE/VARS) et combinés

2. **Type de machine changé:**
   - De: défaut (BIOS legacy)
   - Vers: `-machine q35,accel=kvm` (support UEFI)

3. **Configuration du firmware UEFI:**
   - Utilise `-drive if=pflash` pour les fichiers CODE/VARS séparés (méthode recommandée)
   - Utilise `-bios` comme fallback pour les fichiers combinés
   - Avertit si OVMF n'est pas trouvé et utilise BIOS legacy

4. **Amélioration de la structure du code:**
   - Utilise un tableau bash (`QEMU_ARGS`) au lieu de concaténation de chaînes
   - Plus lisible et maintenable
   - Meilleure gestion des erreurs

## Fichiers ajoutés (non trackés)

Ces fichiers ont été créés pour la documentation et les outils:

- `build-efi-raw.sh` - Script automatisé pour créer des images raw EFI
- `MANUAL_EFI_BUILD.md` - Guide manuel étape par étape
- `BUILD_STATUS.md` - Guide de monitoring du build
- `TESTING_SUMMARY.md` - Résumé des tests
- `FIX_DOCKER_SOCKET.md` - Documentation du correctif pour le socket Docker
- `DIFF_EFI_CHANGES.md` - Ce fichier

## Application du patch

Pour appliquer ce patch sur une autre copie du dépôt:

```bash
cd /path/to/harvester-installer
git apply /tmp/diff-package-harvester-os.patch
```

Ou pour voir le diff complet:

```bash
cd /root/harvester-installer
git diff scripts/package-harvester-os
```

## Version de référence

- **Commit de base:** `085eda28` (Bump copyright year #1215)
- **Branche:** `master`
- **Remote:** `https://github.com/harvester/harvester-installer.git`
