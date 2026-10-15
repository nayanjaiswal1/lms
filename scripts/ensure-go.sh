#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/ensure-go.sh — Make sure a Go toolchain that satisfies backend/go.mod is
# available, without root: use the Go already on PATH when it is new enough,
# otherwise download the exact release into a user-owned cache (the sha256 comes
# from go.dev's release index and is checked before anything is unpacked).
#
# Prints the directory to put on PATH (the bin/ of the toolchain to use):
#   export PATH="$(bash scripts/ensure-go.sh):$PATH"
#
# Used by the Jenkins 'Lab artifacts' stage, whose agent (the laptop/WSL box)
# otherwise needs nothing but Docker. GO_CACHE overrides the cache directory
# (default $HOME/.cache/mindforge-go). Progress goes to stderr; stdout is only
# the directory.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_MOD="${SCRIPT_DIR}/../backend/go.mod"
CACHE="${GO_CACHE:-$HOME/.cache/mindforge-go}"

die() { echo "ensure-go: $*" >&2; exit 1; }

for tool in curl python3 sha256sum tar; do
  command -v "$tool" >/dev/null || die "'$tool' is required to fetch a Go toolchain (apt install curl python3 coreutils tar)"
done

need="$(awk '/^go [0-9]/ {print $2; exit}' "$GO_MOD")"
[[ "$need" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "cannot read the go version from $GO_MOD"

# version_ge A B: A >= B (dotted versions, missing patch = 0)
version_ge() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$2" ]]; }

if command -v go >/dev/null; then
  have="$(go env GOVERSION | sed 's/^go//; s/[^0-9.].*$//')"
  if [[ -n "$have" ]] && version_ge "$have" "$need"; then
    dirname "$(command -v go)"
    exit 0
  fi
fi

case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) die "unsupported architecture $(uname -m)" ;;
esac
[[ "$(uname -s)" == "Linux" ]] || die "only Linux agents are supported"

root="$CACHE/go$need"
if [[ -x "$root/go/bin/go" ]]; then
  echo "$root/go/bin"
  exit 0
fi

file="go${need}.linux-${arch}.tar.gz"
sha="$(curl -fsSL --retry 3 'https://go.dev/dl/?mode=json&include=all' |
  python3 -c 'import json,sys; v,f=sys.argv[1:3]; print(next((x["sha256"] for r in json.load(sys.stdin) if r["version"]==v for x in r["files"] if x["filename"]==f), ""))' "go${need}" "$file")"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "go.dev publishes no sha256 for $file"

mkdir -p "$CACHE"
tmp="$(mktemp -d "$CACHE/.tmp-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
echo "ensure-go: downloading $file" >&2
curl -fsSL --retry 3 -o "$tmp/$file" "https://go.dev/dl/$file"
echo "$sha  $tmp/$file" | sha256sum -c - >&2 || die "sha256 mismatch for $file"
mkdir "$tmp/out"
tar -xzf "$tmp/$file" -C "$tmp/out"
rm -rf "$root"
mkdir -p "$root"
mv "$tmp/out/go" "$root/go"
echo "$root/go/bin"
