# Local Kubernetes dev — k3s in WSL

Runs the full MindForge stack on a real Kubernetes cluster (k3s) inside WSL2, using the **same manifests** (`k8s/base/`) the cloud deploy uses — only `k8s/overlays/local/` differs from `k8s/overlays/prod/`, the same way `prod` already differs per-cloud (domain, secrets, image registry).

This exists for testing the actual k8s deployment path locally before/instead of `docker-compose.dev.yml` — e.g. verifying the Gateway API routing, RBAC, NetworkPolicy, and resource limits actually work, not just the application code.

## Why WSL, why k3s

- **WSL**: Docker builds and `k3s ctr images import` need a real Linux filesystem for reasonable speed — running against `/mnt/c/...` (the Windows-mounted drive) is dramatically slower for anything that touches many small files (`node_modules`, Go module cache). The repo gets rsynced into WSL's native filesystem (`~/mindforge`) rather than worked on directly from `/mnt/c`.
- **k3s**: lightweight, single-binary Kubernetes — bundles containerd, a local-path storage provisioner (so PVCs just work), and Traefik (which we use as the cluster's Gateway API implementation).

## Architecture decisions

| Decision | Why |
|---|---|
| **Gateway API, not Ingress+ingress-nginx** | `kubernetes/ingress-nginx` (the project) was retired/archived by the Kubernetes Steering and Security Response Committees on **2026-03-31** — no further security patches will ever ship. Gateway API is the maintained, industry-standard successor. This changed `k8s/base/` itself (`gateway.yaml` + `httproute.yaml` replace the old `ingress.yaml`), so it benefits the cloud deploy too, not just local. |
| **k3s's bundled Traefik as the Gateway API implementation** | Traefik ≥ v3 supports Gateway API v1.4 natively; k3s already bundles it, so no second ingress controller to install. Its Gateway API provider is off by default — `k8s/local-cluster-setup/traefik-gateway-helmchartconfig.yaml` turns it on. |
| **cert-manager with Gateway API support, local `selfSigned` ClusterIssuer** | Same `cert-manager.io/cluster-issuer: letsencrypt-prod` annotation as prod (baked into `k8s/base/gateway.yaml`, zero patching needed) — only the ClusterIssuer *implementation* differs per environment: self-signed locally (`k8s/local-cluster-setup/selfsigned-issuer.yaml` — browser will show an untrusted-certificate warning, expected), real ACME in prod. There's no way to get a browser-trusted cert for a cluster with no public domain, so this is the correct floor for local dev, not a shortcut. |
| **`mindforge.127.0.0.1.nip.io` as the local hostname** | `nip.io` is public DNS that resolves any `<anything>.<IP>.nip.io` to `<IP>` — so this resolves to `127.0.0.1` with zero configuration. Avoids editing `C:\Windows\System32\drivers\etc\hosts`, which needs admin rights. WSL2's localhost-forwarding makes k3s's LoadBalancer ports (80/443, bound by Traefik) reachable at `localhost` from Windows, which is what this hostname resolves to. |
| **App images (backend/labproxy/frontend): built locally, imported into k3s's containerd — no registry** | k3s runs its own containerd, separate from the docker daemon's image store — `docker build` alone is invisible to it. `docker save <image> \| sudo k3s ctr images import -` copies it across without needing a registry (local or remote) for a single-node dev cluster. These are rebuilt on every code change (`scripts/build-k3s-local-images.sh`), so the manual-import step stays visible and hard to forget. |
| **Lab sandbox images (lab-docker, lab-k8s, ...): pushed to a registry instead** | Unlike the app images, lab images are referenced by *content* (course frontmatter, `LABS_IMAGE_PROFILES`) that's meant to be identical across every environment — baking a registry host into those bare names would break that portability, and a course can reference a lab image (e.g. `mindforge/lab-k8s:1.31`) without anyone re-running an images script that has no reason to know about it. A real registry (`scripts/push-lab-images.sh`, default a local `registry:2` container at `localhost:5000`) makes pulls just work the normal Kubernetes way — the backend prepends the registry (`LABS_IMAGE_REGISTRY`, `runtime_kubernetes.go`'s `qualifyImage`) only when constructing the Pod spec, so the bare name in content/config never changes. See "Bugs found and fixed" #13. |

