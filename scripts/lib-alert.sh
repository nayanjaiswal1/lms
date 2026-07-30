#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/lib-alert.sh — shared failure-alert trap for backup/restore scripts.
# Sourced, not executed directly.
#
# Usage (after `set -euo pipefail` and sourcing .env.prod):
#   source "${SCRIPT_DIR}/lib-alert.sh"
#   trap 'alert_on_failure "backup-prod.sh"' ERR
#
# Requires BACKUP_ALERT_WEBHOOK in the environment (e.g. from .env.prod) — a
# Slack/Discord/generic incoming-webhook URL. If unset, failures still exit
# non-zero as before, just without a notification.
# ══════════════════════════════════════════════════════════════════════════════

alert_on_failure() {
  local exit_code=$?
  local script_name="$1"
  [[ -n "${BACKUP_ALERT_WEBHOOK:-}" ]] || exit "$exit_code"
  local payload
  payload="$(printf '{"text":"[mindforge] %s failed on %s (exit %d). Check logs on the server."}' \
    "$script_name" "$(hostname)" "$exit_code")"
  curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
    -d "$payload" "$BACKUP_ALERT_WEBHOOK" >/dev/null 2>&1 || true
  exit "$exit_code"
}
