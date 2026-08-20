# Animation / loading-state audit — tracking doc

Working doc for the "sidebar click lag" investigation and the broader animation
audit that followed. Not committed to git by default — delete once the work
below is finished, or keep as a reference. Re-derive nothing from memory when
resuming this: read this file first.

## Background (why this exists)

Original report: clicking a sidebar item felt stuck for a few seconds,
system felt slow. Root causes found and fixed:

1. `proxy.ts` (renamed from `middleware.ts`, Next.js 16 deprecated `middleware`)
   was paying a double round-trip on every navigation after the 15-min access
   token expired — refresh call, then a hard redirect back to the same page.
   Fixed: `request.cookies.set()` + `NextResponse.next({ request })` instead
   of redirecting. Also excluded `manifest.webmanifest` from the auth gate,
   added a 5s timeout to the refresh fetch. **Committed** (`43be615`).
2. `HandleRefresh` in `backend/internal/auth/handler.go` made 6 sequential DB
   round trips per refresh call. Collapsed to 1 via CTEs. **Committed** (same
   commit as above).
3. Even with #1 fixed, most routes gave zero visual feedback on click because
   most `app/(app)/**` routes had no `loading.tsx`, and Next's `startTransition`
   keeps the old page painted with no indicator otherwise. This spawned the
   broader animation audit below.

## Animation audit findings (from a research-only fork pass)

1. **`DropdownMenuContent`/`DropdownMenuSubContent`/`SelectContent` had zero
   enter/exit animation** while `PopoverContent`/`DialogContent` already had
   the fade+zoom pattern. **DONE** — same `data-[state=open]:animate-in
   data-[state=closed]:animate-out data-[state=closed]:fade-out-0
   data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95
   data-[state=open]:zoom-in-95` classes copied into all three.
2. **26 of 35 route folders under `app/(app)/` had no `loading.tsx`** — the
   actual root-cause fix per Next's own `useLinkStatus` docs (route-level
   `loading.js` is primary; hint dots are the secondary patch). **IN
   PROGRESS** — see checklist below.
