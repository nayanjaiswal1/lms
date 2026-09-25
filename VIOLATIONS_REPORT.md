# MindForge — Code Quality Violations Report
Date: 2026-09-25
Repo: C:\dev\dream\mindforge
Agents: 3 parallel (duplicated-code, hardcoded-tokens, repeated-css)
Mode: research-only, no edits

## Executive Summary
- **Duplicated code: 15 major clusters** — ~30x decodeJSON, ~30x writeDomainError, query helpers 8x, cursor 3x, schedule validation 5x, plus 6 frontend fetch/upload duplications.
- **Hardcoded tokens/secrets: CRITICAL** — live Neon DB, Upstash Redis, Google OAuth, Brevo SMTP, Gemini LLM key in `backend/.env`; live OIDC JWT + prod backend URL in `frontend/.env.local`; weak dev secrets duplicated in root `.env`. Source-level hardcodes in `frontend/lib/constants.ts:11`, WS fallbacks, `config.go` defaults.
- **Repeated CSS: CRITICAL + HIGH** — 1 raw-color `dark:` file, 3 parallel palettes (gitlab-planning 50+ hex, whatnow fonts, focus-wall brass), 55+ arbitrary `text-[10px]/[11px]`, 100+ `flex-between`, 75x `rounded-lg border`, 76x inline `style`, raw buttons/inputs, radius/shadow/motion/z violations.
- **Banned patterns:** `panic()` in `api/router.go:177`, `TODO` in `gitlab/repo_connection.go:639` + `contentpipeline/importer`, DEV token logging.

---

## PART A — Duplicated Code (DRY violations)

### A1. `decodeJSON` copy-pasted ~30x — verbatim identical
Snippet:
```go
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
    if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
        httputil.WriteError(w, http.StatusBadRequest, "Invalid request body.")
        return false
    }
    return true
}
```
Files:
- `backend/internal/courses/handler.go:153`
- `backend/internal/wiki/handler.go:31`
- `backend/internal/labs/handler.go:103`
- `backend/internal/messaging/handler.go:37`
- `backend/internal/calendar/handler.go:31`
- `backend/internal/coupons/handler.go:27`
- `backend/internal/assessment/handler.go:66`
- `backend/internal/certificates/handler.go:24`
- `backend/internal/diary/handler.go:48`
- `backend/internal/sheets/handler.go:33`
- `backend/internal/project/handler.go:19`
- `backend/internal/sessions/handler.go:19`
- `backend/internal/tickets/handler.go:29`
- `backend/internal/srs/handler.go:115`
- `backend/internal/roadmap/handler.go:41`
- + `whatsnew:31`, `whatnow:38`, `practice:27`, `mentoring:47`, `journal:49`, `interviewexp:25`, `interviewprep:57`, `highlights:25`, `gitlab:23`, `focuswall:21`, `feedback:29`, `systemdesign:23`, `projectmarket:22`, `mcpconnect/oauth_authorize.go:232`
Fix: share at `backend/internal/httputil/response.go` as `httputil.DecodeJSON(w,r,dst) bool`.

### A2. `writeDomainError` wrapper + per-package `domainErrors` map — ~30x
Snippet: `func writeDomainError(w http.ResponseWriter, err error) { httputil.WriteDomainError(w, err, domainErrors, "Something went wrong.") }`
Files:
- `backend/internal/courses/handler.go:144`
- `backend/internal/wiki/handler.go:47`
- `backend/internal/messaging/handler.go:33`
- `backend/internal/calendar/handler.go:27`
- `backend/internal/labs/handler.go:41`
- `backend/internal/assessment/handler.go:62`
- `backend/internal/certificates/handler.go:47`
- `backend/internal/captures/handler.go:64`
- + `coupons:23`, `diary:44`, `feedback:25`, `focuswall:42`, `gitlab:43`, `habit:43`, `highlights:43`, `interviewexp:39`, `journal:45`, `legal:21`, `mentoring:43`, `mistakes:28`, `moderation:29`, `practice:23`, `pricing:27`, `project:31`, `projectmarket:41`, `roadmap:37`, `sessions:37`, `sheets:29`, `srs:28`, `systemdesign:41`, `tickets:25`, `whatnow:33`, `whatsnew:27`
Fix: call `httputil.WriteDomainError` directly or add `httputil.DomainHandler` closure.

