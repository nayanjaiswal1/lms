#!/usr/bin/env bash
# End-to-end lab check against the local dev stack (run on the `make dev-k3s` box): API login -> start lab -> mint ws token
# -> terminal websocket through labproxy -> run a command -> end lab. Uses the seeded dev student.
set -uo pipefail
API=http://127.0.0.1:8090; JAR=/tmp/e2e.jar; LABTITLE="${1:-Create and Inspect Pods}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB=$(grep -m1 '^DATABASE_URL=' "$ROOT/backend/.env" | cut -d= -f2-)
TSHOST=$(grep -m1 '^NEXT_ALLOWED_DEV_ORIGINS=' "$ROOT/frontend/.env.local" | cut -d= -f2-)
WAIT_SECS="${WAIT_SECS:-240}"
# One source for the dev password: the header comment of the seed that creates the accounts.
SEED_PW=$(grep -m1 'Password for all dev users:' "$ROOT/backend/db/fixtures/dev_seed.sql" | sed 's/.*users: *//' | tr -d '[:cntrl:]')
[ -n "$SEED_PW" ] || { echo "cannot read the dev password from dev_seed.sql" >&2; exit 1; }
csrf() { awk '$6=="csrf_token"{print $7}' "$JAR"; }
j() { python3 -c "import sys,json;d=json.load(sys.stdin);print(eval('d'+sys.argv[1]))" "$1"; }
step() { printf '\n== %s\n' "$*"; }

step "login"
rm -f "$JAR"
curl -s -c "$JAR" -H 'Content-Type: application/json' -X POST $API/api/auth/login \
  -d "$(python3 -c 'import json,sys;print(json.dumps({"email":"student@mindforge.dev","password":sys.argv[1]}))' "$SEED_PW")" -o /dev/null -w 'HTTP %{http_code}'; echo

step "find lab: $LABTITLE"
LAB=$(psql "$DB" -Atc "select id from lab_definitions where is_published and title ilike '%${LABTITLE}%' limit 1")
echo "lab_id=$LAB"; [ -n "$LAB" ] || { echo "FAIL: no published lab"; exit 1; }

step "end any active session left by an earlier run"
for old in $(curl -s -b "$JAR" $API/api/labs/sessions/active | python3 -c "import sys,json;d=json.load(sys.stdin).get('data');d=d if isinstance(d,list) else ([d] if d else []);print(' '.join(x.get('session_id') or x.get('id') for x in d))" 2>/dev/null); do
  curl -s -b "$JAR" -H "X-CSRF-Token: $(csrf)" -X POST $API/api/labs/sessions/$old/end -o /dev/null -w "ended $old HTTP %{http_code}
"; done

step "start session"
RES=$(curl -s -b "$JAR" -H "X-CSRF-Token: $(csrf)" -H 'Content-Type: application/json' -X POST $API/api/labs/$LAB/sessions -d '{}')
echo "$RES" | cut -c1-200
SID=$(echo "$RES" | j "['data']['id']" 2>/dev/null)
echo "session_id=$SID"; [ -n "$SID" ] || { echo "FAIL: no session id"; exit 1; }

step "wait for session ready (max ${WAIT_SECS}s; a Pending pod means the node has no free CPU)"
for i in $(seq 1 $((WAIT_SECS/3))); do
  ST=$(curl -s -b "$JAR" $API/api/labs/sessions/$SID | python3 -c "import sys,json;d=json.load(sys.stdin);d=d.get('data',d);print(d.get('status') or d.get('session',{}).get('status'))")
  printf '%s ' "$ST"; case "$ST" in active|running|ready) break;; failed|error|expired) echo; echo "FAIL: $ST"; exit 1;; esac; sleep 3
done; echo

step "mint ws token"
TOK=$(curl -s -b "$JAR" -H "X-CSRF-Token: $(csrf)" -X POST $API/api/labs/sessions/$SID/ws-token | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('data',d)['session_token'])")
echo "token length: ${#TOK}"
[ -n "$TOK" ] || { echo "FAIL: no ws token - the session never became ready (check: kubectl get pods -n mindforge-labs)"; exit 1; }

step "terminal websocket via labproxy (:18081) and via Tailscale path"
export TOK ORIGIN="https://${TSHOST}"
cat > /tmp/e2e-ws.ts <<'TS'
const url = process.env.WS_URL!;
const ws = new WebSocket(url, { protocols: ["mf-lab", process.env.TOK!], headers: { Origin: process.env.ORIGIN! } } as any);
ws.binaryType = "arraybuffer";
let out = "";
const done = (code: number) => { console.log(out.replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "").slice(-400)); process.exit(code); };
ws.onopen = () => {
  ws.send(JSON.stringify({ AuthToken: "", columns: 100, rows: 30 }));
  setTimeout(() => ws.send("0echo E2E_$((6*7)); kubectl version --client 2>&1 | head -1; whoami\r"), 2500);
};
ws.onmessage = (e: MessageEvent) => {
  const b = typeof e.data === "string" ? new TextEncoder().encode(e.data) : new Uint8Array(e.data);
  if (b[0] === 0x30) out += new TextDecoder().decode(b.subarray(1));
  if (out.includes("E2E_42")) setTimeout(() => done(0), 1500);
};
ws.onerror = (e: any) => { console.log("WS ERROR", e?.message ?? ""); done(2); };
ws.onclose = (e: any) => { console.log("WS CLOSED", e.code); done(3); };
setTimeout(() => { console.log("TIMEOUT"); done(4); }, 25000);
TS
export PATH=$HOME/.bun/bin:$PATH
echo "-- direct labproxy"; WS_URL=ws://127.0.0.1:18081/ws bun /tmp/e2e-ws.ts; R1=$?
echo "-- via tailscale /lab-ws (wss)"; WS_URL="wss://${TSHOST}/lab-ws/ws" bun /tmp/e2e-ws.ts; R2=$?

step "end session"
curl -s -b "$JAR" -H "X-CSRF-Token: $(csrf)" -X POST $API/api/labs/sessions/$SID/end -o /dev/null -w "HTTP %{http_code}\n"
echo; echo "RESULT direct=$R1 tailscale=$R2 (0 = pass)"
