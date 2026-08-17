#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/deploy-remote-k3s.sh — Deploy MindForge to a k3s box over SSH.
#
# Usage: scripts/deploy-remote-k3s.sh <user@host> [domain] [--force-clear-docker]
#   user@host             SSH target. Needs a working k3s install (or root
#                          enough to get one — see setup-k3s-local.sh).
#                          Use the target's mDNS name (e.g. nayan@ideapad.local),
#                          not a bare IP — a DHCP lease change silently breaks
#                          an IP-pinned target on the next run, while
#                          <hostname>.local keeps resolving to whatever the
#                          box's current IP is (Avahi/mDNS, already running by
#                          default on Ubuntu — no setup needed). If you pass a
#                          bare IP anyway, the script still works for this one
#                          run, but re-resolves and warns if it drifts.
#   domain                Hostname the app is served on (self-signed HTTPS).
#                          Defaults to the target's own mDNS name
#                          (<remote-hostname>.local) — same IP-independence
#                          reasoning as above, so the app URL never needs
#                          updating either. Override only if you have a real
#                          domain or a different mDNS setup.
#   --force-clear-docker  sysbox-ce's installer refuses to run with ANY
#                          existing docker container (even stopped ones) and
#                          wants them removed. Without this flag the script
#                          aborts and lists them instead of deleting anything
#                          on your behalf.
#
# What this does, in order (everything past step 2 delegates to the project's
# own scripts — this file only handles the parts specific to "reach a machine
# over SSH and drive them," not deploy logic itself):
#   1. Verify SSH key auth works (set it up yourself first — ssh-copy-id — this
#      script won't send your password over the wire for repeated commands).
#   2. One-time: passwordless sudo for the SSH user via a scoped sudoers.d
#      drop-in. Needed because scripts/bootstrap-k3s-local.sh and friends call
#      bare `sudo` internally many times over a run that's too long for a
#      single cached ticket, and there's no TTY on a non-interactive SSH
#      command for sudo to prompt on. Skipped (no prompt) if already set up.
#   3. Transfer the current working tree to ~/mindforge on the target (same
#      excludes as docs/local-k3s-dev.md's manual rsync instructions).
#   4. Ensure helm is on PATH remotely — bootstrap-k3s-local.sh's own PATH
#      preflight check requires it before its own step that installs it.
#   5. Patch the transferred copy's local-overlay domain from the WSL default
#      (mindforge.127.0.0.1.nip.io) to the target's mDNS domain — REMOTE COPY
#      ONLY, so the repo's checked-in k8s/overlays/local stays the generic
#      WSL-default it's documented to be.
#   6. Ensure sysbox-ce is installed remotely (installs it if missing).
#   7. Run scripts/bootstrap-k3s-local.sh on the target — same one-command
#      path documented for local WSL use, just executed over SSH.
#
# Safe to re-run against the same host (every step is idempotent, matching
# the scripts it calls). Re-run any time to redeploy after code changes — the
# same command works even if the box's IP changed since the last run.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

TARGET="${1:-}"
[[ -n "$TARGET" ]] || error "Usage: $0 <user@host> [domain] [--force-clear-docker]"
shift

DOMAIN=""
FORCE_CLEAR_DOCKER=false
for arg in "$@"; do
  case "$arg" in
    --force-clear-docker) FORCE_CLEAR_DOCKER=true ;;
    *) DOMAIN="$arg" ;;
  esac
done

# Retries only on 255 (ssh's own connection-level failure — resolution blip,
# refused, reset — never returned by the remote command itself) so a transient
# mDNS hiccup on a quick preflight check doesn't abort the whole run; a real
# failure in the remote command still propagates its actual exit code
# immediately. Safe to retry full multi-minute remote commands too (e.g. the
# bootstrap script) since everything they call is already idempotent —
# docker's build cache makes a restart from scratch fast, not a full redo.
ssh_target() {
  local attempt rc
  for attempt in 1 2 3 4 5; do
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes "$TARGET" "$@"
    rc=$?
    [[ $rc -ne 255 ]] && return $rc
    [[ $attempt -lt 5 ]] && sleep 3
  done
  return 255
}

# ─── 1. SSH key auth ──────────────────────────────────────────────────────────
info "Checking SSH key auth to ${TARGET}..."
ssh_target true 2>/dev/null || error "Passwordless SSH to ${TARGET} isn't set up. Run: ssh-copy-id ${TARGET} (or manually append your ~/.ssh/id_ed25519.pub to its ~/.ssh/authorized_keys), then re-run this script."
success "SSH key auth works."