### A3. `urlParam / queryStr / queryInt / queryStrPtr / queryBool / queryFloat` — ~8x
Files: `backend/internal/courses/handler.go:161,165,169`, `backend/internal/messaging/handler.go:45,53,65`, `backend/internal/calendar/handler.go:39`, `backend/internal/mentoring/handler.go:55,59`, `backend/internal/tickets/handler.go:37,41`, `backend/internal/assessment/handler.go:95`, `backend/internal/moderation/handler.go:100`, `backend/internal/rewards/handler.go:172`
Note: behavior drift (messaging adds `n<=0` guard).
Fix: `backend/internal/httputil/query.go` — `QueryStr/QueryInt/QueryBool/URLParam`.

### A4. `encodeCursor/decodeCursor` — 3x verbatim
Files: `backend/internal/orgs/cursor.go:11,18`, `backend/internal/jobs/store.go:20,25`, `backend/internal/mcpconnect/action_log.go:159` (+134 sibling)
Fix: `backend/internal/pagination/cursor.go` or `httputil/cursor.go`.

### A5. `starts_at/ends_at` ordering validation — 5x
Files: `backend/internal/courses/handler.go:197,223,372,564,619`, `backend/internal/assessment/handler_assessment.go:58,443`, `backend/internal/calendar/service.go:59`, `backend/internal/sessions/service.go:196`
Fix: `backend/internal/validate/schedule.go`.

### A6. `const handlerLLM = "llm.task"` — 3x
Files: `backend/internal/mistakes/service.go:12,16`, `backend/internal/roadmap/service.go:13,17`, `backend/internal/revisionplan/service.go:12,16`
Fix: import `backend/internal/jobs/handlers/constants.go:7` (`HandlerLLM`).

### A7. `http.Error` plain-text in labproxy bypasses envelope
Files: `backend/cmd/labproxy/proxy.go:83,89,96,100,111,117,130,135`, `backend/cmd/labproxy/preview_host.go:31,37,48,88,94,100`, `backend/cmd/labproxy/preview.go:191,236,243,253`, `backend/internal/labs/service.go:1260`
Fix: JSON envelope via `httputil.WriteError`.

### A8. `auth.RequireClaims` inline 100s x (should be middleware)
Samples: `backend/internal/assessment/handler.go:121,142,158,290,323,367,380,409,422`, `backend/internal/calendar/handler.go:165,190,223,238,290,325,346,367,388,464`, `backend/internal/certificates/handler.go:53,72,87,102,121,138,165,195,211,231`, `backend/internal/captures/handler.go:109,207,312,327,365,388,406`
Fix: Chi middleware `RequireRole` at routes group, read claims from context. Violates AGENTS.md Rule 5.

### A9. Report/ticket list query builder duplicated
Files: `backend/internal/moderation/repo.go:149`, `backend/internal/mentoring/repo.go:806`, `backend/internal/tickets/repo.go:168,196`
Fix: shared store/pagination builder.

### A10. `BACKEND_URL ?? NEXT_PUBLIC_API_URL` + `publicBase()` vs `baseURL()` — ~20x
Canonical: `frontend/lib/server/api.ts:37` (`baseURL()`)
Dupes: `frontend/lib/server/api.ts:121,151`, `frontend/lib/server/public.ts:69`, `frontend/lib/server/roadmap-public.ts:6`, `frontend/lib/server/certificates-public.ts:15`, `frontend/lib/server/courses.ts:99,120`, `frontend/lib/public/actions.ts:7`, `frontend/app/login/actions.ts:71,141`, `frontend/app/register/actions.ts:60`, `frontend/app/verify-email/actions.ts:18`, `frontend/app/demo/actions.ts:28`, `frontend/app/org-select/actions.ts:27`, `frontend/app/org/create/actions.ts:63`, `frontend/app/onboarding/actions.ts:25`, `frontend/app/auth/callback/route.ts:23`, `frontend/lib/server/calendar.ts:218`
Fix: delete all `publicBase()` defs, use `baseURL()`.

