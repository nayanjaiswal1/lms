# MindForge - Consolidated Audit: Findings, Root Causes, Fixes, Status

Single audit document. It replaces reading `audit-report.md` (findings), `compliance-audit.md` (audit spec), `security-scan-2026-10-07.md` (dependency/secret scan) and `audit-fixes-changelog.md` (fixes) separately. It also answers one question for every finding: **why was it present after the implementation phase, and why was it not caught then?**

Audit date 2026-10-07 · branch audited `debug-labs` · audit mode was read-only; fixes were applied afterwards (nothing committed yet). Paths are relative to `backend/internal/` unless prefixed (`frontend/`, `docs/`, repo-root files). No secrets or personal data appear here. This extends `docs/ai-pattern-learnings.md`, which already records the same patterns from earlier reviews (2026-08-01 onward).

---

## 1. Scope and honesty note

### 1.1 Honest scope

- The code base was largely written by AI agents (Claude Code sessions), as `docs/ai-pattern-learnings.md` already states. Git history has one author, so I cannot prove from git which lines an AI wrote.
- The audit and the fixes were done in one session. That session did **not** do the original implementation and has no memory of those sessions. Every "root cause / why not caught" below is inferred from the code, the docs and the finding evidence, not recalled. Where it is a judgement, it says so.
- Part of the audit was done by subagents reading code. Fixes were verified by build, vet and `tsc`, but the DB-backed tests and migrations 054-061 have **never run** (no Docker in the sandbox), so DB-touching fixes are not yet proven against a live database.

### 1.2 Method and coverage limits

Eight domain agents (authn, tenancy, appsec+labs, AI/MCP/3P, privacy, payments, infra, realtime+anon) sampled the code; they did not sweep it exhaustively.

- **Not swept:** all 121 MCP tool bodies (only the `callTool` scope choke point and samples were read); the 108 migrations table by table (grep only); live Render/Vercel/Neon/Redis/B2 settings; wiki repo queries, jobs worker payloads, the frontend checkout UI, public course/profile/roadmap field exposure, server-side wiki HTML sanitization, MCP `/oauth/authorize` redirect matching.
- Git-history secret scan (`git log -S` timed out; no gitleaks run) and `govulncheck`/`pnpm audit` were not run in the original audit, so dependency CVEs were unknown; they were run afterwards (section 6).
- Not fully verified (sampled, not exhaustive): wiki repo queries (org filter seen in handlers/service, repo not line-audited), systemdesign/interviewprep/practice/diary AI paths, labs file/exec endpoints (ownership via `GetSession(sessionID,userID)` seen), payments webhook tenant mapping, privacy export/erasure scope, jobs worker payload trust, frontend-only gates. No sqlc in the repo: queries are raw pgx SQL in `*repo*.go`; 235 `id = $n` SQL literals were triaged by hand.
- Scope note: sampled depth, not exhaustive; items marked "Cannot verify" need runtime/host inspection. Depth note: 108 migration files were scanned by grep for key tables/columns, not every table read; "Cannot verify" = needs runtime/Neon/Render config. Privacy-domain paths were reported relative to `backend/`; realtime-domain paths relative to the repo root, so verify exact line numbers before ticketing. Also Cannot verify: Render exposure of `/metrics`, server-side wiki HTML sanitization, MCP `/oauth/authorize` redirect_uri matching, public courses/profile/roadmap field exposure.

**Verification tags** (each CRITICAL/HIGH carries one): **VL** = verified by audit lead (file:line re-read); **VR** = verified by final reviewer (cited file:line re-read); **AU** = agent-reported, unverified (absence-of-feature or runtime claim not re-read).

### 1.3 Audit spec (from `compliance-audit.md`)

Reproduced verbatim from `docs/compliance-audit.md` (headings demoted one level; nothing else changed).

**MindForge — India Compliance & Security Audit (Audit Spec)**

Role: Senior SaaS security architect + privacy engineer + compliance auditor.
Scope: the whole repo (`backend/`, `frontend/`, `docs/`, Docker/CI/infra, migrations, MCP server).
Output: one report at `docs/audit-report.md` (no secrets/PII in it), then **stop and wait for approval**.

#### Rules

1. **Audit only. Do not modify code**, config, or data. No behavior changes. Read-only SQL/DB access only.
2. Verify against code, not docs. A policy, checkbox, middleware, endpoint, or DB column existing is not proof; trace the full flow.
3. Every claim needs evidence (`file:line`). Mark each item **Implemented / Partial / Missing / N/A / Cannot verify**.
4. Legal-interpretation items → **LEGAL REVIEW REQUIRED**. Tax items → **CA REVIEW REQUIRED**. Never pretend certainty.
5. Separate statutory duties (DPDP Act 2023 + Rules, CERT-In Directions 2022, IT Act, GST, Consumer Protection (E-Commerce) Rules) from voluntary/customer asks (SOC 2, ISO 27001). Never present voluntary as mandatory.
6. International law (GDPR/UK GDPR/US state laws) only if a concrete trigger is found (EU/UK users, pricing in other currencies, targeting). State the trigger.
7. Never print secrets or personal data. Report only: type, location, severity, fix.
8. Don't stop at the first findings. Sweep repo-wide; grep for the buggy *pattern itself* (not `grep -L helper`) — a file can mix safe and unsafe calls. Cross-check `docs/ai-pattern-learnings.md` patterns (unthrottled endpoints, unlocked counters, unpaginated lists, trusted-input-as-validation, missing DB test infra).
9. Use subagents per the global model rules: haiku for wide searches (return short summaries), sonnet for per-domain tracing, opus only for the final cross-domain review.

#### Known MindForge surfaces (must each be covered)

| Surface | Why it matters | Doc |
|---|---|---|
| Orgs, members, roles, RBAC engine | Tenant isolation, privilege escalation | `orgs.md`, `rbac.md` |
| Auth (JWT, sessions, reset, OAuth) | Token/session/enumeration | `auth.md` |
| **Labs** (terminal/code sandboxes, compiler) | Remote code execution, sandbox escape, resource abuse, egress | `labs.md`, `learning.md` |
| **AI Connector (MCP, OAuth 2.1+PKCE)** | Third-party token scope, redirect URI, PKCE, tool-level authz | `ai-connector.md` |
| **Google Calendar sync** | OAuth token storage/encryption, scope minimization, disconnect/revoke | `calendar-sync.md` |
| **Captures** (screenshot/PDF/link upload, vision AI, pdftotext) | Upload safety, SSRF on links, PII sent to AI | `captures.md` |
| **Diary / journal / learning journal** | Most sensitive personal content; AI processing; export/delete | `diary.md`, `learning-journal.md` |
| Roadmap / AI generation | Prompts, retention, provider disclosure | `roadmap.md` |
| Payments (INR; `*_cents` = paise) | Webhook verification, idempotency, GST invoices | `infrastructure.md` |
| Anonymous/public tests | Unauthenticated writes, abuse, IP storage | `anonymous.md` |
| Session booking, certificates, batches | PII to mentors, certificate verification exposure | `session-booking.md`, `courses.md` |
| Wiki / design canvas / interview (Yjs websockets) | WS authz, cross-tenant realtime rooms, embeds/XSS | `wiki.md`, `design.md`, `interview.md` |
| Project workspace, sheets, activity | Share links, IDOR, aggregation leaks | `project-workspace.md`, `sheets.md`, `activity.md` |
| Hosting: Vercel + Render + Neon (all Singapore) | Cross-border transfer, subprocessors, DR | `project_hosting_latency` memory |
| **Single shared dev/prod DB** (Neon, `backend/.env`) | Dev tooling/seeds touching prod PII; test data in prod; no env separation — treat as a standing finding to validate | memory |

#### Phases (deduplicated)

##### 1. System map
Repo structure, services, jobs/cron, queues, storage, cache, email, notifications, analytics, logging/monitoring, AI/LLM, third parties, Docker/CI/IaC, env config, existing policies/legal docs. Output one concise architecture + data-flow diagram (frontend → API → service → DB → external).

##### 2. Data inventory
Table: `Data | Source | Purpose | Storage | Retention | Access | Third party | Sensitive?`.
Include implicit data (IP, UA, device, timestamps, logs, cookies, analytics IDs, AI prompts/responses, audit rows, uploads, billing, learning/diary/journal content, calendar data, certificates). Flag data collected but never used (minimization).

##### 3. DPDP / privacy
- Fiduciary vs Processor roles (MindForge itself vs. orgs that own learner data; a B2B org tenant likely makes MindForge a processor for that data — **LEGAL REVIEW REQUIRED**).
- Principals, purposes, minimization, notice, consent capture/withdrawal (actually recorded?), grievance officer/mechanism, retention policy, sub-processor list, cross-border transfer, children's data (age gate, verifiable parental consent, tracking/targeting limits), breach notification to Board + principals.
- Rights flows, verified end-to-end: **access/summary, correction, erasure** (DB rows, uploads, search index, cache, jobs, AI-provider copies, calendar mirror, backups lifecycle), **export** (authenticated, expiring link, logged), nomination.
- Verify notice/policy text against real flows (see phase 13).

##### 4. Multi-tenancy & authorization (CRITICAL — any cross-tenant leak = CRITICAL)
Map `User → Role → Permission → Resource → Tenant → Action`. Check every route has `RequireRole`/permission checks, object-level checks, tenant filter in every sqlc query, user-supplied tenant/org IDs, jobs, websockets/Yjs rooms, cache keys, search, files, exports, notifications, emails, admin APIs, MCP tools, share links.
Scenarios: user→admin endpoint; org A→org B; user→other user's diary/journal/capture; member→owner action; removed member/deleted user with live token; fork/subscribe leaking source content.

##### 5. Authentication & sessions
Registration, login, logout, reset, email verification, MFA, OAuth/SSO, JWT/refresh rotation + revocation, API keys, MCP tokens. Hashing, password policy, brute-force/rate limits, enumeration, cookie flags (HttpOnly/Secure/SameSite), CSRF, session expiry, recovery flow.

##### 6. API & app security
AuthN/Z per endpoint, input/output validation, rate limits, pagination caps, body/upload limits, SQLi, command injection, SSRF (check denylist in `infrastructure.md` is actually applied on every outbound fetch incl. captures/links/embeds), XSS (TipTap/wiki/design embeds/AI output rendering), CSRF, open redirect, path traversal, mass assignment, over-exposed fields, enumeration, unsafe deserialization, security headers/CORS.

##### 7. Labs / code-execution sandbox (MindForge-specific)
Isolation boundary, container/user/seccomp/network egress, CPU/mem/time/disk/pid limits, per-user/per-org quotas, cleanup, secrets in sandbox env, cross-session leakage, filesystem persistence, cost/DoS abuse, AI-hint prompt injection from lab content.

##### 8. Database, files & storage
Credentials/TLS, public exposure, DB roles/least privilege, encryption at rest and for sensitive columns (OAuth refresh tokens, calendar tokens), raw SQL, migrations, backups/dumps, dev/prod separation. Uploads: type/MIME/size/filename sanitization, malware scanning, private vs public, signed URLs + expiry, authz, tenant isolation, deletion incl. backups.

##### 9. Logging, audit trail, incident readiness
Auditable: login/failed login, password/MFA change, user/role/permission change, admin actions, exports, deletions, API-key/MCP-token create/revoke, billing changes. Logs free of passwords/tokens/keys/PII/AI prompts. Tamper resistance, access, retention (CERT-In: 180 days of logs in India — **LEGAL REVIEW REQUIRED**), time sync. Incident chain: detect → alert → investigate → contain → notify (CERT-In 6h, DPDP Board/principal) → recover → review. Can the current stack realistically meet the timelines?

##### 10. Secrets, config & infrastructure
Scan repo, git history (where accessible), `.env*`, Docker/Compose, CI, frontend bundles, config for: API/cloud/DB/JWT/encryption/OAuth/SMTP/payment/AI/webhook secrets. Then: public ports, TLS, security groups/IAM, network isolation, backups/DR, monitoring, prod access, CDN/DNS, Render/Vercel/Neon settings.

##### 11. Third parties / subprocessors / AI
Table: `Vendor | Purpose | Data shared | Country | Personal data? | DPA / ToS reviewed?` — cloud/hosting, DB, payment, email, analytics, error tracking, Google (Calendar/OAuth), AI/LLM providers, any MCP client (Claude/ChatGPT via connector).
AI flow: user input → backend → provider → prompt → response → storage. Check: PII/customer data in prompts, secrets in prompts, provider retention/training terms, prompts/responses stored or logged, cross-tenant leakage, prompt injection (labs, captures, wiki, imported PDFs), disclosure to users, "AI called once / cached" rule.

##### 12. Payments, GST, subscription UX
Gateway webhook signature + idempotency, subscribe/renew/cancel/refund/failed payment, entitlements, invoices/credit notes, GSTIN/tax breakup/B2B-B2C/place of supply (**CA REVIEW REQUIRED** — no tax conclusions), no raw card data stored, reconciliation. UX/dark patterns: pricing transparency, trial and auto-renewal terms, easy cancellation, refunds, pre-ticked consent, forced data collection, urgency. Consumer-protection rules for e-commerce/subscriptions (**LEGAL REVIEW REQUIRED**).

##### 13. Policy ↔ code gap + legal documents
Find Privacy Policy, Terms, Refund, Cookie, DPA, SLA, Security, AUP. Compare each statement with real behavior (e.g. "no third-party sharing" vs analytics/AI calls; "deleted on request" vs orphaned uploads/backups; retention claims). Report mismatches only — do **not** rewrite documents yet.

##### 14. International & licenses
Trigger analysis for GDPR/UK GDPR/US state laws, transfers, SCCs. Dependency license table (`Dependency | Version | License | Usage | Risk`) for Go modules and pnpm packages; flag GPL/AGPL/LGPL/unknown/commercial and any obligations (SaaS-relevant: AGPL).

#### Finding format (every finding)

```
ID | Category | Severity | Requirement | Current state | Evidence (file:line) | Risk | Component | Fix | Priority | Owner
```
Severity: 🔴 CRITICAL (cross-tenant exposure, auth bypass, secret compromise, RCE/sandbox escape, major PII breach, serious regulatory exposure) · 🟠 HIGH · 🟡 MEDIUM · 🔵 LOW · ⚪ INFO.

#### Scoring

Score 0–5 (0 Missing … 5 Excellent) per area: Privacy, Security, Authn, Authz/Tenancy, Data Management, Incident Response, Infrastructure, Payments & Billing, Legal docs, Third parties, Enterprise readiness. No overall score unless methodology is stated (unweighted mean, with CRITICAL findings capping the area at 1).

#### Report order

1. Executive summary (what it is, top risks, readiness)
2. Architecture + data flow
3. Compliance matrix: `ID | Area | Requirement | Status (PASS/PARTIAL/FAIL/N/A/UNKNOWN) | Severity | Evidence`
4. Critical findings
5. Security findings
6. Privacy / DPDP findings
7. Product / UX / billing findings
8. Legal-doc gaps + **Policy-to-Code mismatches**
9. Third-party/subprocessor list
10. Data retention matrix (data type → current behavior → gap)
11. Scores
12. Remediation roadmap — P0 immediate · P1 before production/enterprise launch · P2 next sprint · P3 long-term
13. Engineering tickets (per important finding): `Title | Problem | Why it matters | Affected files/APIs | Required change | Acceptance criteria | Tests | Priority`

#### Gate

After writing `docs/audit-report.md`: **stop. No fixes until the user approves** which findings to implement. Fixes then follow the project's Production-Ready rules (no stubs/TODOs, tests, one root-cause fix per pattern) and get a bugfix-log entry.

### 1.4 How to read statuses

| Status | Meaning |
|---|---|
| fixed-and-built | Code changed; `go build`, `go vet`, `pnpm tsc --noEmit` pass; the fix does not depend on a DB or migration to be proven, or it is frontend/config |
| fixed-but-DB-test-not-run | Code/migration changed per the changelog, but it touches SQL/migrations 054-061 and the DB-backed tests have never run (no Docker) |
| open | Not addressed in the changelog; still a finding |
| operator-action | Needs a human step (deploy, env var, key, legal/CA review) |
| verify | The changelog does not clearly say; check the code before relying on it |

The status assignment is this document's reading of the changelog, not an independent re-test. "Fixed" never means "tested against a live DB".

---

## 2. Executive summary and scores

### 2.1 What it is

MindForge is a multi-tenant learning SaaS: courses, labs (code sandboxes), assessments, a wiki, diary/journal/captures, mentoring payments in INR, and an MCP "AI Connector" for Claude/ChatGPT. It runs as Next.js on Vercel and Go on Render (free plan), with Neon Postgres, all in Singapore. Object storage is Backblaze B2 in the US. A `docker-compose.prod.yml` self-host path adds labs, Piston, MinIO and Grafana.

**Findings after dedupe:** 🔴 3 CRITICAL · 🟠 30 HIGH · 🟡 41 MEDIUM · 🔵 44 LOW · ⚪ 33 INFO/N/A.

### 2.2 Top risks (as found)

1. **Cross-tenant data exposure (C-01, C-02).** A self-made org `admin` could read any platform user's full profile including email. Leaderboards accepted any `scope_id`, harvesting user IDs and names across tenants.
2. **Erasure that did not erase (C-03, H-01, H-18).** Account deletion anonymized only the `users` row. Diary, journal and captures stayed linked, capture blobs were never deleted, and MCP tokens kept working after deletion, suspension or removal.
3. **Statutory DPDP gaps (H-20..H-28).** Notice omitted AI processors, hosting and the US object store. No grievance officer, breach/CERT-In process, age gate, retention schedule, nomination or auth audit trail.
4. **Abuse and cost surface (H-02, H-03, H-04).** Only `/api/auth` was rate-limited. Public tests, OAuth dynamic registration, `/mcp` and every LLM endpoint were unthrottled.
5. **Self-host runtime (H-10..H-13).** Backend mounted `docker.sock`, Piston ran privileged, the lab bridge was shared, no pids limit, automatic `--privileged` fallback. Only applies when `docker-compose.prod.yml` is used; Render cannot run labs.

**Readiness at audit time:** Not ready for enterprise or regulated launch. Fix the P0 items before onboarding any external org. After the fixes in section 3 the readiness verdict has not been re-assessed; the audit should be re-run once DB tests pass (section 8).

### 2.3 Scores

Method: 0-5 per area, unweighted mean across 11 areas; any open CRITICAL caps its area at 1. Payments agent's 5.5/10 rescaled x0.5 = 2.75. Scores are **as found, before fixes**. The "domain agent" column holds each domain agent's own suggestion before the lead's rescoring.

| Area | Score | Basis | Domain-agent suggestion |
|---|---|---|---|
| Privacy | **1** (capped) | C-03 + H-18..H-28 | 1 (PRIV-01 caps) |
| Security | 2 | Strong session/CSRF/SQL hygiene; HIGH XSS, rate limits, SSRF, lab runtime | 3 (appsec/labs; would cap at 2 if SEC-03 shows egress/inter-session reach); 2.5 (realtime/anon/unauth surface: unthrottled public tests/DCR/certificate, token-in-URL logging, raw HTML hold it under 3) |
| Authn | 3 | Rotation, reuse detection, CSRF and enumeration resistance good; no MFA, MCP lifecycle gap. No CRITICAL, so no cap. Fixing AUTHN-01, 02, 06 and 12 would reach 4 | 3 |
| Authz / Tenancy | **1** (capped) | C-01, C-02; otherwise consistent org-scoping. Would be 2 only if both fixed in the same sprint and TEN-03..08 scheduled | 2 (strict spec: 1 until TEN-01/02 fixed) |
| Data Management | 1 | Erasure, export, retention and blob lifecycle all failing; shared dev/prod DB | 1 |
| Incident Response | 1 | No runbook, POC, alerting, auth audit trail or log retention | 1 |
| Infrastructure | 2 | Secrets via env, TLS; public /metrics, no CI, docker.sock, free plan, no DR evidence | 2.5 (no CRITICAL; capped by shared DB, no CI, root + docker.sock, public /metrics on Render) |
| Payments & Billing | 2.75 | Good gateway hygiene; stuck-paid bug, no GST invoice, one-way refunds | 5.5/10 (gateway integration about 8/10 pulled down by GST, seller/grievance disclosure, stuck-pending bug, one-way refunds; subscriptions N/A) |
| Legal docs | 2 | Terms/Privacy/Refund + versioned acceptance; missing grievance, DPA, cookie, seller info; inaccurate notice | 2 |
| Third parties | 2 | Solid OAuth/MCP engineering; no subprocessor disclosure or DPAs; US storage undisclosed. No CRITICAL; AI-01/17/22/24 HIGH | 2 |
| Enterprise readiness | 1 | No MFA, SSO toggle unenforced, no DPA, no audit trail, no CI, free hosting tier | n/a |
| **Overall (mean)** | **1.70 / 5** | 18.75 / 11 | |

**Domain-agent score notes (verbatim rationale, not repeated in the table):**

- Authz / Tenancy: "Strong, consistent org-scoping pattern across most domains (well above average), but two CRITICAL cross-tenant leaks (TEN-01, TEN-02) cap the area at 1 per the spec's rule; scored 2 only if both are fixed in the same sprint and TEN-03..08 are scheduled. Strict spec application: 1/5 until TEN-01/02 are fixed."
- Authn: "The core session design is strong: rotation, reuse detection, revocation, CSRF and enumeration resistance. Two things hold it back. First, the MCP token path ignores user, member and deletion state (AUTHN-01), plus unthrottled dynamic client registration (AUTHN-02). Second, there is no MFA, no auth audit trail, and documented SSO and device-management features are absent (AUTHN-03 to AUTHN-06). There are no CRITICAL findings, so the spec's cap rule does not apply. Fixing AUTHN-01, 02, 06 and 12 would move it to 4."
- Security (appsec/labs): "3/5 (unweighted; no CRITICAL found, but several HIGH: shared lab bridge/no pid limit/docker.sock, GitLab SSRF bypass, single rate-limit group). Would cap at 2 if SEC-03 shows labs have egress or inter-session reachability at runtime."
- Security (realtime/anon/unauth surface): "2.5/5. No CRITICAL (no cross-tenant leak found); unthrottled public tests/DCR/certificate, token-in-URL logging and raw HTML injection hold it below 3. Realtime/Yjs: N/A (not built, doc drift)."
- Third parties: "Solid OAuth/MCP engineering offset by no subprocessor/AI disclosure (AI-24), no DPA evidence, no LLM quotas (AI-22), MCP access surviving erasure (AI-01). Calendar sync not built (N/A). No CRITICAL here; AI-01/17/22/24 are HIGH."
- Infrastructure: "2.5/5 (no CRITICAL; capped by shared dev/prod DB, no CI, root + docker.sock, public /metrics on Render)."
- Payments and Billing: "5.5/10. Strong gateway-integration hygiene (about 8/10) pulled down by missing GST invoicing (PAY-08), missing seller/grievance disclosures (PAY-10), the stuck-pending-on-transient-failure bug (PAY-01/02) with no reconciliation, and one-way refund handling. Subscriptions N/A."
- Privacy / Data Management / Incident Response / Legal docs: "Privacy 1 (CRITICAL PRIV-01 caps at 1) | Data Management 1 | Incident Response 1 | Legal docs 2".

### 2.4 Architecture and data flow

```
Browser --HTTPS--> Next.js 16 (Vercel sin1; BFF proxy, CSP/HSTS, first-party HttpOnly cookies)
   |                        |  server actions / lib/server/api.ts (re-emits cookies, X-Forwarded-For)
   |                        v
   |              Go API (Render "singapore", plan: free, Docker; Chi + pgx)
   |                +- /api/auth/* (only rate-limited group at audit time) - JWT HS256 + rotating refresh + CSRF
   |                +- RequireAuth+CSRF group: RBAC / RequireOrgRole / self-scoped handlers
   |                +- public: /api/p/*, /api/public/*, certificates, ICS feed, webhooks, /metrics, /health
   |                +- MCP: /.well-known, /oauth/register|authorize|token, /mcp (bearer)
   |                        |
   |      +-----------------+------------------+-------------------+------------------+
   |      v                 v                  v                   v                  v
   |  Neon Postgres     Redis (REDIS_URL,   Backblaze B2 S3      LLM provider        Brevo SMTP (EU)
   |  ap-southeast-1    host unknown):      us-east-005 (USA):   Anthropic / Gemini  Razorpay / Stripe
   |  SHARED dev+prod   rate limit, cache,  captures, uploads    (USA; render.yaml   Google/GitHub OAuth
   |                    queue, lab tokens                        LLM_PROVIDER=       GitLab (tenant URL)
   |                                                              disabled - live    HIBP (hash prefix)
   |                                                              value unverified)
   |
   +-- MCP client (user's Claude/ChatGPT) --OAuth 2.1+PKCE--> /mcp tools --> diary/journal/calendar/wiki/habits

Self-host path only (docker-compose.prod.yml): Caddy :80/:443 -> backend (+docker.sock) -> lab containers on
external bridge "mindforge-labs" <- labproxy (WS terminal); Piston (privileged); MinIO; Prometheus/Grafana.
```

Realtime reality: the only WebSockets are lab terminal/preview (`backend/cmd/labproxy`). Wiki (TipTap) and design (Excalidraw) are single-user HTTP saves, no live rooms. No Yjs/y-websocket server exists.

Route coverage (tenancy domain; scope `backend/internal/**`, Chi router `internal/api/router.go`, 68 route-registering packages, ~900 route lines; status values Implemented / Partial / Missing / N/A / Cannot verify):

Tiers in `api/router.go`: (1) public: `/api/auth/*` (rate-limited), `/api/p/{code}` anon tests, `/api/public/*`, `/api/certificates/{uuid}`, calendar ICS + invite accept, payments webhook, gitlab webhook/callback, MCP OAuth + `/mcp` (own bearer auth), roadmap discover/optional-auth. (2) one big `RequireAuth + RequireCSRF` group (router.go ~L330-L560) containing everything else.

Inside tier 2, per-route authz is one of: `RequireOrgRole` (live DB role, middleware/role.go:45), `RequirePermission/RequireAnyPermission` (RBAC, user_roles per org), `RequirePlatformRole(super_admin)` (every `/api/admin/*` route: jobs, pricing, entitlements, features, whatsnew, highlights, lab-authoring yank, `/api/admin/orgs`), `RequireOrgMember` (+ per-handler `CallerRole` checks in orgs), `RequireProjectRole` (workspace, all 99 routes gated, status-gated), or "self-scoped" (handler filters by `claims.UserID`).

Routes with NO role/permission middleware are all "self-scoped" or "any member of claims.OrgID": activity, calendar, diary(perm), journal(perm), habit, mistakes, whatnow, focuswall, notifications, rewards, feedback, profile, labs sessions, sessions (booking, per-handler participant checks), assessment student group, courses student group, tickets, messaging member group, interviewprep, roadmap, mcpconnect UI, privacy. No route was found that is wholly unauthenticated and returns tenant data other than the intentionally public ones above. Admin APIs: 100% of `/api/admin/*` are guarded (permission or super_admin).

Gaps are therefore not "missing middleware" but "middleware present, object-level / tenant-boundary check missing in handler or repo" (see findings).

