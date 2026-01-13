#!/bin/bash
# ============================================================================
# Script: build-efi-raw.sh
# Description: Crée une image disque raw avec boot EFI/UEFI pour Harvester
# ============================================================================
# Ce script automatise la création d'une image disque raw pré-installée avec
# Harvester, configurée pour le boot EFI/UEFI au lieu du boot BIOS legacy.
#
# Fonctionnalités:
# - Détection automatique de la version depuis les fichiers ISO
# - Détection automatique du firmware OVMF (UEFI)
# - Création d'une VM QEMU avec boot EFI
# - Installation automatique de Harvester
# - Compression de l'image résultante
#
# Prérequis:
# - ISO Harvester déjà construit (via 'make')
# - QEMU installé (qemu-system-x86_64)
# - OVMF installé (qemu-ovmf-x86_64 ou équivalent)
# - KVM activé et accessible
# ============================================================================

# Mode strict: arrête le script à la première erreur
# Utile pour éviter de continuer avec des erreurs silencieuses
set -e

# ============================================================================
# Configuration des variables
# ============================================================================
# VERSION: Version de Harvester (ex: "v1.7.0")
#   - Si vide: détection automatique depuis les fichiers ISO
#   - Si définie: utilise cette version explicitement
VERSION=""

# PROJECT_PREFIX: Préfixe des fichiers générés
# Format: "harvester-{VERSION}" (ex: "harvester-v1.7.0")
PROJECT_PREFIX="harvester"

# ARCH: Architecture cible (amd64 pour x86_64)
ARCH="amd64"

# ARTIFACTS_DIR: Répertoire contenant les artefacts de build
# Contient les ISO, kernel, initrd générés par le build principal
ARTIFACTS_DIR="dist/artifacts"

# ============================================================================
# Étape 0: Détection automatique de la version
# ============================================================================
# Si VERSION n'est pas définie, on essaie de la détecter automatiquement
# en cherchant le fichier ISO le plus récent dans le répertoire des artefacts.
# Cela permet d'utiliser le script sans avoir à spécifier manuellement la version.
# ============================================================================
if [ -z "$VERSION" ]; then
  # Recherche du fichier ISO le plus récent (trié par date, plus récent en premier)
  # Format attendu: harvester-{VERSION}-{ARCH}.iso
  # Exemple: harvester-v1.7.0-amd64.iso
  ISO_FILE=$(ls -t ${ARTIFACTS_DIR}/harvester-*-${ARCH}.iso 2>/dev/null | head -1)
  
  if [ -n "$ISO_FILE" ]; then
    # Extraction de la version depuis le nom de fichier
    # Exemple: "harvester-v1.7.0-amd64.iso" -> "v1.7.0"
    # Utilise sed pour extraire la partie entre "harvester-" et "-${ARCH}.iso"
    VERSION=$(basename "$ISO_FILE" | sed "s/harvester-\(.*\)-${ARCH}\.iso/\1/")
    PROJECT_PREFIX="harvester-${VERSION}"
    echo "Auto-detected version: $VERSION"
  else
    echo "ERROR: Could not find ISO file in ${ARTIFACTS_DIR}/"
    echo "Please set VERSION manually or build the ISO first with 'make'"
    exit 1
  fi
else
  # Si VERSION est définie manuellement, on construit le préfixe
  PROJECT_PREFIX="harvester-${VERSION}"
fi

echo "Building EFI raw image for: ${PROJECT_PREFIX}"

# ============================================================================
# Étape 1: Localisation du firmware OVMF pour le boot UEFI
# ============================================================================
# OVMF (Open Virtual Machine Firmware) est nécessaire pour le boot EFI/UEFI.
# Ce firmware remplace le BIOS legacy et permet aux VMs de démarrer en mode UEFI.
#
# Le firmware peut être trouvé sous différentes formes selon la distribution:
# 1. Fichiers séparés CODE/VARS (recommandé): Permet de modifier les variables
#    NVRAM sans toucher au firmware principal
# 2. Fichier combiné: Tout-en-un, moins flexible mais fonctionne aussi
#
# Ordre de recherche (du plus spécifique au plus générique):
# - openSUSE/Fedora: /usr/share/qemu/ovmf-x86_64-{code,vars}.bin
# - Debian/Ubuntu: /usr/share/OVMF/OVMF_{CODE,VARS}.fd
# - Fallback: /usr/share/OVMF/OVMF.fd (fichier combiné)
# ============================================================================
echo "Step 1: Locating OVMF firmware..."

