# mindforge/lab-docker — teaches Docker itself, so this is the one lab image
# that needs a real Docker daemon running INSIDE the student's own sandbox
# container (nested Docker-in-Docker). Every other lab image runs with
# --cap-drop ALL and no added capabilities; this one is the deliberate,
# narrowly-scoped, operator+org-gated exception described in
# docs/labs.md "Nested Docker labs" — it only ever gets its elevated
# container config when its image is mapped to the "nested-docker" profile
# in BOTH the operator's LABS_IMAGE_PROFILES and the requesting org's
# lab_org_config.allowed_images (backend/internal/labs/container.go,
# backend/internal/labs/service.go StartSession).
#
# Verified interactively against the real flags container.go's buildRunArgs
# emits (--cap-drop ALL --cap-add SYS_ADMIN --cap-add SETUID --cap-add SETGID
# --device /dev/fuse --device /dev/net/tun --security-opt seccomp=unconfined
# --security-opt apparmor=unconfined, network mindforge-labs-dind): rootless
# dockerd needs SETUID/SETGID (not just SYS_ADMIN) for newuidmap/newgidmap to
# succeed, and /dev/net/tun for rootlesskit's vpnkit network driver to create
# its tap interface — SYS_ADMIN + /dev/fuse alone is not sufficient. Storage
# driver is left to dockerd's own auto-detection (overlay2 vs
# fuse-overlayfs) rather than forced, since overlay2-in-a-userns works on a
# modern kernel and fuse-overlayfs is strictly slower when it isn't needed.
#
# The lab network has no internet (see the create-course skill, Path 1) —
# every base image a student's docker build/run will need is preloaded here,
# then docker-load'd by the entrypoint at container boot. Registry-push
# exercises target the in-sandbox registry:2 on localhost:5000, never Docker
# Hub.
#
# preload/*.tar are pre-fetched `docker save` output, checked in rather than
# pulled at image-build time (originally tried a crane-in-a-builder-stage
# approach — abandoned after it stalled repeatedly pulling from Docker Hub in
# a proxied environment that a plain `docker pull` on the host sailed through
# in ~10s each; using the same already-working `docker pull` removes that
# entire failure mode along with the extra build stage and the crane
# dependency). Regenerate after bumping any of the five image tags below:
#   docker pull alpine:3.20 busybox:1.36 nginx:1.27-alpine python:3.12-alpine registry:2
#   docker save alpine:3.20 -o preload/alpine.tar
#   docker save busybox:1.36 -o preload/busybox.tar
#   docker save nginx:1.27-alpine -o preload/nginx.tar
#   docker save python:3.12-alpine -o preload/python.tar
#   docker save registry:2 -o preload/registry.tar
FROM docker:27-dind-rootless

# The base image's own default USER is already the non-root "rootless"
# account — switch back to root explicitly for package installs and the
# user rename below, since apk (and usermod/groupmod) both need root.
USER root
RUN apk add --no-cache bash ttyd shadow curl

# The base image's default user is "rootless" (uid 1000) — every other lab
# image, and the backend's hardcoded `docker exec --user labuser` (both
# container.go's Exec and render_lab.go's verification_script execution),
# expects that exact username. Rename rather than add a second account: a
# second uid-1000 user would fight the existing one for the home directory
# and the /etc/subuid /etc/subgid rootless mapping. usermod/groupmod handle
# the passwd/group/home-dir rename; the subuid/subgid files reference the
# username directly and need the same substitution or rootlesskit's startup
# check (`grep -qE "^($uid|$user):"` in dockerd-entrypoint.sh) stops matching.
RUN usermod -l labuser -d /home/labuser -m rootless \
    && groupmod -n labuser rootless \
    && sed -i 's/^rootless:/labuser:/' /etc/subuid /etc/subgid

COPY preload/ /opt/preload/
COPY entrypoint.sh /usr/local/bin/mindforge-entrypoint.sh
RUN chmod +x /usr/local/bin/mindforge-entrypoint.sh \
    && mkdir -p /home/labuser/work \
    && chown -R labuser:labuser /home/labuser/work

# The readiness contract the backend polls (labs.ReadinessProbePath): exit 0
# once this sandbox is usable, non-zero while it is still booting. An image
# without this file is treated as ready immediately, so only images with
# background services need one. entrypoint.sh writes the marker only after
# dockerd, the preloaded base images, and the registry are all up — a
# `docker info` probe would go green well before that.
RUN printf '#!/bin/sh\n[ -f /tmp/lab-ready ]\n' > /usr/local/bin/lab-ready \
    && chmod +x /usr/local/bin/lab-ready

USER labuser
WORKDIR /home/labuser/work

# DOCKER_HOST must point at the rootless daemon's own socket
# (/run/user/1000/docker.sock) — the base image's baked-in default
# (tcp://docker:2375) assumes a separate sibling "docker" container/hostname
# that does not exist in this single-container setup.
ENV DOCKER_HOST=unix:///run/user/1000/docker.sock

EXPOSE 7681

ENTRYPOINT ["/usr/local/bin/mindforge-entrypoint.sh"]