3. **framer-motion animations ignored `prefers-reduced-motion`** outside the
   landing page (`MotionConfig reducedMotion="user"` only wrapped the landing
   page; `nav-link-hint.tsx`, journal components were not covered — CSS
   `@media (prefers-reduced-motion: reduce)` only affects CSS animations, not
   framer-motion's JS-driven `animate` prop). **DONE** — added
   `components/shared/app-motion-config.tsx`, wraps `{children}` in root
   `app/layout.tsx`. (Landing page's own `LandingMotionConfig` wrap is now
   redundant but harmless — left alone, not cleaned up.)
4. **`AnimatePresence` used in exactly one file** (`journal-entry-card.tsx`)
   — list add/remove elsewhere likely pops in/out with no exit transition.
   **NOT STARTED** — lower confidence, flagged as a follow-up, not blocking.

Also shipped earlier in this session, same thread: `components/layout/
nav-link-hint.tsx` — a small always-mounted framer-motion pulse dot wired into
all 4 nav surfaces (`sidebar-nav-content.tsx`, `mobile-nav.tsx` bottom bar,
`platform-sidebar.tsx`, `platform-mobile-nav.tsx`), grounded in Next's
`useLinkStatus` docs (fixed-size, opacity-only, 100ms delay) and Emil
Kowalski's animation-timing standards (pulse over spinner, ease-out exit).
**Committed** (`81b2e0d`). Not yet redeployed to Vercel after that commit.

**Explicitly ruled out:** a "library to avoid writing 26 files" — evaluated
`react-loading-skeleton` (just a styled placeholder primitive, doesn't reduce
the actual shape-authoring work) and `boneyard-js` (auto-generates skeletons
from real rendered DOM, but requires a live dev server + authenticated
real-data pages to snapshot — not available in this sandbox — **and** its API
is built for client-side `isLoading` state, which conflicts with this
codebase's server-Suspense-only convention, `frontend/CLAUDE.md`: "no
`isLoading` booleans, no spinners"). Hand-authoring per `frontend/CLAUDE.md`'s
existing rule ("hand-authored per route in `loading.tsx`, no auto-skeleton
tooling") is correct here, not a fallback.

## House style for each `loading.tsx`

- `import { Skeleton } from "@/components/ui/skeleton"`
- Match the real page's actual shape (table → row skeletons in
  `.table-responsive`; card grid → `.card-grid`/`.card-grid-2`/`.card-grid-4`
  of `<Skeleton>` blocks; stats → `.grid-stats`; form → `.form-stack`; detail
  page → header block + relevant sections) — read the real `page.tsx` first,
  don't reuse a generic 3-card skeleton everywhere.
- Reuse existing utility classes from `app/globals.css` `@layer components`
  (`.page-container(-sm)`, `.page-header`, `.card-grid*`, `.stack-*`,
  `.table-responsive`, `.grid-stats`, `.form-stack`) — don't invent new ones.
- If a client component already renders its own internal loading state (e.g.
  `admin/rbac/roles/[id]/page.tsx`), copy that exact skeleton into
  `loading.tsx` so there's no visual jump between the two.
- Full-viewport workspace pages (e.g. lab sessions) get a plain full-height
  block, not a fake mimic of an internal pane layout that can vary.

## Checklist — original 26 flagged top-level folders

Reconciled against what actually has a direct `page.tsx` (some are pure
containers with only nested routes — skipped at the top level, handled via
their children below).

- [x] billing
- [x] calendar
- [x] cohort-groups
- [x] courses
- [x] dashboard
- [x] focus-wall
- [x] highlights
- [x] interview-exp
- [x] interview-prep
- [x] learn
- [x] mentoring
- [x] mentors
- [x] mistakes
- [x] plan
- [x] review
- [x] roadmap
- [x] support
- [x] teach
- [x] wiki
- admin — no direct `page.tsx`, handled via children below
- interview — no direct `page.tsx`, handled via children below
- labs — no direct `page.tsx`, handled via children below
- org — not under `app/(app)/`, it's `app/org/**` (separate tree, see below)
- practice — no direct `page.tsx`, handled via children below
- settings — no direct `page.tsx`, handled via children below
- u — no direct `page.tsx`, handled via children below

## Checklist — direct-child pages under the container folders

- [x] admin/content-reports
- [x] admin/coupons
- [x] admin/labs/usage
- [x] admin/labs/warm-pools
- [x] admin/rbac/audit
- [x] admin/rbac/permissions
- [x] admin/rbac/roles (done by an earlier interrupted background run)
- [x] admin/rbac/roles/[id]
- [x] interview/progress
- [x] interview/skills
- [x] labs/[labId]
- [x] labs/sessions/[sessionId]
- [x] labs/sessions/[sessionId]/result
- [x] practice/[sessionId]
- [ ] settings/integrations — not yet inspected
- [ ] settings/privacy — not yet inspected
- [ ] settings/profile — not yet inspected
- [ ] settings/security — not yet inspected
- [ ] u/[slug] — not yet inspected

## Checklist — `app/org/**` (separate route tree, not `app/(app)/org`)

None of these have been inspected yet. All currently missing `loading.tsx`:

- [ ] org (app/org/page.tsx — marketing/landing, public route per proxy.ts's
      `PUBLIC_EXACT_PATHS`, lower priority — double check whether a loading
      state even matters here before writing one)
- [ ] org/create
- [ ] org/setup
- [ ] org/settings (app/org/settings/page.tsx)
- [ ] org/settings/audit-log
- [ ] org/settings/authentication
- [ ] org/settings/domains
- [ ] org/settings/integrations
- [ ] org/settings/jobs
- [ ] org/settings/jobs/[id]
- [ ] org/settings/members

## After all loading.tsx files are done

1. `pnpm tsc --noEmit` from `frontend/` — must be clean.
2. `pnpm eslint --config eslint.config.mjs <every new file>` — don't run the
   full lint suite (has ~700 pre-existing unrelated warnings).
3. Commit (exclude `tsconfig.tsbuildinfo`, `.gitignore`, and definitely not
   `db neon creds.txt` / `key.txt` at the repo root — those are untracked
   secrets, never stage them).
4. Push, then redeploy frontend via `vercel --prod` (backend is untouched by
   this batch, no Render redeploy needed for this specific work).
5. Come back to audit item #4 (`AnimatePresence` list transitions) only if
   the user asks for it — it was flagged as non-blocking.

## Reusable fork prompt template (if resuming via a background agent again)

Three earlier attempts at delegating this to a background fork were killed
by the user before completion (once with zero files written, once again with
zero files written, once partway through writing — that partial run is
actually where the 19 originally-"done" files above came from). If asked to
delegate this again, brief the fork with: the exact remaining checklist items
above, the house-style rules above, and instruct it to write in small batches
(4-5 folders at a time: read pages, write loading.tsx, move on) so partial
progress survives an interruption rather than being lost.