# Recherche prioritaire: fichiers séparés dans /usr/share/qemu/ (openSUSE/Fedora)
# Format: ovmf-x86_64-code.bin et ovmf-x86_64-vars.bin
if [ -f /usr/share/qemu/ovmf-x86_64-code.bin ] && [ -f /usr/share/qemu/ovmf-x86_64-vars.bin ]; then
  OVMF_CODE="/usr/share/qemu/ovmf-x86_64-code.bin"
  OVMF_VARS="/usr/share/qemu/ovmf-x86_64-vars.bin"
  USE_SEPARATE_VARS=true  # Indique qu'on utilise des fichiers séparés
  echo "  Found: ${OVMF_CODE} and ${OVMF_VARS}"

# Recherche alternative: fichiers séparés dans /usr/share/OVMF/ (Debian/Ubuntu)
# Format: OVMF_CODE.fd et OVMF_VARS.fd
elif [ -f /usr/share/OVMF/OVMF_CODE.fd ] && [ -f /usr/share/OVMF/OVMF_VARS.fd ]; then
  OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
  OVMF_VARS="/usr/share/OVMF/OVMF_VARS.fd"
  USE_SEPARATE_VARS=true
  echo "  Found: ${OVMF_CODE} and ${OVMF_VARS}"

# Fallback: fichier combiné OVMF.fd
# Si les fichiers séparés ne sont pas disponibles, on utilise un fichier combiné
# Note: Cette méthode est moins flexible car on ne peut pas modifier les variables
# NVRAM séparément, mais elle fonctionne pour le boot EFI de base
elif [ -f /usr/share/OVMF/OVMF.fd ]; then
  OVMF_CODE="/usr/share/OVMF/OVMF.fd"
  USE_SEPARATE_VARS=false  # Fichier combiné, pas de VARS séparé
  echo "  Found: ${OVMF_CODE} (combined file)"

# Erreur: Aucun firmware OVMF trouvé
# Le script ne peut pas continuer sans firmware UEFI
else
  echo "ERROR: OVMF firmware not found. Please install it first:"
  echo "  Debian/Ubuntu: sudo apt-get install ovmf"
  echo "  openSUSE/SLES: sudo zypper install qemu-ovmf-x86_64"
  echo "  Fedora/RHEL:   sudo dnf install edk2-ovmf"
  exit 1
fi

# ============================================================================
# Étape 2: Vérification de l'existence des fichiers requis
# ============================================================================
# Avant de commencer, on vérifie que tous les fichiers nécessaires existent:
# - ISO: Image ISO Harvester contenant le système live et les images
# - Kernel: Fichier vmlinuz pour démarrer le système live
# - Initrd: Ramdisk initial contenant les modules et scripts de boot
#
# Ces fichiers sont générés lors du build de l'ISO (via 'make').
# ============================================================================
echo "Step 2: Verifying required files..."

# Construction des chemins vers les fichiers requis
# Format: harvester-{VERSION}-{ARCH}.{ext}
ISO_FILE="${ARTIFACTS_DIR}/${PROJECT_PREFIX}-${ARCH}.iso"
KERNEL_FILE="${ARTIFACTS_DIR}/${PROJECT_PREFIX}-vmlinuz-${ARCH}"
INITRD_FILE="${ARTIFACTS_DIR}/${PROJECT_PREFIX}-initrd-${ARCH}"

# Vérification de l'existence de chaque fichier
# Si un fichier manque, on arrête le script avec un message d'erreur explicite
for file in "$ISO_FILE" "$KERNEL_FILE" "$INITRD_FILE"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: Required file not found: $file"
    echo "Please build the ISO first with 'make'"
    exit 1
  fi
done
echo "  All required files found"

# ============================================================================
# Étape 3: Création de l'image disque raw
# ============================================================================
# Création d'une image disque raw de 250GB qui servira de disque virtuel
# pour la VM QEMU. Cette image sera le disque cible pour l'installation de
# Harvester.
#
# Format raw: Format non formaté, accès direct aux secteurs du disque.
# Avantages: Simple, compatible, bonnes performances.
# Inconvénient: Taille fixe (mais peut être compressée après).
#
# Taille 250GB: Suffisante pour:
# - Système d'exploitation Harvester (~10GB)
# - Partition persistante (150GB configurée)
# - Espace pour les VMs et données utilisateur
# ============================================================================
echo "Step 3: Creating raw disk image..."
RAW_FILE="${ARTIFACTS_DIR}/${PROJECT_PREFIX}-${ARCH}.raw"

