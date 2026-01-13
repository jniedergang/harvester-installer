# Guide Rapide : Image Raw EFI en 3 Étapes

## ⚡ Méthode Ultra-Rapide

```bash
# 1. Installer OVMF
sudo zypper install qemu-ovmf-x86_64  # openSUSE
# OU
sudo apt-get install ovmf              # Debian/Ubuntu

# 2. Construire l'ISO (si pas déjà fait)
cd /path/to/harvester-installer
make

# 3. Créer l'image raw EFI
./build-efi-raw.sh
```

**C'est tout !** L'image sera dans `dist/artifacts/harvester-*-amd64.raw.zst`

## 📦 Alternative : Avec BUILD_QCOW

```bash
BUILD_QCOW=true make
```

## ✅ Vérification Rapide

```bash
# Vérifier que la partition EFI existe
sudo parted dist/artifacts/harvester-*-amd64.raw print | grep efi
```

## 🚨 Problèmes Courants

| Problème | Solution |
|----------|----------|
| OVMF non trouvé | `sudo zypper install qemu-ovmf-x86_64` |
| Permission /dev/kvm | `sudo usermod -aG kvm $USER` |
| Pas assez de RAM | Arrêter d'autres conteneurs/services |

## 📖 Documentation Complète

Voir `GUIDE_CREATION_IMAGE_EFI.md` pour plus de détails.