## One-time setup

From **inside WSL** (not Windows):

```bash
# 1. Get the repo onto WSL's native filesystem (fast builds) — adjust the source path.
# --delete matters: a partial/incomplete prior sync (has happened — WSL2's
# cross-filesystem copy from /mnt/c/ can occasionally drop directories under
# load, no error reported) leaves stale empty dirs that --delete cleans up.
# Verify after: `find ~/mindforge/frontend/app -type f | wc -l` should match
# the Windows-side count — an unexplained build failure after this step is
# the first thing to check, before assuming it's an app/build bug.
rsync -a --delete --exclude node_modules --exclude .next --exclude .pnpm-store --exclude bin \
  /mnt/c/dev/dream/mindforge/ ~/mindforge/
cd ~/mindforge

# 2. Everything else, in one command.
bash scripts/bootstrap-k3s-local.sh
```

`scripts/bootstrap-k3s-local.sh` chains `setup-k3s-local.sh` →
`setup-sysbox-local.sh` (only if sysbox-ce is already installed —
otherwise it warns and moves on) → `build-k3s-local-images.sh` →
`deploy-k8s.sh local`, then **verifies** the result instead of stopping at
"kubectl apply didn't error": rollouts are actually `Available`, `/health`
answers a real request through a port-forward, the Gateway/HTTPRoute are
actually `Programmed`/`Accepted`, and — if sysbox is wired in — a real
`mindforge/lab-docker-sysbox:27` Pod is started and its nested `dockerd`
verified to come up, the same way the docker course's own readiness check
does. A clean run means the docker course actually works, not just that the
manifests applied. See `docs/local-k3s-dev.md` "Bugs found and fixed" #11 and
#12 for what this catches that a plain `kubectl apply` wouldn't have.

Then visit **https://mindforge.127.0.0.1.nip.io** (accept the self-signed certificate warning).

