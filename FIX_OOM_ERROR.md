# Fix: Erreur OOM (Out Of Memory) lors du build

## Problème identifié

Le build échoue avec :
```
./package-harvester-os: line 129: 10056 Killed
time="2026-01-08T16:37:52+01:00" level=fatal msg="exit status 137"
```

**Cause :** Le processus `elemental` a été tué par l'OOM killer car il utilisait ~4.7GB de RAM et le système n'avait plus de mémoire disponible.

**Preuve :**
```
Out of memory: Killed process 3657258 (elemental) total-vm:9564368kB, anon-rss:4787456kB
```

## État actuel du système

- **RAM totale :** 12GB
- **RAM utilisée :** 8.3GB
- **RAM disponible :** 4.3GB
- **Swap :** 2.0GB (complètement utilisé)

## Solutions

### Solution 1 : Augmenter le swap (Recommandé)

Créer un fichier swap supplémentaire :

```bash
# Créer un fichier swap de 4GB
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Rendre permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Vérifier
free -h
```

### Solution 2 : Libérer de la mémoire

Arrêter les conteneurs non essentiels :

```bash
# Voir les conteneurs en cours
docker ps

# Arrêter les conteneurs non nécessaires (exemple)
docker stop <container-name>

# Ou arrêter tous les conteneurs sauf ceux critiques
docker ps --format "{{.Names}}" | grep -v "mariadb\|nextcloud" | xargs docker stop
```

### Solution 3 : Limiter la mémoire des conteneurs Docker

Modifier la configuration Docker/podman pour limiter la mémoire :

```bash
# Pour podman, créer/modifier ~/.config/containers/containers.conf
mkdir -p ~/.config/containers
cat > ~/.config/containers/containers.conf <<EOF
[containers]
default_memory = "6G"
EOF
```

### Solution 4 : Utiliser une compression moins gourmande

Modifier temporairement la compression dans `scripts/package-harvester-os` :

```bash
# Changer de xz à gzip (moins gourmand en mémoire)
# Ligne 128 dans package-harvester-os
# De: -x "-comp xz"
# À:  -x "-comp gzip"
```

### Solution 5 : Build en plusieurs étapes

Construire l'ISO sans compression d'abord, puis compresser séparément.

## Solution rapide (recommandée)

Exécuter ces commandes pour augmenter le swap :

```bash
# Créer 4GB de swap supplémentaire
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Vérifier
free -h

# Relancer le build
cd /root/harvester-installer
make
```

## Vérification après fix

```bash
# Vérifier la mémoire
free -h

# Vérifier que le swap est actif
swapon --show

# Surveiller le build
tail -f /tmp/build.log
```

## Notes

- Le build d'ISO nécessite beaucoup de mémoire pour la compression
- La compression xz est très gourmande en mémoire mais produit des fichiers plus petits
- Avec plus de swap, le build sera plus lent mais devrait réussir