### A11. Raw `fetch(baseURL()+authHeaders())` bypassing helpers — ~15x
Files: `frontend/app/(app)/users/actions.ts:102,127`, `frontend/app/org/setup/actions.ts:30,152,191`, `frontend/app/org/settings/authentication/actions.ts:31`, `frontend/app/org/settings/integrations/actions.ts:21`, `frontend/app/org/settings/domains/actions.ts:22,47,73,101`, `frontend/app/(app)/settings/profile/actions.ts:13,113,138,238,268`, `frontend/app/(app)/question-bank/actions.ts:57,93`, `frontend/app/onboarding/actions.ts:36`, `frontend/lib/server/batches.ts:304`, `frontend/lib/profile/server.ts:23`
Fix: `frontend/lib/server/api.ts:62,82,145` (`apiGet/apiPost/apiAction`).

### A12. Hand-rolled multipart upload
Bad: `frontend/lib/batches/actions.ts:73-99` (esp. 80-94)
Good reference: `frontend/lib/wiki/actions.ts:95-96`, `frontend/lib/courses/actions.ts:243`
Fix: `frontend/lib/server/api.ts:117` (`apiUpload`).

### A13. Anonymous public-fetch block — 6x same shape
Files: `frontend/lib/server/courses.ts:96-113,119-132`, `frontend/lib/server/public.ts:75-83,85-93`, `frontend/lib/server/roadmap-public.ts:13-18,24-32`, `frontend/lib/server/certificates-public.ts:21-29`, `frontend/lib/server/pricing.ts:26`, `frontend/lib/server/payments.ts:33`
Fix: new `apiGetPublic<T>(path,{revalidate})`.

### A14. Auth-bootstrap `fetch + forwardSetCookies` — 5x
Files: `frontend/app/login/actions.ts:80-85,149-154,200-212` (+helpers 21-50,173-218), `frontend/app/register/actions.ts:65`, `frontend/app/verify-email/actions.ts:23`, `frontend/app/demo/actions.ts:35`, `frontend/app/org-select/actions.ts:39`, `frontend/lib/server/calendar.ts:215-240`, `frontend/app/auth/callback/route.ts:31`
Fix: new `frontend/lib/server/auth-fetch.ts` (`authFetchWithCookies`).

### A15. Client-component direct `fetch("/api/...")`
Files: `frontend/app/(app)/users/manage-roles-dialog.tsx:85,129,146,168,185`, `frontend/app/(app)/users/manage-features-dialog.tsx:49,67`, `frontend/app/platform/jobs/workers/workers-client.tsx:29`, `frontend/components/settings/gitlab-connection-manager.tsx:32`, `frontend/components/auth/social-login-buttons.tsx:63`, `frontend/lib/whatnow/client.ts:47`
Fix: `frontend/lib/client/api.ts:18` (`apiFetch`).

---

## PART B — Hardcoded Tokens / Secrets / Values

### B-CRITICAL — Live credentials in workspace (gitignored but plaintext, rotate + vault now)
- `backend/.env:7` — Neon `DATABASE_URL` with password `npg_7pDeTtWb8YPr@...`
- `backend/.env:10` — Upstash `REDIS_URL` with token `rediss://default:gQAA...`
- `backend/.env:13-15` — weak predictable `JWT_SECRET`, `COOKIE_SECRET`, `ENCRYPTION_KEY` (`dev_*_replace_me`)
- `backend/.env:31-32` — `GOOGLE_CLIENT_ID=15933...apps.googleusercontent.com` + `GOOGLE_CLIENT_SECRET=GOCSPX-...`
- `backend/.env:38-40` — Brevo `SMTP_USER=b5c1fd001@smtp-brevo.com` + `SMTP_PASS=xsmtpsib-...`, `EMAIL_FROM=nayan.jaiswal.dev@gmail.com`
- `backend/.env:56` — `MINIO_SECRET_KEY=mindforge-dev-secret-2024` (mirrored root `.env:11`)
- `backend/.env:84` — `LLM_API_KEY=AIzaSyCoZ_0aD-...` (gemini-3.1-flash-lite)
- `backend/.env:68` — absolute `KUBECONFIG=C:\Users\jaisw\.kube\config-mindforge-local` + WSL IP comment
- `.env:8,14,21,26` — `POSTGRES_PASSWORD=mindforge_dev_password` + duplicated Neon/Upstash URLs + JWT secret
- `frontend/.env.local:6,8` — prod `BACKEND_URL/NEXT_PUBLIC_API_URL=https://mindforge-backend-m7uz.onrender.com` (drift vs `.env.development.local:6-7` localhost:8080)
- `frontend/.env.local:24` — live `VERCEL_OIDC_TOKEN="eyJhbG..."` RS256 JWT
- `frontend/.env.local:12,14,18` — hardcoded ports/origins (`:9000`, `ws://localhost:18081/ws`, `:3002`)