# Vérification si l'image existe déjà
# Si oui, on demande confirmation avant d'écraser (protection contre perte de données)
if [ -f "$RAW_FILE" ]; then
  read -p "Raw image already exists. Overwrite? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
  # Suppression de l'ancienne image si confirmation
  rm -f "$RAW_FILE"
fi

# Création de l'image raw avec qemu-img
# -f raw: Format raw (non formaté)
# -o size=250G: Taille de 250GB
# Note: Le fichier est créé comme "sparse file" - il n'occupe que l'espace
# réellement écrit sur le disque, pas les 250GB complets
qemu-img create -f raw -o size=250G "$RAW_FILE"
echo "  Created: $RAW_FILE"

# ============================================================================
# Étape 4: Création d'un fichier VARS temporaire (si nécessaire)
# ============================================================================
# Si on utilise des fichiers OVMF séparés (CODE/VARS), on doit créer une
# copie temporaire du fichier VARS car QEMU va le modifier pendant l'exécution
# (écriture des variables NVRAM UEFI).
#
# Pourquoi une copie temporaire?
# - Le fichier VARS original est souvent en lecture seule ou partagé
# - QEMU a besoin d'écrire dedans pour sauvegarder les paramètres UEFI
# - Une copie temporaire évite de modifier le fichier système original
#
# Le trap EXIT garantit que le fichier temporaire sera supprimé même si
# le script est interrompu (Ctrl+C, erreur, etc.)
# ============================================================================
if [ "$USE_SEPARATE_VARS" = true ]; then
  # Création d'un fichier temporaire avec mktemp
  # mktemp crée un fichier unique dans /tmp avec un nom aléatoire
  TEMP_OVMF_VARS=$(mktemp)
  
  # Copie du fichier VARS original vers le temporaire
  cp "$OVMF_VARS" "$TEMP_OVMF_VARS"
  
  # Définition des permissions (644 = rw-r--r--)
  # Permet à QEMU d'écrire dans le fichier
  chmod 644 "$TEMP_OVMF_VARS"
  
  echo "Step 4: Created temporary OVMF VARS: $TEMP_OVMF_VARS"
  
  # Configuration d'un trap pour nettoyer le fichier temporaire à la sortie
  # EXIT: Se déclenche quand le script se termine (normalement ou avec erreur)
  # Garantit le nettoyage même en cas d'interruption
  trap "rm -f $TEMP_OVMF_VARS" EXIT
fi

# ============================================================================
# Étape 5: Construction et exécution de la commande QEMU
# ============================================================================
# Cette étape construit la commande QEMU complète avec tous les paramètres
# nécessaires pour démarrer une VM avec boot EFI et installer Harvester
# automatiquement.
#
# La commande est construite progressivement en ajoutant chaque option.
# Note: On utilise une variable de type chaîne plutôt qu'un tableau car
# certains paramètres contiennent des espaces et doivent être échappés.
# ============================================================================
echo "Step 5: Starting QEMU with EFI boot..."
echo "  This will install Harvester automatically. It may take several minutes..."

# Initialisation de la commande QEMU avec l'exécutable
QEMU_CMD="qemu-system-x86_64"

# Configuration de la machine virtuelle
# q35: Chipset moderne avec meilleur support UEFI que i440fx (legacy)
# accel=kvm: Utilise l'accélération matérielle KVM pour de meilleures performances
QEMU_CMD="$QEMU_CMD -machine q35,accel=kvm"

# CPU: Utilise le CPU de l'hôte (passe toutes les fonctionnalités)
# Permet d'utiliser les extensions CPU modernes (AVX, AES-NI, etc.)
QEMU_CMD="$QEMU_CMD -cpu host"

# Configuration SMP (Symmetric Multi-Processing)
# cores=2: 2 cœurs CPU
# threads=2: 2 threads par cœur (hyperthreading)
# sockets=1: 1 socket CPU
# Total: 4 vCPUs virtuels
QEMU_CMD="$QEMU_CMD -smp cores=2,threads=2,sockets=1"

# Mémoire: 8GB RAM allouée à la VM
# Suffisant pour l'installation et le fonctionnement de Harvester
QEMU_CMD="$QEMU_CMD -m 8192"

# Mode non-graphique: Pas d'interface graphique, sortie sur console
# Utile pour l'automatisation et les environnements sans X11
QEMU_CMD="$QEMU_CMD -nographic"

