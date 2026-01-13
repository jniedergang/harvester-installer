# Guide Simple : Créer une Image Raw avec Boot EFI

Ce guide explique comment créer une image disque raw pré-installée avec Harvester, configurée pour le boot EFI/UEFI.

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir :

1. **QEMU installé**
   ```bash
   # openSUSE/SLES
   sudo zypper install qemu qemu-ovmf-x86_64
   
   # Debian/Ubuntu
   sudo apt-get install qemu-system-x86 ovmf
   
   # Fedora/RHEL
   sudo dnf install qemu-system-x86 edk2-ovmf
   ```

2. **ISO Harvester construit**
   ```bash
   cd /path/to/harvester-installer
   make
   ```

3. **KVM activé** (vérification)
   ```bash
   ls -l /dev/kvm
   # Si erreur, ajoutez votre utilisateur au groupe kvm:
   sudo usermod -aG kvm $USER
   ```

## 🚀 Méthode 1 : Script Automatique (Recommandé)

La méthode la plus simple est d'utiliser le script automatique :

```bash
cd /path/to/harvester-installer
./build-efi-raw.sh
```

Le script va :
- ✅ Détecter automatiquement la version de votre ISO
- ✅ Trouver le firmware OVMF (UEFI)
- ✅ Créer l'image raw de 250GB
- ✅ Installer Harvester automatiquement
- ✅ Compresser l'image (250GB → ~20GB)

**Résultat :** `dist/artifacts/harvester-*-amd64.raw.zst`

## 🔧 Méthode 2 : Avec BUILD_QCOW (Intégré au Makefile)

Si vous préférez utiliser le système de build intégré :

```bash
cd /path/to/harvester-installer
BUILD_QCOW=true make
```

Cette méthode utilise le même code mais s'intègre dans le processus de build principal.

## 📝 Méthode 3 : Manuel (Pour comprendre le processus)

Si vous voulez comprendre chaque étape :

### Étape 1 : Vérifier les fichiers requis

```bash
cd /path/to/harvester-installer
ls -lh dist/artifacts/harvester-*-amd64.iso
ls -lh dist/artifacts/harvester-*-vmlinuz-amd64
ls -lh dist/artifacts/harvester-*-initrd-amd64
```

### Étape 2 : Vérifier OVMF

```bash
# openSUSE/Fedora
ls -lh /usr/share/qemu/ovmf-x86_64-code.bin
ls -lh /usr/share/qemu/ovmf-x86_64-vars.bin

# Debian/Ubuntu
ls -lh /usr/share/OVMF/OVMF_CODE.fd
ls -lh /usr/share/OVMF/OVMF_VARS.fd
```

### Étape 3 : Créer l'image raw

```bash
VERSION="v1.7.0"  # Remplacez par votre version
qemu-img create -f raw -o size=250G dist/artifacts/harvester-${VERSION}-amd64.raw
```

### Étape 4 : Lancer l'installation avec QEMU

```bash
# Créer une copie temporaire du fichier VARS
TEMP_VARS=$(mktemp)
cp /usr/share/qemu/ovmf-x86_64-vars.bin $TEMP_VARS

# Lancer QEMU avec boot EFI
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

# Nettoyer
rm -f $TEMP_VARS
```

### Étape 5 : Compresser l'image

```bash
zstd -T4 --rm dist/artifacts/harvester-${VERSION}-amd64.raw
```

## ✅ Vérification

Pour vérifier que l'image utilise bien le boot EFI :

```bash
# Vérifier la table de partitions (doit montrer une partition EFI)
sudo parted dist/artifacts/harvester-*-amd64.raw print

# Vous devriez voir une partition avec:
# - File system: fat16
# - Name: efi
# - Flags: boot, esp
```

## 🎯 Utilisation de l'Image

### Décompresser l'image

```bash
zstd -d dist/artifacts/harvester-*-amd64.raw.zst
```

### Booter l'image avec QEMU

```bash
# Créer un fichier VARS temporaire
TEMP_VARS=$(mktemp)
cp /usr/share/qemu/ovmf-x86_64-vars.bin $TEMP_VARS

# Booter
qemu-system-x86_64 \
  -machine q35,accel=kvm \
  -cpu host \
  -m 8192 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/ovmf-x86_64-code.bin \
  -drive if=pflash,format=raw,file=$TEMP_VARS \
  -drive file=dist/artifacts/harvester-*-amd64.raw,if=virtio,format=raw \
  -nographic
```

## 🔍 Dépannage

### Erreur : "OVMF firmware not found"

**Solution :** Installez le package OVMF pour votre distribution (voir Prérequis)

### Erreur : "Permission denied" sur /dev/kvm

**Solution :**
```bash
sudo usermod -aG kvm $USER
# Puis reconnectez-vous ou utilisez: newgrp kvm
```

### Erreur : "Out of memory" pendant le build

**Solution :** 
- Arrêtez d'autres conteneurs/services
- Ou utilisez la compression gzip au lieu de xz (déjà configuré dans le code)

### L'image boote en BIOS au lieu d'EFI

**Vérifications :**
1. OVMF est bien installé et détecté
2. La commande QEMU inclut `-machine q35`
3. Les options pflash ou -bios sont présentes

## 📊 Résumé des Fichiers

Après la création, vous aurez :

- **Image compressée :** `dist/artifacts/harvester-*-amd64.raw.zst` (~20GB)
- **Image raw :** `dist/artifacts/harvester-*-amd64.raw` (250GB, supprimée après compression)

## 💡 Astuces

1. **Temps d'installation :** Comptez 10-20 minutes selon votre système
2. **Espace disque :** Assurez-vous d'avoir au moins 300GB d'espace libre
3. **Mémoire :** Le processus nécessite ~8GB de RAM disponible
4. **Compression :** L'image compressée est ~20x plus petite que l'originale

## 🔗 Voir Aussi

- `MANUAL_EFI_BUILD.md` - Guide manuel détaillé avec toutes les options
- `DIFF_EFI_CHANGES.md` - Différences avec la version originale
- `build-efi-raw.sh` - Script automatique avec commentaires
