#!/usr/bin/env bash
# Egress filtering for lab sandboxes on the lab host (audit H1).
# Run as root on the lab host; idempotent. Persist across reboots (systemd unit
# or iptables-persistent) — DOCKER-USER is recreated by dockerd on restart, so
# re-run after every Docker restart.
#
# Lab containers get public-internet egress only: no RFC1918, CGNAT, link-local
# (cloud metadata 169.254.169.254), no other lab bridge, and no host services.
# LAB_POOL must equal the base of "default-address-pools" in daemon.json so
# every per-session network falls inside it.
set -euo pipefail

LAB_POOL="${LAB_POOL:?set LAB_POOL to the daemon.json default-address-pools base, e.g. 172.28.0.0/14}"
CHAIN="MINDFORGE-LABS"
PRIVATE_RANGES=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 100.64.0.0/10)

iptables -N "$CHAIN" 2>/dev/null || true
iptables -F "$CHAIN"
# Replies to connections initiated from outside (labproxy -> terminal) pass.
iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
# Same-bridge traffic (labproxy <-> its session container) is not egress.
iptables -A "$CHAIN" -s "$LAB_POOL" -d "$LAB_POOL" -m physdev --physdev-is-bridged -j RETURN
for range in "${PRIVATE_RANGES[@]}"; do
  iptables -A "$CHAIN" -s "$LAB_POOL" -d "$range" -j DROP
done
iptables -A "$CHAIN" -j RETURN

# Forwarded traffic from lab bridges.
iptables -C DOCKER-USER -s "$LAB_POOL" -j "$CHAIN" 2>/dev/null || iptables -I DOCKER-USER 1 -s "$LAB_POOL" -j "$CHAIN"

# Traffic to the host itself (agent port, SSH, ...) from lab bridges is INPUT.
iptables -N "$CHAIN-IN" 2>/dev/null || true
iptables -F "$CHAIN-IN"
iptables -A "$CHAIN-IN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
iptables -A "$CHAIN-IN" -j DROP
iptables -C INPUT -s "$LAB_POOL" -j "$CHAIN-IN" 2>/dev/null || iptables -I INPUT 1 -s "$LAB_POOL" -j "$CHAIN-IN"

echo "labhost-egress: rules installed for $LAB_POOL"
