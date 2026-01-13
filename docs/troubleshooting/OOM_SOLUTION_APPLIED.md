# OOM Solution Applied

## Problem
The build was failing with an OOM (Out Of Memory) error because the `elemental` process was using ~4.7GB of RAM during xz compression.

## Applied Solutions

### 1. Compression Change: xz → gzip

**Modified File:** `scripts/package-harvester-os` (line 128)

**Before:**
```bash
-x "-comp xz"
```

**After:**
```bash
-x "-comp gzip"
```

**Impact:**
- xz: requires ~5GB RAM, smaller files
- gzip: requires ~2GB RAM, slightly larger files
- ~60% reduction in memory usage

### 2. Memory Release

Temporarily stopped Minecraft containers that were using ~4.5GB total:
- minecraft-hardcore (~750MB)
- minecraft-plat (~1.16GB)
- minecraft-creatif (~1.9GB)
- minecraft-aventure (~1GB)

## Restart Containers After Build

Once the build is complete, you can restart the containers:

```bash
docker start minecraft-hardcore minecraft-plat minecraft-creatif minecraft-aventure
```

## Verification

The build should now succeed with:
- Less memory required (gzip instead of xz)
- More RAM available (containers stopped)

## Note

If you prefer to keep xz compression (smaller files), you will need to:
1. Increase swap (if possible)
2. Or have more RAM available
3. Or stop more containers/services

To revert to xz, modify line 128 in `scripts/package-harvester-os`:
```bash
-x "-comp xz"
```