### B-HIGH — Hardcoded values in source
- `frontend/lib/constants.ts:11` — `NOW_FEATURE_ALLOWED_EMAIL = "jaiswal2062@gmail.com"` (access gate, dup `backend/.env:42`)
- `frontend/hooks/use-lab-terminal.ts:125`, `frontend/hooks/use-lab-preview.ts:33` — fallback `"ws://localhost:8081"` (stale vs `:18081/ws`)
- `frontend/app/layout.tsx:71` — fallback `'http://localhost:3000'` (vs `:3002`)
- `backend/internal/config/config.go:287,295-296,301-302,305` — `PORT 8080`, `FRONTEND_URL http://localhost:3000`, `BACKEND_URL http://localhost:8080`, `SMTP_HOST localhost`, `SMTP_PORT 1025`, `EMAIL_FROM noreply@mindforge.dev`
- `backend/internal/config/config.go:347,378,381,392` — `PASSWORD_BREACH_API_URL https://api.pwnedpasswords.com/range/`, `MINIO_ENDPOINT localhost:9000`, `MINIO_BUCKET mindforge`, `LLM_MODEL claude-sonnet-4-6`
- `backend/internal/config/config.go:359-360` — CIDRs `127.0.0.0/8 ::1/128 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16`
- `backend/internal/mailer/brevo.go:17` — `const brevoAPIURL = "https://api.brevo.com/v3/smtp/email"`
- `backend/internal/ai/anthropic.go:12`, `backend/internal/ai/gemini.go:13` — `https://api.anthropic.com/v1/messages`, `https://generativelanguage.googleapis.com/v1beta/openai`
- `backend/internal/orgs/types.go:81` — `"gmail.com","outlook.com","yahoo.com","hotmail.com"`
- `docker-compose.dev.yml:173` — `LABPROXY_PREVIEW_DOMAIN: localhost`

### B-MEDIUM — Banned-pattern / hygiene
- `backend/internal/api/router.go:177` — `panic(fmt.Errorf("api: secrets vault init failed: %w", err))` → use `slog.Error` + `os.Exit(1)`
- `backend/internal/jobs/registry.go:36,55,72` — `panic(...)` handler already registered / dead hook / no handler (startup-only, flagged)
- `backend/internal/gitlab/repo_connection.go:639` — `// TODO: populate UpdatedAt...`
- `backend/internal/contentpipeline/importer/importer.go:6,275,282,290,293` — TODO emitter
- `backend/internal/auth/email.go:19,34`, `backend/internal/jobs/handlers/batch_import.go:175`, `invite.go:163` — `slog.Info("DEV EMAIL: ... token", "token", token)` gated but logs secrets
- `backend/internal/config/config.go:351-354,401-419` — magic numbers centralized but hardcoded (`10`, `15m/720h/24h/30m/3s/1m/30s/8m/10m`, `0.30/2.50/0.50/50.00`, `20/3/10/30/60`)

### B-CLEAN (verified, no action)
- `sync.Map`: zero hits — `jobs/registry.go:19` uses `sync.RWMutex+map` correctly.
- `secret := "change_me"` in Go: none — `requireSecret()` + `change_me` rejection, `labproxy/main.go:19-23` fatals if unset.
- `if isDev skip auth`: none — `IsProd()` fails closed, stub provider prod-gated, SMTP localhost fatals in prod.
- `panic("not implemented")` / `return nil // TODO`: none in prod (remaining TODOs are lesson starter-code/fixtures).

---

## PART C — Repeated CSS / Design-System Violations

