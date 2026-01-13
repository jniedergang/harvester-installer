# Fix Applied: Docker Socket Issue

## Problem
The build was failing with:
```
Error: statfs /var/run/docker.sock: no such file or directory
time="2026-01-08T16:25:02+01:00" level=fatal msg="exit status 125"
```

## Root Cause
- Dapper (the build tool) expects a Docker socket at `/var/run/docker.sock`
- Podman doesn't create this socket by default
- The build system was configured to use podman instead of docker

## Solution Applied

1. **Enabled podman.socket systemd service:**
   ```bash
   sudo systemctl enable --now podman.socket
   ```
   This creates a socket at `/run/podman/podman.sock`

2. **Created symlink to docker.sock:**
   ```bash
   sudo ln -sf /run/podman/podman.sock /var/run/docker.sock
   ```
   This makes podman's socket available at the expected docker location

3. **Verified docker compatibility:**
   ```bash
   docker ps  # Should work now
   ```

## Verification

Check if the socket is working:
```bash
ls -la /var/run/docker.sock
docker ps
```

The socket should be a symlink pointing to `/run/podman/podman.sock`

## Persistence

The podman.socket service is now enabled, so it will start automatically on boot. The symlink should persist, but if it doesn't, you can recreate it:

```bash
sudo ln -sf /run/podman/podman.sock /var/run/docker.sock
```

## Build Status

After applying this fix, the build should proceed past the docker socket error. Monitor with:

```bash
tail -f /tmp/build.log
```
