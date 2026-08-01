#!/bin/bash
set -euo pipefail

log() { echo "[entrypoint] $*"; }

# setup_script runs as root (see container.go's Start) so it can provision
# privileged things, but --cap-drop ALL strips CAP_DAC_OVERRIDE even from
# root — meaning root cannot traverse labuser's home directory at its
# default 0750 mode to reach a workdir, regardless of that workdir's own
# permissions. Loosen the home directory to 0755 (traversable); the workdir
# itself is already created+chowned in the Dockerfile.
chmod 755 /home/labuser

log "starting rootless dockerd"
# The base image's own dockerd-entrypoint.sh already contains the correct
# rootlesskit-wrapping logic for a non-root uid (verified interactively: this
# is NOT reimplemented here because getting the rootlesskit flags/newuidmap
# checks/TLS cert generation exactly right by hand is exactly the kind of
# thing that silently breaks on a base-image bump).
/usr/local/bin/dockerd-entrypoint.sh dockerd >/tmp/dockerd.log 2>&1 &

log "waiting for dockerd readiness"
ready=""
for _ in $(seq 1 70); do
  if docker info >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ -z "$ready" ]; then
  log "dockerd never became ready; last log lines:"
  tail -n 60 /tmp/dockerd.log || true
  exit 1
fi
log "dockerd ready"

# rootlesskit creates the socket 0660 labuser:labuser. The platform runs a
# lab's setup_script and verification_script as root (`docker exec --user
# root`, container.go), and this container's profile is --cap-drop ALL plus
# only SYS_ADMIN/SETUID/SETGID — no CAP_DAC_OVERRIDE — so root has no way
# past those 0660 bits and every `docker` command it runs fails with
# "permission denied while trying to connect to the Docker daemon socket".
# That is what made this image's setup_script (a `docker info` readiness
# poll) spin until the provisioning deadline while the container itself was
# perfectly healthy. Widening the socket grants nothing new: root here
# already holds SYS_ADMIN over the sandbox, labuser already owns the socket,
# and the socket is reachable only inside this container's own namespaces.
chmod 0666 "${XDG_RUNTIME_DIR:-/run/user/1000}/docker.sock"

log "loading preloaded base images"
for tarball in /opt/preload/*.tar; do
  docker load -i "$tarball" >/dev/null
done

log "starting in-sandbox registry on :5000"
# --network host, not a published port on the default bridge: creating any
# bridge-networked container (a fresh veth pair) inside this rootless-in-
# rootless nesting fails on at least some kernels with "failed to disable
# IPv6 on container's interface eth0: unknown" (confirmed reproducible even
# with IPv6 fully disabled at every other level — outer sysctl, per-container
# --sysctl, and a --ipv6=false user-defined network all hit the identical
# error; only --network host avoids creating a veth at all). --network host
# means the registry binds directly into this sandbox's own network
# namespace, so "localhost:5000" from the student's terminal reaches it
# exactly the same as a published port would have — no behavior change for
# the registry's own usage, just a different (working) plumbing choice.
# A registry hiccup must not take the whole session down with it (this
# script is the container's PID 1, under `set -e`), so failure here is
# logged, not fatal.
docker run -d --name registry --restart=no --network host registry:2 >/dev/null \
  || log "warning: registry failed to start — offline registry exercises won't work this session, terminal still will"

log "starting ttyd"
exec ttyd -W -p 7681 bash