Tokens: `bg-background/card/muted/popover`, `text-foreground/muted-foreground/primary/ai/success/destructive`, `border-border/input/ring`, `rounded sm/md/lg/xl/pill`, `shadow-card/raised/modal/float`, `duration-fast(120)/normal(200)/slow(350)+ease-smooth`, `z-raised(10)/sticky(200)/overlay(300)/modal(400)/dropdown(450)/toast(500)`, layout `.page-container/.page-header/.card-base/.card-raised/.card-grid/.grid-responsive*/.grid-stats/.flex-center/.flex-between/.empty-state/.skeleton/.modal-responsive/.table-responsive`.

### C1. CRITICAL: raw Tailwind colors + `dark:` — `frontend/components/courses/block-editor/text-blocks.tsx:66-69`
```
info:    "border-blue-500/40 bg-blue-500/10 text-blue-700 dark:text-blue-300",
warning: "border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-300",
tip:     "border-green-500/40 bg-green-500/10 text-green-700 dark:text-green-300",
danger:  "border-red-500/40 bg-red-500/10 text-red-700 dark:text-red-300",
```
Fix: use `globals.css:592-599` `.prose-content .callout-info/warning/tip/danger`.

### C2a. Parallel palette — `frontend/components/gitlab-planning/planning.css:12-59,82-87` (largest)
~50 hex vars (`--ae-bg:#f8fafd`, `--ae-brand:#2563eb`, `--m-primary:#004ac6`, tone rows blue/amber/emerald/purple/rose/slate 9 shades each) consumed in 100+ `bg-(--*)/text-(--*)/border-(--*)`:
- `.../issue-row.tsx:35,58,90,92,95,111,118`
- `.../step-card.tsx:54-56,61,64,73,84,109,115,117,134`
- `.../issues-toolbar.tsx:14,30-31,45,53,69,77,83,100,102,105`
- `.../issue-drawer.tsx:54,64-65,88,94,125,150,172-173,183,193,211,220,224,228`
- `frontend/app/(standalone)/gitlab/issues/page.tsx:32`
+ `planning.css:140` `rgb(33 49 69 / 0.4)`, `:73-76` scrollbar dup `globals.css:407-417`, `:129-135` typography dup, `:104-121` `.ae-md` dup `.prose-content`.
Fix: map to `bg-card/text-foreground/border-border`, `badge-info/.difficulty-*`, `.ai-surface`.

### C2b. `frontend/app/(standalone)/now/whatnow.css:5-49` + raw `<button>`
New font stacks (`--wn-serif/sans/mono` vs only `--font-plus-jakarta` + `--font-jetbrains-mono`), raw buttons: `components/whatnow/focus-overlay.tsx:112-114,135-136,146,151,167,170,178`, `now-stage.tsx:61,70`, `capture-sheet.tsx:60`, `shelf.tsx:121`, `whatnow-app.tsx:94`
Fix: `components/ui/button.tsx` (`cva`), `dialog.tsx` + `.modal-responsive`.

### C2c. `frontend/components/focus-wall/focus-wall.module.css:14-22,28,37,111,128,141-142,152,161`
`--brass:#c9a24e`, `--brass-bright:#e8cc86`, `--kraft:#ede1c7`, radial `#241a10/#15110d`, 6x `rgba(0,0,0,0.45)` shadows.
Fix: `--note-yellow/blue/pink/green` → `bg-note-*`, shadows → `var(--shadow-*)`, brass → `bg-primary`.

### C2d. Other scoped hex
- `frontend/components/assessments/coding-question.module.css:6,13-14,24,29,31-32,46,50,59,63,67-68,72` — `#1e1e1e/#6e7681/#2d2d2d/#d4d4d4/#264f78` → `bg-terminal/...`
- `frontend/components/diary/diary-theme.css:90` `2px`, `frontend/components/habits/journal-theme.css:81` `4px` → `rounded-sm/md/lg`
- `frontend/lib/design-library.ts:11-19` `"#1971c2"/"#2f9e44"/"#e8590c"` — data-only OK, map to `--habit-*` if rendered.