TARGET_HOST="${TARGET#*@}"
if [[ "$TARGET_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  warn "${TARGET} is IP-pinned — if this box's DHCP lease changes, this exact command will stop working. Prefer its mDNS name instead: ${TARGET%@*}@$(ssh_target hostname 2>/dev/null || echo '<hostname>').local"
fi

# ─── 2. Passwordless sudo (one-time) ─────────────────────────────────────────
if ssh_target sudo -n true 2>/dev/null; then
  info "Passwordless sudo already set up on ${TARGET} — skipping."
else
  warn "This deploy runs many long-lived scripts that call bare 'sudo' internally, over a non-interactive SSH session with no TTY to prompt on. One-time fix: a scoped sudoers.d drop-in granting NOPASSWD to this SSH user only."
  if [[ -n "${DEPLOY_SUDO_PASSWORD:-}" ]]; then
    SUDO_PW="$DEPLOY_SUDO_PASSWORD"
  else
    read -r -s -p "One-time sudo password for ${TARGET} (not stored, used only to write the sudoers drop-in; or set DEPLOY_SUDO_PASSWORD to skip this prompt): " SUDO_PW
    echo
  fi
  REMOTE_USER="${TARGET%@*}"
  echo "$SUDO_PW" | ssh_target "sudo -S -v" 2>/dev/null || error "sudo authentication failed."
  echo "$SUDO_PW" | ssh_target "sudo -S bash -c 'echo \"${REMOTE_USER} ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/mindforge-deploy && chmod 440 /etc/sudoers.d/mindforge-deploy && visudo -cf /etc/sudoers.d/mindforge-deploy'" \
    || error "Failed to write /etc/sudoers.d/mindforge-deploy."
  unset SUDO_PW
  ssh_target sudo -n true 2>/dev/null || error "sudoers drop-in written but passwordless sudo still isn't working — check /etc/sudoers.d/mindforge-deploy on the target."
  success "Passwordless sudo configured (/etc/sudoers.d/mindforge-deploy on ${TARGET})."
fi

# ─── 3. Transfer the working tree ────────────────────────────────────────────
info "Transferring ${PROJECT_ROOT} to ${TARGET}:~/mindforge..."
ssh_target "mkdir -p ~/mindforge"
if command -v rsync &>/dev/null; then
  rsync -a --delete --exclude node_modules --exclude .next --exclude .pnpm-store \
    --exclude bin --exclude .git -e "ssh -o BatchMode=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes" "${PROJECT_ROOT}/" "${TARGET}:~/mindforge/"
else
  # Raw ssh here, not ssh_target: a dropped connection mid-stream can't be
  # resumed by retrying just the ssh leg — the local tar process has already
  # moved past whatever bytes the dead ssh consumed, so a partial retry would
  # feed the new ssh a corrupt, truncated tar stream. Instead retry the WHOLE
  # tar+ssh pipeline together — each attempt starts a fresh tar from byte
  # zero, which is the only way to guarantee a consistent stream.
  TRANSFER_OK=false
  for attempt in 1 2 3; do
    if tar -czf - --exclude=node_modules --exclude=.next --exclude=.pnpm-store --exclude=bin --exclude=.git \
        -C "$(dirname "$PROJECT_ROOT")" "$(basename "$PROJECT_ROOT")" \
        | ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes \
          "$TARGET" "rm -rf ~/mindforge && tar -xzf - -C ~/"; then
      TRANSFER_OK=true
      break
    fi
    warn "Transfer attempt ${attempt}/3 failed (likely a dropped connection mid-stream) — retrying..."
    sleep 3
  done
  [[ "$TRANSFER_OK" == true ]] || error "Transfer to ${TARGET} failed after 3 attempts."
fi
REMOTE_COUNT="$(ssh_target "find ~/mindforge -type f | wc -l")"
success "Transferred (${REMOTE_COUNT} files on target)."

# ─── 4. helm on PATH (bootstrap-k3s-local.sh's own preflight needs it first) ──
if ssh_target "command -v helm" &>/dev/null; then
  info "helm already on PATH remotely — skipping."
else
  info "Installing helm remotely (bootstrap-k3s-local.sh's PATH preflight requires it before its own install step)..."
  ssh_target "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get_helm.sh && chmod +x /tmp/get_helm.sh && sudo /tmp/get_helm.sh" >/dev/null
  ssh_target "command -v helm" &>/dev/null || error "helm install failed."
  success "helm installed."
fi

# ─── 5. Point the local overlay at this machine's mDNS domain ───────────────
# mDNS (<hostname>.local), not <ip>.nip.io: nip.io bakes a literal IP into the
# hostname it resolves to, so it breaks the moment the box's DHCP lease
# changes. Avahi (already running by default on Ubuntu — verified, not
# assumed, by the check below) answers <hostname>.local with whatever the
# box's current IP actually is, so this domain never goes stale.
if [[ -z "$DOMAIN" ]]; then
  if ! ssh_target "systemctl is-active --quiet avahi-daemon" 2>/dev/null; then
    error "avahi-daemon isn't running on ${TARGET} — can't derive a stable mDNS domain. Install/enable it (sudo apt install avahi-daemon) or pass a domain explicitly: $0 ${TARGET} <domain>"
  fi
  REMOTE_HOSTNAME="$(ssh_target hostname)"
  [[ -n "$REMOTE_HOSTNAME" ]] || error "Couldn't read ${TARGET}'s hostname."
  DOMAIN="${REMOTE_HOSTNAME}.local"
  info "No domain given — using ${TARGET}'s mDNS name: ${DOMAIN} (stable across IP changes)"
fi
info "Pointing the local overlay at ${DOMAIN} (remote copy only)..."
ssh_target "cd ~/mindforge && sed -i 's/mindforge\\.127\\.0\\.0\\.1\\.nip\\.io/${DOMAIN}/g' \
  k8s/overlays/local/configmap-domain.patch.yaml \
  k8s/overlays/local/kustomization.yaml \
  scripts/build-k3s-local-images.sh \
  scripts/bootstrap-k3s-local.sh"
success "Local overlay targets ${DOMAIN}."

# ─── 6. sysbox-ce (nested-docker lab support) ────────────────────────────────
if ssh_target "command -v sysbox-runc" &>/dev/null; then
  info "sysbox-runc already installed remotely — skipping."
else
  info "Installing sysbox-ce remotely..."
  ARCH="$(ssh_target "dpkg --print-architecture")"
  EXISTING="$(ssh_target "docker ps -aq" 2>/dev/null || true)"
  if [[ -n "$EXISTING" ]]; then
    if [[ "$FORCE_CLEAR_DOCKER" == true ]]; then
      warn "Removing existing docker containers on ${TARGET} (--force-clear-docker): sysbox-ce's installer refuses to restart docker with any container present."
      ssh_target "docker rm -f \$(docker ps -aq)" >/dev/null
    else
      ssh_target "docker ps -a"
      error "sysbox-ce's installer needs docker ps -a empty (it restarts docker to reconfigure it) — see containers listed above on ${TARGET}. Re-run with --force-clear-docker to remove them, or clear them yourself first."
    fi
  fi
  LATEST_TAG="$(curl -fsSL https://api.github.com/repos/nestybox/sysbox/releases/latest | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)"
  [[ -n "$LATEST_TAG" ]] || error "Couldn't resolve latest sysbox-ce release tag from GitHub."
  DEB_VERSION="${LATEST_TAG#v}"
  DEB_URL="https://github.com/nestybox/sysbox/releases/download/${LATEST_TAG}/sysbox-ce_${DEB_VERSION}.linux_${ARCH}.deb"
  info "Fetching ${DEB_URL}..."
  ssh_target "curl -fsSL -o /tmp/sysbox-ce.deb '${DEB_URL}' && sudo apt-get install -y /tmp/sysbox-ce.deb" >/dev/null \
    || error "sysbox-ce install failed — check the deb exists for arch ${ARCH} at ${DEB_URL}."
  ssh_target "command -v sysbox-runc" &>/dev/null || error "sysbox-ce installed but sysbox-runc still not on PATH."
  success "sysbox-ce installed."
fi

# ─── 7. Run the project's own bootstrap ──────────────────────────────────────
# KUBECONFIG set explicitly (not relying on ~/.bashrc): the project's scripts
# `export KUBECONFIG=~/.kube/config` themselves, but only within their own
# process — a sibling script invoked later (e.g. setup-sysbox-local.sh, which
# restarts k3s and needs kubectl right after) doesn't inherit that export
# from a script that already exited, and ~/.bashrc's copy of the same export
# is never sourced by a non-interactive `bash script.sh`. Setting it once here
# makes it inherited by every child process for the whole run.
info "Running scripts/bootstrap-k3s-local.sh on ${TARGET} (this builds all app images, pushes lab images, deploys, and verifies — can take a while)..."
ssh_target "cd ~/mindforge && KUBECONFIG=\$HOME/.kube/config bash scripts/bootstrap-k3s-local.sh"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployed to ${TARGET}${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "  App: https://${DOMAIN} (accept the self-signed cert warning)"
echo "  Redeploy after code changes: $0 ${TARGET}"
echo "  (domain and SSH target are both mDNS-based, so this keeps working even if ${TARGET}'s IP changes)"
echo ""