**Doc drift** (docs describe things the code does not do; the fix pass marked unbuilt features "planned (not built)"):

| Doc | Claim | Code reality |
|---|---|---|
| `docs/interview.md:39-53,154` | Yjs relay `WS /ws/interview/:id` | No `/ws` route; no yjs dependency (RT-01) |
| `docs/calendar-sync.md` | Google Calendar OAuth sync | Not implemented: no scope, routes or token table (AI-15) |
| `docs/labs.md:128,129,338-346` | Own netns, no inter-container routing, egress proxy | One shared external bridge; no egress proxy found (SEC-03, SEC-07) |
| `docs/auth.md` | OIDC/SAML, magic link, `require_sso`, session list/revoke, step-up, impossible travel, switch-org | None implemented; SSO toggle stored but never read (AUTHN-04/05) |
| `docs/design.md:136,155` | `/design` embed | No embed route (RT-25) |

### 2.5 Compliance matrix

Statutory = DPDP Act 2023 + Rules, CERT-In Directions 2022, IT Act, CGST, Consumer Protection (E-Commerce) Rules 2020. Voluntary = SOC 2 / ISO 27001 (customer asks only, never mandatory). Status is **as found at audit time**.

| ID | Area | Requirement | Basis | Status | Sev | Evidence |
|---|---|---|---|---|---|---|
| CM-01 | Tenancy | No cross-tenant reads | Security | FAIL | 🔴 CRITICAL | C-01, C-02 |
| CM-02 | Tenancy | Object-level authz on admin routes | Security | PARTIAL | 🟠 HIGH | H-05, H-06, H-09 |
| CM-03 | Authn | Revoke all credentials on delete/suspend/remove | Security / DPDP s.12 | FAIL | 🟠 HIGH | H-01, H-08 |
| CM-04 | Authn | Session design (rotation, CSRF, cookies) | Security | PASS | - | authn "implemented well" |
| CM-05 | Authn | MFA for privileged roles | Voluntary (SOC2/ISO) | FAIL | 🟡 MEDIUM | M-01 |
| CM-06 | AppSec | Rate limits on public/costly routes | Security | FAIL | 🟠 HIGH | H-03 |
| CM-07 | AppSec | XSS-safe content rendering + CSP | Security | FAIL | 🟠 HIGH | H-15 |
| CM-08 | AppSec | SSRF denylist on every outbound fetch | Security | PARTIAL | 🟠 HIGH | H-14, M-15 |
| CM-09 | AppSec | SQL parameterization | Security | PASS | - | SEC-20 |
| CM-10 | Labs | Sandbox isolation (limits, network, no privileged) | Security | FAIL | 🟠 HIGH | H-10..H-13 |
| CM-11 | DPDP | Accurate notice (s.5) | Statutory | FAIL | 🟠 HIGH | H-20 |
| CM-12 | DPDP | Consent recorded, withdrawable (s.6) | Statutory | PARTIAL | 🟡 MEDIUM | M-06 (LEGAL REVIEW REQUIRED) |
| CM-13 | DPDP | Access summary (s.11) | Statutory | PARTIAL | 🟠 HIGH | H-19 |
| CM-14 | DPDP | Erasure (s.12) | Statutory | FAIL | 🔴 CRITICAL | C-03, H-18, M-32 |
| CM-15 | DPDP | Grievance redressal (s.13) | Statutory | FAIL | 🟠 HIGH | H-21 |
| CM-16 | DPDP | Nomination (s.14) | Statutory | FAIL | 🟠 HIGH | H-28 (LEGAL REVIEW REQUIRED: commencement) |
| CM-17 | DPDP | Children's data / verifiable parental consent (s.9) | Statutory | FAIL | 🟠 HIGH | H-24 (LEGAL REVIEW REQUIRED) |
| CM-18 | DPDP | Retention / erase when purpose served (s.8(7)) | Statutory | FAIL | 🟠 HIGH | H-27 |
| CM-19 | DPDP | Breach notice to Board + principals (s.8(6)) | Statutory | FAIL | 🟠 HIGH | H-25 |
| CM-20 | DPDP | Reasonable security safeguards (s.8(5)) | Statutory | PARTIAL | 🟠 HIGH | C-01, C-02, H-01 |
| CM-21 | CERT-In | 6h incident reporting, POC | Statutory | FAIL | 🟠 HIGH | H-25 (LEGAL REVIEW REQUIRED) |
| CM-22 | CERT-In | 180-day logs within India | Statutory | UNKNOWN | 🟠 HIGH | H-26 (LEGAL REVIEW REQUIRED) |
| CM-23 | Audit | Auth/export/delete/billing events logged | Statutory-adjacent + Voluntary | FAIL | 🟠 HIGH | H-26 |
| CM-24 | Fiduciary | Role clarity + DPA with B2B orgs | Statutory (contract) | FAIL | 🟠 HIGH | H-23 (LEGAL REVIEW REQUIRED) |
| CM-25 | Payments | Webhook signature + idempotency | Security | PARTIAL | 🟠 HIGH | H-29 (signature PASS) |
| CM-26 | GST | Tax invoice / credit note | Statutory | FAIL | 🟠 HIGH | H-30 (CA REVIEW REQUIRED) |
| CM-27 | E-Commerce Rules | Seller details, grievance officer | Statutory | FAIL | 🟠 HIGH | H-21 (LEGAL REVIEW REQUIRED) |
| CM-28 | Payments | No raw card data stored | PCI scope | PASS | - | PAY-16 |
| CM-29 | Infra | Dev/prod separation | Security | FAIL | 🟠 HIGH | H-17 |
| CM-30 | Infra | Internal endpoints not public | Security | FAIL | 🟠 HIGH | H-16 |
| CM-31 | Infra | CI with tests and vuln scans | Voluntary | FAIL | 🟡 MEDIUM | M-39 |
| CM-32 | Infra | Backups / DR tested | Voluntary + s.8(5) | UNKNOWN | 🟡 MEDIUM | M-40 |
| CM-33 | Secrets | No secrets in tracked files | Security | PASS (history UNKNOWN at audit time; scanned later, section 6.3) | ⚪ INFO | INF-07/08 |
| CM-34 | 3P | Subprocessor list disclosed, DPAs | Statutory notice + contract | FAIL | 🟠 HIGH | H-20, M-29 |
| CM-35 | Licenses | No copyleft obligations triggered | Legal | PARTIAL | 🟡 MEDIUM | M-41 (AGPL) |
| CM-36 | International | GDPR/UK/US laws | Only with trigger | N/A | ⚪ INFO | No trigger found (section 4.2) |
| CM-37 | Voluntary | SOC 2 / ISO 27001 | Voluntary | N/A | ⚪ INFO | Not claimed; prerequisites missing |

---

## 3. Findings

Each finding has one entry; aliases from different agents are merged (alias `X = Y` means the same issue). "Fix (recommended)" is the audit's recommendation; "Fix applied" is from the changelog. **Root cause** codes (R1..R10) refer to the classes in section 7.2; "Process" = the process failures in 7.3. Priority is the audit's original priority.

### 3.1 🔴 CRITICAL

#### C-01 (= TEN-01) - Cross-tenant profile read - 🔴 CRITICAL - P0 - tag VL
- **Source fields (category / requirement / component / owner / priority):** Category: IDOR / cross-tenant. Requirement: tenant admin reads only its own members. Component: profile. Owner: Backend. Source state: Partial -> FAIL.
- **What:** `GET /api/profile/user/{userID}` returned the full profile (email, goals, timezone, notification prefs, skills, stats) of any user when the caller's live org role was `admin`. The target's org was never checked. Becoming admin of an own org needs only two accounts. User IDs were harvestable via C-02, `author_id` in platform-wide interview-exp and public certificate JSON.
- **Evidence:** profile/service.go:445-453 (449); profile/handler.go:262-306; profile/routes.go:39.
- **Risk:** any registered user can harvest emails and profiles of every tenant (DPDP personal-data breach).
- **Fix (recommended):** require the target to be an active member of the caller's org before the admin branch; add a cross-org negative test. Acceptance: org-A admin gets 404 for an org-B user. Test: DB test cross-org negative + same-org positive.
- **Root cause (R1):** the handler was "authenticated, role is admin, fetch row by id". The role check answered "may the caller use this feature", and was treated as answering "may the caller see this row". Not caught because tests ran as one user in one org and no cross-org negative test existed.
- **Fix applied:** `GetUserProfile` requires the requester to be an active org member; non-members get not-found; handler validates the UUID.
- **Status:** fixed-but-DB-test-not-run.
- **Further source detail:** Source fix detail: reuse an `authz` `requireOrgMembership`-style query in `GetUserProfile`; drop `requesterOrgRole=="admin"` for non-members.
- **Engineering ticket (section 13 of the report):** Title: Scope admin profile read to own org. Problem: admin branch skips target-org check. Why it matters: cross-tenant PII. Affected files / APIs: profile/service.go:445-453; `GET /api/profile/user/{id}`.

#### C-02 (= TEN-02) - Leaderboard cross-tenant read - 🔴 CRITICAL - P0 - tag VL
- **Source fields (category / requirement / component / owner / priority):** Category: cross-tenant read / user-supplied scope id. Requirement: leaderboards scoped to the caller (own org/batch/course). Component: rewards. Owner: Backend. Source state: FAIL.
- **What:** `scope=org|batch|group|course&scope_id=<any>` built the Redis key from the query string with no membership check. `scope=global` listed all users. Returned user_id, name, avatar, XP; `GET /api/rewards/leaderboard/me` the same.
- **Evidence:** rewards/handler.go:60-89,115,130-168; rewards/models.go:96-104.
- **Risk:** cross-tenant learner directory; feeds C-01 ID harvesting. Any user reads other tenants' learner names, avatars and IDs.
- **Fix (recommended):** use `claims.OrgID` for `org`; check membership for batch/group/course; drop or anonymise `global`. Acceptance: foreign `scope_id` -> 403. Test: handler tests per scope.
- **Root cause (R1):** request ids were trusted as keys; nothing required "other tenant gets 403".
- **Fix applied:** scope pinned to caller's org (`resolveLBKey`, `ScopeInOrg`); global board anonymises everyone but the caller.
- **Status:** fixed-but-DB-test-not-run.
- **Further source detail:** Source fix detail: ignore `scope_id` for `org` (always `claims.OrgID`); for batch/group/course verify membership/org ownership of the id; gate or drop `global`/return anonymised.
- **Engineering ticket (section 13 of the report):** Title: Lock leaderboard scope to caller. Problem: `scope_id` trusted. Why it matters: cross-tenant directory. Affected files / APIs: rewards/handler.go:60-168.

#### C-03 (= PRIV-01) - Erasure did not erase - 🔴 CRITICAL - P0 - tag VL
- **Source fields (category / requirement / component / owner / priority):** Category: erasure. Requirement: DPDP s.12 erasure (statutory). Component: privacy. Owner: Backend.
- **What:** delete account anonymized only the `users` row (plus webauthn, social, project_interests). The users row is never hard-deleted, so 59 `ON DELETE CASCADE` children (diary, journal, captures, SRS, calendar...) were never removed. MCP connections untouched. Diary/journal/capture free text stayed linked to the user id. The policy implied otherwise (mismatch 2, section 4.2).
- **Evidence:** privacy/repo.go:96-135 (113-124); db/migrations/024_diary.sql:19-20; 033_captures.sql:17-35; 001_baseline.sql (59 CASCADE FKs).
- **Risk:** The most sensitive personal content survives "deletion"; the policy implies otherwise (mismatch 2, section 4.3).
- **Fix (recommended):** in one tx delete or scrub per table, revoke MCP (H-01) and GitLab connections, delete blobs (H-18). Acceptance: no user-linked personal rows remain after delete. Test: enumerate every `user_id` FK table.
- **Root cause (R2):** deletion was written first, when `users` was the only table that mattered; each later feature added `user_id` tables and nothing tied the erase routine to the schema. A hand-written list goes stale on the first new table. No test enumerated `user_id` tables; erasure is invisible in normal use.
- **Fix applied:** catalog-driven erasure (cascade FKs read from `pg_constraint`, explicit `retainedUserTables`) deleting rows, MCP audit rows and storage blobs; a test fails if a table is neither erased nor explicitly retained.
- **Status:** fixed-but-DB-test-not-run.
- **Further source detail:** the anonymized users fields are name/email/avatar/password hash. Source fix alternative: delete/scrub per table in the tx, or tombstone the user for RESTRICT content.
- **Engineering ticket (section 13 of the report):** Title: Real account erasure. Problem: only users row anonymized. Why it matters: DPDP s.12; policy mismatch. Affected files / APIs: privacy/repo.go:96-135, service.go:41-65. Required change: per-table delete/scrub in one tx incl. MCP, GitLab, blobs queue.

### 3.2 🟠 HIGH

