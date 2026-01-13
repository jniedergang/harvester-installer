# Fix: OOM (Out Of Memory) Error During Build

## Identified Problem

The build fails with:
```
./package-harvester-os: line 129: 10056 Killed
time="2026-01-08T16:37:52+01:00" level=fatal msg="exit status 137"
```

**Cause:** The `elemental` process was killed by the OOM killer because it was using ~4.7GB of RAM and the system had no more available memory.

**Evidence:**
```
Out of memory: Killed process 3657258 (elemental) total-vm:9564368kB, anon-rss:4787456kB
```

## Current System State

- **Total RAM:** 12GB
- **Used RAM:** 8.3GB
- **Available RAM:** 4.3GB
- **Swap:** 2.0GB (completely used)

## Solutions

### Solution 1: Increase Swap (Recommended)

Create an additional swap file:

```bash
# Create a 4GB swap file
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make it permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify
free -h
```

### Solution 2: Free Up Memory

Stop non-essential containers:

```bash
# View running containers
docker ps

# Stop non-essential containers (example)
docker stop <container-name>

# Or stop all containers except critical ones
docker ps --format "{{.Names}}" | grep -v "mariadb\|nextcloud" | xargs docker stop
```

### Solution 3: Limit Docker Container Memory

Modify Docker/podman configuration to limit memory:

```bash
# For podman, create/modify ~/.config/containers/containers.conf
mkdir -p ~/.config/containers
cat > ~/.config/containers/containers.conf <<EOF
[containers]
default_memory = "6G"
EOF
```

### Solution 4: Use Less Memory-Intensive Compression

Temporarily modify compression in `scripts/package-harvester-os`:

```bash
# Change from xz to gzip (less memory-intensive)
# Line 128 in package-harvester-os
# From: -x "-comp xz"
# To:  -x "-comp gzip"
```

### Solution 5: Build in Multiple Steps

Build the ISO without compression first, then compress separately.

## Quick Solution (Recommended)

Run these commands to increase swap:

```bash
# Create 4GB of additional swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Verify
free -h

# Restart the build
cd /root/harvester-installer
make
```

## Verification After Fix

```bash
# Verify memory
free -h

# Verify swap is active
swapon --show

# Monitor the build
tail -f /tmp/build.log
```

## Notes

- ISO build requires a lot of memory for compression
- xz compression is very memory-intensive but produces smaller files
- With more swap, the build will be slower but should succeed
