# Archive ZIP : Support Boot EFI

## 📦 Fichier créé

**`harvester-efi-essentials.zip`** (19 KB)

## 📋 Contenu de l'archive

L'archive contient tous les fichiers essentiels pour ajouter le support boot EFI à Harvester :

1. **`build-efi-raw.sh`** (21 KB)
   - Script automatique pour créer l'image raw avec boot EFI
   - Détection automatique de version et firmware
   - Installation et compression automatiques

2. **`patch-package-harvester-os.patch`** (12 KB)
   - Patch à appliquer sur `scripts/package-harvester-os`
   - Contient toutes les modifications pour le support EFI
   - Format standard Git patch

3. **`GUIDE_CREATION_IMAGE_EFI.md`** (5.8 KB)
   - Guide complet avec 3 méthodes d'utilisation
   - Instructions détaillées étape par étape
   - Section dépannage complète

4. **`GUIDE_RAPIDE_EFI.md`** (1 KB)
   - Guide ultra-rapide en 3 étapes
   - Commandes essentielles
   - Tableau de dépannage

5. **`DIFF_EFI_CHANGES.md`** (6 KB)
   - Documentation technique des changements
   - Explication du diff
   - Référence pour les développeurs

6. **`README.md`** (2.3 KB)
   - Instructions d'installation
   - Guide de démarrage rapide
   - Références vers la documentation

## 🚀 Utilisation

### Extraire l'archive

```bash
unzip harvester-efi-essentials.zip
cd harvester-efi-essentials
```

### Installation rapide

```bash
# 1. Appliquer le patch
cd /path/to/harvester-installer
git apply harvester-efi-essentials/patch-package-harvester-os.patch

# 2. Copier le script
cp harvester-efi-essentials/build-efi-raw.sh .
chmod +x build-efi-raw.sh

# 3. Installer OVMF
sudo zypper install qemu-ovmf-x86_64  # openSUSE
# OU
sudo apt-get install ovmf              # Debian/Ubuntu

# 4. Construire l'ISO (si nécessaire)
make

# 5. Créer l'image EFI
./build-efi-raw.sh
```

## 📖 Documentation

- **Débutant :** Commencez par `README.md` puis `GUIDE_RAPIDE_EFI.md`
- **Utilisateur avancé :** Lisez `GUIDE_CREATION_IMAGE_EFI.md`
- **Développeur :** Consultez `DIFF_EFI_CHANGES.md` et le patch

## ✅ Vérification

Après installation, vérifiez que tout fonctionne :

```bash
# Vérifier que le patch est appliqué
cd /path/to/harvester-installer
git status  # scripts/package-harvester-os devrait être modifié

# Vérifier que le script est exécutable
ls -lh build-efi-raw.sh

# Tester la détection OVMF
./build-efi-raw.sh  # S'arrêtera si OVMF n'est pas trouvé
```

## 📝 Notes

- L'archive fait seulement **19 KB** (compressée)
- Tous les fichiers sont autonomes et documentés
- Compatible avec toutes les distributions Linux supportées
- Le patch peut être appliqué sur n'importe quelle version récente de harvester-installer

## 🔗 Emplacement

L'archive est disponible à :
```
/root/harvester-installer/harvester-efi-essentials.zip
```
