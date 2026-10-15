# Remote dev box runbook (hot reload on k3s)

How the "ideapad" dev box runs MindForge with live backend and UI reload, and every problem we hit getting it
working, with cause and fix. Written 2026-10-15. Companion to [local-k3s-dev.md](local-k3s-dev.md) (the WSL k3s
deploy path); this one is the *inner-loop dev* path.

## 1. What runs where

```
your PC browser ──► Tailscale (tailnet only, HTTPS) ─┬─► 127.0.0.1:3000   next dev        (Fast Refresh)
                                                     └─► 127.0.0.1:18081  labproxy        (/lab-ws, native)
                                  ssh ─────────────────► 127.0.0.1:8090   backend (Air)   (Go hot reload)

k3s cluster on the box (reached by kubectl port-forward, auto-restarted)
  postgres  ─► 127.0.0.1:15432   database `mindforge_dev`, role `mindforge_dev`
  piston    ─► 127.0.0.1:2000    code execution
  lab pods  ─► created by the backend through the kube API (namespace mindforge-labs)

external (from backend/.env)
  Redis        Upstash
  object store Backblaze B2 (MINIO_* keys; private bucket for lab bundles)
```

| Piece | Why this way |
|---|---|
| Database, not a schema | The baseline migration hard-codes `public.`; a schema would isolate nothing. |
| Loopback `DATABASE_URL` | `config.IsLocalDB()` is true for 127.0.0.1, so dev fixtures auto-seed on every boot. |
| labproxy runs natively | The cluster's labproxy reads *its own* database and can never see the dev backend's lab sessions. |
| Everything on 127.0.0.1 | Nothing is exposed to the LAN. Remote access is Tailscale or an SSH tunnel. |
| Backend on :8090 | :8080 is taken by Jenkins on the box. |

## 2. Set up (one time)

1. Clone the repo on the box, copy `.env` and `backend/.env` from your main machine (they are gitignored).
2. `bash scripts/setup-dev-box.sh` — installs make/go/bun/kubectl/psql/openssl/tailscale, sets kubeconfig,
   `tailscale serve` (`/` and `/lab-ws`), creates the `mindforge_dev` database and role in the cluster Postgres
   (over `kubectl exec`, no superuser secret read), writes `DATABASE_URL`, `PORT`, `KUBECONFIG`, `PISTON_URL`,
   `LABS_RUNTIME`, `LAB_TOKEN_SECRET`, and the frontend's `BACKEND_URL`, `NEXT_ALLOWED_DEV_ORIGINS`,
   `NEXT_PUBLIC_LAB_PROXY_URL`. Idempotent; a backup of the old env is kept as `backend/.env.bak.<ts>`.
3. `make dev-k3s`. Open the Tailscale URL the setup printed.
4. Optional end-to-end check: `bash scripts/e2e-dev-lab.sh`.

Do **not** `source backend/.env` in a shell (see issue 11). Read single values with `grep`.

### Access without Tailscale

`ssh -L 3000:localhost:3000 -L 18081:localhost:18081 user@box`, then browse `http://localhost:3000`. The lab
terminal's default `ws://localhost:18081` then works unchanged and `localhost` counts as a secure context. Tailscale
gives one stable HTTPS URL that only your own devices can use; both are fine.

## 3. Problems and fixes

