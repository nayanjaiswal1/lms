#!/bin/bash
# /opt/mindforge/grade.sh <mode> --seed <seed>
#
# Root-owned generic grader wrapper (docs/debug-labs.md §4). Runs in the
# CLEAN-ROOM grader sandbox (labs.GradeInCleanRoom): a throwaway container
# seeded with the pristine workspace plus only the student's editable files,
# so nothing here is ever readable from the student's own container.
#
#   stdin   the grader bundle (tar.gz: grader.json, tests/, fixtures/, ...)
#   argv    <mode>      a mode defined in the bundle's grader.json
#           --seed S    server-random per-Check seed (hex); names the scratch DB
#   stdout  exactly one JSON object: {"mode","passed","checks":[{name,passed,message?}],"error"?}
#           (author-written messages only — no test source, no expected values)
#   stderr  diagnostics for platform logs; never shown to the student
#   exit    0 whenever a JSON verdict was produced (pass/fail lives in the JSON)
#
# All mode semantics live in the bundle's grader.json and the image's
# /opt/mindforge/grader engine — nothing here hard-codes a lab kind's modes.
set -uo pipefail

WORKDIR=/home/labuser/work
ENGINE=/opt/mindforge/grader/run_grade.py
MAX_BUNDLE_BYTES=1048576

json_error() {
  printf '{"mode":"%s","passed":false,"checks":[],"error":"%s"}\n' "${MODE_SAFE:-unknown}" "$1"
}

MODE="${1:-}"
[ $# -ge 1 ] && shift
SEED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --seed) SEED="${2:-}"; shift 2 || break ;;
    *) MODE_SAFE=unknown; json_error "usage: grade.sh <mode> --seed <seed>"; exit 0 ;;
  esac
done

if ! [[ "$MODE" =~ ^[a-z][a-z0-9-]{0,31}$ ]]; then
  MODE_SAFE=unknown; json_error "invalid mode"; exit 0
fi
MODE_SAFE="$MODE"
if ! [[ "$SEED" =~ ^[0-9a-f]{8,64}$ ]]; then
  json_error "invalid seed"; exit 0
fi

TMP="$(mktemp -d /tmp/mf-grade.XXXXXX)"
chmod 700 "$TMP"
DB="grade_${SEED:0:24}"

cleanup() {
  mf-svc clear-env >/dev/null 2>&1 || true
  for db in "$DB" "${DB}_base"; do
    psql -q -h 127.0.0.1 -U labuser -d template1 \
      -c "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)" >/dev/null 2>&1 || true
  done
  cd / && rm -rf "$TMP"
}
trap cleanup EXIT

# Read the bundle from stdin with a hard size cap (the platform caps grader
# bundles at 512 KB; anything past the cap is rejected, not truncated).
head -c $((MAX_BUNDLE_BYTES + 1)) >"$TMP/grader.tar.gz"
if [ "$(stat -c %s "$TMP/grader.tar.gz")" -gt "$MAX_BUNDLE_BYTES" ] || [ ! -s "$TMP/grader.tar.gz" ]; then
  json_error "grader bundle missing or too large"; exit 0
fi

# Refuse absolute paths and traversal before extracting anything.
if ! tar -tzf "$TMP/grader.tar.gz" >"$TMP/listing" 2>/dev/null; then
  json_error "grader bundle unreadable"; exit 0
fi
if grep -Eq '(^/|(^|/)\.\.(/|$))' "$TMP/listing"; then
  json_error "grader bundle contains unsafe paths"; exit 0
fi
mkdir -p "$TMP/grader"
if ! tar -xzf "$TMP/grader.tar.gz" -C "$TMP/grader" --no-same-owner --no-same-permissions 2>/dev/null; then
  json_error "grader bundle extraction failed"; exit 0
fi
# Symlinks in a bundle could point the engine at arbitrary files.
if find "$TMP/grader" -type l | grep -q .; then
  json_error "grader bundle contains symlinks"; exit 0
fi

# Clean-room readiness: the image's own database must be serving.
if [ -x /usr/local/bin/lab-ready ] && ! /usr/local/bin/lab-ready >/dev/null 2>&1; then
  for _ in $(seq 1 40); do
    /usr/local/bin/lab-ready >/dev/null 2>&1 && break
    sleep 0.5
  done
fi

cd "$WORKDIR" || { json_error "workspace missing"; exit 0; }

# -I: the engine ignores PYTHON* env vars, user site and the cwd on sys.path.
python3 -I "$ENGINE" \
  --mode "$MODE" --seed "$SEED" \
  --grader-dir "$TMP/grader" --workdir "$WORKDIR" --tmp "$TMP" --db "$DB"
status=$?
if [ $status -ne 0 ]; then
  json_error "grader engine failed"
fi
exit 0
