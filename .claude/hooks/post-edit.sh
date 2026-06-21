#!/bin/bash
# Runs after every Write/Edit tool call.
# Checks file type and runs the appropriate validator so Claude self-corrects immediately.

input=$(cat)
file=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

if [[ -z "$file" ]]; then
  exit 0
fi

BACKEND_DIR="$(dirname "$0")/../../backend"
FRONTEND_DIR="$(dirname "$0")/../../frontend"

if [[ "$file" == *.go ]]; then
  cd "$BACKEND_DIR" 2>/dev/null && go build ./... 2>&1 | head -30
elif [[ "$file" == *.ts ]] || [[ "$file" == *.tsx ]]; then
  cd "$FRONTEND_DIR" 2>/dev/null && pnpm tsc --noEmit 2>&1 | head -30
fi