### C3. Arbitrary values
- `text-[10px]` 30+ hits: `.../step-card.tsx:74,98,109,113,145,147`, `issue-row.tsx:58`, `task-detail-panel.tsx:38`, `quadrant-card.tsx:30`, `algo-visualizer/array-chart.tsx:86,128`, `code-view.tsx:42`, `live-preview-panel.tsx:72`, `habits/sleep-quality-chart.tsx:54,58`, `reading-progress-card.tsx:35,39`, `gym-performance-card.tsx:35,39,47`, `profile/difficulty-solved-chart.tsx:72`, `daily-habit-wheel.tsx:279,450` → `text-xs`
- `text-[11px]` 25+ hits: `step-card.tsx:69,84,108,162`, `issue-row.tsx:86`, `markdown-split-editor.tsx:73,102,118,132`, `issue-drawer.tsx:64,90,102`, `task-detail-panel.tsx:83`, `change-log-card.tsx:22`, `live-preview-panel.tsx:66`, `quadrant-card.tsx:26,46` → `text-xs`
- `text-[11.5px]` `markdown-split-editor.tsx:132`, `text-[8px]` `daily-habit-wheel.tsx:279`, `text-[9px]` `habit-grid.tsx:61`
- Layout arbitrary: `min-h-[280px]` `transcript-input.tsx:125`, `min-h-[400px]x3` `diary-editor.tsx:269,280 + diary-fix-english-review.tsx:108 + diary-analyze-review.tsx:147`, `min-h-[480px]` `course-wizard.tsx:280`, `min-h-[500px]` `wizard/content-tab.tsx:35`, `min-h-[520px]/lg:min-h-[640px]` `coding-item-panel.tsx:43`, `h-[70vh]` `plan-timeline.tsx:125`, `h-[220px]` `sleep-quality-chart.tsx:11`, `min-h-[60vh]` `app/not-found.tsx:7 + app/error.tsx:17`
- `max-w-[85%]` x3: `courses/design-chat-panel.tsx:53,67` + `tickets/ticket-thread.tsx:31` → utility
- `max-w-[85vw]` drawer x3 verbatim: `wiki/wiki-sidebar-drawer.tsx:54`, `courses/course-sidebar-drawer.tsx:65`, `journal/journal-topics-drawer.tsx:43` → `.sidebar-drawer-right` in `globals.css`

### C4. Repeated strings with existing utilities
- `flex items-center gap-2` 100+ hits (keep inline); `flex items-center justify-between*` 100+ hits → `.flex-between` (e.g. `calendar/event-panel.tsx:463,490,516`, `issue-drawer.tsx:62,165,219`, `course-wizard.tsx:330`)
- `rounded-lg border border-border` 75 hits → `.card-base/.card-raised/.ai-surface` (e.g. `code-view.tsx:36`, `lesson-mcq-question.tsx:48,60`, `wizard/settings-tab.tsx:36,53,71,94`, `proctor-preflight.tsx:155,160,165,188,193,198`, `coding-item-panel.tsx:43`)
- `rounded-xl border border-border bg-card p-6` 20+ hits → `.card-raised` (e.g. `mentor-*.tsx:21,20,38,36,73`, `habits/*-card.tsx`, `sessions/[sessionId]/page.tsx:46,100`, `test-runner.tsx:252,303,344,386,629`)
- `text-xs font-semibold uppercase tracking-widest text-muted-foreground` 18 hits → `.section-label` (e.g. `sleep-quality-chart.tsx:27,45,54,58`, `sidebar-nav-content.tsx:39`)
- `bg-muted/40|/50` 48 hits → extract `.upload-dropzone` (e.g. `code-view.tsx:37`, `file-blocks.tsx:46,126`, `resume-upload.tsx:49`)
- `grid grid-cols-2 gap-4` → `.grid-stats`; `page-container + py-*` 14 hits → drop `py-*` (e.g. `test-runner.tsx:444`, `legal/terms/page.tsx:16`, `org/setup/page.tsx:109`)