Each step is still its own script if you want to run just one (e.g. only
rebuild + redeploy after a code change — see "Redeploying after a code
change" below); `bootstrap-k3s-local.sh` is the one-shot path for going from
a fresh rsync to a verified-working deploy without manual fixes in between.

### Nested-docker labs (the "docker" course)

`bootstrap-k3s-local.sh` handles this automatically if sysbox-ce is already
installed on the WSL host (`dpkg -l | grep sysbox-ce`) — it runs
`setup-sysbox-local.sh` and then proves the course works end-to-end rather
than just applying a manifest. To run that step on its own (e.g. sysbox
wasn't installed during the first bootstrap and you've since installed it):

```bash
bash scripts/setup-sysbox-local.sh   # labels the node, wires sysbox-runc into k3s + RuntimeClass
```

Kubernetes has no `--cap-add` equivalent, so `KubernetesContainerService.Start`
refuses to run any `nested-docker`-profile image (`LABS_IMAGE_PROFILES`, e.g.
`mindforge/lab-docker-sysbox:27`) without a `RuntimeClass` configured (see
"Bugs found and fixed" #11 below). This is the same `RuntimeClass`
(`k8s/base/runtimeclass-sysbox.yaml`) production uses, not a local-only
manifest — see the note in that file for why
`scheduling.nodeSelector`/`scheduling.tolerations` are on it. The script
only labels this single node `mindforge.io/sysbox=true`; it deliberately does
NOT apply the `mindforge.io/sysbox-only` taint production uses to dedicate a
node pool, since tainting the only node in a local cluster would block every
other Pod (postgres, redis, backend, ...) from scheduling — see "Known
local-only limitations" below.

Then set `LABS_NESTED_DOCKER_RUNTIME_CLASS=sysbox-runc` in `backend/.env`
(native hybrid dev) and restart the backend. If sysbox-ce isn't installed at
all, see `github.com/nestybox/sysbox/releases` first — installing sysbox-ce
itself is out of scope for this script.

### Getting lab sandbox images into the cluster

Every `lab-images/*` Dockerfile (`lab-docker`, `lab-docker-sysbox`, `lab-k8s`,
`lab-node-web`, `lab-python-web`) is built and pushed to a registry by:

```bash
bash scripts/push-lab-images.sh                              # local default: localhost:5000
REGISTRY=ghcr.io/youruser bash scripts/push-lab-images.sh     # any other registry
```

`bootstrap-k3s-local.sh` runs this for you with the local default. Content
frontmatter and `LABS_IMAGE_PROFILES` always reference the bare image name
(`mindforge/lab-k8s:1.31`) so the same value works in every environment —
only `LABS_IMAGE_REGISTRY` (set in `backend/.env` for native hybrid dev, or
`k8s/overlays/local/configmap-domain.patch.yaml` for an in-cluster backend)
decides where the Kubernetes runtime actually pulls it from. See
`ENV_VARS.md` "LABS_IMAGE_REGISTRY" and "Bugs found and fixed" #13 below for
why this replaced a manual `docker save | k3s ctr images import` step.

## Bringing over existing dev data

If you have a running `docker-compose.dev.yml` stack with real data in it (not just fixtures), dump it and restore into the k3s cluster instead of starting from the migration-bundled seed fixtures:

```bash
# On the docker-compose side (Windows or wherever it's running):
docker exec mindforge_postgres_dev pg_dump -U mindforge -d mindforge_dev -Fc > mindforge_dev.dump
# (redirect to a file — don't use pg_dump's -f flag; Git Bash on Windows rewrites
#  an in-container /tmp/... path into a host path before docker ever sees it)

# Copy the dump into WSL, then:
bash scripts/restore-db-to-k3s.sh /path/to/mindforge_dev.dump
```

## Redeploying after a code change

```bash
bash scripts/build-k3s-local-images.sh   # rebuild + reimport whichever images changed
bash scripts/deploy-k8s.sh local         # kubectl apply -k — picks up the new :local tags
```

`kubectl apply -k` doesn't force a rollout just because the underlying `:local` image content changed (the tag is unchanged, so k8s doesn't know to re-pull) — the app Deployments' `imagePullPolicy: IfNotPresent` means the cluster won't re-fetch on tag-content change either, since `k3s ctr images import` already replaced the local image the same tag points to. If a redeploy doesn't seem to pick up your change:

```bash
kubectl rollout restart deployment/backend deployment/frontend deployment/labproxy -n mindforge
```

## Useful commands

| What | Command |
|---|---|
| Pod status | `kubectl get pods -n mindforge` (app) / `-n mindforge-labs` (Piston/lab sandboxes) |
| Logs | `kubectl logs -n mindforge -l app=backend -f` |
| Gateway/route status | `kubectl get gateway,httproute -n mindforge` |
| Certificate status | `kubectl get certificate -n mindforge` |
| Render the overlay without applying | `kubectl kustomize k8s/overlays/local` |
| Tear down the app (keep cluster/addons) | `kubectl delete -k k8s/overlays/local` |
| Tear down everything | `sudo /usr/local/bin/k3s-uninstall.sh` |

---

## Bugs found and fixed along the way

None of these were local-only issues — they'd have broken the cloud deploy path (`scripts/build-push-k8s-images.sh` + `scripts/deploy-k8s.sh`) too, since it uses the same Dockerfiles and (now) the same `k8s/base/`. Fixed at the root rather than worked around.

| # | File(s) | Bug | Fix |
|---|---|---|---|
| 1 | `frontend/Dockerfile` | Used `npm ci` + `package-lock.json`, but the project is pnpm-only (`pnpm-lock.yaml`, `pnpm-workspace.yaml`) — `package-lock.json` doesn't exist, so the build always failed. | Switched to `pnpm install --frozen-lockfile` / `pnpm run build`. |
| 2 | `frontend/package.json` | No `packageManager` field — nothing pinned which pnpm version to use. `pnpm-workspace.yaml`'s `allowBuilds` key requires **pnpm ≥ 10.26** (introduced there; became the only mechanism in pnpm 11, replacing `onlyBuiltDependencies`); an unpinned/older pnpm errored with a misleading `packages field missing or empty`. | Added `"packageManager": "pnpm@11.11.0"` — the exact version already in use locally (the one that generated the lockfile). Dockerfile now just runs `corepack enable` and lets it resolve the pinned version — one source of truth instead of duplicating a version number in two files. |
| 3 | `frontend/Dockerfile` | Pinned `node:20-alpine`, but pnpm 11 depends on Node's built-in `node:sqlite` module, only fully stable (no experimental warning, no flag) from **Node 26+** (available unflagged from 22.13, release-candidate in 24, stable in 26). | Pinned all three build stages to `node:26-alpine`, matching the actual local dev environment. Updated `README.md`'s prerequisite table (was "20+"). |
| 4 | `frontend/Dockerfile` | `corepack enable` failed with `corepack: not found` on `node:26-alpine` — Node stopped bundling corepack as of **25.0.0** (nodejs/node TSC vote, March 2025). | `npm install -g corepack@latest && corepack enable`. |
| 5 | `k8s/base/ingress.yaml` (deleted) | Targeted `ingressClassName: nginx` — `kubernetes/ingress-nginx` was retired/archived 2026-03-31, no further security patches ever. | Replaced with Gateway API: `k8s/base/gateway.yaml` (Gateway) + `k8s/base/httproute.yaml` (HTTPRoute, http→https redirect). `k8s/overlays/{prod,local}/kustomization.yaml` patch the hostnames via JSON6902 (see #6). |
| 6 | (same migration) | A strategic-merge patch overriding `Gateway.spec.listeners[].hostname` **silently replaced the entire `listeners` array**, dropping `port`/`protocol`/`tls`/`allowedRoutes` — kustomize's strategic-merge doesn't know how to merge list items inside a CRD (no `patchMergeKey` metadata, unlike built-in k8s types). | Switched to JSON6902 `- op: replace, path: /spec/listeners/N/hostname` patches (inlined in each overlay's `kustomization.yaml`), which touch only the exact field. |
| 7 | (same migration) | The old `ingress.yaml` only routed `/api`, `/mindforge`, and `/` — the AI Connector's `/oauth`, `/.well-known`, and `/mcp` routes (real backend routes — see `backend/internal/mcpconnect/`) silently fell through to the frontend's catch-all `/` instead of reaching the backend. Present since before this migration; just never exercised via an actual k8s deploy. | Added explicit `/oauth`, `/.well-known`, `/mcp` rules to `httproute.yaml`, matching what `Caddyfile.dev` already proxies correctly for docker-compose dev. |
| 8 | `k8s/base/configmap.yaml` + `k8s/base/frontend.yaml` | `mindforge-config`'s `PORT: "8080"` (meant for the backend) is pulled into **every** container sharing that ConfigMap via `envFrom`. Next.js's server reads the bare `PORT` var directly, so the frontend container silently listened on 8080 while its Service/readiness/liveness probes all target 3000 — permanent `CrashLoopBackOff`. | Added an explicit `env: [{name: PORT, value: "3000"}]` to `frontend.yaml` — an explicit `env` entry takes precedence over `envFrom` for the same key. |
| 9 | `scripts/restore-db-to-k3s.sh` | Bundled `DROP DATABASE` in the same multi-statement `psql -c "..."` call as a preceding `SELECT`, but `DROP/CREATE DATABASE` cannot run inside a transaction block, which is what psql wraps multi-statement `-c` calls in. | Split into three separate `psql -c` invocations (terminate connections, drop, create). |
| 10 | `k8s/overlays/local/kustomization.yaml` (new) | Traefik's Gateway API provider requires a Gateway listener's `port` to exactly match one of Traefik's own entryPoint ports — but k3s's bundled Traefik runs its entryPoints on **8000/8443 internally** (avoids needing `CAP_NET_BIND_SERVICE` for <1024 in-container), separately mapped to the standard external 80/443 by its Service. `k8s/base/gateway.yaml` correctly declares standard ports 80/443 (right for prod/any standards-compliant Gateway API implementation) — but that mismatch made both listeners fail with `PortUnavailable: no matching entryPoint`, so every request 404'd from Traefik itself before ever reaching a route. | Added a JSON6902 patch (local overlay only) setting `spec.listeners[].port` to `8000`/`8443`. Base stays standards-correct; this is purely a k3s/Traefik packaging quirk. |
| 11 | (native hybrid dev, `LABS_RUNTIME=kubernetes`) | Pre-existing gap, not introduced by this migration: `docs/labs.md` already noted Docker Desktop can't run `sysbox-runc` at all, so nested-docker labs (the "docker" course) never worked locally even under the old `docker-compose.dev.yml` setup. Moving to `LABS_RUNTIME=kubernetes` surfaced the same gap as a different, earlier failure — `KubernetesContainerService.startPod` hard-fails any `nested-docker`-profile image with no `RuntimeClass` configured, by design (no `--cap-add` equivalent in Kubernetes — see `runtime_kubernetes.go`), and this k3s cluster had no `RuntimeClass` beyond what k3s ships by default (`crun`, `nvidia`, the wasm family). Also caught in the same pass: `k8s/base/configmap.yaml` bakes `LABS_RUNTIME=kubernetes` into every environment including prod, and no overlay ever set `LABS_NESTED_DOCKER_RUNTIME_CLASS` or shipped a `RuntimeClass` — this course was equally broken in the real cloud deploy, not just locally. | `scripts/setup-sysbox-local.sh` registers an already-installed `sysbox-ce`'s `sysbox-runc` as a k3s containerd runtime, labels the node, and applies `k8s/base/runtimeclass-sysbox.yaml` — a base (not local-only) manifest, since prod needs it too — which declares `scheduling.nodeSelector: mindforge.io/sysbox=true` so a Pod using it can never land on a node without sysbox registered, plus a matching toleration for the `mindforge.io/sysbox-only` taint production uses to dedicate a node pool (inert locally — see "Known local-only limitations"). The script then imports the nested-docker lab images into containerd and smoke-tests with a throwaway Pod. Pods using this RuntimeClass also need `hostUsers: false` — sysbox virtualizes the container's root user via its own user namespace, and without that field the kubelet maps the pod to the host's real root UID first, defeating the isolation (`runtime_kubernetes.go` sets this only when `K8sRuntimeClass == "sysbox-runc"`, not for RuntimeClasses generally). See "Nested-docker labs" above for the one-time setup. |
| 12 | `backend/internal/labs/runtime_kubernetes.go` | The `nested-docker` Pod's `/var/lib/docker` `emptyDir` had no `SizeLimit`, and the container had no matching `ephemeral-storage` resource request/limit — a student's `docker build`/image pulls could grow unbounded and pressure the node's disk, affecting every other pod on it, not just their own session. Not caught by any manifest-apply check because it's a resource-shape issue, not a syntax one. | Added `NestedContainerDiskGB` (`models.go`) and `ImageProfile.K8sExtraVolumeSizeGB` (`profile.go`), same fallback-to-constant idiom as `CPU`/`MemoryMB`; `startPod` sets both the `emptyDir`'s `SizeLimit` and the container's `ephemeral-storage` request/limit from it. Separately: none of steps 1-4 actually *verify* a deploy works beyond "kubectl apply didn't error" — a RuntimeClass with no node labeled, or an unbounded volume, would both apply cleanly and still leave the docker course broken for the next student. `scripts/bootstrap-k3s-local.sh` (new) chains all four steps and adds a real verification pass: rollout `Available` checks, a `/health` request through a port-forward, Gateway/HTTPRoute `Programmed`/`Accepted` checks, and — if sysbox is wired in — an actual `mindforge/lab-docker-sysbox:27` Pod whose nested `dockerd` is confirmed to come up, the same readiness check the course content itself uses. |
| 13 | `scripts/setup-sysbox-local.sh` | Its ad hoc `docker save \| k3s ctr images import` loop hardcoded a fixed list of images. When the fast-kubernetes course's `lab-k8s` module went live (`environment: mindforge/lab-k8s:1.31`, also mapped in `LABS_IMAGE_PROFILES` as a `nested-docker` profile), nothing ever added it to that loop — so `mindforge/lab-k8s:1.31` was never imported into containerd, and a real student session hit `ImagePullBackOff` against Docker Hub (`pull access denied` — there's no such public image there). The failure surfaced generically as "Lab failed to start" in the frontend toast, with the real cause only visible via `kubectl get events -n mindforge-labs`. Same root problem the app-images side already avoids: a bare image name plus a manual, easy-to-forget import step, one entry at a time. | Replaced the whole class of "forgot to add it to the import list" bug with a registry: `scripts/push-lab-images.sh` builds every `lab-images/*` Dockerfile from a single source of truth (its `IMAGES` map) and pushes all of them together, so a new lab image is missing only if its Dockerfile itself is missing from `lab-images/`. `LABS_IMAGE_REGISTRY` (`config.go`, `runtime_kubernetes.go`'s `qualifyImage`) prepends the registry at Pod-creation time, after profile classification (which stays keyed on the bare name) — content and `LABS_IMAGE_PROFILES` needed zero changes. `scripts/setup-k3s-local.sh` configures containerd to trust the default local registry (`localhost:5000`, plain HTTP, no cert to manage) as part of cluster setup, the same category as the Traefik HelmChartConfig it already installs there. |

**Investigation dead-end worth recording:** the very first symptom (every page returning a bare-text 500, `ChunkLoadError: Cannot find module '.../[root-of-the-server]__*.js'`) looked exactly like a documented Next.js 16 Turbopack standalone-build bug ([vercel/next.js#88844](https://github.com/vercel/next.js/issues/88844)), and switching the build to `next build --webpack` was tried as the documented workaround. It didn't actually fix anything — the real cause was an **incomplete `rsync`** from `/mnt/c/...` into WSL's native filesystem: `components/`, `lib/`, `hooks/`, and `public/` had silently synced as empty directories (a one-time WSL2 cross-filesystem flakiness, not reproducible on demand), so the build had nothing to compile and both Turbopack and webpack produced only a `/404` fallback either way. Re-running `rsync -a --delete` and diffing file counts against the Windows source (`find <dir> -type f | wc -l` on both sides) confirmed and fixed it; the build then succeeded with plain `next build` (default Turbopack). **Lesson:** after any `rsync` into WSL for this workflow, verify file counts match before spending time debugging what looks like an application/build bug — `scripts/setup-k3s-local.sh`'s initial sync is the most likely place for this to recur.

## Known local-only limitations (not bugs — inherent to a single-node cluster with no public domain/DNS)

- **Browser shows an untrusted-certificate warning.** The `selfSigned` ClusterIssuer can't produce a publicly-trusted cert — there's no domain to prove ownership of via ACME HTTP-01/DNS-01 locally. Click through it. Prod uses real Let's Encrypt via the same annotation.
- **Piston (code execution) needs privileged Pods**, same as prod — `mindforge-labs` namespace already has the permissive Pod Security Admission labels for this (`k8s/base/namespace.yaml`). k3s allows privileged Pods by default, so this just works locally without extra config.
- **No dedicated node pool for sysbox-runc Pods.** `k8s/base/runtimeclass-sysbox.yaml` tolerates a `mindforge.io/sysbox-only` taint so production can isolate untrusted nested-docker workloads onto their own node pool (defense in depth beyond sysbox's own isolation). A single-node cluster has nowhere to put that taint without also blocking postgres/redis/backend/everything-else from scheduling, so `scripts/setup-sysbox-local.sh` labels the node `mindforge.io/sysbox=true` but never taints it — nested-docker Pods share the one node with everything else locally. Not a gap to fix locally; provision a real multi-node cluster (or a separate tainted node pool) before treating this as validated for production isolation.
