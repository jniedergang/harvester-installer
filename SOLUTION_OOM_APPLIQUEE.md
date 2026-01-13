# Solution OOM appliquée

## Problème
Le build échouait avec une erreur OOM (Out Of Memory) car le processus `elemental` utilisait ~4.7GB de RAM lors de la compression xz.

## Solutions appliquées

### 1. Changement de compression : xz → gzip

**Fichier modifié :** `scripts/package-harvester-os` (ligne 128)

**Avant :**
```bash
-x "-comp xz"
```

**Après :**
```bash
-x "-comp gzip"
```

**Impact :**
- xz : nécessite ~5GB RAM, fichiers plus petits
- gzip : nécessite ~2GB RAM, fichiers légèrement plus grands
- Réduction de ~60% de l'utilisation mémoire

### 2. Libération de mémoire

Arrêt temporaire des conteneurs Minecraft qui utilisaient ~4.5GB au total :
- minecraft-hardcore (~750MB)
- minecraft-plat (~1.16GB)
- minecraft-creatif (~1.9GB)
- minecraft-aventure (~1GB)

## Relancer les conteneurs après le build

Une fois le build terminé, vous pouvez relancer les conteneurs :

```bash
docker start minecraft-hardcore minecraft-plat minecraft-creatif minecraft-aventure
```

## Vérification

Le build devrait maintenant réussir avec :
- Moins de mémoire requise (gzip au lieu de xz)
- Plus de RAM disponible (conteneurs arrêtés)

## Note

Si vous préférez garder la compression xz (fichiers plus petits), vous devrez :
1. Augmenter le swap (si possible)
2. Ou avoir plus de RAM disponible
3. Ou arrêter plus de conteneurs/services

Pour revenir à xz, modifiez la ligne 128 dans `scripts/package-harvester-os` :
```bash
-x "-comp xz"
```