# Console série principale: Redirigée vers stdout/stderr
# Permet de voir les messages du kernel et du système en temps réel
QEMU_CMD="$QEMU_CMD -serial mon:stdio"

# Console série secondaire: Redirigée vers un fichier de log
# Capture tous les logs d'installation pour analyse ultérieure
QEMU_CMD="$QEMU_CMD -serial file:harvester-installer.log"

# Pas de carte réseau: L'installation automatique n'en a pas besoin
# Toutes les images nécessaires sont déjà dans l'ISO
QEMU_CMD="$QEMU_CMD -nic none"

# ========================================================================
# Ajout du firmware UEFI (OVMF)
# ========================================================================
# Méthode 1 (recommandée): Utilisation de pflash avec fichiers séparés
# - pflash simule une mémoire flash parallèle utilisée par UEFI
# - CODE (readonly): Firmware UEFI principal, non modifiable
# - VARS (read-write): Variables NVRAM modifiables par le système
if [ "$USE_SEPARATE_VARS" = true ]; then
  # Premier pflash: Firmware CODE en lecture seule
  # readonly=on: Protège le firmware contre les modifications accidentelles
  QEMU_CMD="$QEMU_CMD -drive if=pflash,format=raw,readonly=on,file=${OVMF_CODE}"
  
  # Deuxième pflash: Variables NVRAM en lecture/écriture
  # Utilise le fichier temporaire créé à l'étape 4
  QEMU_CMD="$QEMU_CMD -drive if=pflash,format=raw,file=${TEMP_OVMF_VARS}"

# Méthode 2 (fallback): Utilisation de -bios avec fichier combiné
# Moins flexible mais fonctionne si les fichiers séparés ne sont pas disponibles
else
  QEMU_CMD="$QEMU_CMD -bios ${OVMF_CODE}"
fi

# ========================================================================
# Configuration des périphériques de stockage et de boot
# ========================================================================
# Disque virtuel: Image raw créée précédemment
# if=virtio: Interface virtio (meilleures performances que IDE/SATA)
# cache=writeback: Cache en écriture (améliore les performances)
# discard=ignore: Ignore les commandes TRIM (non nécessaire pour raw)
QEMU_CMD="$QEMU_CMD -drive file=${RAW_FILE},if=virtio,cache=writeback,discard=ignore,format=raw"

# CD-ROM: ISO Harvester pour l'installation
# Contient le système live et toutes les images de conteneurs nécessaires
QEMU_CMD="$QEMU_CMD -cdrom ${ISO_FILE}"

# Kernel Linux: Fichier vmlinuz pour démarrer le système live
# Extrait de l'ISO, utilisé pour le boot initial
QEMU_CMD="$QEMU_CMD -kernel ${KERNEL_FILE}"

# Paramètres du kernel: Configuration complète pour le boot depuis ISO
# cdroot root=live:CDLABEL=COS_LIVE: Boot depuis le système live sur CD
# rd.live.dir=/: Répertoire racine du système live
# rd.live.ram=1: Charge le système complet en RAM (plus rapide)
# rd.live.squashimg=rootfs.squashfs: Image squashfs du système de fichiers
# console=ttyS1: Console série sur ttyS1 (pour capturer les logs)
# rd.cos.disable: Désactive certaines fonctionnalités COS non nécessaires
# net.ifnames=1: Utilise les noms d'interface réseau prévisibles (eth0, etc.)
# harvester.install.mode=install: Mode installation (pas mode live)
# harvester.install.device=/dev/vda: Disque cible pour l'installation (/dev/vda = premier disque virtio)
# harvester.install.automatic=true: Installation automatique sans interaction
# harvester.install.powerOff=true: Arrête la VM automatiquement après installation réussie
# harvester.os.password=rancher: Mot de passe par défaut pour l'utilisateur
# harvester.scheme_version=1: Version du schéma de partitionnement à utiliser
# harvester.install.persistentPartitionSize=150Gi: Taille de la partition persistante (données utilisateur)
# harvester.install.skipchecks=true: Ignore les vérifications pré-installation (utile pour tests)
QEMU_CMD="$QEMU_CMD -append \"cdroot root=live:CDLABEL=COS_LIVE rd.live.dir=/ rd.live.ram=1 rd.live.squashimg=rootfs.squashfs console=ttyS1 rd.cos.disable net.ifnames=1 harvester.install.mode=install harvester.install.device=/dev/vda harvester.install.automatic=true harvester.install.powerOff=true harvester.os.password=rancher harvester.scheme_version=1 harvester.install.persistentPartitionSize=150Gi harvester.install.skipchecks=true\""