### Environment and cluster

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `kubectl` prints Jenkins HTML ("Authentication required… hudson.model") | k3s `kubectl` defaults to `/etc/rancher/k3s/k3s.yaml` (root-only), then falls back to `localhost:8080` = Jenkins | Use `~/.kube/config` (`KUBECONFIG`); scripts set it. |
| 2 | `bun: command not found` | Installed to `~/.bun/bin`, not on `PATH` | Scripts add it; setup appends to `~/.bashrc`. |
| 3 | Port-forward errors "address already in use" on 5432/6379/2000 | Stale forwards or other services on the box | `dev-k3s.sh` kills stale `kubectl port-forward`/labproxy at start; Postgres is forwarded to 15432, not 5432. |
| 4 | `svc "piston" not found` | Piston lives in namespace `mindforge-piston`, not `mindforge-labs` | Forward from the right namespace. |
| 5 | Backend exits "minio: ensure bucket failed … localhost:9000" | `statefulset/minio` was scaled to 0 in the cluster | Object storage is external (B2) via `MINIO_*`; no MinIO forward. |
| 6 | Backend exits "required secret env var is not set key=LAB_TOKEN_SECRET" | Not in the copied `.env` | Must equal the in-cluster labproxy's value (distinct from `JWT_SECRET`); setup copies it from the cluster secret. |
| 7 | "Sign-in is temporarily unavailable" / "We couldn't reach the server" | Backend not running (port taken or crashed) | Check `curl 127.0.0.1:8090/health`; run `server.exe` in the foreground to see the real error. |
| 8 | Backend can't bind, UI proxies to Jenkins | `PORT=8080` collides with Jenkins | `PORT=8090`, frontend `BACKEND_URL=http://127.0.0.1:8090`. |
| 9 | `.env` setting ignored (still `MINIO_ENDPOINT=localhost:9000`) | `godotenv.Load()` never overrides variables already in the shell; an earlier `set -a; source backend/.env` exported old values | `dev-k3s.sh` unsets every key the file defines before starting. |
| 10 | Sourcing `.env` fails oddly / `psql` connects to a local socket | The URL contains an unquoted `&` so bash backgrounds the line and truncates it | Read with `grep -m1 '^DATABASE_URL=' … \| cut -d= -f2-`. |
| 11 | `KUBECONFIG=C:\Users\…` in the box's `.env` | `.env` copied from Windows | Setup rewrites it to `~/.kube/config`; `dev-k3s.sh` sets it *after* the unset. |
| 12 | `pkill -f "make dev-k3s"` over SSH kills the SSH command itself | The pattern matches its own command line | Use `pkill -f "[m]ake dev-k3s"`. |
| 13 | A backgrounded SSH command dies when the call ends | SSH session closes and sends SIGHUP | Start with `setsid nohup … &` on the box. |
| 14 | `pkill` "Operation not permitted" on `next-server` | It belongs to a cluster pod (user `sysbox`), not your dev server | Leave it alone. |

### Frontend

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 15 | HMR websocket blocked, edits never appear | `allowedDevOrigins` hard-coded a LAN IP | `NEXT_ALLOWED_DEV_ORIGINS` (comma-separated) in `frontend/.env.local`. |
| 16 | CSP "Executing inline script violates… sha256-…" in the console | Same hash every time = a browser extension injecting a script, not the app (no inline scripts in `app/`, `components/`, `lib/`) | Ignore, or confirm in an incognito window. |
| 17 | Passkey `SecurityError` on the login page | WebAuthn RP ID is for another domain | Harmless; password sign-in works. |

