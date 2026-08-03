#!/bin/bash
set -euo pipefail

log() { echo "[entrypoint] $*"; }

log "starting dockerd"
# Plain root dockerd — no rootlesskit. sysbox-runc already gives this
# container's root user a real (safely virtualized) root, so the rootless
# wrapper entrypoint.sh uses for the default mechanism would only add a
# redundant, conflicting layer of user-namespacing on top of sysbox's own
# (see docs/labs.md "Nested Docker labs": rootlesskit's newuidmap fails with
# "Operation not permitted" when nested inside a sysbox-runc container).
dockerd >/tmp/dockerd.log 2>&1 &

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

# dockerd's socket is root:root 0660 by default, and the platform always
# execs setup/verification/terminal-adjacent commands as non-root labuser
# (docs/labs.md "Verification runs as non-root") — without this, every such
# `docker` command labuser runs fails with "permission denied while trying
# to connect to the Docker daemon socket" even though the container itself
# is healthy (same class of issue entrypoint.sh documents for the rootless
# image's own socket, just root-owned here instead of labuser-owned).
chmod 0666 /var/run/docker.sock

log "loading preloaded base images"
for tarball in /opt/preload/*.tar; do
  docker load -i "$tarball" >/dev/null
done

log "starting in-sandbox registry on :5000"
# Unlike entrypoint.sh's rootless-dind variant, a published port (not
# --network host) is fine here: sysbox-runc's real (non-rootlesskit)
# networking is exactly what fixes the "failed to disable IPv6 on
# container's interface eth0" veth bug this image class otherwise hits, so
# ordinary bridge networking works for our own registry container too.
docker run -d --name registry --restart=no -p 5000:5000 registry:2 >/dev/null \
  || log "warning: registry failed to start — offline registry exercises won't work this session, terminal still will"

touch /tmp/lab-ready

log "starting ttyd as labuser"
# dockerd needs root; ttyd's shell must not (see docs/labs.md "Verification
# runs as non-root" — the same rule applies to the interactive terminal).
exec su-exec labuser sh -c 'cd /home/labuser/work && exec ttyd -W -p 7681 bash'
