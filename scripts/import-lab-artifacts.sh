#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/import-lab-artifacts.sh — Import a CI-verified labset (platform labs
# built and verified offline by `coursegen blocks verify --artifact`) into an
# environment. See docs/debug-labs.md "Platform labs: CI artifacts".
#
# Usage:
#   bash scripts/import-lab-artifacts.sh --target k8s   DIR   # Jenkins deploy: kubectl exec into deploy/backend
#   bash scripts/import-lab-artifacts.sh --target local DIR   # dev box: go run with backend/.env
#   ... [--assemble-only]   with --from-cache: assemble + validate DIR, then stop before importing
#                     (Jenkins "Check labs" gate, runs before Deploy)
#   ... [--partial]   import only DIR's recipes (authoring one recipe; never on a deploy)
#   ... [--from-cache CACHE]   first assemble DIR (new/empty) from a verify cache
#                     with `coursegen blocks verify --artifact DIR --cached-only`
#                     for this environment's runtime id; fails if any platform
#                     recipe is not in CACHE (Jenkins "Import labs")
#
# The expected runtime id is read from THIS environment's lab image with
# `docker run --entrypoint cat` (never by starting a lab pod): the import
# refuses a labset verified against a different grader/renderer.
#
# LAB_IMAGE   Optional. Overrides the lab image to read the stamp from
#             (default: <LABS_IMAGE_REGISTRY>/mindforge/lab-debug:1, the
#             registry taken from the mindforge-config ConfigMap for k8s or
#             backend/.env for local).
# NAMESPACE   Optional. App namespace for --target k8s (default: mindforge).
#
# The labset is secret (graders, fix and cheat overlays): it is streamed to the
# pod over stdin and never written anywhere public.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB_IMAGE_NAME="mindforge/lab-debug:1"
STAMP_PATH="/opt/mindforge/RUNTIME_ID"
NAMESPACE="${NAMESPACE:-mindforge}"

die() { echo "import-lab-artifacts: $*" >&2; exit 1; }
usage() { die "usage: $0 --target k8s|local [--partial] [--from-cache CACHE] LABSET_DIR"; }

target="" partial="" dir="" from_cache="" assemble_only=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="${2:-}"; shift 2 ;;
    --partial) partial="--partial"; shift ;;
    --assemble-only) assemble_only=1; shift ;;
    --from-cache) from_cache="${2:-}"; shift 2 ;;
    -*) usage ;;
    *) [[ -z "$dir" ]] || usage; dir="$1"; shift ;;
  esac
done
[[ "$target" == "k8s" || "$target" == "local" ]] || usage
[[ -n "$dir" ]] || usage
[[ -z "$assemble_only" || -n "$from_cache" ]] || die "--assemble-only needs --from-cache"
[[ -z "$from_cache" || -d "$from_cache" ]] || die "--from-cache $from_cache is not a directory"
command -v docker >/dev/null || die "docker is required to read the lab image's runtime stamp"

if [[ -z "${LAB_IMAGE:-}" ]]; then
  if [[ "$target" == "k8s" ]]; then
    registry="$(kubectl get configmap mindforge-config -n "$NAMESPACE" -o jsonpath='{.data.LABS_IMAGE_REGISTRY}')"
  else
    # grep, never `source`: an unquoted '&' in backend/.env would background the line.
    registry="$(grep -m1 '^LABS_IMAGE_REGISTRY=' "$PROJECT_ROOT/backend/.env" | cut -d= -f2- || true)"
  fi
  LAB_IMAGE="${registry:+${registry}/}${LAB_IMAGE_NAME}"
fi

runtime_id="$(docker run --rm --pull missing --entrypoint cat "$LAB_IMAGE" "$STAMP_PATH" | tr -d '[:space:]')"
[[ -n "$runtime_id" ]] || die "$LAB_IMAGE carries no runtime stamp at $STAMP_PATH"

if [[ -n "$from_cache" ]]; then
  mkdir -p "$dir"
  dir="$(cd "$dir" && pwd)"
  from_cache="$(cd "$from_cache" && pwd)"
  (cd "$PROJECT_ROOT/backend" && go run ./cmd/coursegen blocks verify --artifact "$dir" --cache "$from_cache" \
     --cached-only --runtime-id "$runtime_id")
fi
[[ -f "$dir/manifest.json" ]] || die "$dir is not a labset (no manifest.json)"
dir="$(cd "$dir" && pwd)"
if [[ -n "$assemble_only" ]]; then
  echo "import-lab-artifacts: $dir complete for lab runtime ${runtime_id:0:12} (assemble-only, nothing imported)"
  exit 0
fi
echo "import-lab-artifacts: $dir -> $target (lab runtime ${runtime_id:0:12} from $LAB_IMAGE)"

if [[ "$target" == "k8s" ]]; then
  tar -C "$dir" -cf - . |
    kubectl exec -i -n "$NAMESPACE" deploy/backend -- /app/coursegen blocks import --expect-runtime-id "$runtime_id" $partial -
else
  cd "$PROJECT_ROOT/backend"
  go run ./cmd/coursegen blocks import --expect-runtime-id "$runtime_id" $partial "$dir"
fi