### C5. Inline `style={{}}` — 76 hits
Violations:
- `app/demo/tour/demo-shell.tsx:31,85` `zIndex:"var(--z-sticky)"` redundant with `z-sticky` → drop style
- `components/batches/batch-avatar.tsx:99` dynamic `hsl()` — document contrast
- `app/(app)/assessments/[id]/results/page.tsx:195,200` `height:"80px"/${barPct}%`, `demo-shell learner-view.tsx:65` `height:"6px"` → `h-20/h-1.5/.progress-track`
- `course-sidebar-rail.tsx:49` `width`, `lesson-code-runner.tsx:169` `outputHeight`, `shared/code-editor.tsx:89,100` `height` → responsive `w-full sm:w-[Npx]` or CSS var
- `daily-habit-wheel.tsx:262,284,309,347,379,392,444` `animationDelay` x7 → `prefers-reduced-motion` guard
- `journal-toolbar.tsx:212`, `array-chart.tsx:80`, `course-progress-bar.tsx:45`, `issue-row.tsx:92`, `issue-steps.tsx:40`, `step-card.tsx:117` → `.progress-track/.progress-fill-ai` + `duration-slow ease-smooth`

### C6. Missing shadcn reuse
- Raw `<button>` → `Button ghost/icon/link`: `wiki-tree-node.tsx:99,104,108`, `block-editor/index.tsx:76,80,84`, `course-docs-toggle.tsx:46`, `gitlab-planning/*` ~20 (`issues-toolbar.tsx:37,45,93,108,119,131,139`, `issue-drawer.tsx:74,80,188,193,220,224,228`), `whatnow/*`
- Raw `<select>` `issues-toolbar.tsx:127`, `<textarea>` `issue-drawer.tsx:184`, `<input checkbox>` `issue-steps.tsx:48` → `ui/select/textarea/checkbox`
- `<table>` without `ResponsiveTable`: `platform/features/page.tsx:63`, `org/settings/jobs/page.tsx:80`, `admin/rbac/roles/role-table.tsx:137`

### C7. Radius/shadow/motion/z/focus
- `rounded-2xl` on cards → `rounded-lg/.card-base` or `rounded-xl/.card-raised`: `test-runner.tsx:252,303,344,386,629,674`, `ai-assistant-card.tsx:10`, `change-log-card.tsx:16`, etc.
- `shadow-sm/md/lg/xl` → `shadow-card/raised/modal/float`: `ui/input.tsx:12`, `ui/tag-input.tsx:51`, `multi-select-dropdown.tsx:63,74`, `coding-question.tsx:202`, `issue-row.tsx:35`, etc.
- `duration-300/500/700 + ease-out` → `duration-fast/normal/slow + ease-smooth`: `xp-progress-bar.tsx:48,70`, `leaderboard-table.tsx:71`, `step-card.tsx:117`, `ui/sheet.tsx:55`, `sticky-note.tsx:108`
- `z-10` → `z-raised/sticky`: `calendar/week-view.tsx:82,103`, `journal-timeline.tsx:84`, `habit-view-switch.tsx:32,42`
- `focus-visible:ring-0/focus:ring-0/focus:outline-none` → restore `ring-ring`: `text-blocks.tsx:16,45,85,95`, `structure-tab.tsx:140`, `journal-toolbar.tsx:260`, etc. (exception: `.diary-write-area`)

### C8. Forms — 30+ files import Form* verbatim
e.g. `projects/create-assignment-form.tsx:13,127,179,192`, `assessments/create-assessment-form.tsx:12`, `batches/create-batch-form.tsx:10`
Fix: `<FormInputField/>` + typed primitives (`form-select-field/checkbox/textarea/switch/slider`).

---

## Recommended Fix Order
1. Rotate live secrets (Neon, Upstash, Google, Brevo, Gemini, OIDC) + vault + `change_me` guard already in `deploy-*.sh` — keep.
2. Backend `httputil.DecodeJSON`, `Query*`, `cursor`, `validate/schedule`, `HandlerLLM` import, `WriteDomainError` direct.
3. Frontend `baseURL()`, `apiAction/apiGet/apiUpload`, `apiGetPublic`, `authFetchWithCookies`, `apiFetch`.
4. CSS: `text-blocks.tsx` colors → callouts, `planning.css` → tokens, drawer `max-w-[85vw]` → `.sidebar-drawer-right`, `flex-between/card-base/card-raised/section-label`, shadcn Button/Select/Textarea/Checkbox, radius/shadow/motion/z.
