#!/bin/bash
# Runs after every Write/Edit tool call.
# Checks file type and runs the appropriate validator so Claude self-corrects immediately.
# Output is deduped and trimmed so a noisy/repetitive tool doesn't burn tokens.

input=$(cat)
file=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

if [[ -z "$file" ]]; then
  exit 0
fi

BACKEND_DIR="$(dirname "$0")/../../backend"
FRONTEND_DIR="$(dirname "$0")/../../frontend"

# Collapses repeated identical lines (order-preserving) and caps total length —
# a tool that repeats the same warning per package/file shouldn't cost tokens
# once for every repetition.
condense() {
  awk '!seen[$0]++' | head -30
}

if [[ "$file" == *.go ]]; then
  cd "$BACKEND_DIR" 2>/dev/null || exit 0
  go vet ./... 2>&1 | condense
elif [[ "$file" == *.ts ]] || [[ "$file" == *.tsx ]]; then
  cd "$FRONTEND_DIR" 2>/dev/null || exit 0
  pnpm tsc --noEmit 2>&1 | condense
  # eslint accepts an absolute path directly, so no relative-path conversion needed.
  # boundaries/dependencies legacy-selector warning is repo-wide config noise,
  # unrelated to the edited file — drop it before condensing the real output.
  pnpm exec eslint "$file" 2>&1 | grep -v '^\[boundaries\]\|legacy selector syntax\|migration-guides' | condense
fi