#### H-01 (= AUTHN-01 = AI-01 = TEN-07; linked C-03) - MCP tokens outlive user/member state - 🟠 HIGH - P0 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: MCP token lifecycle (AUTHN-01 "MCP tokens / revocation"; AI-01 "MCP authz/lifecycle"; TEN-07 "Removed member / third-party token"). Requirement: AUTHN-01 a suspended, deleted or removed user must lose every live credential, including MCP bearer tokens; AI-01 revoke MCP access when user is erased/removed/suspended; TEN-07 MCP/AI-connector tokens must die with membership, account lock, deletion. Component: mcpconnect, privacy. Owner: Backend. Priority: P0 (AUTHN-01, AI-01), P1 (TEN-07). Source state: AUTHN-01 Missing; AI-01 and TEN-07 Partial/FAIL.
- **What:** `GetConnectionByAccessHash` checked only token expiry and `mcp_connections.status='active'`; never `users.status` or `org_members.status`. Delete, suspend, member removal and logout-all never revoked MCP. The refresh path had the same gap; refresh TTL 720h (access 1h). Only wiki tools called `LiveOrgRole`; tools operate on `conn.OrgID`. Password reset also did not revoke. Org kill-switch was the only org-level stop.
- **Evidence:** mcpconnect/repo.go:193-279; mcpconnect/mcp_auth.go:34-88,438-476; oauth_token.go:73-91; mcpconnect/models.go:116-120; mcpconnect/tools.go:2479-2485 (wiki only); privacy/* and orgs/member.go had 0 refs to `mcp_connections`.
- **Risk:** a deleted/removed user's AI client keeps reading/writing diary, journal, calendar, habits for up to 30 days; DPDP erasure gap. Also reported: a removed employee's Claude/ChatGPT keeps reading org lesson notes and calendar and writing events for 30 days or more; access token 1h, refresh 30d; this is a "removed member / deleted user with live token" failure.
- **Fix (recommended):** join active user + member in both lookups; revoke connections and delete `mcp_access_token` rows in the delete, remove, suspend and logout-all txs. Acceptance: suspended user's MCP call -> 401. Test: DB tests per lifecycle event.
- **Root cause (R2/R3):** MCP was added as a separate feature in its own session with its own token table; lifecycle events (delete/remove/suspend) live in other packages that never learned about it.
- **Fix applied:** live-connection predicate in MCP auth; erasure deletes MCP rows/audit rows.
- **Status:** fixed-but-DB-test-not-run. **Verify:** explicit revocation inside member-remove, suspend and logout-all txs is not itemised in the changelog (the live predicate covers access, not stored status).
- **Further source detail:** `requireMCPAuth` checks only token + connection status + org toggle; `exchangeRefreshToken` has the same gap; only the user (`RevokeConnection`) or the org AI toggle can stop a connection; grep found no `mcp_connections` writes outside mcpconnect. Source fix detail: `LiveOrgRole` check on every `/mcp` request; join `users.status='active'` and an active `org_members` row into both `GetConnectionByAccessHash` and `GetConnectionByRefreshHash`; set `mcp_connections.status='revoked'` and delete `mcp_access_token` rows in the same tx on account delete, member removal (`MemberService.Remove/Update(status)`), suspension (`SetUserStatus`), logout-all and password reset. Extra evidence: privacy/service.go:46-65; privacy/repo.go:91-150 and 114-132 (no mcp cleanup); mcpconnect/mcp_auth.go:44-83, 438-476.
- **Engineering ticket (section 13 of the report):** Title: Kill MCP on user/member state change. Problem: token lookup ignores user/member. Why it matters: post-erasure access. Affected files / APIs: mcpconnect/repo.go:244-279, oauth_token.go; privacy, orgs/member.go, authz admin.

#### H-02 (= AUTHN-02 = RT-14 = AI-02) - OAuth dynamic client registration - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: OAuth DCR (AUTHN-02 "OAuth 2.1 (MCP) / abuse"; RT-14 "Unauth/DCR"; AI-02 "OAuth DCR"). Requirement: AUTHN-02 dynamic client registration must be controlled, redirect URIs restricted, token endpoints throttled; RT-14 throttle dynamic client registration; AI-02 DCR hardened. Component: mcpconnect, router. Owner: Backend. Priority: P1. Alias severity: AUTHN-02 HIGH, RT-14 HIGH, AI-02 MEDIUM. Source state: AUTHN-02 Missing; AI-02 Partial.
- **What:** `/oauth/register` unauthenticated, unthrottled, no body cap, accepts any scheme with a host (`javascript:`, non-loopback `http://`), unbounded `client_name`/URIs; `client_name` attacker-chosen and shown on consent. `/oauth/token` and `/mcp` also unthrottled. Approve checks only that the PKCE challenge is non-empty.
- **Evidence:** mcpconnect/oauth_register.go:18-48 (34-40); mcpconnect/routes.go:12-18; mcpconnect/oauth_authorize.go:23-40; api/router.go:313 (sole RateLimit).
- **Risk:** DB bloat; consent phishing ("Claude" client with attacker redirect); refresh-token hammering. Unbounded client-row inserts (DB growth); the token goes to the attacker's redirect; `javascript://host` or non-loopback http redirect abuse if authorize does not re-validate; code over http.
- **Fix (recommended):** per-IP limits; cap clients/IP/day; https or loopback only; size caps; show redirect host on consent; enforce `code_challenge_method=S256` at authorize. Acceptance: `javascript:`/remote-http rejected; 429 over limit. Test: unit + limiter test.
- **Root cause (R3):** endpoint added in its own session; "make it work" excluded "make it abuse-proof"; `ai-pattern-learnings.md` rule not enforced.
- **Fix applied:** DCR validation (`validRedirectURI`, `cleanClientName`), sliding-window limit on OAuth-register path, `MaxBody`, MCP authorize consent component (frontend).
- **Status:** fixed-and-built.
- **Further source detail:** `/oauth/authorize` is also outside the rate-limited group; no cap on `redirect_uris` count/length or `client_name` length; scheme and host only need to be non-empty. Extra evidence: mcpconnect/routes.go:14, 372-379; api/router.go:312-313,370.
- **Engineering ticket (section 13 of the report):** Title: Harden OAuth DCR. Problem: open, unthrottled, any scheme. Why it matters: phishing, DoS. Affected files / APIs: mcpconnect/oauth_register.go, routes.go, api/router.go.

#### H-03 (= SEC-17 = RT-06 = AI-22; +RT-13, PAY-13, RT-17) - Rate limiting / LLM quota - 🟠 HIGH - P0 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: rate limiting (SEC-17 "Rate limits"; RT-06 "Public tests/rate limit"; AI-22 "AI rate/cost cap"). Requirement: SEC-17 per-route-group rate limits; RT-06 throttle unauthenticated writes; AI-22 per-user rate limit + cost cap on LLM endpoints. Component: api, assessment, many AI consumers. Owner: Backend. Priority: P1 (SEC-17, AI-22), P0 (RT-06). Related rows: RT-13 LOW, RT-17 LOW, PAY-13 (implemented; rate-limit gap only). Source state: AI-22 Partial.
- **What:** `RateLimit` was used exactly once, on `/api/auth`. Unthrottled: public tests `/api/p/*` (each submit runs Judge0; unlimited attempt rows), every LLM endpoint without an ad-hoc cap (diary fix-english/analyze, journal structure, captures retry, highlights, practice, systemdesign incl. MCP feedback tool, assessment, revisionplan, projectmarket, gitlab review), uploads, search, MCP and webhook routes. Short-code guessing (RT-13, 10-char crypto/rand ~51 bits) and webhooks (RT-17, PAY-13) unbounded. The LLM `http.Client` had no timeout. Ad-hoc caps existed only for roadmaps, lab hints, labauthor/labbuild, digest budget, interviewprep, workspace.
- **Evidence:** api/router.go:313 (repo-wide grep: 1 hit); assessment/routes.go:203-210; diary/routes.go:26-28; journal/routes.go:25; practice/service.go:143; systemdesign/service.go:127,190; ai/anthropic.go:28; roadmap/handler.go:13-46.
- **Risk:** denial-of-wallet on AI and Judge0, DB spam, scraping. Source risks: cost abuse on paid AI providers, scraping, resource DoS (SEC-17); denial-of-wallet by any logged-in user or looping MCP client (AI-22); DB spam and Judge0 cost/CPU abuse (RT-06). Matches the `ai-pattern-learnings.md` "unthrottled endpoints" pattern.
- **Fix (recommended):** per-user and per-IP limiter on authenticated and public groups; central quota wrapper on `ai.LLMProvider`; monthly cap; client timeout. Acceptance: burst -> 429; quota exceeded -> 429. Test: middleware + quota tests.
- **Root cause (R3):** `ai-pattern-learnings.md` recorded "unthrottled endpoints" on 2026-08-01 and told authors to throttle in the same PR; the rule was prose, not a gate, and later endpoints repeated it. Each endpoint was a separate session seeing one package.
- **Fix applied:** sliding-window limits on public and OAuth-register paths, per-user limiter, per-user LLM quota (`QuotaProvider`, `QuotaTrip` 5xx -> 429), AI HTTP timeout. Limits attach to route groups and a central quota wrapper sits around the LLM provider so a new endpoint is covered by default.
- **Status:** fixed-and-built. **Verify:** webhook route limiting (PAY-13/RT-17) is not itemised.
- **Further source detail:** Source fix detail: per-user limiter middleware on the authenticated group plus stricter limits on AI/upload/export/public routes (SEC-17); Redis limiter per IP/code/email on start+submit and a cap on concurrent coding runs (RT-06); central per-user/org quota wrapper on `ai.LLMProvider` (Redis) + global monthly cap + client timeout (AI-22). AI endpoints relied on ad-hoc per-feature limiters (workspace, labauthor, labbuild, labs cooldowns). Extra evidence: assessment/handler_public.go; assessment/service.go:359-376; jobs/handlers/digest_user.go:162; `grep middleware.RateLimit(` = 1 hit.
- **Engineering ticket (section 13 of the report):** Title: Global rate limiting + AI quota. Problem: one limited group. Why it matters: denial-of-wallet. Affected files / APIs: api/router.go; ai/provider.go; assessment/routes.go.

#### H-04 (= RT-07; +RT-08) - Public test policy not enforced - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: public tests (RT-07 "Public tests/policy"; RT-08 "Public tests/validation"). Requirement: RT-07 max_attempts, ends_at, duration enforced; RT-08 input validation, body limit. Component: assessment, httputil. Owner: Backend. Priority: P1. Alias severity: RT-07 HIGH, RT-08 MEDIUM.
- **What:** the public path ignored `max_attempts`, `starts_at/ends_at` and duration (only the authed path enforced them). It validated only that name/email are non-empty (no format/length/phone checks, no body cap).
- **Evidence:** assessment/handler_public.go:44-147; service.go:140,672 (authed only); httputil/response.go:40-46.
- **Risk:** unlimited retries per email; late submissions graded; junk PII. Oversized bodies, junk PII (RT-08).
- **Fix (recommended):** enforce window, per-email cap, server deadline, validators, MaxBytes. Acceptance: over-cap start -> 409; late submit rejected. Test: handler tests.
- **Root cause (R1/R3):** happy path "anyone can take the test" worked; policy fields were added to the authed flow only.
- **Fix applied:** public test validation, time window, attempt cap, deadline; attempt token moved to `X-Attempt-Token` header (legacy URL paths still work with a deprecation log); `MaxBody`.
- **Status:** fixed-but-DB-test-not-run.
- **Further source detail:** no email format/length/phone checks; `DecodeJSON` has no size cap and there is no global `MaxBytesReader`. Source fix: MaxBytesReader, validators, answers cap. Extra evidence: handler_public.go:55-85 (RT-07), 44-53 (RT-08).
- **Engineering ticket (section 13 of the report):** Title: Enforce public-test policy. Problem: attempts/window ignored. Why it matters: integrity. Affected files / APIs: assessment/handler_public.go, service.go.

#### H-05 (= TEN-03) - Course tree leaks content before enrollment - 🟠 HIGH - P0 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: entitlement bypass / draft leak (TEN-03). Requirement: paid and unpublished course content only to enrolled learners / authors. Component: courses. Owner: Backend. Priority: P0. Source state: FAIL.
- **What:** `GET /api/courses/{id}` and `/by-slug/{slug}` returned the full tree (`content_body`, `storage_key`, `assessment_id`, `lab_id`) before the enrollment check, regardless of price or draft status; no redaction code existed. The public tree route also returns `content_body` (by design for `is_public`, but no free/price guard). `Enroll` was not blocked on unpublished courses.
- **Evidence:** courses/service.go:124-149; courses/repo.go:381-475,659,690; courses/handler.go:227-255; courses/models.go:121; courses/handler_student.go:44.
- **Risk:** paid notes free to every org member; drafts and S3 keys leak; revenue loss.
- **Fix (recommended):** redact content/keys for non-enrolled, non-preview, non-author viewers; filter unpublished courses; block enrolment on unpublished. Acceptance: non-enrolled sees titles only. Test: service tests by role/status.
- **Root cause (R1):** "show the course page" built before "who may see which field"; entitlement was checked after the data was fetched.
- **Fix applied:** `GetCourseTree` + `restrictTreeForViewer`; `IsOrgStaff`.
- **Status:** fixed-but-DB-test-not-run. **Verify:** blocking `Enroll` on unpublished courses and the public-tree free/price guard are not itemised.
- **Further source detail:** any authenticated org member can call the routes; leaked statuses include draft/in_review; `GetCourseDetailForViewer` returns the tree before the enrollment check. Source fix detail: strip `content_body`/`storage_key` for non-enrolled, non-free-preview modules and non-author viewers; filter `status<>published` for non-authors in `GetCourse`/`GetCourseBySlug`; block `Enroll` on non-published (courses/handler_student.go:44). Extra evidence: courses/repo.go:381-397,402-420.
- **Engineering ticket (section 13 of the report):** Title: Redact course tree for non-entitled. Problem: content before enrollment. Why it matters: revenue + draft leak. Affected files / APIs: courses/service.go:124-149, repo.go.

#### H-06 (= TEN-04) - Admin overview reads personal data - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: admin reads personal data (TEN-04 "Tenant escalation / privacy"). Requirement: org admin must not read members' personal (non-org) data. Component: useroverview. Owner: Backend/Privacy. Priority: P1. Source state: FAIL.
- **What:** `GET /api/admin/rbac/users/{id}/overview` returned the target's private journal, mistakes, habits and sheets. Those tables have no `org_id` (handler comment L77-83 acknowledges), so any org that onboards a user reads their pre-existing journal.
- **Evidence:** useroverview/handler.go:86-151 (gather 108-151).
- **Risk:** The most sensitive personal content (journal) is exposed to any org admin the user ever joined.
- **Fix (recommended):** remove personal domains or gate on explicit per-org user consent. Acceptance: overview has no journal/habits/mistakes. Test: handler test.
- **Root cause (R1):** tables made for single-user features had no `org_id`; later org-admin features joined them without noticing. Pattern recorded in `ai-pattern-learnings.md` as "Personal data reachable through an org-scoped door".
- **Fix applied:** overview reduced to enrollments + recent activity; admin user detail Sheets/Mistakes/Habits/Journal tabs deleted (frontend).
- **Status:** fixed-and-built.
- **Further source detail:** endpoint requires `admin.view_members`; returns the target's complete private journal entries, mistakes, habits and sheets; only `GetUser(org)` membership guards it; any org can invite/auto-onboard a user and then read the whole pre-existing journal. Source fix: remove journal/mistakes/habits from the admin overview or require explicit user consent per org; limit to org-scoped course/activity data. Line refs differ between sources: useroverview/handler.go:86-151 (gather 112-151) in the merged report, 86-150 (gather 108-150) in the raw tenancy output.
- **Engineering ticket (section 13 of the report):** Title: Remove personal data from admin overview. Problem: journal visible to org admin. Why it matters: privacy. Affected files / APIs: useroverview/handler.go:112-151.

#### H-07 (= TEN-05) - Domain verification was self-attested - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: fake control / stub (TEN-05). Requirement: domain ownership must be proven before an org holds a verified domain / auto-join. Component: orgs. Owner: Backend. Priority: P1. Source state: FAIL.
- **What:** `Verify` compared the caller-supplied token with the token `Add` returned in the same response; no DNS or email proof despite the `verification_method` enum. Any org could "verify" a victim's domain. `auto_join_enabled` has no consumer yet; it becomes 🔴 CRITICAL (tenant takeover) once auto-join/SSO-by-domain reads it.
- **Evidence:** orgs/domain.go:25-66,97-145 (117); db/migrations/001_baseline.sql:2059-2070.
- **Risk:** Impersonation of a corporate domain; any org can "verify" a victim company's domain; future account/tenant takeover.
- **Fix (recommended):** real DNS TXT verification; never treat the returned token as proof; unique verified domain. Acceptance: verify fails without TXT record. Test: resolver-mocked test.
- **Root cause (R5):** the happy-path test (add, then verify with the returned token) passed, so the feature looked finished; "proof of control" was never in the test.
- **Fix applied:** DNS TXT check (`_mindforge-verification.<domain>` = `mindforge-verification=<token>`), only method `dns_txt`; migration 054 resets all existing "verified" rows and adds a unique index on verified domains; UI shows the TXT name/value, email method removed.
- **Status:** fixed-but-DB-test-not-run. Operator note: all previously "verified" domains were reset.
- **Further source detail:** any org admin can mark any non-free-mail domain verified; no consumer of `auto_join_enabled` (grep `org_domains` outside domain.go = none). Source fix detail: real DNS TXT / email-to-domain verification before setting verified=true; never return the token as the proof; unique(domain) where verified.
- **Engineering ticket (section 13 of the report):** Title: Real domain verification. Problem: token echo = proof. Why it matters: domain impersonation. Affected files / APIs: orgs/domain.go.

#### H-08 (= TEN-06; +AUTHN-10, AUTHN-11) - Removed/suspended member keeps role - 🟠 HIGH - P1 - tag VR (handler.go:1226); rest AU
- **Source fields (category / requirement / component / owner / priority):** Category: removed member keeps role (TEN-06 "Removed member / live token"; AUTHN-10 "Session invalidation / cache"; AUTHN-11 "Stale claims"). Requirement: TEN-06 removal/suspension must cut all access incl. refresh and long-lived tokens; AUTHN-10 account deletion, suspension and role change must kill sessions immediately; AUTHN-11 authorization must not rely on JWT `org_role`. Component: auth, authz, orgs, wiki, privacy. Owner: Backend. Priority: P1 (TEN-06), P3 (AUTHN-10, AUTHN-11). Alias severity: AUTHN-10 LOW, AUTHN-11 LOW. Source state: Partial.
- **What:** login/refresh read `org_members.role` without `status='active'`, so a removed default-org admin got `OrgRole=admin` again on refresh. `GetEffectivePermissions` had no member join. Removal deleted only the `tenant_admin` user_role; other roles/overrides survived. The RBAC cache (5 min) was not invalidated (orgs `invalidateSession` clears only the session_version cache). Messaging `ListMessages` staff branch ignored member status. Wiki trusted `claims.OrgRole` (AUTHN-11). Account deletion did not clear the Redis `sv:` cache (30s window, AUTHN-10); refresh tokens not revoked at delete, though refresh rejects non-active accounts.
- **Evidence:** auth/handler.go:500-575,1224-1236; authz/repo.go:25-41; authz/cache.go:15; orgs/rbac_sync.go:34-39; orgs/member.go:29-34,240-290; wiki/handler.go:57-381; messaging/repo.go:54; authz/admin_repo.go:782-850; privacy/service.go:61; session/cache.go:13,98-122.
- **Risk:** Removed/suspended staff keep read/write on default-org data up to the refresh/cache window or indefinitely and regain the admin claim on refresh. AUTHN-10: the window is at most 30s, but an avoidable inconsistency on the erasure path. AUTHN-11: low after the session_version bump, but the pattern is inconsistent and the claim is trusted for wiki privileges.
- **Fix (recommended):** status filter; delete all role rows on removal; `InvalidateUser`; `LiveOrgRole` in wiki; invalidate `sv:` cache from `DeleteAccount` and set `refresh_tokens.revoked_at`. Acceptance: removed admin's refresh yields no admin role. Test: DB tests.
- **Root cause (R1/R2):** liveness checks were added to some paths (`RequireOrgRole`, `LiveOrgRole`) but login/refresh/permission lookups were written earlier and not revisited; the pattern was inconsistent.
- **Fix applied:** `mintSession` ignores non-active memberships; effective permissions require an active membership; removal revokes all roles and permission overrides; permission cache invalidated on role/status change and removal; wiki `requireMember` uses live org role.
- **Status:** fixed-but-DB-test-not-run. **Verify:** messaging staff branch and account-delete `sv:` cache/refresh-revoke (AUTHN-10) are not itemised.
- **Further source detail:** org removal bumps session_version (orgs/member.go:165-175,265-275); `RequireOrgRole` and `LiveOrgRole` read the live DB role and check status='active'; suspend (`AdminService.SetUserStatus`) and member changes call `InvalidateVersionCache`; account deletion (`SetUserStatusUnscoped`, called from `privacy.DeleteAccount`) bumps session_version but not the Redis `sv:` cache. Source fix detail: call `authz.Service.InvalidateUser` on role/status change; `cache.InvalidateVersionCache` from `DeleteAccount` (or move invalidation into the repo layer); delete all user_roles/overrides for the org on removal. Extra evidence: auth/handler.go:630; authz/admin_service.go:270; wiki/handler.go:57-210; middleware/role.go:43-120; orgs/member.go:170-195.
- **Engineering ticket (section 13 of the report):** Title: Live member status everywhere. Problem: removed staff regain role. Why it matters: lingering access. Affected files / APIs: auth/handler.go:1226; authz/repo.go; orgs/member.go; wiki/handler.go.

#### H-09 (= TEN-08) - Tenant admin writes global user status - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: tenant -> global side effect (TEN-08 "Tenant boundary / global side effect"). Requirement: tenant admin account-status change must affect only that tenant. Component: authz. Owner: Backend. Priority: P1. Source state: FAIL.
- **What:** `PATCH /api/admin/rbac/users/{id}/status` wrote global `users.status` and bumped the global session_version for any active member of the caller's org, with no rank check. Org-A admin could lock a user out of every org, including owners of other orgs.
- **Evidence:** authz/admin_repo.go:766-840; authz/admin_service.go:247-275; authz/routes.go (manage_members).
- **Risk:** Org A admin locks a user out of every org, including owners of other orgs; cross-tenant DoS / account lockout; peer-privilege abuse.
- **Fix (recommended):** org-scoped suspension (`org_members.status`); reserve global status for super_admin; deny when target outranks actor. Acceptance: org-A admin cannot affect org-B access. Test: DB test.
- **Root cause (R1):** feature built single-tenant first ("admin suspends user"); tenant boundary not in the feature description.
- **Fix applied:** `SetMemberStatus` suspends one org membership only (tenant admins); global suspend super-admin only; `ErrOutranked`.
- **Status:** fixed-but-DB-test-not-run.
- **Further source detail:** no check on the target's higher role (owner of the caller's org, other-org owner, super_admin) or other-org membership; an org-A admin who invited the victim can suspend an org owner.
- **Engineering ticket (section 13 of the report):** Title: Org-scoped suspension. Problem: tenant writes global status. Why it matters: cross-tenant lockout. Affected files / APIs: authz/admin_repo.go:766-790.

#### H-10 (= SEC-01 = INF-04 + SEC-23) - Host-root containers - 🟠 HIGH - P1 - tag VR (compose); Dockerfile AU
- **Source fields (category / requirement / component / owner / priority):** Category: host-root containers (SEC-01 "Labs / host isolation"; INF-04 "Container hardening"; SEC-23 "Judge0/Piston executor"). Requirement: SEC-01 backend must not hold host-root equivalent; INF-04 non-root container; SEC-23 code runner isolation. Component: labs runtime, Infra, piston. Owner: Platform (SEC-01, SEC-23), Eng (INF-04). Priority: P1. Alias severity: SEC-01 HIGH, INF-04 MEDIUM, SEC-23 MEDIUM.
- **What:** backend mounts `/var/run/docker.sock` (dev and prod compose) and runs as root (no USER), docker CLI installed. Piston runs `privileged: true` (4g mem limit) on the same host as Postgres/Redis. Args are passed as argv (no host shell), which is partial mitigation. Piston/Judge0 clients use operator URLs (not user-supplied).
- **Evidence:** docker-compose.prod.yml:114-115,144; docker-compose.dev.yml:109; backend/Dockerfile:18-34; labs/container.go:285; labs/piston.go:29; assessment/executor.go:63.
- **Risk:** any backend RCE or Piston escape = host root, then DB and secrets.
- **Fix (recommended):** separate lab/runner host or K8s runtime (`runtime_kubernetes.go` exists), socket proxy restricting verbs, non-root image, gVisor/VM for Piston with no egress. Acceptance: backend container has no socket, non-root. Test: compose lint/check.
- **Root cause (R7):** socket mount was the shortest way to make labs work; compose files and Dockerfiles are not covered by Go/TS checks.
- **Fix applied:** Dockerfile and `docker-compose.prod.yml` changed (docker-proxy, networks).
- **Status:** verify (non-root USER and Piston isolation not itemised); partially fixed-and-built.
- **Further source detail:** Source fix detail: run labs on a host with no other services (SEC-01); `USER nonroot` (INF-04); dedicated host/VM or gVisor with Piston network-isolated and no egress (SEC-23). Source risk (INF-04): container escape / host takeover; (SEC-23): escape from the privileged container compromises co-located services; Piston runs `privileged: true` (required by its isolate) with a 4g memory limit on the same compose host as DB/backend. The backend also shells out to `docker` for run/exec/rm.
- **Engineering ticket (section 13 of the report):** Title: Remove host-root from API host. Problem: docker.sock, root, privileged Piston. Why it matters: host takeover. Affected files / APIs: docker-compose.prod.yml:114,144; backend/Dockerfile. Required change: separate runner host/socket proxy; USER; isolate Piston.

#### H-11 (= SEC-04) - Elevated lab profile / `--privileged` fallback - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: elevated lab profile (SEC-04 "Labs / elevated profile"). Requirement: elevated containers contained. Component: labs runtime. Owner: Platform. Priority: P1.
- **What:** rootless-dind profile uses SYS_ADMIN+NET_ADMIN with seccomp and apparmor unconfined, and auto-retries with `--privileged` if the scoped start fails. Off by default (needs `LABS_IMAGE_PROFILES` + org allowlist).
- **Evidence:** labs/container.go:100-168; docs/labs.md:753.
- **Risk:** A student escapes to the host if the profile is enabled; sandbox escape to host on a Docker Desktop-style or shared host. Privileged = host root for any student.
- **Fix (recommended):** fail closed (no privileged retry); require sysbox-runc; startup check that the lab host runs no other services. Acceptance: scoped start failure -> error, never privileged. Test: unit test on args.
- **Root cause (R7):** convenience fallback so labs "just work" on Docker Desktop-style hosts.
- **Fix applied:** none itemised (labs/container.go changed per git status; labs lab-token and allowed-origins are the only itemised labs items).
- **Status:** verify.
- **Further source detail:** Source fix detail: remove the `--privileged` auto-retry in production builds (fail closed); require sysbox-runc in prod; enforce lab host separation (the doc says it "must not run other services") with a startup check. Extra evidence: labs/container.go:126-136, 103-107, 159-165.
- **Engineering ticket (section 13 of the report):** Title: No privileged fallback. Problem: auto `--privileged` retry. Why it matters: sandbox escape. Affected files / APIs: labs/container.go:100-168.

#### H-12 (= SEC-02) - Lab resource limits - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: lab resource limits (SEC-02 "Labs / resource limits"). Requirement: CPU/mem/pid/disk limits. Component: labs runtime. Owner: Platform. Priority: P1.
- **What:** only `--cpus` and `--memory` set. No `--pids-limit` (fork bomb), `--ulimit`, `--storage-opt`/tmpfs, `--read-only` or `--memory-swap`. Output buffers are bounded.
- **Evidence:** labs/container.go:88,142.
- **Risk:** Fork bomb or disk fill on the shared host; DoS across tenants.
- **Fix (recommended):** add pids-limit, memory-swap, ulimits, storage quota, read-only rootfs where lab permits. Acceptance: args include limits. Test: args unit test.
- **Root cause (R7):** CPU/memory were the obvious knobs; abuse scenarios (fork bomb, disk fill) not in the feature description.
- **Fix applied:** none itemised. **Status:** verify.
- **Further source detail:** Source fix detail: `--pids-limit`, `--memory-swap=memory`, `--ulimit nofile/nproc`, `--storage-opt size` (or quota'd volume), `--read-only` + tmpfs where the lab permits.
- **Engineering ticket (section 13 of the report):** Title: Lab resource limits. Problem: no pids/disk caps. Why it matters: DoS. Affected files / APIs: labs/container.go:88.

#### H-13 (= SEC-03) - Lab network isolation - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: lab network (SEC-03 "Labs / network egress"). Requirement: sandbox egress denied; no inter-session reach. Component: labs network. Owner: Platform. Priority: P1.
- **What:** all standard labs share one external bridge `mindforge-labs` created with no `--internal` or ICC-off; labs.md claims "no inter-container routing" and "own netns" (contradiction). Metadata-IP block exists only in docs. labproxy shares the bridge. "No internet" relies on external network creation, not verified.
- **Evidence:** docker-compose.prod.yml:9-12,236; labs/container.go:83-86; docs/labs.md:128 vs 699-736.
- **Risk:** Student A can scan/attack student B's containers and labproxy neighbors; possible egress/metadata access if the network is not `--internal`.
- **Fix (recommended):** `--internal`, `enable_icc=false`, per-session networks or enforced iptables; fix the doc. Acceptance: container A cannot reach B or the internet. Test: integration test on a lab host.
- **Root cause (R7/R9):** one shared network is the shortest way to let labproxy dial containers; docs described the intended design as if built.
- **Fix applied:** `docker-compose.prod.yml` networks changed (details not itemised); docs synced.
- **Status:** verify; operator: deploy frontend and labproxy together.
- **Further source detail:** the docs admit the shared bridge; the metadata-IP block is a host-iptables doc item only, with no enforcement in code. Source fix detail: per-session networks or iptables isolation; verify and document; fix the doc contradiction. Extra evidence: docs/labs.md:699,700,736 vs :128; docker-compose.prod.yml:10-12.
- **Engineering ticket (section 13 of the report):** Title: Isolate lab network. Problem: shared bridge. Why it matters: lateral movement, egress. Affected files / APIs: compose networks; labs/container.go; docs/labs.md.

#### H-14 (= SEC-10) - SSRF bypass in GitLab calls - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: SSRF (SEC-10). Requirement: denylist on every outbound fetch to a user/admin-supplied URL. Component: gitlab. Owner: Backend. Priority: P1.
- **What:** the guarded transport (dial-time IP re-resolution, covers redirects and rebinding) was used only by captures link fetch and gitlab `client.go`. GitLab OAuth token, revoke and service calls used a bare `http.Client` against the admin-set `BaseURL`.
- **Evidence:** gitlab/service.go:292; service_oauth.go:168,258; gitlab/oauth.go:124,143; vs client.go:42-44; handler_connection.go:73.
- **Risk:** DNS rebinding / internal-network SSRF by an org admin pointing a GitLab base URL at an internal host; token POSTs reach internal services.
- **Fix (recommended):** one shared guarded-client constructor for all GitLab calls plus a redirect check. Acceptance: internal BaseURL blocked at dial. Test: netguard test.
- **Root cause (R7):** `netguard` existed but each new outbound client had to opt in, and one did not.
- **Fix applied:** `netguard.NewHTTPClient` with extended denylist; GitLab client uses it.
- **Status:** fixed-and-built.
- **Further source detail:** webhook/other GitLab calls also use plain clients; only a handler-time IP check exists, no dial-time check. Source fix: use `netguard.GuardedTransport` for all GitLab clients (single shared constructor); add `CheckRedirect`.
- **Engineering ticket (section 13 of the report):** Title: Guarded transport for all GitLab calls. Problem: bare clients. Why it matters: SSRF. Affected files / APIs: gitlab/service.go:292; service_oauth.go:168,258.

#### H-15 (= SEC-13 = RT-22 + RT-26) - Stored XSS + weak CSP - 🟠 HIGH (upgraded from MEDIUM) - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: stored XSS + weak CSP (SEC-13 "XSS"; RT-22 "XSS/lesson HTML"; RT-26 "CSP"). Requirement: SEC-13 sanitize HTML rendered via dangerouslySetInnerHTML; RT-22 sanitize HTML; RT-26 strong CSP. Component: frontend/courses, courses/contentpipeline, frontend. Owner: Full-stack (SEC-13, RT-22), Frontend (RT-26). Priority: P1. Alias severity: SEC-13 MEDIUM, RT-22 MEDIUM, RT-26 MEDIUM (upgraded to HIGH).
- **What:** lesson markdown rendered with `marked.parser` (raw HTML passes), injected via `dangerouslySetInnerHTML`; no sanitizer in go.mod/package.json. Prod CSP had `script-src 'unsafe-inline'` and `connect-src ws: wss:` (any host); no `frame-ancestors` (XFO DENY present). Reaches anonymous public course notes. Upgraded because it is cross-user and cross-tenant via public courses. Related: mermaid SVG via `dangerouslySetInnerHTML` after `securityLevel: strict` (RT-23, LOW); TipTap/wiki stored-HTML path unverified (RT-25, LOW).
- **Evidence:** frontend/lib/courses/markdown.ts:218; frontend/components/courses/lesson-html.tsx:44; frontend/next.config.ts:33-52; frontend/components/highlights/mermaid-diagram.tsx:70,91,125.
- **Risk:** Stored XSS from instructor/imported/AI course content to learners (session theft is blocked by HttpOnly, but CSRF-protected actions are possible); any course author runs script in learners' sessions; `connect-src ws: wss:` is an exfil channel and there is no inline-script defence for any XSS. Upgraded from agent MEDIUM: cross-user and cross-tenant via public courses.
- **Fix (recommended):** DOMPurify (or a server allowlist) on render, nonce-based CSP, narrow `connect-src`. Acceptance: `<img onerror>` stripped, inline script blocked. Test: Vitest sanitizer cases.
- **Root cause (R8):** renderer built for trusted author content; later features (imported/AI content, public courses) widened who supplies it. A permissive CSP is the default that makes Next.js work, and tightening needs nonce plumbing nobody was asked to build.
- **Fix applied:** nonce-based CSP (`lib/csp.ts`, `proxy.ts`), `'unsafe-inline'` removed from `script-src`, pages render dynamically; `sanitize-html` allowlist (`lib/courses/sanitize.ts`, `markdown.ts`).
- **Status:** fixed-and-built. **Verify:** `connect-src ws: wss:` narrowing is not itemised (the changelog says CSP/proxy files were not touched during the dependency pass).
- **Further source detail:** server-side sanitization of lesson/course HTML was not found in Go (bluemonday/UnsafeRender grep empty; the `sanitize.go` files in ai/assessment are prompt sanitizers); CSP would not contain an XSS. Source fix: sanitize on write (bluemonday) or DOMPurify client-side; restrict `ws:` to the API/labproxy hosts; nonces. Extra evidence: frontend/next.config.ts:38,45; mermaid-diagram.tsx:91,125.
- **Engineering ticket (section 13 of the report):** Title: Sanitize lesson HTML + nonce CSP. Problem: raw marked HTML. Why it matters: stored XSS. Affected files / APIs: frontend/lib/courses/markdown.ts:218; lesson-html.tsx; next.config.ts. Required change: DOMPurify; nonce CSP; narrow connect-src.

#### H-16 (= INF-03 = RT-18) - Public /metrics - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: public /metrics (INF-03 "Metrics exposure"; RT-18 "Unauth/metrics"). Requirement: /metrics not public. Component: API/api. Owner: Eng (INF-03), DevOps (RT-18). Priority: P1. Alias severity: INF-03 HIGH, RT-18 MEDIUM.
- **What:** `/metrics` registered unauthenticated; the comment relies on Caddy, but Render serves the container directly.
- **Evidence:** api/router.go:107-110; render.yaml:2-14; metrics/metrics.go:4.
- **Risk:** Route, pool and runtime information disclosed publicly (routes, pool stats); metrics disclosure if the backend host is reachable directly.
- **Fix (recommended):** token or IP allowlist, or a separate internal listener. Acceptance: unauth GET -> 401/404. Test: router test.
- **Root cause (R7):** written for the Caddy deployment; Render deployment came later without revisiting.
- **Fix applied:** `/metrics` guarded by `RequireMetricsToken`.
- **Status:** fixed-and-built; operator-action: set `METRICS_TOKEN` (and Prometheus config uses it).
- **Further source detail:** RT-18 says it relies on Caddy proxying only `/api/*` and Render exposure is unverified. Source fix: token/IP allowlist, separate internal port or listener; confirm Render. Extra evidence: render.yaml:6-14; metrics/metrics.go:4.
- **Engineering ticket (section 13 of the report):** Title: Protect /metrics. Problem: public on Render. Why it matters: info leak. Affected files / APIs: api/router.go:110.

#### H-17 (= INF-01; +INF-02) - Shared dev/prod database - 🟠 HIGH - P0 - tag AU (confirmed by project memory)
- **Source fields (category / requirement / component / owner / priority):** Category: dev/prod separation (INF-01; INF-02). Requirement: separate dev/prod DB. Component: DB, Tests. Owner: Eng. Priority: P0 (INF-01), P2 (INF-02). State: Partial/Confirmed.
- **What:** local `backend/.env` points at the production Neon DB (standing finding). Seeds, coursegen and dev tooling run against prod PII. No guard if `TESTDB_URL` points at Neon (INF-02, LOW).
- **Evidence:** backend/.env:7 (value not read into report); .gitignore:2; testdb/testdb.go:44,174.
- **Risk:** Dev seeds/migrations/scripts can mutate prod PII; dev mistakes mutate or expose prod personal data (DPDP s.8(5)).
- **Fix (recommended):** separate Neon project/branch for dev; prod creds only in Render; refuse non-local test DBs. Acceptance: local env cannot reach prod host. Test: testdb guard test.
- **Root cause (R7):** a convenience that was never revisited.
- **Fix applied:** `testdb.checkTestDBURL` guard so tests never run against the shared DB.
- **Status:** operator-action (move local `backend/.env` onto a dev Neon branch). Test guard: fixed-and-built.
- **Further source detail:** `backend/.env` (untracked, gitignored) `DATABASE_URL` points at the Neon pooler (ap-southeast-1) per memory; dev tooling, seeds and coursegen run against it. Source fix: separate Neon branch/project for dev; prod creds only in Render; refuse TESTDB_URL that matches the DATABASE_URL host or is non-local.
- **Engineering ticket (section 13 of the report):** Title: Separate dev from prod DB. Problem: shared Neon. Why it matters: prod PII mutation. Affected files / APIs: backend/.env (local), testdb.go.

#### H-18 (= PRIV-02) - Capture blobs never deleted - 🟠 HIGH - P0 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: erasure of uploads (PRIV-02 "Erasure"). Requirement: erasure incl. uploads. Component: captures/storage. Owner: Backend. Priority: P0.
- **What:** no code path deletes capture blobs or other objects (no `RemoveObject`/Delete in storage/captures). Blobs live in Backblaze B2 (USA).
- **Evidence:** storage/minio.go (upload only); captures/*; 033_captures.sql:20; render.yaml:33.
- **Risk:** Orphaned screenshots/PDFs forever.
- **Fix (recommended):** delete on capture delete and erasure; bucket lifecycle rule. Acceptance: object gone after delete. Test: storage integration test.
- **Root cause (R2):** same as C-03: upload path built, delete path never required.
- **Fix applied:** capture dismiss deletes the blob and nulls `storage_key`; erasure deletes storage blobs; B2 lifecycle rules documented in `docs/infrastructure.md`.
- **Status:** fixed-but-DB-test-not-run; operator-action: apply the B2 lifecycle rule in the bucket.
- **Further source detail:** capture blobs (`storage_key`) in private MinIO/S3 are never deleted by any code path.
- **Engineering ticket (section 13 of the report):** Title: Delete blobs on capture delete/erasure. Problem: orphans forever. Why it matters: erasure. Affected files / APIs: storage/minio.go; captures/*.

#### H-19 (= PRIV-05) - Incomplete data export - 🟠 HIGH - P0 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: access summary s.11 (PRIV-05 "Export"). Requirement: DPDP s.11 access summary (statutory; portability is not a DPDP right). Component: privacy. Owner: Backend. Priority: P0.
- **What:** export covered 9 sections (profile, org memberships, course purchases, assessment attempts, support tickets, legal acceptances, project interests/memberships) and omitted diary, journal, captures, habits, notes, calendar, wiki, SRS, AI interactions, labs. Direct JSON response, no expiring link, no audit row. (DPDP s.11 is an access summary; portability is not a DPDP right.)
- **Evidence:** privacy/repo.go:36-60; privacy/handler.go:19-30.
- **Risk:** Export incomplete vs data held; the policy promises a copy of personal data.
- **Fix (recommended):** extend to all user tables; audit the export. Acceptance: export lists every user table. Test: table-enumeration test.
- **Root cause (R2):** same class as C-03: a hand-written list.
- **Fix applied:** export uses curated queries plus a generic sweep (`exportSkippedTables`).
- **Status:** fixed-but-DB-test-not-run. **Verify:** whether export is audit-logged (new `auth_events`) is not itemised.
- **Further source detail:** Source fix detail: extend `exportQueries` to all user-owned tables; audit-log the export. Extra evidence: privacy/repo.go:36-52.
- **Engineering ticket (section 13 of the report):** Title: Complete data export. Problem: 9 sections only. Why it matters: DPDP s.11. Affected files / APIs: privacy/repo.go:46-60.

#### H-20 (= PRIV-10 = AI-24 = AI-17 + AI-14) - Notice omits AI/vendors; no AI consent - 🟠 HIGH - P0 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: notice s.5 / AI disclosure (PRIV-10 "Notice"; AI-24 "User disclosure"; AI-17 "AI PII in prompts"; AI-14 "MCP client as recipient"). Requirement: PRIV-10 DPDP s.5 accurate notice; AI-24 notice that content goes to an AI provider; AI-17 minimize/consent for personal content sent to the LLM; AI-14 disclose the user-initiated transfer to Claude/ChatGPT. Component: legal, ai consumers. Owner: Legal (PRIV-10, AI-24, AI-14), Product+Legal (AI-17). Priority: P0 (PRIV-10), P1 (AI-24, AI-17), P2 (AI-14). Alias severity: AI-14 MEDIUM. State: AI-17 Partial; AI-24 and AI-14 Missing.
- **What:** policy named only Stripe, Razorpay and SSO. It omitted Anthropic and Gemini (raw diary, journal, OCR and screenshot text, quiz answers, GitLab review and workspace content sent with no scrubbing and no per-user AI consent; only a global `LLM_PROVIDER` switch), Brevo, Neon/Render/Vercel (Singapore), Backblaze B2 (USA), GitLab, MCP clients and the diary/journal/captures categories. Live `LLM_PROVIDER` unknown (blueprint says `disabled`). No secrets/passwords seen in prompts.
- **Evidence:** frontend/app/legal/privacy/page.tsx:21-34,57-58 (no vendor/AI/grievance matches, VR); diary/service.go:44-50,75-81; journal/handler.go:408-414; captures/job.go:102-110; ai/provider.go:21-31; render.yaml:25,27,33.
- **Risk:** Inaccurate notice; diary text sent to AI undisclosed; DPDP notice/consent for cross-border processing of the most sensitive data; DPDP notice + policy-to-code mismatch. AI-14 notice gap: student data flows to the user's own AI vendor under their terms.
- **Fix (recommended):** subprocessor list, AI section, in-product AI label, per-user AI consent for diary/captures, org-level AI switch. Acceptance: policy matches section 5.1; AI calls blocked without consent. Test: consent gate test.
- **Root cause (R6):** privacy page written from marketing intent, not the data flow; legal/process requirements never surface from a coding request.
- **Fix applied:** legal pages (privacy etc., `lib/legal-constants.ts`); AI consent setting (migration 055 `user_privacy_settings`) and settings card.
- **Status:** fixed-but-DB-test-not-run; operator-action: legal review of policy texts. **Verify:** whether AI calls are actually blocked server-side without consent.
- **Further source detail:** the policy also omits Google Calendar, a Singapore-transfer statement and object storage; no AI scrubbing, no per-user AI consent, only a global `LLM_PROVIDER` switch. Source fix: describe the connector + controls in the policy (AI-14); org-level AI switch. Extra evidence: internal/ai/anthropic.go:12; gemini.go:13; frontend/app/legal/privacy/page.tsx s1, s4.
- **Engineering ticket (section 13 of the report):** Title: Accurate notice + AI consent. Problem: vendors/categories missing. Why it matters: DPDP s.5. Affected files / APIs: frontend/app/legal/privacy; diary, captures AI paths.

#### H-21 (= PRIV-08 + PAY-10) - Grievance officer / E-Commerce seller details - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: grievance s.13 / E-Commerce Rules (PRIV-08 "Grievance"; PAY-10 "E-commerce rules"). Requirement: PRIV-08 DPDP s.13 grievance redressal, published contact (statutory); PAY-10 seller details, grievance officer, contact on site. Component: legal, legal pages. Owner: Legal. Priority: P1. Alias severity: PAY-10 MEDIUM. State: PAY-10 Missing.
- **What:** no Grievance Officer name, contact or SLA (DPDP s.13); support was an in-app ticket requiring login, so locked-out/deleted users could not reach it. No seller legal name, address or GSTIN on the site (E-Commerce Rules 2020). LEGAL REVIEW REQUIRED.
- **Evidence:** frontend/app/legal/* (no grievance/seller/registered office/GSTIN matches); privacy page s7.
- **Risk:** Non-compliant notice; locked-out/deleted users cannot reach support; non-compliance with the Consumer Protection (E-Commerce) Rules 2020.
- **Fix (recommended):** publish grievance officer, timelines, public channel and seller details. Acceptance: public page reachable logged out. Test: page smoke test.
- **Root cause (R6).** **Fix applied:** grievance page (`lib/legal-constants.ts`).
- **Status:** operator-action: set `GRIEVANCE_OFFICER_*`; legal review. **Verify:** seller legal name/address/GSTIN disclosure.
- **Further source detail:** the policy says only "in-app support ticket"; grep of frontend/app/legal for seller, grievance, registered office, GSTIN found nothing. Source fix: add seller legal name, address, grievance officer + timelines.
- **Engineering ticket (section 13 of the report):** Title: Grievance officer + seller details. Problem: absent. Why it matters: DPDP s.13; E-Com Rules. Affected files / APIs: frontend/app/legal/*. Required change: publish contact, SLA, seller info (legal drafts).

#### H-22 (= PRIV-22) - Missing legal documents - 🟠 HIGH - P1 - tag AU
- **Source fields (category / requirement / component / owner / priority):** Category: legal doc set (PRIV-22 "Legal docs"). Requirement: required docs. Component: legal. Owner: Legal. Priority: P1.
- **What:** present Terms, Privacy, Refund and the versioned acceptance gate. Missing Cookie, DPA, SLA, Security, standalone AUP (only Terms s4), grievance page.
- **Evidence:** frontend/app/legal/{terms,privacy,refund-policy,accept}.
- **Risk:** Enterprise blocker.
- **Fix (recommended):** draft the missing docs (legal drafts first). Acceptance: pages exist, linked from footer. Test: smoke test.
- **Root cause (R6).** **Fix applied:** privacy, grievance, security, cookie, AUP, DPA pages added.
- **Status:** fixed-and-built for the pages; SLA not listed -> verify; operator-action: legal review.
- **Further source detail:** E-Commerce Rules grievance officer is also LEGAL REVIEW REQUIRED. Source fix wording: "Draft the missing docs (do not rewrite yet)".
- **Engineering ticket (section 13 of the report):** Title: Missing legal docs. Problem: Cookie, DPA, SLA, Security, AUP. Why it matters: enterprise blocker. Affected files / APIs: frontend/app/legal. Required change: legal drafts, then pages.

#### H-23 (= PRIV-11) - Fiduciary/processor role, no DPA - 🟠 HIGH - P1 - tag AU
- **Source fields (category / requirement / component / owner / priority):** Category: fiduciary/processor (PRIV-11). Requirement: role clarity. Component: legal. Owner: Legal. Priority: P1.
- **What:** policy treats MindForge as sole controller; org tenants/mentors see learner data; MindForge likely a processor for B2B tenant learner data. No DPA existed. LEGAL REVIEW REQUIRED.
- **Risk:** B2B contractual gap.
- **Fix (recommended):** draft a B2B DPA available to orgs.
- **Root cause (R6).** **Fix applied:** DPA page and `DPA_CONTACT_EMAIL`. **Status:** operator-action: legal review of the DPA text and role.
- **Further source detail:** whether MindForge is a processor for org data is LEGAL REVIEW REQUIRED; evidence: frontend/app/legal (accept, privacy, refund-policy, terms only).
- **Engineering ticket (section 13 of the report):** Title: B2B DPA + role clarity. Problem: no DPA. Why it matters: contractual exposure. Affected files / APIs: legal. Required change: draft DPA (LEGAL REVIEW). Acceptance criteria: DPA available to orgs. Tests: n/a.

#### H-24 (= PRIV-12) - Children's data / age gate - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: children s.9 (PRIV-12 "Children"). Requirement: DPDP s.9 verifiable parental consent under 18 (statutory). Component: auth. Owner: Legal. Priority: P1.
- **What:** no DOB, age declaration or age gate; policy silent on minors (DPDP s.9). LEGAL REVIEW REQUIRED.
- **Evidence:** grep dob/date_of_birth/parental over `internal`: 0 hits; auth/handler.go register path; legal pages.
- **Risk:** If minors register, s.9 is breached.
- **Fix (recommended):** 18+ declaration or verifiable parental consent. Acceptance: under-18 cannot complete signup without the flow. Test: handler tests.
- **Root cause (R6).** **Fix applied:** social signup needs an 18+ declaration (migration 057).
- **Status:** fixed-but-DB-test-not-run (social path). **Verify:** password registration path.
- **Further source detail:** Source fix wording: age declaration, 18+ policy or parental consent; LEGAL REVIEW REQUIRED.
- **Engineering ticket (section 13 of the report):** Title: Age gate. Problem: none. Why it matters: DPDP s.9. Affected files / APIs: auth register + social paths. Required change: age declaration / parental flow.

#### H-25 (= PRIV-13) - Incident response / breach notice - 🟠 HIGH - P1 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: breach notice s.8(6) / CERT-In 6h (PRIV-13 "Breach"). Requirement: DPDP s.8(6) Board + principal notice; CERT-In 6h (statutory). Component: ops. Owner: Ops/Legal. Priority: P1.
- **What:** no IR runbook, security contact, CERT-In POC or notification mechanism (DPDP s.8(6); CERT-In 6h). No error-tracking/alerting vendor, so detection is weak. LEGAL REVIEW REQUIRED.
- **Evidence:** grep breach/CERT-In in legal: 0.
- **Risk:** Cannot meet the timelines without a process.
- **Fix (recommended):** IR runbook, POC, alerting, notification templates. Acceptance: tabletop exercise done.
- **Root cause (R6).** **Fix applied:** security page added with `SECURITY_CONTACT_EMAIL`; no runbook/alerting itemised.
- **Status:** open (runbook, CERT-In POC, alerting); operator-action: set `SECURITY_CONTACT_EMAIL`.
- **Further source detail:** no breach runbook, notification mechanism or security contact in code/docs/UI; evidence also from the ai-mcp-3p subprocessor table. Source fix: IR runbook, security contact, CERT-In POC.
- **Engineering ticket (section 13 of the report):** Title: Incident response readiness. Problem: no runbook/POC/alerting. Why it matters: CERT-In 6h, DPDP s.8(6). Affected files / APIs: docs, ops. Required change: runbook, POC, alerting, templates. Tests: n/a.

#### H-26 (= AUTHN-06 = PRIV-14 + PRIV-15 + PRIV-16) - Audit trail and log retention - 🟠 HIGH - P1 - tag VR (auth); rest AU
- **Source fields (category / requirement / component / owner / priority):** Category: audit trail + log retention (AUTHN-06 "Audit trail"; PRIV-14 "Audit"; PRIV-15 "Audit integrity"; PRIV-16 "Log retention"). Requirement: AUTHN-06 log login, failed login, password reset/change, passkey add/remove, logout-all, MCP connect/revoke; PRIV-14 audit coverage; PRIV-15 tamper resistance; PRIV-16 CERT-In 180-day logs, India jurisdiction (LEGAL REVIEW REQUIRED). Component: auth, mcpconnect, audit, infra. Owner: Backend (AUTHN-06, PRIV-14, PRIV-15), Ops (PRIV-16). Priority: P1. Alias severity: AUTHN-06 MEDIUM, PRIV-15 MEDIUM. State: AUTHN-06 Missing.
- **What:** no audit rows for login, failed login, reset, passkey, logout-all, MCP connect/revoke, export, deletion or billing (auth pkg: 0 audit refs; audit written from authz admin_service, coupons, features, library, labs, mcpconnect, ~11 sites). Audit writes ignore errors (`_ =`), are not append-only, never set `ip_address`, and live in the shared dev/prod DB. `mcp-action-log` covers tool calls, not connect/revoke. App logs go to Render stdout with default retention, in Singapore; CERT-In 180-day India log retention unmet (LEGAL REVIEW REQUIRED).
- **Evidence:** auth/*.go (0 "audit"); authz/admin_service.go:41-263; audit_repo.go:51; 001_baseline.sql:445; api/router.go:183; orgs/member.go:290-300; render.yaml.
- **Risk:** No forensic or CERT-In-style evidence for account takeover; no source for user-visible "recent activity"; incident response is blind. Cannot reconstruct incidents or prove deletions. Silent audit loss; rows editable. CERT-In 180-day India retention likely not met.
- **Fix (recommended):** append-only `auth_events` + central emitter; fail on audit error; log sink with 180-day retention. Acceptance: login/reset/export/delete produce rows; update denied. Test: DB tests.
- **Root cause (R6/R3):** audit writes added per admin feature; the auth package was written before any audit requirement existed.
- **Fix applied:** append-only `auth_events` (migration 056, delete-deny trigger) in new `authevents` package.
- **Status:** fixed-but-DB-test-not-run for auth events. **Open / operator-action:** audit write error handling in existing `_ =` sites (verify), `ip_address` population (verify), 180-day India log sink.
- **Further source detail:** only org member/role changes are audited; failed logins are recorded nowhere beyond the rate limiter; `mcp-action-log` covers tool calls, not connect or revoke; audit has no append-only trigger/REVOKE. Source fix: `auth_events` table (user, event, ip prefix, ua hash, ts); central audit emitter for auth/export/delete/billing; log/fail on error; append-only grants; populate IP; India-region log store with 180d retention. Extra evidence: orgs/member.go:290-300; authz/admin_service.go:41-263; privacy/handler.go (none); render.yaml.
- **Engineering ticket (section 13 of the report):** Title: Auth audit trail + log retention. Problem: no auth events; mutable audit. Why it matters: forensics, CERT-In. Affected files / APIs: auth/*, privacy, mentoring, audit_repo.go. Required change: append-only events table, central emitter, 180-day sink.

#### H-27 (= PRIV-18) - No retention schedule - 🟠 HIGH - P2 - tag AU
- **Source fields (category / requirement / component / owner / priority):** Category: retention s.8(7) (PRIV-18 "Retention"). Requirement: DPDP s.8(7) erase when purpose served. Component: jobs. Owner: Backend. Priority: P2.
- **What:** purge jobs only for tokens, lab sessions, lab builds (30d), warm pool decisions and project interests. Nothing for diary, journal, captures, AI interactions, attempt_events, audit_logs, xp_events or inactive accounts. Policy: kept while account active (DPDP s.8(7)).
- **Evidence:** jobs/handlers/analytics.go:102-114; workspace_purge.go; labbuild/jobs.go:13.
- **Risk:** Indefinite retention.
- **Fix (recommended):** retention schedule + purge jobs. Acceptance: rows older than policy removed. Test: job tests.
- **Root cause (R6).** **Fix applied:** retention purge job (`15 3 * * *`) with `Retention*` config; `mcp_connections` purge (`RETENTION_MCP_CONNECTION_DAYS`, default 90).
- **Status:** fixed-but-DB-test-not-run. **Verify:** which data types the job covers versus the list above; the policy text still needs a retention statement.
- **Engineering ticket (section 13 of the report):** Title: Retention schedule. Problem: indefinite. Why it matters: DPDP s.8(7). Affected files / APIs: jobs/handlers.

#### H-28 (= PRIV-07) - Nomination (DPDP s.14) - 🟠 HIGH - P2 - tag VR
- **Source fields (category / requirement / component / owner / priority):** Category: nomination s.14 (PRIV-07 "Rights"). Requirement: DPDP s.14 nomination (statutory; LEGAL REVIEW REQUIRED on commencement). Component: privacy. Owner: Legal/Backend. Priority: P2.
- **What:** no nomination mechanism anywhere (grep nominat: 0). LEGAL REVIEW REQUIRED (commencement of Rules).
- **Risk:** Missing right.
- **Fix (recommended):** nominee field + process. Acceptance: nominee stored and exercisable. Test: handler tests.
- **Root cause (R6).** **Fix applied:** nominee settings (migration 055) and settings card.
- **Status:** fixed-but-DB-test-not-run; "exercisable" process is operator/legal.
- **Further source detail:** Evidence: grep nominat over backend/frontend/docs: none.
- **Engineering ticket (section 13 of the report):** Title: Nomination. Problem: missing. Why it matters: DPDP s.14. Affected files / APIs: profile/privacy.

#### H-29 (= PAY-01 + PAY-02 + PAY-03) - Paid but not fulfilled - 🟠 HIGH - P1 - tag VL/VR
- **Source fields (category / requirement / component / owner / priority):** Category: paid but not fulfilled (PAY-01 "Webhook idempotency"; PAY-02 "Webhook idempotency"; PAY-03 "Reconciliation"). Requirement: PAY-01 a transient failure while applying a verified event must be recoverable by gateway retry or reconciliation; PAY-02 same for session credit packs; PAY-03 periodic reconciliation with the gateway. Component: mentoring webhook, mentoring/sessions, payments. Owner: Backend. Priority: P1 (PAY-01, PAY-02), P2 (PAY-03). Alias severity: PAY-03 MEDIUM. State: PAY-01/02 Partial; PAY-03 Missing.
- **What:** the `payment_events` row is inserted before processing (UNIQUE provider,event_id). If `confirmPurchase` fails (DB blip), the handler returns 500 but redelivery hits `inserted=false` and is a silent no-op, so the purchase stays pending though paid; the code comment claiming gateway retry recovers it is wrong. The pack path marks the error and returns 200, so no retry. No reconciliation sweep exists (pending purchases only expire for coupon holds).
- **Evidence:** mentoring/service_purchase.go:306-314,329-336,365-377; handler_webhook.go:44-50; repo.go:185-195,366-381; sessions/service_checkout.go:138-141.
- **Risk:** Customer charged, no enrollment or credits; paid but uncredited packs with manual fix only; silent revenue/entitlement drift.
- **Fix (recommended):** dedup only on processed rows (or one tx); reconcile pending > N min; alert on `payment_events.error`. Acceptance: simulated DB blip then redelivery completes the purchase. Test: DB test with fault injection.
- **Root cause (R4):** the two halves were written in separate sessions and each looked correct alone; failure handling (retry, crash between steps) was not in the feature description; no test crashed between steps. Rule added: a dedupe key means "fully handled", not "seen".
- **Fix applied:** webhook retry, `ReconcilePayments` job (`*/15 * * * *`), migration 059.
- **Status:** fixed-but-DB-test-not-run.
- **Further source detail:** Source fix detail: dedup only on rows with `processed_at NOT NULL` (or insert + process in one tx / re-process unprocessed rows); sweep over `idx_payment_events_unprocessed`; scheduled job fetching order/session status for pending > 30 min; reconciliation from `payment_events.error`. Extra evidence: repo.go:366-381; handler_webhook.go:44-49.
- **Engineering ticket (section 13 of the report):** Title: Webhook recovery + reconciliation. Problem: paid but pending. Why it matters: customer harm. Affected files / APIs: mentoring/service_purchase.go:306-377; sessions/service_checkout.go.

#### H-30 (= PAY-08) - GST invoice - 🟠 HIGH - P1 - tag AU
- **Source fields (category / requirement / component / owner / priority):** Category: GST invoice (PAY-08 "GST / invoicing"). Requirement: GST invoice, GSTIN, tax breakup, place of supply, credit notes, B2B vs B2C. Component: purchases. Owner: CA + Backend. Priority: P1. State: Missing.
- **What:** receipt only (MF-YYYY-NNNNNN): amount/discount/currency/provider/status; no GSTIN (seller/buyer), HSN/SAC, tax breakup, place of supply or credit note on refund; global sequence, not per-FY. CA REVIEW REQUIRED (applicability; tax-inclusive pricing).
- **Evidence:** mentoring/repo.go:291; service_purchase.go:238-242; no gstin/tax columns in migrations.
- **Risk:** Possible tax invoice non-compliance.
- **Fix (recommended):** CA defines; then tax fields, invoice and credit-note numbering. Acceptance: invoice shows CA-required fields. Test: invoice render test.
- **Root cause (R6):** tax compliance is not a coding task until someone schedules it.
- **Fix applied:** none. **Status:** open / operator-action (CA).
- **Further source detail:** Source note: the receipt sequence resets nothing per FY; the sequence is global.
- **Engineering ticket (section 13 of the report):** Title: GST invoicing. Problem: receipt only. Why it matters: tax compliance. Affected files / APIs: mentoring/repo.go; migrations. Required change: after CA input, tax fields, invoice/credit-note series.

### 3.3 🟡 MEDIUM

Tag AU unless noted. "Fix applied" is from the changelog; `verify` = not clearly itemised.

| ID (aliases) | Finding and evidence | Root cause | Fix applied | Status | Risk (source) | Source fields (category / requirement / component / owner / priority) |
|---|---|---|---|---|---|---|
| M-01 (AUTHN-03) | No MFA/TOTP; passkeys optional; `UserVerification` only "preferred"; docs describe step-up that does not exist. auth/webauthn.go:197,493. Fix: TOTP + recovery codes; require for privileged roles (P1) | R5/R6: passkeys were additive; MFA never a feature request | TOTP MFA (`mfa.go`, `totp.go`), recovery codes, migration 060 `user_mfa`, required for org owners/admins and platform roles, `/login/mfa` page; QR code (dep `qrcode`); `POST /api/auth/mfa/recovery-codes` (TOTP only, audited, emails notice); DB tests `auth/mfa_db_test.go` | fixed-but-DB-test-not-run; operator: apply 060 to a dev copy first, owners/admins will be forced to enrol | Admin, owner and platform roles are protected by a password alone; credential stuffing and phishing succeed with one factor; enterprise buyers will ask for this. | Category: MFA. Requirement: MFA or step-up for password and OAuth accounts, and for admin roles. Component: auth. Owner: Backend/Frontend. Pri: P1. Source state: Missing. Fix wording: require MFA or a passkey for org admin, owner and platform roles. Extra evidence: grep for totp/mfa/step-up in `internal` returns no auth code. |
| M-02 (AUTHN-04) | `sso_enabled`/`allowed_domains` stored and editable but never read; no OIDC/SAML/magic link despite docs (false assurance). orgs/handler.go:384-445; orgs/onboarding.go:159-175; auth/handler.go:372-445,1235. Fix: enforce or remove from UI/docs (P2) | R9: design doc read as shipped; schema columns made it look real | docs synced, unbuilt features marked "planned (not built)" | verify (UI toggle removal not itemised) | The control gives false assurance: an org that believes password login is disabled still accepts it; docs and code are out of sync. | Category: SSO (OIDC/SAML) / magic link. Requirement: `docs/auth.md` documents OIDC/SAML, magic-link login, `require_sso`, `allow_*` toggles and `switch-org` enforcement. Component: auth, orgs. Owner: Backend/Docs. Pri: P2. Source state: Missing (login always mints a session in `DefaultOrgID`; no read of `org_auth_config`). |
| M-03 (AUTHN-07) | No email on password reset/change or passkey add/remove; only duplicate-registration and passkey-clone advisories. auth/handler.go:916-1020; auth/email.go:52-79. Fix: enqueue notifications (P2) | R1: not in feature description | recovery-code regeneration emails a notice; change-password endpoint added | verify (reset/passkey notices) | A silent account takeover through the reset path goes unnoticed. | Category: notifications. Requirement: notify the user on password reset/change, new passkey, new-device login. Component: auth. Owner: Backend. Pri: P2. Source state: Missing. Fix wording: enqueue a notification email at the end of `HandleResetPassword` and on passkey add/remove. Extra evidence: no enqueue after commit. |
| M-04 (AUTHN-08) | 10/min per-account limit counts successes; no backoff/CAPTCHA/failed-count lockout; victim can be throttled; ~14,400 guesses/day/account; in-memory fallback per replica when Redis down. auth/handler.go:122-133,376-378; config/config.go:372,387; middleware/ratelimit.go:28-37. Fix: count failures, backoff, CAPTCHA (P2) | R3 | login lockout keyed by email and IP; Cloudflare Turnstile on register, login, forgot-password (`RequireCaptcha`, `X-Captcha-Token`), prod refuses to start without `TURNSTILE_SECRET_KEY`; MFA verify not gated; demo login and admin reset use `X-Captcha-Bypass`/`CAPTCHA_BYPASS_SECRET` (set on both sides) | fixed-and-built; operator: create Turnstile keys, set `TURNSTILE_SECRET_KEY`, `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `CAPTCHA_BYPASS_SECRET`, test the widget in a browser | Slow online guessing stays viable; deliberate throttling of a target user is possible. | Category: rate limit / lockout. Requirement: brute-force protection per account, with backoff and no easy lockout-DoS. Component: auth. Owner: Backend. Pri: P2. Source state: Partial (login limited to 10/min per account via `AuthRateLimitMax` plus per IP+path; in-memory fallback per replica when Redis is down is a documented tradeoff). Fix wording: count only failures; exponential backoff (e.g. 5 failures then 15-minute cool-off) with a notification; CAPTCHA after N failures. Extra evidence: ratelimit/ratelimit.go:75-79. |
| M-05 (AUTHN-12) | Open redirect: `safeNextPath` rejects `//host` but allows `/\evil.com` (browsers normalise `\`); used after login, last-visited and legal accept. frontend/lib/utils.ts:17-20; login/actions.ts:97,165; login/page.tsx:27; legal/accept/actions.ts:26; last-visited/route.ts:6-14. Fix: reject `\`/control chars; compare origin via `new URL` (P1) | R1: happy-path redirect worked; no negative input test | none itemised | open | A phishing link `/login?next=/\evil.com` sends the user to an attacker page right after authentication. | Category: open redirect. Requirement: `next` redirect targets must be same-origin. Component: frontend. Owner: Frontend. Pri: P1. Source state: Partial (browsers normalize `\` to `/`, so the Location becomes `//evil.com`). Fix wording: reject any `\` and control characters; better, parse with `new URL(next, origin)` and compare origins. |
| M-06 (AUTHN-14 + PRIV-09) | Social signup writes no `legal_acceptances`; consent bundled with ToS; no purpose-level consent or withdrawal (LEGAL REVIEW REQUIRED). auth/handler.go:307-318; auth/social.go:508-536; legal/repo.go:18-30; legal/models.go:24-33; frontend callback route.ts:55+. Fix: record on all paths, separate AI/marketing consents + withdrawal (P1) | R6 | AI consent setting (migration 055); social 18+ declaration (057) | verify (acceptance row on social signup; withdrawal flow); legal review | A social-only account can exist before consent is recorded (AUTHN-14); bundled consent, LEGAL REVIEW REQUIRED (consent vs legitimate use) (PRIV-09). | Category: consent capture on social signup (AUTHN-14); consent (PRIV-09). Requirement: AUTHN-14 Terms and Privacy acceptance recorded for every signup path, LEGAL REVIEW REQUIRED (DPDP consent proof); PRIV-09 DPDP s.5-6 notice/consent, withdrawal. Component: auth, legal. Owner: Backend/Legal (AUTHN-14), Legal (PRIV-09). Pri: P2 (AUTHN-14), P1 (PRIV-09). Source state: Partial (password registration writes `legal_acceptances` with version and IP prefix; a frontend legal-gate redirect `resolveLegalGateRedirect` may capture it later, whether it is a hard block is Cannot verify; acceptance is recorded append-only with version + truncated IP: Implemented; no granular consent for AI processing, calendar sync, marketing). Fix wording: insert the acceptance in `findOrCreateSocialUser`, or block session use until the gate is satisfied; separate purpose consents + withdraw flow. |
| M-07 (TEN-09) | Mentor role has org-wide batch, attempt, proctoring and analytics read/write (no `batch_mentors` predicate). assessment/routes.go:49-50,115-150; handler_assessment.go:509-585; handler_batch_ext.go:277-289; handler_dashboard.go:16-28; handler_analytics.go:25-60. (Contrast: sessions.MenteeProgress enforces mentor<->student.) Fix: `batch_mentors` predicate (P2) | R1: comment said "mentor managing their own students" but nothing enforced it | mentor scoping (`mentor_scope.go`); DB tests `assessment/mentor_scope_db_test.go` | fixed-but-DB-test-not-run | A mentor reads/edits any learner cohort's results (PII, scores). | Category: over-privilege (intra-tenant). Requirement: mentor limited to their assigned batches/students. Component: assessment. Owner: Backend. Pri: P2. Source state: FAIL (`staffAll` incl. mentor gives org-wide GET batch, members, progress, analytics, assessment attempts, proctoring logs and POST/DELETE batch members for ANY batch; only org_id is checked). Fix wording: add a batch_mentors membership predicate for the mentor role in batch/attempt/analytics repo calls. |
| M-08 (TEN-10) | Own-org admin can edit/delete platform-wide interview-exp content (`UpdateQna/DeleteQna/DeleteComment` allow `orgRole==admin`). interviewexp/service.go:185-210,248-258; routes.go:22-41. Fix: super_admin moderation only (P2) | R1 | none itemised | verify (interviewexp files changed per git status) | Any self-made org admin can vandalise/delete all tenants' shared content. | Category: cross-tenant write authority. Requirement: org admin authority must end at the org boundary. Component: interviewexp. Owner: Backend. Pri: P2. Source state: FAIL (interview-exp is platform-wide, no org_id, docs/interview.md L11; the admin role is cheaply obtainable, TEN-01 note). Fix wording: use a platform moderation permission (super_admin) for cross-org content; keep author-only edit. |
| M-09 (TEN-11) | Public roadmap resolves private/draft course, lab and question titles/slugs by raw id. roadmap/repo.go:153-173,270-370 (291-310); routes.go:41-45; service.go:110-130. Fix: resolve only published + public items (P2) | R1 | none itemised | verify | Leak of unpublished course/lab names across tenants to anonymous users. | Category: cross-tenant read (titles). Requirement: public/anon roadmap must not resolve non-public catalog items. Component: roadmap. Owner: Backend. Pri: P2. Source state: FAIL (`GET /api/roadmaps/{id}` OptionalAuth + is_public, and fork, resolve courses/lab_definitions/questions by raw id with no org/publish filter). Fix wording: resolve only items visible to anonymous (published + is_public) in the public view; org-scope in the owner view. Extra evidence: roadmap/repo.go:175. |
| M-10 (TEN-12) | `OrgStatusGate` defined, applied to zero routes; suspended/archived/unverified orgs keep access (only workspace has its own gate). middleware/org.go:102-145; workspace/middleware.go:160. Fix: global org-status middleware after RequireAuth (P2) | R4/R3: middleware written, never wired; nothing tested a suspended org | none itemised | verify | Suspension for non-payment/abuse cannot be enforced; unverified orgs are fully usable. | Category: org lifecycle control missing. Requirement: suspended/archived/pending orgs must lose API access. Component: middleware. Owner: Backend. Pri: P2. Source state: FAIL (members of suspended/archived or unverified `pending_verification/onboarding` orgs keep full access via `claims.OrgID`; grep shows no callers of `OrgStatusGate`). Fix wording: apply the status check in a global org-context middleware after RequireAuth. |
| M-11 (TEN-13) | Admin can demote, suspend or remove peer admins (only owners protected). orgs/member.go:96-135,225-235; orgs/types.go:50-64. Fix: actor rank > target rank (P2) | R1 | `outranks` check (admins cannot manage peers) | fixed-but-DB-test-not-run | A rogue/compromised admin removes peers; no owner approval. | Category: peer escalation. Requirement: admin must not manage peer admins. Component: orgs. Owner: Backend. Pri: P2. Source state: Partial (`CanGrantRole(admin, learner)` is true and there is no rank check on the target; the last-owner guard exists as a DB constraint). Fix wording: require actor rank > target rank for role/status/removal. |
| M-12 (TEN-14 = RT-16) | ICS feed `?token=` never expires, ignores user/member status, token logged in URLs, no rate limit. calendar/handler.go:416-442; calendar/service.go:398; calendar/repo.go:664,693; router.go:90. Fix: expiry, status check, revoke on removal, redact logger (P2) | R1/R3 | `RedactRequestURI` middleware; expiry/status check not itemised | verify (partial: log redaction fixed-and-built) | Removed member keeps the org calendar (batch/course/session titles) (TEN-14); token leakage via logs/Referer exposes the calendar (RT-16). | Category: long-lived share/feed token (TEN-14); unauth/ICS feed (RT-16). Requirement: TEN-14 calendar feed token must stop working for removed/locked users; RT-16 token in query. Component: calendar. Owner: Backend. Pri: P2. Alias severity: RT-16 MEDIUM. Source state: FAIL (`events.ics?token=` resolves `(user_id, org_id)` from `auth_tokens` with no expiry, user status or org-membership check). Fix wording: check active membership + user status on resolve; set expiry; revoke on removal; redact the query in the logger, rate limit. Extra evidence: calendar/handler.go:416-426. |
| M-13 (SEC-06) | Lab cooldowns fail open on Redis error; no per-user or global host cap (per-org default 20, clean-room semaphore 4). labs/service.go:1062-1064,1173-1188; labs/models.go:11; repo.go:184-210; service_grade.go:35,310. Fix: fail closed, capacity caps (P2) | R7 | none itemised | verify | Cost/DoS if Redis is down or many orgs each take 20 sessions. | Category: labs / quotas. Requirement: per-user/org quotas. Component: labs service. Owner: Backend. Pri: P2. Source state: per-org MaxConcurrentSessions default 20, run/submit/verify/hint cooldowns via Redis SetNX, clean-room semaphore of 4; cooldowns fail OPEN on Redis error; per-user session cap and total host capacity cap not verified. Fix wording: fail closed (or local fallback limiter) on Redis error; add a global host capacity cap and a per-user cap. |
| M-14 (SEC-07) | Lab egress proxy and `lab_egress_rules` documented but no implementation found. docs/labs.md:129,338-346,740. Fix: build it or remove the claim (P2) | R9 | docs synced ("planned (not built)") | open (doc corrected; control not built) | Docs claim a control that may not exist. | Category: labs / egress proxy. Requirement: allowlisted egress enforces the SSRF denylist. Component: labs. Owner: Backend. Pri: P2. Source state: documented only; grep finds no proxy implementation in backend code (not located). Fix wording: confirm implemented or remove the claim; if built, test the denylist + DNS rebinding. |
| M-15 (SEC-11) | netguard denylist misses 100.64/10, 198.18/15, 0.0.0.0/8, 192.0.0.0/24, multicast, NAT64 (64:ff9b::/96), 6to4 (2002::/16); no redirect-count/scheme re-check; 5MB response cap. netguard/denylist.go; captures/extract.go:54-57,92. Fix: explicit CIDR list (P2) | R7 | extended denylist in `netguard.NewHTTPClient` | fixed-and-built | Reach to cloud-provider internal ranges (e.g. Tailscale/100.64). | Category: SSRF. Requirement: denylist completeness. Component: netguard. Owner: Backend. Pri: P2. Source detail: also missing global multicast; 0.0.0.0/8 only partially covered via unspecified; redirects are re-dialed through the guarded transport (good). Fix wording: add an explicit CIDR list incl. 100.64/10, 198.18/15, 0.0.0.0/8, 64:ff9b::/96, 2002::/16. |
| M-16 (SEC-14) | Presigned PUT takes `maxBytes`/`mimeType` but never uses them (30-min arbitrary upload). storage/minio.go:112-120. Fix: POST policy with content-length-range + type (P1) | R1: parameters present, never wired | none itemised | verify (open) | Storage cost abuse; hostile content type served from the media bucket. | Category: uploads. Requirement: presigned PUT enforces size/type. Component: storage. Owner: Backend. Pri: P1. Source detail: `PresignedPutURL` takes maxBytes and mimeType but never uses them (no content-length-range policy; the mime is a local unused variable); an uploader can put arbitrary size/type via the URL for 30 min. Fix wording: presigned POST policy with content-length-range + content-type condition, or proxy uploads. |
| M-17 (SEC-18 = RT-21) | No global body cap; `DecodeJSON` unbounded; MaxBytesReader only in 8-12 handlers; server Read 15s/Idle 60s. httputil/response.go:40-46; cmd/server/main.go:422-431. Fix: global MaxBytesHandler (P2) | R3 | `MaxBody` middleware | fixed-and-built | Memory DoS on unbounded JSON endpoints; large-body DoS (RT-21). | Category: body size limits (SEC-18); server limits (RT-21). Requirement: global body cap. Component: api, server. Owner: Backend. Pri: P2. Alias severity: RT-21 LOW. Source detail: MaxBytesReader is per-handler (captures, import, avatar, labs files, courses upload, workspace interest, labauthor, labbuild; grep: 12 sites, RT-21 counts 8 handlers); `http.Server` ReadTimeout 15s, IdleTimeout 60s. Fix wording: global `http.MaxBytesReader` middleware (e.g. 1MB) with per-route overrides. |
| M-18 (SEC-19 = INF-13) | API sets no nosniff/HSTS; relies on Caddy/Next. router.go:677-694. Fix: secure-headers middleware (P2) | R7 | `SecureHeaders` middleware | fixed-and-built | Weaker defense in depth; API lacks nosniff/HSTS (JSON only, low) (INF-13). | Category: security headers (API) (SEC-19); security headers (INF-13). Requirement: API/edge headers. Component: api/edge, Headers. Owner: Platform (SEC-19), Eng (INF-13). Pri: P2 (SEC-19), P3 (INF-13). Alias severity: INF-13 INFO. Source detail: relies on the Caddyfile (no header directives found besides a labproxy host comment) and Next headers; frontend headers are good; backend JSON responses lack nosniff; CSP has `unsafe-inline` scripts and `connect-src ws: wss:`. Fix wording: secure-headers middleware or a Caddy `header` block; tighten connect-src to the known WS host. Extra evidence: next.config.ts:23-52 (frontend/next.config.ts:23-33 for INF-13); router.go:682-685. |
| M-19 (RT-02, downgraded from HIGH) | labproxy `CheckOrigin` returns true; token is query-borne, not a cookie, so CSWSH needs the token. cmd/labproxy/proxy.go:116-118 (VR). Fix: origin allowlist (P2) | R7 | allowed-origins config in labproxy | fixed-and-built; operator: set `LABPROXY_ALLOWED_ORIGINS` | A cross-site page can drive the lab terminal if it holds a token; no defence in depth. | Category: WS/CSWSH. Requirement: Origin check on the WS upgrade. Component: labproxy. Owner: Backend. Pri: P1 (RT-02 raw), P2 (merged report). Alias severity: RT-02 HIGH (downgraded to MEDIUM). Fix wording: CheckOrigin allowlist from env. |
| M-20 (RT-03 = TEN-22 part) | Lab WS token in query string (`?session_token=`, logged); Redis registry check fails open. cmd/labproxy/proxy.go:131,360-368. Fix: subprotocol token; fail closed (P2) | R7 | lab token moved to a WebSocket subprotocol | fixed-and-built; verify (Redis fail-open); deploy frontend and labproxy together | Token in proxy/CDN logs; revocation bypass during a Redis outage. | Category: WS/token in URL (RT-03). Requirement: no tokens in query string/logs. Component: labproxy. Owner: Backend. Pri: P2. TEN-22 part: move the token to a header/subprotocol when feasible (P3). Fix wording: Sec-WebSocket-Protocol or first-message auth; fail closed. |
| M-21 (RT-04) | No WS `SetReadLimit` or per-user connection cap in labproxy. Fix: limits (P2) | R7 | none itemised | verify | Memory/bandwidth DoS by one authed user. | Category: WS limits. Requirement: message size, connection limits. Component: labproxy. Owner: Backend. Pri: P2. Fix wording: SetReadLimit, per-user WS cap (Redis). Evidence: grep SetReadLimit backend/cmd/labproxy: none. |
| M-22 (RT-11) | Public attempt token in URL path, logged by chi Logger, no expiry; result returns candidate name. router.go:90; assessment/routes.go:209-210; repo_public.go CreatePublicAttempt. Fix: header token, redact, expiry (P2) | R1 | token moved to `X-Attempt-Token` header (legacy paths still work, deprecation log); `RedactRequestURI` | fixed-but-DB-test-not-run; expiry verify; legacy path still live | Log readers can read/submit results. | Category: public tests/token. Requirement: token exposure. Component: assessment. Owner: Backend. Pri: P2. Source detail: the token is `gen_random_uuid()` (unforgeable). Fix wording: header/body token, redact the logger, expiry. |
| M-23 (RT-12) | Public test name/email/phone kept indefinitely in `anonymous_identity` jsonb; no notice; no IP stored (LEGAL REVIEW REQUIRED). assessment/repo_public.go:47. Fix: purge job + notice (P2) | R6 | retention purge job (coverage not itemised) | verify | DPDP minimisation/retention; LEGAL REVIEW REQUIRED. | Category: public tests/PII+IP. Requirement: IP storage + retention. Component: assessment. Owner: Backend/Legal. Pri: P2. Source detail: name/email/phone in jsonb `anonymous_identity`; no retention purge or notice found; no IP stored. Fix wording: purge job, notice on the start form. |
| M-24 (RT-15 = TEN-16) | Public certificate JSON exposes internal `user_id`, `issued_by`, `assessment_attempt_id`, `course_id` plus learner name; no rate limit (UUID unguessable). certificates/repo.go:218-236; models.go:68-91; routes.go:67-68. Fix: minimal public DTO + rate limit (P2) | R1 | certificates files changed (git) but not itemised | verify | Internal IDs/name leak to anyone with a certificate link; feeds ID harvesting. | Category: unauth/certificate (RT-15); public over-exposure (TEN-16). Requirement: RT-15 cert verify exposure; TEN-16 public verification should expose the minimum. Component: certificates. Owner: Backend. Pri: P2 (RT-15), P3 (TEN-16). Alias severity: TEN-16 LOW. Source state: Partial (UUID is unguessable but the ids are unnecessary). Fix wording: dedicated public DTO (name, course title, issue date, status), rate limit. |
| M-25 (AI-07 = AUTHN-17) | MCP refresh rotation has no reuse detection; update not compare-and-set (concurrent refreshes both succeed); scope cannot be narrowed. mcpconnect/repo.go:190-217; oauth_token.go:73-112,297-315. Fix: CAS update, revoke on reuse (P2) | R4: race class already fixed on core refresh path, not repeated here | refresh-token rotation with reuse detection (migration 058) | fixed-but-DB-test-not-run | A stolen refresh token used first goes unnoticed; a thief who rotates first locks out the user without detection. | Category: refresh rotation (AI-07); MCP refresh reuse (AUTHN-17). Requirement: rotation with reuse detection. Component: mcpconnect. Owner: Backend. Pri: P2 (AI-07), P3 (AUTHN-17). Alias severity: AUTHN-17 LOW. Source state: Partial (the refresh hash is overwritten on use so the old one is invalid, but there is no family or reuse detection). Fix wording: `UPDATE ... WHERE refresh_token_hash=old`; keep the previous hash and revoke the connection on its reuse. |
| M-26 (AI-10) | Omitted scope grants all 11 MCP scopes; re-approve overwrites with no re-consent. mcpconnect/oauth_authorize.go:46-48; models.go:44; repo.go:158-170; routes.go:392-393. Fix: least-scope default, per-scope opt-out (P2) | R1 | per-scope re-consent; MCP authorize consent component | verify (least-scope default) | Over-broad grant; a prompt-injected client can mutate/delete data. | Category: consent / scope. Requirement: granular, informed consent. Component: mcpconnect, frontend. Owner: Backend+FE. Pri: P2. Source state: Partial (consent lists scopes but offers no per-scope opt-out; an omitted scope param grants ALL 11 scopes incl. journal, calendar delete, wiki write; mutating tools have a revert log, good). Fix wording: default least scope; per-scope checkboxes. |
| M-27 (AI-12) | `mcp_action_log` (audit_logs) stores full args and before/after personal text; no retention; survives erasure. mcpconnect/action_log.go:34,112-121. Fix: retention + purge on erasure (P2) | R2/R6 | erasure deletes MCP audit rows | fixed-but-DB-test-not-run; retention window verify | A second copy of sensitive content outliving deletion. | Category: MCP logging. Requirement: logs free of personal content. Component: mcpconnect, privacy. Owner: Backend. Pri: P2. Source state: Partial (stores journal/diary/habit/note text). Fix wording: retention limit + purge on erasure. |
| M-28 (AI-16) | Single unversioned AES key (sha256 of `ENCRYPTION_KEY`), no KDF/rotation, shared dev/prod. secrets/secrets.go:23-45; config/config.go:314,347. Fix: key ID + rotation; separate prod key (P2) | R7 | none | open; operator: separate prod key | Compromise/rotation is impossible without re-encrypting. | Category: encryption key. Requirement: key management for at-rest secrets. Component: secrets. Owner: Backend. Pri: P2. Source state: Partial (AES-256-GCM, key = sha256(ENCRYPTION_KEY), no KDF/versioning/rotation; single key shared across dev/prod per the shared env memory). Fix wording: key-id prefix + rotation; separate prod key. |
| M-29 (AI-18) | No DPA or ZDR evidence for Anthropic/Gemini; Gemini free tier may train (Cannot verify; contractual). ai/anthropic.go:12,23; ai/gemini.go:13,24; config/config.go:419-423. Fix: paid/ZDR tier, DPAs, vendor register (P1) | R6 | none | operator-action | Training on student text; unreviewed US transfer. | Category: AI provider terms. Requirement: retention/training terms. Component: ai. Owner: Owner/Legal. Pri: P1. Source state: Cannot verify (contractual); calls api.anthropic.com and generativelanguage.googleapis.com (Gemini default gemini-2.0-flash). Fix wording: paid/ZDR tier, sign DPA, vendor register. |
| M-30 (AI-19) | `lab_ai_interactions` keeps full prompts/responses, no TTL; labauthor stores prompt; no slog of prompt content found. 001_baseline.sql:1555-1566; labauthor/draft.go:104. Fix: retention + erasure cascade (P2) | R2/R6 | catalog-driven erasure covers the table; retention TTL not itemised | verify | AI content retained outside erasure/retention. | Category: AI storage. Requirement: prompts/responses stored? Component: labs. Owner: Backend. Pri: P2. Source state: Partial (full prompt+response per session, no TTL seen; labauthor stores the prompt; no slog of prompt/response content found). Fix wording: retention + erasure cascade. |
| M-31 (AI-20) | Diary, journal, labs, wiki prompts lack untrusted-content delimiters (captures/workspace have them); `Sanitize*` strip HTML and cap only; `SanitizeAnswer` truncates bytes mid-rune. ai/prompts.go:81-88,294-296,630-632,675-707; ai/sanitize.go:11-47. Fix: uniform delimiters + output allow-list (P2) | R1 | none | open | Steering of the diary highlight Apply action and of hints. | Category: prompt injection. Requirement: untrusted content delimited. Component: ai. Owner: Backend. Pri: P2. Source state: Partial (captures and workspace use delimiters + a "treat as data" system text, server-recomputed scores and clamped outputs; diary/journal/labs/wiki rely on JSON mode + parse). Fix wording: uniform delimiters; allow-list output validation. |
| M-32 (PRIV-03, corrected + downgraded) | Third-party copies. The agent cited "Google Calendar encrypted refresh tokens"; `001_baseline.sql:1099,1123` are actually GitLab connection and installation tokens (calendar sync is not built). Real gaps: GitLab user connections not revoked on erasure; AI-provider copies and Neon backups undocumented. 001_baseline.sql:1090-1125; privacy/repo.go:96-135. Fix: revoke GitLab tokens on erase; document provider/backup expiry (P2) | R2 | erasure is catalog-driven (GitLab revocation at the provider not itemised) | verify | Data persists at Google/Anthropic/Gemini and in backups; no backup lifecycle stated. | Category: erasure. Requirement: erasure of derived/3rd-party copies. Component: calendar/ai. Owner: Backend. Pri: P1 (agent), P2 (merged report). Alias severity: PRIV-03 HIGH (agent), corrected + downgraded to MEDIUM. Original agent claim: no step for AI-provider copies, the Google Calendar mirror (encrypted refresh tokens retained, external events not removed/revoked) or backups; fix as claimed: revoke + delete calendar tokens/events on erase. |
| M-33 (PRIV-04) | `legal_acceptances` (truncated IP), audit actor and purchases retained after anonymize; basis unstated; policy says consent rows hold no personal data. legal/repo.go:20-27. LEGAL + CA REVIEW REQUIRED (P2) | R6 | explicit `retainedUserTables` list | verify; legal review | Retention basis for payments unstated (CA REVIEW REQUIRED); LEGAL REVIEW REQUIRED. | Category: erasure / residual identifiers. Requirement: residual identifiers. Component: legal/payments. Owner: Legal. Pri: P2. Fix wording: state the basis. Extra evidence: frontend/app/legal/privacy/page.tsx s5. |
| M-34 (PRIV-06) | Correction (s.12): profile edit exists; correction for other data not traced (Cannot verify) (P2) | R6 | none | verify | Partial / Cannot verify. | Category: rights. Requirement: DPDP s.12 correction. Component: profile. Owner: Product. Pri: P2. Source detail: the policy claims profile edit. Fix wording: confirm settings cover name/email/avatar. Evidence: privacy page s3. |
| M-35 (PAY-04) | Only captured/failed and checkout events handled; a dashboard refund/chargeback leaves access active. payments/razorpay.go:150-173; stripe.go:91-130. Fix: handle refund/dispute events -> revoke (P2) | R4 | refund/dispute reversal | fixed-but-DB-test-not-run | Access is retained after a refund or dispute. | Category: gateway refund sync. Requirement: gateway-initiated refunds/chargebacks/disputes reflected. Component: payments. Owner: Backend. Pri: P2. Source state: Missing (Razorpay handles only payment.captured/failed; Stripe only checkout.session.*; a refund done in the gateway dashboard leaves the purchase completed and enrollment active). Fix wording: handle refund.processed, charge.refunded and dispute events through the same revoke path. |
| M-36 (PAY-05) | Gateway refund before the DB tx (split state; retry re-calls gateway); full refund only; coupon not released; no pack refund or credit clawback. service_purchase.go:254-287; sessions refund only `cancellation_refund` ledger reason (baseline.sql:2641). Fix: persist "refunding" intent first; pack refund path (P2) | R4: intent not persisted before the external side effect | `ReversePackPurchase` (claws back unspent credits, releases coupon via `coupons.ReleaseTx`), migration 059 | fixed-but-DB-test-not-run; verify refunding-intent ordering | Inconsistent state; credits kept after refund. | Category: refund flow. Requirement: refund and revoke consistent. Component: mentoring. Owner: Backend. Pri: P2. Source state: Partial (if the tx fails, money is returned but status stays completed and access is kept; a retry re-calls the gateway, a double-refund attempt the gateway likely rejects). Fix wording: persist refund intent (status `refunding`) before the gateway call; pack refund + credit revoke ledger entry; optional partial refund. |
| M-37 (PAY-06) | Refund policy covers paid courses only, not credit packs; manual via ticket; refund API gated by `payments.manage_refunds`; no refund link at checkout. frontend/app/legal/refund-policy/page.tsx:1-30; courses/handler.go:21; routes.go:57. LEGAL REVIEW REQUIRED (P2) | R6 | none itemised | verify; legal review | Policy gap for credit packs. | Category: refund policy. Requirement: refund is manual via support ticket. Component: frontend/legal. Owner: Legal+Frontend. Pri: P2. Source state: Implemented (manual only); the policy page cites the E-Commerce Rules. Fix wording: extend the policy to packs; surface the link at checkout. |
| M-38 (PAY-09) | Price transparency: no tax line; API returns amount and discount; checkout UI not inspected. service_purchase.go:171-175. LEGAL REVIEW REQUIRED (P2) | R6 | none | open (depends on H-30 / CA) | Mis-stated total. | Category: price display. Requirement: price transparency, tax-inclusive/exclusive stated. Component: frontend checkout. Owner: Frontend. Pri: P2. Source state: Cannot verify in the UI (not exhaustively inspected); the API returns amount and discount. Fix wording: show final price, tax and discount before pay. |
| M-39 (INF-06) | No CI (no `.github`): no tests, govulncheck, pnpm audit or gitleaks on push (VR). Fix: add CI (P1) | R3: rules never mechanical | "CI workflow hardening" (details not itemised): `.github/workflows/ci.yml` was added during the fixes | fixed locally, uncommitted (`.github/` is untracked); operator must commit it and confirm it runs (a CI step running `go test ./...` with Docker is still needed, section 9) | Regressions and vulns ship unscanned. | Category: CI. Requirement: CI with tests/scans. Component: CI. Owner: Eng. Pri: P1. Fix wording: add CI: test, vet, govulncheck, pnpm audit, gitleaks. Evidence: `ls .github` was absent at audit time. |
| M-40 (INF-12) | Backups/DR undocumented; Neon PITR window unknown; Render free plan (cold starts, no SLA). render.yaml:9-10 (VR). Fix: document and test a restore; paid plan (P1) | R7 | none | operator-action | Data loss, no RTO/RPO. | Category: backups / DR. Requirement: backups and DR. Component: DB/Infra. Owner: Ops. Pri: P1. Source state: Cannot verify (no backup/restore scripts or PITR config in repo; relies on Neon defaults; Render free plan has cold starts and no SLA). Fix wording: document Neon PITR retention, test a restore; paid Render plan. |
| M-41 | AGPL-3.0 MinIO and Grafana in the compose stack (unmodified, separate services; low obligation). LEGAL REVIEW REQUIRED. docker-compose.*.yml. Fix: confirm no modification/network-exposed derivative (P2) | licensing not a coding task | none | operator-action (legal) | - | Category: licenses. Component: docker-compose. Pri: P2. Source: license table row (MinIO/Grafana AGPL-3.0, pinned, unmodified separate services). |

### 3.4 🔵 LOW

Status = per changelog; unlisted means no itemised fix (verify/open).

| ID (aliases) | Finding and evidence | Fix applied / status | Risk (source) | Source fields (category / requirement / component / owner / priority) |
|---|---|---|---|---|
| AUTHN-05 | No device list/per-session revoke, impossible-travel, switch-org (documented, not built); `max_sessions` and `logout-all` exist. api/router.go:312-348; auth/handler.go:1114-1133; webauthn.go:620 | docs marked planned; open | A lost-device scenario is only fixable with full logout-all; docs overstate the controls. | Category: session mgmt / docs gap. Requirement: device list and per-session revoke (`GET /api/auth/sessions`, `DELETE /api/auth/sessions/:id`), impossible-travel alerts, `switch-org` per `docs/auth.md`. Component: auth. Owner: Backend. Pri: P2. Source state: Missing (none of the routes is registered; no impossible-travel logic, only a comment). Fix wording: add list and revoke-by-family endpoints (data is in `refresh_tokens`); update docs. Extra evidence: api/router.go:415-424. |
| AUTHN-09 = SEC-22 | Per-IP limiter key: verify deployed `TRUSTED_PROXY_CIDRS` against Render ingress (wrong value either shares one bucket = self-DoS, or makes XFF spoofable). middleware/realip.go:21,46-76; config/config.go:398; frontend/proxy.ts:184-188 | operator-action (cannot verify in prod) | A wrong trusted-CIDR setting either blocks all users together (one shared IP bucket makes the 10/min path limit a global cap, self-DoS) or lets an attacker bypass the limit (spoofable XFF). | Category: rate limit / IP trust (AUTHN-09); client IP / rate-limit key (SEC-22). Requirement: the per-IP limiter must key on the real client IP; spoof resistance. Component: config, infra (AUTHN-09); api (SEC-22). Owner: DevOps (AUTHN-09), Backend (SEC-22). Pri: P2 (AUTHN-09), P3 (SEC-22). Source state: Cannot verify in prod (the proxy forwards X-Forwarded-For; RealIP trusts it only from the default RFC1918/loopback ranges; if the Vercel to Render hop comes from a public IP outside `TRUSTED_PROXY_CIDRS`...). Fix wording: prefer a shared-secret header from the Next server; verify the trusted-proxy list. Extra evidence: frontend/lib/server/auth-fetch.ts:33-34. |
| AUTHN-10, AUTHN-11 | Folded into H-08 | see H-08 | - | Details in H-08 (Source fields). |
| AUTHN-13 | No PKCE/nonce on social login (state cookie is sound; confidential client secret mitigates). auth/social.go:64-84,96-116,423-470 | open | Residual risk is low; the confidential client secret mitigates code interception. | Category: OAuth login hardening. Requirement: social login should use PKCE and bind state to the browser. Component: auth. Owner: Backend. Pri: P3. Source state: Partial (state is a 128-bit random value in an HttpOnly SameSite=Lax cookie, constant-time compare, per-provider namespace; no ID token is used, userinfo is read; takeover via unverified email is handled). Fix wording: add `oauth2.S256ChallengeOption` PKCE. |
| AUTHN-15 | Verify-email and reset token consume not atomic (SELECT then UPDATE); same race class fixed on refresh/exchange. auth/handler.go:737-768,930-1000 vs social.go:211-222 | open (verify) | Low impact (needs the token and a race); the same race class was already fixed on the refresh and exchange paths. | Category: token single-use atomicity. Requirement: verify-email and reset tokens must be consumed atomically. Component: auth. Owner: Backend. Pri: P3. Source state: Partial (SELECT then a later UPDATE consumed_at; two concurrent requests can both pass, for reset both set a password and the last write wins). Fix wording: `UPDATE auth_tokens SET consumed_at=now() WHERE ... AND consumed_at IS NULL RETURNING user_id` inside the transaction. |
| AUTHN-16 | 30s refresh grace window (accepted tradeoff, documented). auth/handler.go:536-600 | accepted | Small window; a thief with the stolen cookie inside it gets one access token. | Category: refresh grace window. Requirement: a replayed rotated refresh token must not mint credentials. Component: auth. Owner: Backend. Pri: P3. Source state: Partial, accepted tradeoff (a rotated token replayed within 30s gets a fresh access token and no new refresh; reuse after 30s revokes the whole family). Fix wording (optional): bind the grace to the same `device_hint` and IP prefix. Extra evidence: auth/handler.go:536-585,588-600. |
| AUTHN-18 | Password min 8, max 72, HIBP fails open, no change-password endpoint, no set-password for social/passkey users. auth/password.go:165-263 | change-password endpoint (`password_change.go`) added: fixed-and-built; min length/HIBP unchanged | Min length 8 is the low end; a breach-API outage silently disables the check (logged at Warn). | Category: password policy. Requirement: length floor and breach check. Component: auth. Owner: Backend. Pri: P3. Source state: Implemented with caveats (min 8, max 72 bcrypt cap, no composition rules, NIST-aligned; Pwned-passwords k-anonymity check and context-term check; the breach check fails open on timeout or error, by design; register and reset share the policy; no authenticated change-password endpoint and no set-password flow for social or passkey users). Fix wording: consider 10+ characters; change-password endpoint with re-auth that revokes other sessions. Extra evidence: auth/handler.go:238-250,929-933. |
| AUTHN-19 | Diary draft stays in `localStorage` after logout. diary-editor.tsx:29-38,100; logout-action.ts:30-33 | open | Sensitive personal content can persist on a shared computer after logout. | Category: frontend storage. Requirement: no tokens in `localStorage`. Component: frontend. Owner: Frontend. Pri: P3. Source state: Implemented for tokens (`localStorage` holds UI preferences, anonymous course progress and an unsaved plaintext diary draft that is not shown to be cleared on logout). Fix wording: clear `diary-draft` keys on logout, or accept and disclose. |
| AUTHN-20 | Register duplicate branch skips bcrypt (timing oracle, rate limited). auth/handler.go:264-285,396-403,853-863 | open | A weak timing oracle on register (bcrypt 12 vs none), rate limited. | Category: enumeration. Requirement: responses and timing must not reveal whether an account exists. Component: auth. Owner: Backend. Pri: P3. Source state: Mostly implemented (uniform bodies on register, forgot-password, resend-verification; dummy bcrypt compare on login; locked status revealed only after the password matches). Fix wording: run a dummy `GenerateFromPassword` on the duplicate branch. |
| TEN-15 | `lab:idem:{client-supplied}` key not user-scoped; `GetSessionByID` not user-scoped. labs/service.go:159-170,354; handler_session.go:202,227 | open (verify) | Cross-user session handle disclosure if the key is guessable. | Category: unscoped idempotency / cache key. Requirement: cache keys must include tenant/user. Component: labs. Owner: Backend. Pri: P3. Source state: FAIL (low): a reused key returns another user's active session (container id/host); the frontend uses `crypto.randomUUID()` but the API accepts any string; hint idempotency is session-scoped (OK). Fix wording: namespace `lab:idem:{org}:{user}:{key}`; verify existing.UserID==caller. Extra evidence: frontend components/labs/lab-start-button.tsx:46. |
| TEN-17 | Sheet slug 32-bit entropy; `Subscribe(sheetID)` has no access check. sheets/service.go:17-27; handler.go:331-343,44-72; repo.go:150-165,494-502 | custom sheets visible only to owner/subscribers or members of an org shared with the creator (`canViewSQL`); cross-org preview/subscribe -> 404: fixed-but-DB-test-not-run; optional "mark public" toggle needs a column and migration (not done) | A private sheet is readable via enumeration/leaked link; no private flag. | Category: share link entropy / access. Requirement: share links must be high-entropy capabilities. Component: sheets. Owner: Backend. Pri: P3. Source state: Partial (slug = slugified name + 4 random bytes; `GetSheetPreview` by slug works for any sheet; `Subscribe(sheetID)` has no access/visibility check, so any holder of a sheet UUID or slug gains read access via a `user_sheets` row; sheets are global, not org-scoped, by design; the workspace share token is 256-bit, rotatable, masked, rate-limited: good). Fix wording: owner-controlled visibility/share-token on sheets, required on subscribe. Extra evidence: workspace/service_project.go:53. |
| TEN-18 | Reaction toggle, `captures.Promote` `merge_into_id`, moderation report accept any id without tenant/ownership check. messaging/handler.go:115-133; captures/handler.go:440-447; moderation/service.go:25-52 | open (verify) | A minor cross-tenant write/existence oracle. | Category: integrity IDOR (write). Requirement: writes must be authorised against the target object's tenant. Component: messaging, captures, moderation. Owner: Backend. Pri: P3. Source state: FAIL (low): `moderation.CreateReport` accepts any content id from any tenant (org derived from content). Fix wording: apply the same `batches.org_id` / `user_id` predicate used by sibling queries. Extra evidence: messaging/repo.go:256-272; captures/repo.go:221-234. |
| TEN-19 | `RequireOrgMember` honours `X-Org-Id` header; `liveOrgRole` prefers it (latent; jobs re-checks). middleware/org.go:46-57; role.go:60-90 | open | Latent escalation if reused elsewhere. | Category: design footgun. Requirement: authz helper must not trust a caller-controlled header. Component: middleware. Owner: Backend. Pri: P3. Source state: Partial (`RequireOrgMember` resolves org from URL `{id}`, then `X-Org-Id`, then JWT; `liveOrgRole` prefers that OrgCtx role, contradicting its own comment; only jobs/features use it with RequireOrgRole; jobs re-checks URL==orgCtx so it is safe today, the jobs route uses `{orgID}` while the middleware reads `{id}`). Fix wording: drop the header fallback or make `liveOrgRole` always use `claims.OrgID`. Extra evidence: jobs/handler_http.go:33-35,75-80. |
| TEN-20 | `project_teams.gitlab_project_id` globally unique; webhook lookup by numeric id alone. gitlab/repo_team.go:336-338; service_webhook.go:58-90 | migration 061 makes it unique per org; webhooks match the team by installation secret: fixed-but-DB-test-not-run | Cross-tenant DoS on provisioning. | Category: global uniqueness. Requirement: third-party ids must be unique per installation. Component: gitlab. Owner: Backend. Pri: P3. Source state: numeric ids from different tenants' GitLab instances collide (provisioning failure/mis-routing; the token check still prevents injection). Fix wording: key on (installation_id, gitlab_project_id). |
| SEC-08 | Lab hint prompt framing not traced (hints rate-limited 3s, cached). labs/hint.go:188 | open | Instructor/student content could steer hint output (low impact, no tools). | Category: labs / AI hint prompt injection. Requirement: lab content must not steer AI. Component: labs/hint. Owner: Backend. Pri: P3. Source state: not fully traced (hints are rate-limited at 3s and cached per docs; content rendered via AI-output rendering, see SEC-13; prompt framing/untrusted-delimiting in hint.go Cannot verify). Fix wording: wrap lab/student text as delimited untrusted data; no secrets in the prompt. |
| SEC-15 | Captures: no AV scan, no per-user storage quota (20MB cap, sniffed MIME allowlist, server keys) | open | Residual: no AV scan, no per-user storage quota. | Category: uploads / captures. Requirement: MIME sniff, size, filename. Component: captures. Owner: Backend. Pri: P3. Source state: 20MB cap, MaxBytesReader, `http.DetectContentType` allowlist (jpeg/png/webp/pdf), server-generated object key (user id + random + ext-from-mime), no client filename (no traversal), per-request count cap 20, stored private under the user prefix (Implemented). Fix wording: per-user quota; optional AV. Extra evidence: captures/handler.go:25,113,190-197,155. |
| SEC-16 | pdftotext output unbounded (30s timeout, argv, no shell). captures/extract.go:22-48 | open | Memory exhaustion from a hostile PDF. | Category: command injection. Requirement: exec safety. Component: captures. Owner: Backend. Pri: P3. Source state: pdftotext uses fixed argv, stdin/stdout and a 30s timeout (Implemented); no memory/ulimit cap on the process or output size; lab docker exec single-quote escapes the script into `bash -c` with an argv list to docker, so no host shell injection. Fix wording: cap output via LimitedWriter; run with `ulimit -v`. Extra evidence: labs/container.go:277-285. |
| SEC-21 = INF-14 | CORS exact-match allowlist; empty-Origin edge if `FrontendURL` unset (`Origin "" == ""`). router.go:677-694 | open (guard `origin != ""`) | Low. | Category: CORS (SEC-21, severity INFO in the raw output; INF-14, severity LOW). Requirement: strict origin. Component: api. Owner: Backend (SEC-21), Eng (INF-14). Pri: P3 (SEC-21), P2 (INF-14). Source state: exact-match allowlist (FRONTEND_URL + extras), credentials only for allowed origins, `Vary: Origin`, CSRF middleware on the authenticated group; INF-14: origin echoed with Allow-Credentials true, allowlist logic not reviewed (credentialed CORS misconfig if reflect-all). Fix wording: guard `origin != ""`; confirm the allowlist logic. Extra evidence: api/router.go:413,682-685. |
| RT-10 | `GetPublicResult` ignores `show_results` | open | Config not honoured. | Category: public tests/show_results. Requirement: respect show_results. Component: assessment. Owner: Backend. Pri: P3. Fix wording: check the flag. Evidence: handler_public.go GetPublicResult. |
| RT-13, RT-17 | Folded into H-03 | see H-03 | Low entropy risk only (RT-13); low (RT-17). | Category: public tests/enumeration (RT-13); unauth/webhooks (RT-17). Requirement: code enumeration; webhook auth. Component: assessment (RT-13); mentoring/gitlab (RT-17). Owner: Backend. Pri: P3. Source state: RT-13 short_code is 10 chars crypto/rand (~51 bits), fine, but unthrottled so the guessing rate is unbounded; RT-17 payment webhook signature verified and body capped, GitLab token checked and body capped, no rate limit. Fix wording: RT-06 limiter (RT-13); optional per-IP limit (RT-17). Extra evidence: assessment/handler_assessment.go:80-91; mentoring/handler_webhook.go:29-55; gitlab/handler_webhook.go:36-74. |
| RT-23, RT-25 | Folded into H-15 | see H-15 | Low (RT-23); cannot verify the stored-HTML path, doc drift (RT-25). | Category: XSS/mermaid (RT-23); XSS/wiki (RT-25). Requirement: safe diagram render; wiki links/embeds. Component: highlights (RT-23); wiki (RT-25). Owner: Frontend (RT-23), Full-stack (RT-25). Pri: P3 (RT-23), P2 (RT-25). Source state: RT-23 SVG via dangerouslySetInnerHTML after mermaid securityLevel strict; RT-25 TipTap Link default protocol allowlist, openOnClick only read-only, server-side storage sanitization not verified, docs mention a `/design` embed but no embed route found. Fix wording: DOMPurify on svg (RT-23); verify the render path, validate JSON schema server-side (RT-25). Extra evidence: frontend/components/wiki/wiki-editor-inner.tsx:67; docs/design.md:136,155. |
| AI-05 | MCP auth code stored unhashed (2-min, single use, atomic) | open | Low. | Category: OAuth code. Requirement: single-use, short expiry. Component: mcpconnect. Owner: Backend. Pri: P3. Source state: Implemented (DELETE...RETURNING atomic consume, TTL 2 min, client/redirect/PKCE checked after delete; code stored un-hashed in `auth_tokens.token_hash`). Fix wording: hash the code before storing. Extra evidence: mcpconnect/repo.go:117-135; oauth_authorize.go:151-166; models.go:111. |
| AI-08 | No purge for expired `mcp_access_token`, unused `mcp_auth_code`, stale `mcp_clients`; every `/mcp` call writes `last_used_at` | `mcp_connections` purge added (default 90 days): fixed-but-DB-test-not-run; token/client purge verify | Table growth. | Category: token hygiene. Requirement: expired token cleanup. Component: jobs. Owner: Backend. Pri: P3. Source state: Missing (the purge job covers only email_verify/oauth_exchange). Fix wording: add a purge for mcp purposes + orphan clients. Extra evidence: jobs/handlers/analytics.go:109-114; mcpconnect/repo.go:281. |
| AI-21 | Cache-key tenant/user scoping only sampled | open (add test) | Low. | Category: cache cross-tenant. Requirement: cache keys tenant/user scoped. Component: ai. Owner: QA. Pri: P3. Source state: Partial (practice bank shared by technology is generated, not user content: OK; labauthor/labs keyed with org/cache_key; not exhaustively verified). Fix wording: test that user-content caches include user/org. Extra evidence: practice/service.go:79-112; labauthor/draft.go:104; workspace/repo_ai_cache.go. |
| AI-23 | Diary/journal AI calls deliberately uncached, repeatable per keystroke | open (hash cache + debounce) | Cost. | Category: called-once rule. Requirement: cache before call. Component: diary. Owner: Backend. Pri: P3. Source state: Partial (cache-first in practice, labs, drafts, digest, roadmap). Fix wording: content-hash cache + debounce. Extra evidence: diary/service.go:36-39,67-72. |
| AI-25 | HIBP prefix-only not verified (config/config.go:368) | open (verify) | Low. | Category: outbound HTTP. Requirement: breach-check privacy. Component: auth. Owner: Backend. Pri: P3. Source state: Cannot verify that only the SHA-1 prefix is sent (HIBP range URL configured). Fix wording: confirm prefix-only. |
| AI-26 | `/mcp` 401 lacks `resource_metadata` (mcp_auth.go:433) | open | Interop. | Category: MCP discovery. Requirement: WWW-Authenticate metadata. Component: mcpconnect. Owner: Backend. Pri: P3. Fix wording: add the param. |
| PRIV-17 | Email addresses in assessment/auth email logs. assessment/email.go:19,41,62; auth/email.go:21,38,55,74 | open | Email PII in logs. | Category: log hygiene. Requirement: no PII in logs. Component: assessment/auth. Owner: Backend. Pri: P3. Source detail: auth error logs carry error strings only (good); dev-suppressed email logs print the address; the assessment email warn logs addresses in all envs. Fix wording: log the user id. |
| PRIV-19 | `audit_logs.ip_address` never set; refresh_tokens ip + UA(200) kept; attempt_events retention unspecified | open (verify with H-26) | Minor. | Category: minimization. Requirement: collected-but-unused. Component: schema. Owner: Backend. Pri: P3. Fix wording: drop the unused column; document purpose. Extra evidence: 001_baseline.sql:445,1836,2489-2490; auth/handler.go:1261. |
| PRIV-20 | No cookie banner/page (only first-party HttpOnly auth cookies, no trackers) | cookie page added: fixed-and-built | Low. | Category: cookies. Requirement: cookie notice (not DPDP-statutory; ePrivacy only if EU). Component: frontend. Owner: Product. Pri: P3. Source detail: no analytics/tracker packages in package.json. Fix wording: add a cookie paragraph to the policy. Extra evidence: frontend/package.json; docs/auth.md:13. |
| PRIV-21 | Policy names Stripe, UI shows only Razorpay (razorpay-checkout.tsx:30) | verify | Minor mismatch. | Category: third-party scripts. Requirement: disclosure. Component: frontend. Owner: Product. Pri: P3. Source detail: Razorpay checkout.js from CDN; fonts via next/font; the policy names Stripe + Razorpay but only Razorpay is seen in the frontend. Fix wording: confirm gateways. |
| PRIV-23 | Passkey/social accounts delete with session only (no step-up). privacy/service.go:41-53 | open | Session theft = irreversible deletion. | Category: deletion UX. Requirement: step-up auth. Component: privacy. Owner: Backend. Pri: P3. Fix wording: step-up re-auth. |
| PRIV-24 | Anonymize tx commits, then `SetUserStatus` runs separately (failure leaves live anonymized account). privacy/service.go:55-63 | verify (erasure rewritten; single-tx not itemised) | Inconsistent state. | Category: erasure atomicity. Requirement: consistency. Component: privacy. Owner: Backend. Pri: P3. Fix wording: single tx. |
| PAY-12 | Coupon lost-race after capture still enrolls, logged only (no alert/metric) | open | Minor revenue leakage. | Category: coupon abuse. Requirement: atomic cap and one use per user. Component: coupons. Owner: Backend. Pri: P3. Source state: implemented well (FOR UPDATE count + live holds in tx, ConsumeTx guarded UPDATE, UNIQUE(coupon_id,user_id) and UNIQUE(purchase_id)). Fix wording: emit a metric/alert on the lost-race path. Extra evidence: service_purchase.go:115-136, 405-416; coupons/repo.go:228-258; baseline.sql:4759,4775. |
| PAY-16 | Raw webhook payload (possible email/contact) retained in `payment_events.payload`. razorpay.go:101-117; baseline.sql:2166 | open (redaction/retention) | Retention of PII in the payload. | Category: card data. Requirement: no raw card data stored/logged. Component: payment_events. Owner: Backend. Pri: P3. Source state: Implemented by design (Stripe hosted checkout and Razorpay modal; no card fields in schema); the raw webhook payload may contain PII such as email/contact. Fix wording: define retention/redaction. |
| PAY-17 | No refund-policy link at checkout; acceptTerms defaults false (good) | open | Disclosure gap. | Category: dark patterns / consent. Requirement: no pre-ticked consent. Component: frontend. Owner: Frontend. Pri: P3. Source state: Implemented (acceptTerms defaults false; no urgency/countdown tactics in payments code, frontend not exhaustively searched); refund-policy link at checkout not found (grep); LEGAL REVIEW REQUIRED. Fix wording: link the refund policy on checkout/pack purchase. Extra evidence: frontend/components/auth/register-form.tsx:33. |
| PAY-18 | New pending pack row per click (no dedup). sessions/service_checkout.go:54 | open | Pending-row clutter only. | Category: multi-table tx. Requirement: transactions. Component: sessions. Owner: Backend. Pri: P3. Source state: Implemented (purchase complete + coupon + enrollment + ticket + event processed in one tx; the zero-total path reuses it); pack purchase create is not reused for retries. Fix wording: reuse the live pending pack row. Extra evidence: service_purchase.go:392-453. |
| INF-02 | TESTDB_URL guard | `testdb.checkTestDBURL`: fixed-and-built | Accidental truncate if TESTDB_URL is set to prod. | Category: test safety. Requirement: tests must not hit prod. Component: Tests. Owner: Eng. Pri: P2. Source state: Implemented (DB tests use testcontainers or TESTDB_URL; sslmode=disable only for the ephemeral container); risk remains if TESTDB_URL points at Neon (no guard); TRUNCATE/DROP found only in Go tests/router, not audited line-by-line. Fix wording: refuse TESTDB_URL that matches the DATABASE_URL host / non-local. |
| INF-05 | Unpinned/old images: alpine:3.19, golang:1.26-alpine, caddy:2-alpine, piston and adminer:latest (minio, prometheus, grafana pinned). backend/Dockerfile:2,18; docker-compose.dev.yml:238 | Dockerfile/compose changed; pinning not itemised: verify | Supply chain / unpatched base. | Category: base image pinning. Requirement: pin images. Component: Infra. Owner: Eng. Pri: P2. Source detail: alpine:3.19 is EOL-ish; piston and adminer:latest are unpinned by digest. Fix wording: pin digests, bump alpine, drop adminer:latest. |
| INF-10 | Compose Postgres URLs without `sslmode` (internal only; Neon has `sslmode=require` + channel binding) | open | Low. | Category: DB TLS (severity INFO in the raw output). Requirement: TLS to DB. Component: DB. Owner: Eng. Pri: P3. Source state: Implemented for Neon (sslmode=require + channel_binding=require); compose Postgres URLs inside the docker network have no sslmode (internal only). Fix wording: set sslmode=require in prod compose if Postgres ever leaves the network. Extra evidence: backend/.env:7 (masked); .env.prod.example:26. |
| INF-15 | Override ports are dev-only (docker-compose.override.yml:7-11); ensure the override is not used in prod | open (ops) | Low. | Category: compose ports. Requirement: minimal exposure. Component: Infra. Owner: Ops. Pri: P3. Source state: prod publishes only 80/443 via Caddy; minio/piston host ports only in the (dev) override; adminer/prometheus unpublished. Fix wording: ensure the override file is not used in prod. Extra evidence: docker-compose.prod.yml:302-304. |

### 3.5 ⚪ INFO / N/A (33)

Recorded so the count reconciles; none is a defect to fix unless noted.

| ID | Note | Source fields (category / requirement / component / risk / fix / priority / evidence) |
|---|---|---|
| AUTHN-21 | No user-facing API keys exist (only MCP bearer tokens). If added: hash, show once, scope | Category: API keys. Requirement: API keys, if any, must be hashed and scoped. Source state: N/A (grep for api_key in backend Go returns only fixtures; MCP bearer tokens are covered elsewhere). Fix wording: if added later, store only a hash, show the key once, scope it. Pri/Owner: n/a. |
| TEN-21 | Lab library `library_visibility='platform'` and interview-exp are intentional cross-org sharing; Redis keys tenant/user namespaced except C-02/TEN-15 | Category: platform content sharing. Requirement: cross-tenant sharing must be explicit. Component: library. Fix: none. Pri: P3. Evidence: library/repo.go:53-55; authz/cache.go:24. Source detail: Redis keys such as `rbac:perms:{org}:{user}`, leaderboard and lab rate limits are tenant/user-namespaced except TEN-02/TEN-15. |
| TEN-22 = RT-01 | No Yjs/y-websocket server exists; doc drift. If built: per-room org+participant check, Origin check, header token | Category: WebSocket / realtime rooms (TEN-22, N/A / Cannot verify; RT-01 "WS/Yjs", INFO). Requirement: WS authz for wiki/design/interview Yjs rooms; Yjs room authz / cross-tenant rooms. Component: labproxy; interview. Owner: Backend. Pri: P3. Source detail: the only WS is the lab terminal (`cmd/labproxy`), which validates a scoped, Redis-registered JWT and checks the session owner (proxy.go:131-175); `session_token` travels in the query string (logging risk). Fix wording: move the token to a header/subprotocol when feasible (TEN-22); fix the doc, or build with a per-room org+participant check, Origin check, header token (RT-01). Evidence: docs/interview.md:39-53; router.go (no `/ws` route); frontend/package.json (no yjs). Risk: doc drift; a future build may skip room authz. |
| TEN-23 | Jobs: org routes compare URL org with resolved org; worker payload trust not traced (Cannot verify). Add per-handler test that payload org matches entity org | Category: background jobs. Requirement: jobs run with org context and cannot cross tenants. Component: jobs. Owner: Backend. Pri: P3. Source state: Cannot verify (partial); org job admin routes compare the URL org with the resolved org (handler_http.go L75-80,120,154,185,228,284) and query with `&orgCtx.OrgID`; worker handlers take org_id in the payload set by enqueuers; not exhaustively traced. Evidence: jobs/handler_http.go:67-300; jobs/handlers/*. |
| SEC-05 | Standard lab profile: `--cap-drop ALL`, no-new-privileges, exec as `labuser`, default seccomp (setup script runs as root, author-controlled) | Category: labs / seccomp + user (standard). Requirement: non-root, caps dropped. Component: labs runtime. Risk: acceptable. Fix: n/a. Pri: P3. Evidence: container.go:139, 257, 250. |
| SEC-09 | Lab cleanup: `docker rm -f` on kill, pause on idle, warm pool unbound until claim; warm-pool reuse leakage Cannot verify; no platform secrets via `-e` | Category: labs / cleanup and leakage. Requirement: cleanup, no cross-session reuse. Component: labs. Owner: Backend. Pri: P3. Source detail: containers are named per session+reset; risk Cannot verify. Fix wording: verify a warm container is never reused after binding and the sandbox env carries no platform secrets (none set via `-e` in run args: Implemented). Evidence: container.go:49-60,205,216. |
| SEC-12 | Fixed-host outbound (Anthropic, Gemini, Brevo, OAuth, HIBP, projectmarket GitHub; Piston/Judge0 are operator env); no link-preview/embed fetchers | Category: SSRF / other outbound. Requirement: fixed-host outbound. Component: various. Risk: low. Fix: none. Pri: P3. Evidence: ai/anthropic.go:111; mailer/brevo.go:67; auth/social.go:274; projectmarket/github.go:66; labs/piston.go:85. Source detail: hosts are hardcoded or env-configured, not user controlled (Implemented). |
| SEC-20 | SQL: all `fmt.Sprintf` SQL sites interpolate only placeholder indexes or constant column lists (9 sites: captures/repo.go:148; courses/repo.go:1431; diary/repo.go:184; journal/repo.go:76,158; messaging/repo.go:60; mistakes/repo.go:90,109; moderation/repo.go:149) | Category: SQL injection. Requirement: parameterized SQL. Component: repos. Risk: low. Fix: none. Pri: P3. Source detail: no user-controlled identifiers found in the 9 sites. |
| SEC-24 | Mass assignment/open redirect/deserialization not sampled in depth (open redirect covered by M-05) | Category: mass assignment / open redirect / deserialization (severity N/A). Risk: Cannot verify. Component: -. Owner: Backend. Pri: P3. Source detail: JSON handlers decode into typed structs (no `map[string]any` merge seen in sampled files); open redirect not tested. Fix wording: run a targeted review of redirect_uri handling in OAuth/MCP (belongs to the auth phase). |
| RT-05 | No load-test simulator backend found; re-audit if built | Category: load-test simulator. Requirement: abuse/cost. Component: interview. Owner: Backend. Risk: N/A. Fix wording: re-audit if built. Pri: P3. Evidence: grep backend/internal: none. |
| RT-09 | Public tests strip correct flags/explanations/hidden tests (`assessment/sanitize.go:11-60`) | Category: public tests/answer leakage. Requirement: correct answers not sent. Component: assessment. Risk: implemented well. Fix: -. Evidence: assessment/sanitize.go:11-60. |
| RT-19 | `/health` returns "ok" only | Category: health. Requirement: health. Component: api. Risk: none. Fix: -. Evidence: router.go:101-103. |
| RT-20 | No pprof/swagger/debug endpoints registered (also INF-16) | Category: pprof/swagger. Requirement: debug endpoints. Component: api. Risk: implemented well. Fix: -. Evidence: grep pprof/swagger: none (also INF-16: grep pprof/debug, no hits). |
| RT-24 | Journal markdown uses react-markdown + remark-gfm, no rehype-raw; `@braintree/sanitize-url` present; check `rel=noopener` | Category: XSS/markdown. Requirement: markdown. Component: journal. Owner: Frontend. Risk: implemented well. Fix wording: check `rel=noopener` on links. Pri: P3. Evidence: components/journal/journal-markdown.tsx:1-72; package.json:17. |
| AI-03 | OAuth redirect exact-match at authorize, approve, deny and token | Category: OAuth redirect. Requirement: exact-match redirect_uri. Source state: Implemented. Evidence: mcpconnect/oauth_authorize.go:28-37; oauth_token.go:285. |
| AI-04 | S256-only PKCE enforced; approve only checks challenge non-empty (optional format validation) | Category: OAuth PKCE. Requirement: S256 only, enforced. Component: mcpconnect. Owner: Backend. Risk: low. Source state: Implemented. Fix wording (optional): validate the challenge format at approve; constant-time compare. Pri: P3. Evidence: oauth_authorize.go:66-73,146; pkce.go:14-20. |
| AI-06 | MCP access+refresh tokens hashed at rest via `auth.HashToken`, raw returned once | Category: token storage. Requirement: tokens hashed at rest. Source state: Implemented. Evidence: mcpconnect/oauth_token.go:304,323-352. |
| AI-09 | User revoke is owner-scoped; access tokens die immediately via status join | Category: revoke. Requirement: user can revoke. Source state: Implemented. Evidence: mcpconnect/connections.go:35-48; repo.go:314-318,270-271. |
| AI-11 | Single `callTool` scope choke point; identity from token not args; only sampled tools verified (121 tool bodies not swept). Add DB-backed cross-tenant tests per tool | Category: tool authz. Requirement: per-tool scope + tenant scoping. Component: mcpconnect. Owner: QA. Pri: P2. Source state: Implemented (sampled). Fix wording: add DB-backed cross-tenant tests per tool. Evidence: tools.go:2569-2575; :2072-2159. |
| AI-13 | Org kill-switch checked per call and at approve | Category: connector control. Requirement: org can disable. Source state: Implemented. Evidence: mcpconnect/mcp_auth.go:459-467; oauth_authorize.go:129-135. |
| AI-15 | Google Calendar sync NOT IMPLEMENTED (design doc only: no scope, routes, token table). If built: reuse `secrets.Vault`, revoke at Google, delete mirrored events on disconnect/erasure, include in export; HIGH if shipped without encryption/revoke/purge | Category: Google Calendar sync. Requirement: OAuth state, scope minimization, token encryption, revoke. Component: calendar. Owner: Backend. Pri: P3. Source detail: design says calendar.events least privilege and revoke on disconnect (good) but token encryption is not specified; existing Google login uses AccessTypeOnline and a CSRF state cookie (HttpOnly/SameSite=Lax, constant-time compare). Evidence: docs/calendar-sync.md:15-30,115,155; auth/social.go:65-83,101-104; secrets/secrets.go:38-42. |
| PAY-07 | Subscriptions/renewals/trials not built; if planned: RBI e-mandate rules, cancellation UX, renewal reminders, trial terms (LEGAL REVIEW REQUIRED) | Category: subscriptions. Requirement: subscribe/renew/cancel/failed-payment/trial/auto-renew. Component: product. Owner: Product. Risk: design gap if the roadmap includes it. Fix wording: design doc before building. Pri: P3. Evidence: docs/infrastructure.md:218-241; no subscription tables in 001_baseline.sql. |
| PAY-11 | Server-side price, amount/currency cross-check on webhook | Category: amount tampering. Requirement: server-side price. Source state: Implemented (price from the DB course/pack, coupon discount computed server-side). Evidence: service_purchase.go:41-47, 94-97; 358-363; sessions/service_checkout.go:54-57, 131-136. |
| PAY-13 | Webhook signature verification fine (HMAC, raw body 1MB cap, constant time, 5-min tolerance, Stripe SDK tolerance); rate-limit gap folded into H-03 | Category: webhook signature. Requirement: HMAC, raw body, constant-time, timestamp. Component: payments. Owner: Backend. Risk: low. Pri: P3. Source detail: Razorpay replay protection depends on created_at and the eventID falls back to a composite key; the webhook route has no rate limit (limit applies at router.go:313 to the auth group only). Fix wording (optional): IP/rate limit on the webhook route. Evidence: razorpay.go:125-139, 179-189; stripe.go:85-86; handler_webhook.go:30. |
| PAY-14 | Credit double-spend guarded (status UPDATE `WHERE status='pending'` + ledger insert in one tx with user credit lock; cancellation refund unique index) | Category: double-credit races. Requirement: credits atomic. Source state: Implemented. Evidence: sessions/repo.go:588-617; baseline.sql:7513. |
| PAY-15 | Stub gateway registers only when no gateway set and not production | Category: dev stub in prod. Requirement: no dev bypass. Source state: Implemented (the webhook secret is enforced at startup when a key is set). Evidence: payments/registry.go:58-75; config.go:275-283. |
| INF-07 | Tracked env files are only `*.example`; `.env`, `.env.prod` ignored; pattern scan found only placeholder/fixture DB URLs | Category: secrets in repo. Requirement: no secrets tracked. Component: Repo. Owner: Eng. Risk: low. Fix wording: run gitleaks over full history (not done at audit time: the history -S scan timed out). Pri: P2. Evidence: git ls-files; .gitignore:2-4; backend/db/fixtures/interview-prep-45.generated.sql:38323 (fixture). |
| INF-08 | `git log --all -- .env backend/.env .env.prod` empty (history scanned later, section 6.3) | Category: git history. Requirement: no past secret commits. Component: Repo. Owner: Eng. Risk: unknown. Source state: Cannot verify fully (the deep -S pattern scan did not complete). Fix wording: gitleaks history scan. Pri: P2. |
| INF-09 | `requireSecret()` on `ENCRYPTION_KEY` etc.; render.yaml secrets `sync:false` | Category: hardcoded fallbacks. Requirement: config from env, required secrets. Component: Config. Owner: Eng. Risk: low. Fix wording: spot-check of other fallbacks not done. Pri: P3. Evidence: config/config.go:314,347; render.yaml (secrets block). |
| INF-11 | AES-256-GCM vault used by gitlab, orgs, projectmarket; calendar/MCP tokens not individually verified; key rotation not evidenced (see M-28) | Category: column encryption. Requirement: encrypt OAuth tokens. Component: Secrets. Owner: Eng. Pri: P2. Source detail: users are gitlab/service_oauth.go and projectmarket/github.go; calendar tokens not individually verified. Fix wording: verify calendar/MCP tokens use the vault; add key versioning. Evidence: secrets/secrets.go:1-22. |
| INF-16 | No pprof (same as RT-20) | Category: pprof. Requirement: no debug endpoints. Component: API. Risk: none. Fix: -. Evidence: grep pprof/debug (no hits). |
| INF-17 | Vulnerability scan not run at audit time (run afterwards, section 6) | Category: vuln scan. Requirement: dependency vulns. Component: Deps. Owner: Eng. Risk: unknown. Source state: Cannot verify (govulncheck not installed; pnpm audit not run, network). Fix wording: run in CI. Pri: P1. Evidence: `which govulncheck` (absent). |

### 3.6 Verified strengths (what was implemented well)

Recorded so the next audit does not re-derive them.

- **Tenancy/authz:** all `/api/admin/*` guarded by `RequirePlatformRole(super_admin)` or RBAC codes; `RequireOrgRole` reads the live role from DB (middleware/role.go:45-90) and session_version is bumped on role/status change (orgs/member.go:165-175). Workspace (99 routes): `RequireProjectRole` + `ProjectStatusGate`, every item/time-log/release/sprint query has `AND project_id=$n`, time-log edit locks the row and checks owner, share token 256-bit, masked, rotatable, rate-limited per IP/email/project (workspace/routes.go, repo_items.go:121-231, service_timelog.go:141-205, handler_recruiting.go:62-100). Courses/modules/messages/FAQs/tickets/moderation/labauthor/projectmarket/gitlab dashboards re-verify `org_id` (e.g. `GetCourse(org,id)`, `GetModule` joins `courses.org_id`, messaging `EXISTS batches.org_id`, `GetTeam(org,team)`, labauthor `org_id=$2` on every mutate, certificates threshold calls `GetCourse(org,..)` first). Personal-data domains (diary, journal, captures, habit, whatnow, mistakes, srs, highlights notes, focuswall, roadmap owner paths, activity) filter `user_id=$n`; capture keys server-generated under `captures/{userID}/`. Session booking is exemplary (participant check, mentor-only `SaveNotes`, `MenteeProgress` needs mentor<->student history: sessions/service.go:523-612). Org member management: last-owner DB guard, owner protection, `CanGrantRole`, audit log, `removeFromOrgWorkspaces` in the same tx; authz admin writes call `requireOrgMembership` before role/override assignment and block self-status-change. Sheets mutations check ownership and `sheet_id`; combine verifies each source; roadmap fork re-matches via `RematchForOrg`. GitLab webhooks use per-installation secret with constant-time compare (service_webhook.go:58-90); lab proxy WS token scoped, revocable, owner-checked; features user-flags and jobs org routes re-check the target user/org (features/service.go:271,315).
- **Authn:** access JWT HS256 with pinned algorithm and `jti`; secrets >= 32 bytes and not placeholders or startup fails (auth/jwt.go:63-80; config.go:629-642); access TTL 15m, refresh 30d (both from env), refresh tokens 256-bit random stored as SHA-256; atomic refresh rotation in one CTE with family-wide revoke on reuse, and a locked account cannot refresh (auth/handler.go:496-600); logout blocks the `jti` and revokes the refresh token, logout-all and reset bump `session_version` (Redis jti/version cache falls back to Postgres: session/cache.go); cookies HttpOnly, SameSite=Lax, Secure on all deployed envs (`IsProd` is true for staging too); CSRF is a signed HMAC double-submit token with constant-time compare on all authenticated mutations plus refresh/logout (middleware/csrf.go; router.go:325-327,413); first-party cookies re-emitted with Domain stripped (frontend/lib/server/set-cookie.ts); bcrypt cost 12 with dummy compare equalizing timing; reset tokens superseded on a new request, all consumed on use, and all sessions revoked on reset; account-takeover defences (unverified local account reclaimed on social link, GitHub primary+verified email only, single-use 2-min exchange token claimed atomically, `Referrer-Policy: no-referrer`); email links do not log tokens and the dev token echo was removed; passkeys (challenge in Redis GetDel 5-min, clone-warning, last-sign-in-method guard, discoverable login that does not reveal account existence); MCP OAuth (S256 only, exact redirect match, single-use code, hashed tokens, org kill-switch checked on every call); Next.js proxy deny-by-default public path list, fails closed (redirects to login) when the backend is down or `BACKEND_URL` is unset, and the JWT is decoded only for UX (the backend is the authority); HSTS 2 years preload, CSP and Referrer-Policy in next.config.ts. Live role checks from the DB (`LiveOrgRole`, `status='active'`); member removal and role change bump `session_version` and invalidate the cache (orgs/member.go:170-195,276-281).
- **AppSec/labs:** captures SSRF guarded dialer with per-dial IP resolution (covers redirects/rebinding), http/https only, 5MB cap, 15s timeout (extract.go:54-100; netguard/transport.go); captures uploads sniffed MIME allowlist, size caps, server-chosen keys, per-user prefix; lab standard profile cap-drop ALL, no-new-privileges, non-root exec, bounded exec output, cooldowns, clean-room semaphore, kill/pause lifecycle, K8s pods `AutomountServiceAccountToken=false` (runtime_kubernetes.go:178); pdftotext via argv with timeout; bound SQL parameters everywhere sampled; CORS exact-origin allowlist + CSRF; frontend headers HSTS 2y preload, X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy, CSP with object-src none, base-uri self, frame-src limited to youtube-nocookie + lab proxy (next.config.ts:16-55); mermaid `securityLevel` strict.
- **AI/MCP:** OAuth: exact redirect match, S256-only PKCE, atomic single-use 2-min codes, hashed tokens, refresh rotation, immediate revoke, org kill switch per call; one `LLMProvider` abstraction with JSON mode; untrusted-content delimiters for captures/workspace; roadmap daily cap, digest budget, lab hint cooldown; single scope choke point (`callTool`), identity from token not args, wiki uses live role, action log with revert; AES-256-GCM vault for replayable third-party tokens; per-provider OAuth state cookie with constant-time compare; no prompt/response content logging and no third-party trackers found.
- **Privacy:** append-only versioned consent log with server-controlled version and forced re-accept (internal/legal/*); export/delete behind auth+CSRF and delete verifies the password and kills sessions (privacy/routes.go:22-27); IP truncated before storage and X-Forwarded-For trusted only from configured proxy CIDRs (config.go:22, router.go:85); auth cookies httpOnly/SameSite/Secure first-party and no tracker packages; token cleanup and project-interest purge jobs; Google OAuth/GitLab tokens stored encrypted; role/permission changes audited with before/after state.
- **Payments:** signature verification before parsing, constant-time compare, timestamp tolerance; dedup via UNIQUE(provider,event_id) with guarded state transitions as backstop (repo.go:287-307); server-side pricing with amount/currency cross-check and paid access enforced independently of purchase status; atomic coupon cap with live holds (FOR UPDATE, `ConsumeTx`, UNIQUE(coupon_id,user_id) and UNIQUE(purchase_id)); Stripe idempotency key per purchase (stripe.go:75); credit ledger with locks and unique refund index; stub blocked in production; refund permission-gated; receipts owner-scoped; no pre-ticked consent and no dark patterns found; no raw card data stored (Stripe hosted checkout, Razorpay modal).
- **Infra:** secrets via env, `requireSecret` at startup, render.yaml `sync:false`; `.env` files gitignored; Neon TLS with channel binding; prod compose publishes only 80/443; frontend HSTS/CSP/XFO headers; no pprof; testcontainers for DB tests.
- **Realtime/public:** answer stripping in public/student question view; unforgeable attempt token (`gen_random_uuid()`) and 10-char crypto/rand short code; minimal `/health`; workspace public share/interest rate-limited with body cap and uniform 202; webhooks verify signature/token and cap body; lab WS JWT type+issuer check, user-id IDOR guard and token registry (proxy.go:137-161); react-markdown without raw HTML, mermaid strict, XFO DENY, HSTS, nosniff, object-src none, frame-src allowlist; trusted-proxy-aware RealIP prevents XFF-spoofed rate buckets (router.go:84-89).

---

## 4. Privacy / DPDP, legal-document gaps and policy-to-code mismatches

### 4.1 Role and statutory framing

**Role (LEGAL REVIEW REQUIRED):** MindForge is the Data Fiduciary for individual sign-ups and personal tools (diary, journal, captures). For B2B org tenants it is likely a processor for learner data the org controls. No DPA existed and the policy treated MindForge as sole controller (H-23).

Findings: C-03, H-18..H-28, M-06, M-23, M-27, M-30, M-32..M-34 (section 3). Privacy score as found: 1 (capped).

**Docs present at audit time:** Terms, Privacy, Refund, versioned acceptance gate. **Missing then:** Cookie notice, DPA, SLA, Security page, standalone AUP, Grievance page, seller disclosures (H-21, H-22). The fix pass added privacy, grievance, security, cookie, AUP and DPA pages (SLA and seller disclosures: verify), all needing legal review.

### 4.2 Statutory vs voluntary

| Regime | Type | Applies? | Status (as found) |
|---|---|---|---|
| DPDP Act 2023 + Rules | Statutory | Yes (Indian fiduciary; phased commencement, LEGAL REVIEW REQUIRED) | FAIL on notice, erasure, grievance, children, breach, retention, nomination |
| CERT-In Directions 2022 | Statutory | Yes (service provider in India) | FAIL on 6h reporting/POC; UNKNOWN on 180-day logs (LEGAL REVIEW REQUIRED) |
| IT Act s.43A / SPDI Rules | Statutory | Yes (passwords, financial info) | PARTIAL (reasonable security undermined by C-01/C-02) |
| CGST | Statutory | If registered/threshold (CA REVIEW REQUIRED) | FAIL on invoice fields |
| Consumer Protection (E-Commerce) Rules 2020 | Statutory | Likely, for paid courses (LEGAL REVIEW REQUIRED) | FAIL on seller/grievance disclosures |
| SOC 2 / ISO 27001 | **Voluntary** | Only if customers ask | Not claimed; MFA, audit trail, CI and DR gaps would block |
| GDPR / UK GDPR / US state laws | Conditional | **No trigger found:** currency defaults to INR (config/config.go:459), no EU/UK targeting or localisation. Brevo (EU) and Backblaze/Anthropic (US) are vendors, an outbound transfer, not a trigger | N/A. The privacy policy cites GDPR "where applicable" (page.tsx:24-25): LEGAL REVIEW REQUIRED whether to keep it |

### 4.3 Policy-to-code mismatches

| # | Policy statement | Code reality | Ref |
|---|---|---|---|
| 1 | Privacy s3: "request a copy of your personal data" | Export covered 9 tables; diary, journal, captures and others omitted | H-19 |
| 2 | Privacy s3: deletion "anonymizes ... immediately" | Diary, journal and captures retained with user_id; blobs never deleted; MCP keeps access | C-03, H-18, H-01 |
| 3 | Privacy s4: processors = payment, email, SSO | Anthropic, Gemini, Brevo (unnamed), Neon/Render/Vercel, **Backblaze B2 USA**, GitLab, MCP clients (and planned Google Calendar) undisclosed | H-20 |
| 4 | Privacy s1: categories collected | Omits diary, journal, captures, calendar, AI prompts, proctoring events, public-test candidate data | H-20 |
| 5 | Privacy s7: support via in-app ticket | No grievance officer; locked-out or deleted users cannot reach it | H-21 |
| 6 | Privacy cites GDPR | No EU trigger | 4.2 |
| 7 | Refund policy cites E-Commerce Rules | No grievance officer or timelines; packs not covered; names Stripe but UI shows only Razorpay | M-37, PRIV-21 |
| 8 | Org "SSO enabled" toggle (UI) | Never enforced | M-02 |
| 9 | Privacy: consent rows hold no personal data | Truncated IP retained (matches truncation claim; basis unstated) | M-33 |
| 10 | IP truncation claim | **Matches** code (auth/handler.go:330,1261; legal/handler.go:70) | - |

These mismatches describe the as-found state. Whether the rewritten policy texts now match the code is a legal-review item, not verified here.

### 4.4 Data inventory

| Data | Source | Purpose | Storage | Retention (as found) | Access | Third party | Sensitive? |
|---|---|---|---|---|---|---|---|
| Name, email, avatar, pw hash | register / OAuth | account | `users` (Neon SG) | until anonymize (row kept) | user/admin/org (org admin via the C-01 leak) | Google/GitHub OAuth | PII |
| Passkeys, social IDs | auth | login | webauthn_credentials, social_accounts | deleted on erase | user | - | yes |
| Refresh token hash, truncated IP, UA (200) | login | session security | refresh_tokens | until expiry (job) | system | - | PII |
| Consent + truncated IP | accept page | proof | legal_acceptances | indefinite | system | - | low |
| Diary, journal, habits, tasks | user | personal log | diary_entries, learning_journal_entries... | indefinite; **not erased** | user; org admin via H-06; MCP client | LLM (undisclosed) | **high** |
| Captures (image/PDF/link + OCR text) | upload | note ingest | captures + **B2 us-east-005** | indefinite; blobs never deleted | user | vision LLM, Backblaze (USA) | **high** |
| AI prompts/responses | features | hints, feedback | lab_ai_interactions, workspace_ai_cache | indefinite | user/org | Anthropic/Gemini | med-high |
| MCP action log (args, before/after text) | MCP tools | revert/audit | audit_logs (mcp_action_log) | indefinite; survives erasure | user/admin | user's AI vendor | high |
| GitLab tokens (AES-GCM), MR/issue content | org/user connect | ticket linking, AI review | gitlab_connections/installations | until revoke; not on erasure | org | GitLab | med |
| Purchases, payment_events raw payload | checkout/webhook | billing | purchases, payment_events | indefinite | user/admin | Razorpay/Stripe (no card data) | financial |
| Assessment attempts, attempt_events (proctoring) | exams | scoring/proctoring | assessment_*, attempt_events | indefinite | org/mentor (M-07) | Judge0/Piston (code) | med |
| Public test candidate name/email/phone | `/api/p` | hiring | public attempts `anonymous_identity` | indefinite | org | - | PII |
| Certificates (learner name), mentor sessions, tickets | completion/features | verification/service | certificates, own tables | indefinite | **public** by UUID (certificates); org/mentor | - | low-med |
| Audit rows | admin actions | accountability | audit_logs | indefinite, mutable | admins | - | low |
| App logs (URIs incl. tokens in query) | server | ops | Render stdout | host default | ops | Render | med |
| Redis keys (rate limits, lab tokens, leaderboards, jobs) | runtime | cache/queue | Redis (host unknown) | TTLs | system | unknown | low-med |
| diary-draft in browser | editor | unsaved draft | localStorage | until cleared (not on logout) | device | - | high |
| Calendar events + Google tokens (enc) | user/Google | sync (planned) | calendar_events, `*_refresh_token_enc` (agent claim) | indefinite (agent claim); not built, and the "Google tokens" reading was the GitLab tokens (M-32) | user | Google | med |

Collected but unused (minimization): `audit_logs.ip_address` (never set); `org_domains.auto_join_enabled` (no consumer); `org_auth_config.sso_enabled`/`allowed_domains` (never read).

---

## 5. Subprocessors, licenses, retention matrix, unauthenticated routes

### 5.1 Subprocessor list

| Vendor | Purpose | Data shared | Country | Personal data? | DPA / ToS reviewed? |
|---|---|---|---|---|---|
| Neon | Primary DB (**shared dev+prod**) | All app data incl. diary/journal | Singapore (ap-southeast-1; per memory) | Yes | Cannot verify |
| Render | Backend hosting (free plan) | All API traffic, logs, env secrets | Singapore | Yes | Cannot verify |
| Vercel | Frontend + BFF | Requests, IPs, cookies | Singapore (+ global edge) | Yes (IP) | Cannot verify |
| **Backblaze B2** (`MINIO_ENDPOINT`) | Object storage | Captures, uploads, PDFs | **USA (us-east-005)** | Yes | Cannot verify; **not in policy** |
| Anthropic | LLM | Diary, journal, captures (text+images), answers, code | USA | Yes | No DPA/ZDR evidence |
| Google Gemini API | LLM (default model gemini-2.0-flash) | Same | USA/global | Yes | No evidence; free-tier training risk |
| Brevo | Transactional email | Email, name, body | EU (France) | Yes | Cannot verify; not in policy |
| Razorpay | Payments (INR) | Name, email, amount | India | Yes | Cannot verify (named) |
| Stripe | Payments | Name, email, amount | USA/global | Yes | Cannot verify (named; UI uses Razorpay) |
| Google / GitHub OAuth | Social login | Email, profile | USA | Yes | Cannot verify |
| GitLab (SaaS or self-hosted) | Ticket linking, AI review | Tokens (encrypted), MR/issue content | Varies | Yes | Cannot verify |
| Have I Been Pwned | Breach check | SHA-1 prefix (prefix-only unverified, AI-25) | USA | Minimal | n/a |
| Redis host (`REDIS_URL`) | Rate limit, cache, queue | Keys, job payloads | Unknown | Possibly | Cannot verify |
| Piston / Judge0 | Code execution (`PISTON_URL`) | User code | Self-hosted (likely) / operator URL | Low | Cannot verify |
| MCP clients (Claude, ChatGPT) | User-authorized assistant | Scoped student data | USA | Yes (user-initiated) | User's own terms; not in policy (AI-14) |
| Google Calendar | Planned sync | Calendar events | USA | Yes | N/A (not built) |
| Analytics / error tracking | none found in frontend or go.mod | - | - | - | Means no error/breach visibility (H-25) |

**AI flow:** user input -> Go handler -> `ai.LLMProvider` (single abstraction; JSON mode) -> Anthropic or Gemini -> response parsed. Stored in `lab_ai_interactions`, `workspace_ai_cache` and the diary/journal tables. No prompt logging to slog found. No secrets seen in prompts. "Called once / cached": partial (diary and journal deliberately uncached, AI-23).

### 5.2 Licenses

Go: 179 modules (`go list -m all`, module-cache LICENSE sniffed, heuristic): Apache-2.0 67, MIT 51, BSD 31, ISC 1, MPL-2.0 1, unknown/no file 28 (mostly indirect/replace/main). No GPL/AGPL/LGPL among Go modules.

| Dependency | Version | License | Usage | Risk |
|---|---|---|---|---|
| Go modules (179) | backend/go.mod | Apache-2.0 67, MIT 51, BSD 31, ISC 1, MPL-2.0 1, unknown 28 | runtime | Low; resolve the 28 unknowns (per-module list not enumerated) |
| github.com/jackc/pgx/v5, github.com/go-chi/chi/v5 | go.mod | MIT | DB driver, router | None |
| pgregory.net/rapid | v1.2.0 | MPL-2.0 | test-only property testing | Low (file-level copyleft, not shipped) |
| Frontend direct deps (88) | package.json | MIT 84, Apache-2.0 2, ISC 2 | UI | None; transitive deps not scanned |
| **MinIO** | pinned | **AGPL-3.0** | object store (compose) | **🟡 MEDIUM**, unmodified separate service. LEGAL REVIEW REQUIRED (M-41) |
| **Grafana** | pinned | **AGPL-3.0** | dashboards (compose) | **🟡 MEDIUM**, same |
| poppler-utils | image | GPL-2/3 | `pdftotext` subprocess | Low (subprocess, not linked) |
| Postgres, Redis 7, docker-cli, Piston | images | PostgreSQL, BSD, Apache, MIT | infra | None |

### 5.3 Data retention matrix

| Data type | Current behavior (as found) | Gap |
|---|---|---|
| Account identity | Anonymized on request; row kept | Children not purged (C-03) |
| Diary / journal / captures text | Kept forever; survive deletion | 🔴 CRITICAL C-03, H-27 |
| Capture blobs (B2 USA) | Never deleted | H-18 |
| MCP connections/tokens | Live after deletion; expired rows never purged | H-01, AI-08 |
| MCP action log | Forever, full content | M-27 |
| AI prompts/responses | Forever (lab_ai_interactions) | M-30 |
| Sessions / auth tokens | Purged on expiry by job | OK |
| Consent records | Forever | State basis (M-33) |
| Audit logs | Forever, mutable, errors ignored | H-26 |
| App logs | Render default; Singapore | CERT-In 180d India: LEGAL REVIEW REQUIRED |
| Public-test candidate PII | Forever | M-23 |
| Payments + raw webhook payload | Forever | CA REVIEW REQUIRED for tax retention; redact payload (PAY-16) |
| Backups (Neon PITR) | Default; undocumented | M-40, M-32 |
| AI provider copies | Provider-side unknown | M-29 |
| diary-draft (browser) | Survives logout | AUTHN-19 |

The retention purge job added in the fix pass changes the "forever" rows only to the extent its configuration covers them (H-27: verify).

### 5.4 Unauthenticated route table

Rate-limit column is **as found**; the fix pass added sliding-window limits on public and OAuth-register paths, `RequireMetricsToken` on `/metrics`, and the attempt-token header.

| Route | Auth basis | Rate limit (as found) | Note | Code ref (source) |
|---|---|---|---|---|
| GET /health | none | none | static "ok" | router.go:101 |
| GET /metrics | none | none | H-16 | router.go:110 |
| /api/auth/* (register, login, verify-email, resend-verification, forgot/reset-password, social/exchange, webauthn login begin/finish, csrf-token, google/github redirect+callback, refresh, logout) | none / OAuth state / cookie+CSRF | **yes** (router.go:313) | only limited group | router.go:312-346 |
| GET /api/invitations/preview/{token} | invite token | none | add limit | assessment/routes.go:204 |
| GET/POST /api/p/{code}[/start, /submit/{token}, /result/{token}] | short code / attempt token | none | H-03, H-04, M-22 | assessment/routes.go:207-210 |
| GET /api/profile/public/{slug} | slug | none | field exposure unverified | profile/routes.go:45 |
| GET /api/calendar/invites/{token}/accept, /api/calendar/events.ics?token= | token | none | M-12 | calendar/routes.go:52-53 |
| GET /api/public/courses, /{slug}/tree, /modules/{id}/translations | none | none | H-15 reaches here; pagination unverified | courses/routes.go:96-98 |
| GET /api/public/pricing, /api/public/payments/config | none | none | static | - |
| /.well-known/oauth-*, POST /oauth/register, GET /oauth/authorize, POST /oauth/token, POST /mcp | none / PKCE / bearer | none | H-01, H-02 | mcpconnect/routes.go:12-17 |
| GET /api/gitlab/callback, POST /api/gitlab/webhook | state / webhook token | none | RT-17 (in H-03) | gitlab/routes.go:176-177 |
| GET /api/certificates/{uuid} | UUID | none | M-24 | certificates/routes.go:68 |
| POST /api/payments/webhooks/{provider} | HMAC signature | none | PAY-13 (in H-03) | mentoring/routes.go:53 |
| GET /api/public/workspaces/{shareToken}, POST .../interest | 256-bit token | **yes** (IP/email/project) | good; body capped, uniform 202 | workspace/routes.go:243-244; handler_recruiting.go:63 |
| GET /api/roadmaps/discover, /api/roadmaps/{id} (OptionalAuth) | none / optional | none | M-09; `is_public` filter unverified | roadmap/routes.go:42,49 |
| pprof / swagger | - | - | not present | - |

---

## 6. Dependency and security scan results (2026-10-07)

Branch `debug-labs`. Tools: `govulncheck` (latest), `pnpm audit --prod` (pnpm 11.11.0), `gitleaks` (installed from source, `gitleaks git --log-opts=-500 --redact`). No secret values appear here. This closes the original audit's gaps INF-07/08/17 (history scan and vuln scans not run).

### 6.1 Go (`govulncheck ./...`, backend)

Before: 10 reachable vulnerabilities in 3 modules plus the standard library.

| ID | Package | Found | Fixed | Action |
|---|---|---|---|---|
| GO-2026-6355, GO-2026-6354 | golang.org/x/crypto | v0.54.0 | v0.56.0 | Bumped to v0.56.0 |
| GO-2026-6253 | github.com/moby/go-archive (test-only, via testcontainers) | v0.2.0 | v0.3.0 | Bumped to v0.3.0 |
| GO-2025-3770 | github.com/go-chi/chi/v5 | v5.2.1 | v5.2.2 | Bumped to v5.2.2 |
| GO-2026-6218 net/url, -6090 crypto/tls, -6089 net/http, -6088 encoding/xml, -5972 encoding/asn1, -5026 net/http | Go standard library | go1.26.5 | go1.26.6 | **Open: needs the Go 1.26.6 toolchain** |

Also bumped as transitive of the above: golang.org/x/text v0.41.0, moby/sys/user v0.4.1. `go build ./... && go vet ./...` pass after the bumps.

After: only the six standard-library findings remain, fixed by building with Go 1.26.6. `backend/Dockerfile` uses the floating `golang:1.26-alpine` image, so the next image build picks it up; local developer machines (go1.26.5) need a toolchain upgrade. `go.mod` says `go 1.26.0`, so no file change is needed. govulncheck also reports 5 findings in imported packages and 2 in required modules that the code does not call (not actioned).

### 6.2 Frontend (`pnpm audit --prod`)

Before: 62 vulnerabilities (3 critical, 20 high, 31 moderate, 8 low), criticals and most highs in `next`.

Applied (no code changes needed):
- `next` 16.2.9 -> 16.3.8 (minor; clears the critical and high Next advisories, patched in >=16.2.11 / 16.3.3 / 16.3.6) and transitive `postcss`, `sharp`, `nanoid`, `source-map-js`.
- `mermaid` 11.16.0 -> 11.16.1.
- `@tiptap/*` 3.28.0 -> 3.31.4 (fixes `@tiptap/core`).
- `pnpm-workspace.yaml` `overrides`: `dompurify ^3.4.16`, `katex ^0.18.2`, `lodash-es ^4.17.24`, `nanoid ^3.3.18` (3.x) and `^5.1.16` (5.x), `prosemirror-view ^1.42.3`, `baseline-browser-mapping ^2.11.0`.

After: **1 high remaining** - `braces` (via `sass > chokidar`, build-time only). The advisory lists `>=3.0.4` as patched, but the npm registry has no `braces` release above 3.0.3, so there is nothing to upgrade to. It is a dev/build-path dependency (file-glob expansion in the sass watcher), not shipped to the browser or run on user input. Re-check when upstream publishes.

`pnpm tsc --noEmit` is clean and `pnpm build` succeeds on Next 16.3.8. The frontend CSP and proxy files were not touched in this dependency pass. The dependency changes are in the working tree, uncommitted.

### 6.3 Secrets (gitleaks, last 500 commits = all 152 commits on the current history)

53 raw findings, all triaged:

| Finding | Where | Verdict |
|---|---|---|
| ~45 `generic-api-key` | `content/**` course lessons/quizzes (Kubernetes secrets, `--discovery-token-ca-cert-hash`, `Idempotency-Key`, `Sec-WebSocket-Key` header names), generated fixtures `backend/db/fixtures/*.generated.sql` | False positives: teaching examples and header names |
| `gitlab-pat` | `backend/internal/secrets/secrets_test.go` | False positive: obvious test plaintext used to exercise encryption |
| `generic-api-key` | `backend/internal/jobs/e2e_test.go` (`lowKey`) | False positive: e2e test constant |
| `generic-api-key` | `k8s/overlays/prod/secrets.env.example` | False positive: empty example value |
| `generic-api-key` | `VIOLATIONS_REPORT.md` line 127 (commit aa4bb56, still in HEAD) | **Review.** The text quotes an `LLM_API_KEY` value that starts with the Google API key prefix. The quoted value is only 14 characters (a real key is 39), so it is truncated and not usable, but confirm it was a prefix and not a full key; if the key ever was real, rotate it and scrub the line |

No private keys, no AWS/Stripe/Razorpay keys, and no `.env` files with values were found in history.

---

## 7. Root-cause themes (cross-cutting analysis)

### 7.1 The common cause

Implementation sessions were driven by feature requests ("add X"). A feature request defines the **happy path**. Nothing in the loop forced the questions that produce most of this audit's findings:

1. Who else can call this, and with what ids? (authorization, tenancy)
2. What happens on the second request, a retry, a crash, a concurrent call? (races, idempotency, money)
3. What happens when the user leaves, or is removed or suspended? (lifecycle)
4. What does it cost if someone hammers it? (rate limits, quotas)
5. Where does the user's data go, and for how long? (consent, retention, erasure)
6. Does the doc say only what the code does? (docs drift)

An agent asked to "build the profile endpoint" builds a working profile endpoint. "Only admins of the same org may read it" must be stated or tested; it does not appear from the feature description. The only checks in the loop (`go vet`, `tsc`, unit tests) verify that code compiles and the happy path works, so they pass on insecure code.

The repo already had the right rules written down (`ai-pattern-learnings.md`: rate-limit new endpoints, lock counters, verify tenant in the query). They were advice in a markdown file, not enforced by any test, lint or CI gate, so the same patterns came back in new code. That is the main process failure.

### 7.2 Why each class appeared

**R1. Cross-tenant and IDOR** (C-01, C-02, H-04, H-05, H-06, H-09, M-07..M-11, TEN-*)
- Handlers were written as "authenticated, role is admin, fetch the row by id". The role check answers "may this caller use this feature" and was treated as also answering "may this caller see this row". Request ids were trusted as keys. Tables created for single-user features (journal, mistakes, habits) had no `org_id`, and later org-admin features joined them without noticing.
- Not caught: tests ran as one user in one org; no cross-org negative test existed or was required.
- Pattern in `ai-pattern-learnings.md`: "Personal data reachable through an org-scoped door" (added in this audit).

**R2. Erasure and lifecycle that did not cover new tables** (C-03, H-01, H-08, H-18, H-19, M-27, M-30, M-32)
- Deletion was written first, when `users` was the only table that mattered. Each later feature added tables with `user_id` FKs, and nothing tied erase/export to the schema. A hand-written list goes stale on the first new table.
- Not caught: no test enumerated every `user_id` table. Erasure is invisible in normal use.
- Cause removed by: erase and export now read the FK catalog, so a new table is covered automatically, and a test fails if a table is neither erased nor explicitly retained.

**R3. Missing rate limits, quotas, timeouts, global caps** (H-02, H-03, M-04, M-17, M-39)
- `RateLimit` was used once in the whole router. Each endpoint was added in its own session; "make it work" does not include "make it abuse-proof". `ai-pattern-learnings.md` had recorded this exact pattern on 2026-08-01; the rule was not enforced and later endpoints repeated it.
- Cause removed by: limits attach to route groups and a central quota wrapper sits around the LLM provider, so a new endpoint is covered by default instead of by remembering.

**R4. Money paths and split-state writes** (H-29, M-25, M-35, M-36, M-10)
- `CreatePackPurchase` never wrote the `granted` field that `CompletePurchase` read, so pack purchases could not credit the ledger (found and fixed in the fix pass: "pack purchases never credited the ledger"). Refund and dispute events were parsed but ignored for packs. The gateway was called before intent was persisted. Webhooks returned 2xx on internal failure and deduped on event id alone.
- The two halves were written in separate sessions and each looked correct alone; failure handling (retry, crash between steps) was not part of the feature description. No test ran create and complete together; none crashed between the gateway call and the DB write.
- Rules added: every write another function reads gets one test that runs both; a persisted intent precedes any external side effect; a dedupe key means "fully handled", not "seen".

**R5. Fake controls** (H-07, M-01, M-02)
- `Verify` compared the caller's token with the token `Add` had just returned. The happy-path test (add, then verify with the returned token) passes, so the feature looked finished; the security property (proof of control) was never part of the test. Same shape: SSO toggle stored but never read.

**R6. Privacy, consent, retention, compliance process** (H-20..H-28, H-30, M-06, M-23, M-29, M-33, M-37, M-38)
- AI features sent user text to third parties without opt-in; no retention schedule, grievance contact, age gate or append-only auth log; wrong or missing items in the privacy notice. These are legal and process requirements, not code behaviour, so a coding request never surfaces them. The privacy page was written from marketing intent, not the actual data flow. Compliance work (DPDP, CERT-In, legal pages) was not scheduled; it was never a coding task until this audit made it one.
- Judgement: this class needs a human checklist at design time (a "names its consent check and retention window" gate). The fixes are code, but the policy texts still need legal review.

**R7. Infrastructure and hardening** (H-10..H-14, H-16, H-17, M-13..M-21, M-28, M-40)
- Each item was the shortest way to make labs, GitLab and metrics work: Docker socket in the backend, privileged Piston, shared lab bridge, no pids limit, bare `http.Client` for GitLab, public `/metrics` (written for Caddy, deployed on Render), local `.env` pointing at the production DB. Compose files and Dockerfiles are not covered by Go or TS checks. The shared dev/prod database was a convenience never revisited. `netguard` existed but each new outbound client had to opt in, and one did not.
- Cause removed by: one `netguard.NewHTTPClient` constructor used by all GitLab calls; `testdb` refuses non-local URLs.

**R8. Frontend XSS and CSP** (H-15)
- Lesson markdown rendered raw through `dangerouslySetInnerHTML`; CSP allowed `'unsafe-inline'` and any `ws:` host. The renderer was built for trusted, author-written content; later features (imported and AI content, public courses) widened who can supply content without revisiting the trust assumption. A permissive CSP is the default that makes Next.js work, and tightening needs nonce plumbing nobody was asked to build.

**R9. Docs claiming features that do not exist** (M-02, M-14, doc drift in 2.4)
- Magic link, OIDC/SAML, device list, switch-org, Yjs relay, calendar sync, design embed were described as shipped. Design docs were written before the build and read as if complete; schema columns (`allow_magic_link`, `oidc_*`) made the claim look real. No status line existed to tell the two apart.
- Rule added: each doc section carries a status; "planned (not built)" is removed only by the change that builds it.

**R10. Tests that could not have caught any of this** (all)
- Packages with DB code had only pure-Go tests (`ai-pattern-learnings.md` records four silently broken SQL bugs found the first time a real DB ran). There was no DB test harness, so each package matched its local test style. The harness (`testdb`) now exists, but this audit's DB tests were written without Docker and have never been executed. **This is the largest remaining risk in the fixes themselves.**

### 7.3 Why it was not done in the implementation phase (direct answer)

1. **The prompt was the spec.** Feature prompts described behaviour, not threats, abuse, failure or lifecycle. The agent delivered what was asked.
2. **No negative tests.** Nothing required "other tenant gets 404", "second call is rejected", "crash between steps is recoverable", "deleted user's token stops working".
3. **Rules were prose, not gates.** `ai-pattern-learnings.md` and `CLAUDE.md` described the right habits but no CI check, lint or test enforced them, so each new session could repeat the pattern.
4. **Session isolation.** Each session saw one package. Cross-cutting concerns (rate limiting, tenancy, erasure, retention) live between packages and were nobody's job.
5. **A one-person project with no review step.** No second reader asked the six questions in 7.1.
6. **Compliance work (DPDP, CERT-In, legal pages) was not scheduled.** It was never a coding task until this audit made it one.

### 7.4 What already prevents a repeat (done in code)

- Catalog-driven erasure and export, with a test that fails on an unclassified `user_id` table.
- Rate limits on route groups, central LLM quota and timeout.
- One guarded outbound HTTP client; `testdb` refuses non-local DB URLs.
- Tenant checks in the query itself (profile, rewards, sheets, courses), with negative tests written (unrun).
- Docs carry a "planned (not built)" status for unbuilt features.

---

## 8. Remaining open items and operator actions

### 8.1 Remediation roadmap (original prioritisation)

| Priority | Items |
|---|---|
| **P0 - immediate** | C-01, C-02, C-03, H-01, H-03 (public tests + AI quota first), H-05, H-17, H-18, H-19, H-20 |
| **P1 - before production / enterprise launch** | H-02, H-04, H-06..H-16, H-21..H-26, H-29, H-30 (after CA), M-01, M-05, M-06, M-16, M-29, M-39, M-40 |
| **P2 - next sprint** | H-27, H-28, remaining MEDIUM (M-02..M-04, M-07..M-15, M-17..M-28, M-30..M-38, M-41) |
| **P3 - long term** | LOW items; exhaustive sweeps (121 MCP tools, 108 migrations); SOC 2 / ISO readiness if customers ask (voluntary). Gitleaks history, govulncheck and pnpm audit are now done (section 6) |

### 8.2 Findings still open or marked verify

Fixed locally but uncommitted: M-39 (`.github/workflows/ci.yml` is untracked; commit it and confirm it runs).

Open (no fix in the changelog): H-25 (IR runbook, CERT-In POC, alerting), H-30 (GST invoice, CA), M-05 (open redirect `/\`), M-14 (lab egress proxy not built; docs corrected), M-28 (single unversioned AES key), M-31 (prompt delimiters for diary/journal/labs/wiki), M-38 (price/tax display), and the LOW items marked open in 3.4.

Verify before relying on them (changelog silent or ambiguous): H-10 (non-root USER, Piston isolation), H-11, H-12, H-13 (lab privileged fallback, pids/ulimits, per-session networks), H-15 (`connect-src` narrowing), H-19 (export audit row), H-20 (server-side AI consent enforcement), H-21 (seller details), H-22 (SLA page), H-24 (password-register age gate), H-26 (audit error handling, `ip_address`), H-27 (retention coverage), M-02, M-03, M-06, M-08, M-09, M-10, M-12, M-13, M-16, M-20, M-21, M-22 (expiry), M-23, M-24, M-26, M-30, M-32, M-33, M-34, M-36, M-37, and H-01 explicit revocation on remove/suspend/logout-all.

### 8.3 Operator actions

From the changelog and the security scan:

1. Run `go test ./...` with Docker; apply migrations 054-061 to a dev copy first (owners/admins will be forced to enrol in MFA).
2. Build and deploy with Go 1.26.6 (six stdlib vulnerabilities); upgrade local toolchains.
3. Confirm `VIOLATIONS_REPORT.md` line 127 is not a real Google API key (rotate and scrub if it is).
4. `braces` high advisory: no fixed version exists yet; re-check upstream.
5. Commit the dependency changes (`backend/go.mod`, `backend/go.sum`, `frontend/package.json`, `frontend/pnpm-lock.yaml`, `frontend/pnpm-workspace.yaml`) and the untracked `.github/` CI workflow (M-39), then confirm the workflow runs. `package.json` and the lockfile also contain unrelated pending edits (`sanitize-html`) already in the working tree. Nothing from the fix pass is committed yet.
6. Set env: `METRICS_TOKEN`, `LABPROXY_ALLOWED_ORIGINS`, `GRIEVANCE_OFFICER_*`, `SECURITY_CONTACT_EMAIL`, `DPA_CONTACT_EMAIL` (see `ENV_VARS.md`, `backend/.env.example`, `frontend/.env.example`).
7. Move local `backend/.env` onto a dev Neon branch (H-17).
8. Deploy frontend and labproxy together (lab token moved to a WebSocket subprotocol).
9. Legal/CA review: DPA, GST invoicing (H-30), policy texts, children/age gate, nomination commencement, CERT-In log retention, AGPL components (M-41), refund policy/E-Commerce disclosures.
10. Turnstile: create keys; set `TURNSTILE_SECRET_KEY`, `NEXT_PUBLIC_TURNSTILE_SITE_KEY`, `CAPTCHA_BYPASS_SECRET` (required on both sides for demo login and admin password reset); test the widget in a browser. Production refuses to start without `TURNSTILE_SECRET_KEY`.
11. Apply the B2 bucket lifecycle rules documented in `docs/infrastructure.md`.
12. Verify live settings: actual `LLM_PROVIDER`, Render/Neon/B2/Redis configuration, `TRUSTED_PROXY_CIDRS` against Render ingress, Neon PITR window and a tested restore, paid Render plan, DPAs/ZDR with Anthropic/Gemini, production encryption key separate from dev.
13. Optional: a "mark public" toggle for custom sheets (needs a column and migration).
14. Re-run the unswept checks (MCP tool bodies, migrations table by table) and this audit after DB tests pass and before onboarding an external org, ideally with a human reviewer for legal and billing parts.

### 8.4 Fixes applied beyond a single finding (changelog, for completeness)

- **Backend:** `profile`, `rewards`, `useroverview`, `courses` (`GetCourseTree`, `restrictTreeForViewer`, `IsOrgStaff`), `assessment` (mentor scoping, public-test validation), `orgs/members` (`outranks`, role/override revocation, cache invalidation), `authz` (`SetMemberStatus`, `ErrOutranked`, active-membership permissions), `wiki` live role, `auth` (`mintSession`, TOTP MFA + recovery codes, login lockout by email and IP, change-password, social 18+ declaration, `authevents`), MCP OAuth (DCR validation, live-connection predicate, refresh rotation with reuse detection, per-scope re-consent), `privacy` (catalog-driven erasure, curated + generic export, AI consent and nominee settings), `captures` (blob deletion on dismiss), retention purge job, payments (webhook retry, `ReconcilePayments`, refund/dispute reversal, `ReversePackPurchase`), rate limiting/quotas/`MaxBody`/`SecureHeaders`/`RedactRequestURI`/`RequireMetricsToken`, `netguard.NewHTTPClient`, `testdb.checkTestDBURL`, labs/labproxy (WS subprotocol token, allowed origins), Dockerfile, `docker-compose.prod.yml` (docker-proxy, networks), `prometheus.yml`, CI workflow hardening, dependency bumps (`x/crypto`, `chi`, others).
- **Migrations:** 054 (domain verification reset + unique verified domain), 055 `user_privacy_settings`, 056 `auth_events` (delete-deny trigger), 057 (social 18+ declaration), 058 (MCP refresh reuse detection), 059 (payments reconcile/reversal), 060 `user_mfa`, 061 (`project_teams.gitlab_project_id` unique per org). **None has been run against a database.**
- **Pack-purchase ledger bug:** an existing bug (pack purchases never credited the ledger) was found and fixed during the payments work.
- **Frontend:** nonce CSP, `sanitize-html` allowlist, legal pages (`lib/legal-constants.ts`), MCP authorize consent component, org-domains TXT UI, admin user-detail tabs removed, settings cards (MFA, change password, AI consent, nominee), `/login/mfa`, Turnstile widget, dependency bumps (62 vulnerabilities incl. 3 critical -> 1 high with no npm fix).
- **Docs:** `docs/*.md` synced to code with unbuilt features marked "planned (not built)"; `docs/security-scan-2026-10-07.md`, `ENV_VARS.md` and the `.env.example` files updated; `docs/auth.md` MFA section; bugfix-log entries appended to `C:\Users\jaisw\bugfix-log.md`.

### 8.5 Gate (from the audit report)

**Stop here.** This audit made no changes beyond writing this report. **No fixes will be implemented until the user approves** which findings to address and in what order. Approved fixes will follow the project's Production-Ready rules (no stubs or TODOs, tests, one root-cause fix per pattern) and get a `bugfix-log.md` entry. Before ticketing, re-run the unswept checks (MCP tool bodies, migrations, gitleaks history, govulncheck, pnpm audit) and confirm live Render/Neon/B2/Redis settings, including the actual `LLM_PROVIDER`.

---

## 9. Prevention checklist

Still needed (process, not code):

1. **Run the DB tests** (Docker). Until they pass, the new negative tests are untested claims and DB-touching fixes are "fixed-but-DB-test-not-run".
2. **Make the rules mechanical.** Add a CI step that runs `go test ./...` with Docker plus `govulncheck`, `pnpm audit` and `gitleaks`, and a route-coverage test that fails when a new route has no rate-limit group or role guard.
3. **Pre-merge checklist for any new endpoint:**
   - caller scope: who may call it, with which ids
   - tenant id in the query itself, with a cross-org negative test
   - rate limit / quota (and a timeout for any external call)
   - failure and retry behaviour (retry, crash between steps, concurrent call); persisted intent before any external side effect; a dedupe key means "fully handled", not "seen"
   - lifecycle (suspend, remove, delete) including any new token/credential table
   - consent and retention for any user data; it must be named in the notice and covered by erase and export (the catalog-driven test will fail otherwise)
   - every write another function reads gets one test that runs both
   - proof-of-control features (verification, ownership) get a test for the failure case, not only the happy path
4. **Docs status rule:** each doc section carries a status; "planned (not built)" is removed only by the change that builds it.
5. **Design-time compliance gate:** a feature that handles personal data names its consent check and retention window before it is built; legal-document changes get legal review.
6. **Outbound HTTP:** all outbound clients use `netguard.NewHTTPClient`; compose/Dockerfile changes are reviewed against the lab-isolation findings (no docker.sock in the API container, non-root, pids/ulimits, internal per-session networks).
7. **Re-run this audit** after the DB tests pass and before onboarding an external org, with a human reviewer for the legal and billing parts (DPA, GST invoicing, policy texts).