### Data, fixtures, labs

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 18 | `make migrate` / `make seed` fail "container mindforge_postgres_dev not running" | They shell into the Docker Postgres | Not needed: the backend migrates on boot and, with a loopback DB, seeds all fixtures on every boot. |
| 19 | Fixtures not seeded on a remote (Neon) DB | `SeedDev` is gated on `IsLocalDB()` so `ENV=development` can't seed a remote DB | Use the k3s Postgres via port-forward (loopback). `DEV_SEED_REMOTE_DB=true` (with `ENV=development`) is an explicit opt-in for a remote dev DB; never effective in production/staging. |
| 20 | Linux course missing | New course files were untracked on one machine and course content is DB rows loaded from `*.generated.sql` | Commit the content and fixture; seed loads it. `master` already had its own Linux course (#29/#30), so the branch took master's version. |
| 21 | "Lab not available yet" on a production-debugging lab | The lab was unpublished: all 47 recipe builds failed with `lab-bundles/….tar.gz: Key not found` | Bundles live in the **private** bucket (`MINIO_PRIVATE_BUCKET`, default `<bucket>-private`) and are uploaded by `coursegen blocks sync`, not by loading SQL: `cd backend && go run ./cmd/coursegen blocks sync --out /tmp/lab-blocks.sql` (with `MINIO_*` in the environment). The 15-minute `lab.platform_recipes` job then builds and publishes. |
| 22 | Lab starts but "This lab is not available for your organization" (`lab_image_not_allowed`) | `lab-k8s`/`lab-docker` are `nested-docker` profile images and need an org allowlist; the old `lab_org_config` block in `dev_seed.sql` was commented out against a table that doesn't exist | `dev_seed.sql` sets `org_settings.labs.allowed_images` (all-or-nothing: list every image the fixtures use, incl. `lab-debug:1`). |
| 23 | Editing a fixture `.sql` changes nothing | Fixtures/migrations are `//go:embed`-ed and Air only rebuilt on `.go` | `.air.toml` `include_ext = ["go", "sql"]`. |

### Lab terminal

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 24 | Lab page opens (timer, tasks) but terminal says "Disconnected / Connection lost" | The session is created server-side, but the **browser** opens the terminal websocket straight to labproxy. The default `ws://localhost:18081` is the *viewer's* machine | `tailscale serve --bg --set-path /lab-ws http://127.0.0.1:18081` (Tailscale strips the prefix, like Caddy) and `NEXT_PUBLIC_LAB_PROXY_URL=wss://<host>/lab-ws` in `frontend/.env.local`. NEXT_PUBLIC values are inlined at build, so restart. labproxy also needs `LABPROXY_ALLOWED_ORIGINS` to include the page origin (set by `dev-k3s.sh`). |
| 25 | Lab session stuck `provisioning`, pod `Pending`, event `Insufficient cpu` | 4-CPU node, 83% already requested: the 47 recipe builds run 1-CPU `mindforge-validate-build-*` pods and a lab pod queues behind them | Wait for the builds, or free CPU. **Open:** throttle build concurrency so background builds can't starve user labs. Check with `kubectl get pods -n mindforge-labs` and `kubectl describe node`. |

### Accounts, email, MFA

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 26 | Admin sign-in demands a TOTP code you don't have | MFA is mandatory for privileged roles (super_admin, org admins) | Reset in the **dev** DB only (below). The next sign-in shows the enrolment screen; add the secret to an authenticator app or use `oathtool --totp -b <secret>`. |
| 27 | Registration "We sent a verification link…" but no email | `ENV=development` only mails addresses in `DEV_EMAIL_ALLOWLIST`, matched exactly (`name+tag@…` is a different string); others are logged as `DEV EMAIL: … suppressed (dev)`. Tokens are never logged | Mark verified in SQL (below), or add the exact address to `DEV_EMAIL_ALLOWLIST` and restart (SMTP creds must be set). |

### Repo and process

| # | Problem | Fix |
|---|---|---|
| 28 | One PR mixed dev-box, k8s and course changes (`git add scripts` and an already-staged index swept unrelated files into commits) | Split by feature (#33 dev box, #34 k8s external Neon, #35 courses); the old PR was reverted to master and closed. Stage files by name. |
| 29 | Merge conflict with master on the Linux course | Same course merged separately; kept master's version (it had a newer lab scenario). |
| 30 | GitGuardian "Generic Password" on `scripts/e2e-dev-lab.sh` | The script hard-coded the dev seed password. It now reads it from the `dev_seed.sql` header. The earlier commit still contains it: mark the incident a false positive/test credential in the GitGuardian dashboard. |
| 31 | A real DB password was pasted into chat | Rotate it in the Neon console and update `backend/.env`. Never paste terminal output that includes `DATABASE_URL`. |

## 4. Reference

### Dev accounts

Seeded by `backend/db/fixtures/dev_seed.sql`; the password for all of them is in that file's header. Dev DB only.
`student@`, `instructor@`, `mentor@mindforge.dev` have no MFA. `orgadmin@` and `admin@mindforge.dev` require MFA.

### Reset MFA for the dev admin (dev DB only; check the target host first)

```bash
DB=$(grep -m1 '^DATABASE_URL=' backend/.env | cut -d= -f2-)
echo "$DB" | sed -E 's#.*@([^/?]+)/([^?]+).*#target: \1 / \2#'      # expect 127.0.0.1:15432 / mindforge_dev
psql "$DB" -v ON_ERROR_STOP=1 -c "
delete from user_mfa_recovery_codes where user_id=(select id from users where email='admin@mindforge.dev');
delete from user_mfa where user_id=(select id from users where email='admin@mindforge.dev');"
```

### Mark an account's email verified (dev DB only)

```bash
psql "$DB" -c "update users set email_verified = true where email = 'someone+tag@example.com'"
```

### Useful checks

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8090/health      # backend
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18081/health     # labproxy
kubectl get pods -n mindforge-labs                                        # lab and build pods
kubectl describe node | grep -A6 'Allocated resources'                    # CPU headroom
psql "$DB" -Atc "select status, count(*) from lab_builds group by 1"      # recipe build progress
tail -f ~/dev-k3s.log                                                     # when started with setsid nohup
```

## 5. Open items

- Throttle lab-recipe build concurrency so it cannot starve user lab sessions on a small node (issue 25).
- Decide whether to make dev MFA optional for privileged roles under `ENV=development` (security-sensitive; not done).
- Rotate any credential that was pasted into chat (issue 31).