# Initrd: Ramdisk initial pour le boot
# Contient les modules kernel et scripts nécessaires au démarrage
QEMU_CMD="$QEMU_CMD -initrd ${INITRD_FILE}"

# Boot: Boot depuis CD une seule fois puis disque
# once=d: Boot depuis CD (d) une seule fois, puis utilise l'ordre par défaut
# Après l'installation, le système bootera depuis le disque (/dev/vda)
QEMU_CMD="$QEMU_CMD -boot once=d"

# Exécution de QEMU avec tous les paramètres configurés
# eval est nécessaire car QEMU_CMD contient des espaces et guillemets
# L'installation se fera automatiquement et la VM s'arrêtera à la fin
eval $QEMU_CMD

# ============================================================================
# Étape 6: Affichage des logs d'installation
# ============================================================================
# Affichage des 100 dernières lignes du log d'installation pour vérifier
# que tout s'est bien passé. Utile pour le débogage en cas de problème.
# ============================================================================
echo ""
echo "Step 6: Installation log (last 100 lines):"
echo "=========================================="
# || true: Continue même si tail échoue (fichier vide ou inexistant)
tail -100 harvester-installer.log || true

# ============================================================================
# Étape 7: Vérification de l'installation
# ============================================================================
# Vérifications de base pour s'assurer que l'installation a réussi:
# 1. Le fichier raw existe toujours
# 2. Le fichier n'est pas vide (taille > 0)
# 3. La table de partitions peut être lue (vérification optionnelle)
# ============================================================================
if [ ! -f "$RAW_FILE" ]; then
  echo "ERROR: Raw image file not found after installation"
  exit 1
fi

# Vérification de la taille du fichier
# stat -f%z: macOS/BSD (taille en octets)
# stat -c%s: Linux (taille en octets)
# Le fichier doit avoir une taille > 0 (au moins quelques secteurs écrits)
FILE_SIZE=$(stat -f%z "$RAW_FILE" 2>/dev/null || stat -c%s "$RAW_FILE" 2>/dev/null)
if [ "$FILE_SIZE" -eq 0 ]; then
  echo "ERROR: Raw image file is empty"
  exit 1
fi

# Affichage de la table de partitions pour vérification
# Permet de voir les partitions créées (EFI, OEM, Recovery, State, etc.)
# || echo: Continue même si parted échoue (peut nécessiter root)
echo ""
echo "Step 7: Verifying partition table..."
parted "$RAW_FILE" print || echo "Warning: Could not read partition table (may need root access)"

# ============================================================================
# Étape 8: Compression de l'image raw
# ============================================================================
# Compression de l'image raw avec zstd pour réduire sa taille.
# Les images raw de 250GB peuvent être compressées à ~7-10% de leur taille
# originale car elles contiennent beaucoup d'espaces vides (sparse file).
#
# zstd: Algorithme de compression moderne, rapide et efficace
# -T4: Utilise 4 threads pour la compression (parallélisation)
# --rm: Supprime le fichier original après compression réussie
# Résultat: Fichier .zst beaucoup plus petit et facile à transférer
# ============================================================================
echo ""
echo "Step 8: Compressing raw image..."
COMPRESSED_FILE="${RAW_FILE}.zst"

# Suppression de l'ancien fichier compressé s'il existe
# (au cas où on relance le script)
if [ -f "$COMPRESSED_FILE" ]; then
  rm -f "$COMPRESSED_FILE"
fi

# Compression avec zstd
# Le fichier original sera supprimé automatiquement après compression réussie
zstd -T4 --rm "$RAW_FILE"
echo "  Created: $COMPRESSED_FILE"

# ============================================================================
# Étape 9: Résumé et instructions
# ============================================================================
# Affichage d'un résumé de la création et des instructions pour utiliser
# l'image créée. Inclut aussi des commandes pour vérifier le boot EFI.
# ============================================================================
echo ""
echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
echo "Compressed raw image: $COMPRESSED_FILE"
echo ""
echo "To verify EFI boot was used, check for EFI partition:"
echo "  sudo parted $COMPRESSED_FILE print"
echo ""
echo "Note: The raw image has been compressed and removed."
echo "      To decompress: zstd -d $COMPRESSED_FILE"
