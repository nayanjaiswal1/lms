# Sheet Tracker — Phase 1 Build Notes

> Session record for the first implementation pass of the Sheet Tracker feature (2026-07-04). The full feature spec lives in [docs/sheets.md](sheets.md); this file documents what was actually built in Phase 1, the bugs found along the way, and what's still open. Scope was deliberately narrowed by the user mid-build — see "Scope decision" below.

---

## Scope decision

The full `docs/sheets.md` spec covers import/export, LeetCode profile sync, combine/fork, and revision-reminder cron jobs. Partway through planning, the user cut this down to a minimal Phase 1:

1. Create your own sheet, **or** start tracking any existing (system) sheet
2. Track progress per problem: mark **solved**, **revisit** (revision), or back to **todo**
3. Click a problem to navigate straight to its external URL — no in-app solving surface

CSV/JSON import, LeetCode sync, export, combine/fork, cross-sheet search builder, and the revision-reminder cron were explicitly descoped for later.

An earlier, broader plan was drafted and briefly sent to a remote Ultraplan cloud session for refinement; that session failed (`error_during_execution`) before returning anything, so the plan was revised locally to the reduced scope above and implementation proceeded from there.

---

## What was built

### Backend — `backend/internal/sheets/`

New package mirroring the existing `srs`/`practice` package shape (`models.go`, `repo.go`, `service.go`, `handler.go`, `routes.go`).

**Migrations:**
- `028_sheets.sql` — `sheets`, `sheet_items`, `user_sheets`, `user_problem_progress` tables. Trimmed from the full spec: no `forked_from_id`, `source_sheet_ids`, `subscriber_count`, or `visibility` tiers — those return when fork/combine/browse-by-popularity are actually built.
- `029_seed_sheets.sql` — seeds the four system sheets (`is_system = true`) with real, accurate LeetCode-linked problems:

  | Sheet | Items seeded |
  |---|---|
  | Blind 75 | 75 (full canonical list) |
  | NeetCode 150 | 145 |
  | Grind 169 | 70 (accurate subset) |
  | Striver's A2Z | 95 (accurate subset) |

  Striver's A2Z (~450 items) and Grind 169 (169 items) weren't hand-authored to full count — fabricating hundreds of unverified LeetCode URLs was judged worse than shipping an accurate partial list. Documented in the migration header as the real long-term fix: extend via more `sheet_items` rows later.

**API surface (this phase only):**
```
GET    /api/sheets/public              browse system sheets to "start with"
GET    /api/sheets/:slug               sheet detail
GET    /api/sheets/:slug/items         items + this user's progress
POST   /api/sheets                     create + auto-own
POST   /api/sheets/:id/items           add item (owner only)
PATCH  /api/sheets/:id/items/:itemId   edit item (owner only)
DELETE /api/sheets/:id/items/:itemId   (owner only)
GET    /api/user/sheets                my sheets (owned + subscribed), for tabs
POST   /api/sheets/:id/subscribe       start tracking a system sheet
DELETE /api/sheets/:id/subscribe       stop tracking
PATCH  /api/progress/:topic_tag        body {status: todo|done|revisit}
```

Progress is keyed by `topic_tag`, not `sheet_item_id` — marking a problem done on one sheet marks it done everywhere else the same `topic_tag` appears, per the cross-sheet design in `docs/sheets.md`.

Status transitions (`repo.UpsertProgress`):
- `todo → done`: `solved_at = now()`, `revision_at = now() + 7 days`
- `done → revisit`: `solved_at` unchanged, `revision_at = now()`
- `→ todo`: both cleared

Wired into `backend/internal/api/router.go` (mounted in the existing authenticated group, same as `srs`/`practice` — no extra permission middleware, matching sibling packages) and `backend/tygo.yaml` (Go→TS type generation entry added, though hand-authored types were used in practice — see below).

### Frontend

- `app/(app)/sheets/page.tsx` — server component. Reads `sheet`/`modal`/`group` search params, fetches user's sheets + public sheets + active sheet's items in parallel, renders the empty state or the tab/table view.
- `lib/server/sheets.ts` — read-only data fetchers (`getPublicSheets`, `getUserSheets`, `getSheetItems`) using `apiGet`, following the `lib/server/srs.ts` precedent. All shared types (`Sheet`, `SheetItem`, `UserSheetSummary`, etc.) live here too — see the boundaries-lint note below for why.
- `lib/sheets/actions.ts` — `"use server"` mutations (`createSheetAction`, `addSheetItemAction`, `subscribeSheetAction`, `updateProgressAction`, etc.) using `apiAction`.
- `components/sheets/`:
  - `sheet-tabs.tsx` — server-rendered `<Link>`-based tab bar, no client JS
  - `sheets-toolbar.tsx` — "Start a sheet" / "Create sheet" buttons, also plain Links opening `?modal=`
  - `sheet-table.tsx` + `sheet-table-row.tsx` — the problem list; each row's status circle cycles `todo → done → revisit → todo`
  - `browse-sheets-dialog.tsx`, `create-sheet-dialog.tsx`, `add-item-dialog.tsx` — the three modals
  - `group-toggle.tsx` — None / Topic / Difficulty, added after initial ship (see below)
  - `sheet-item-groups.tsx` — accordion wrapper for grouped views, added after initial ship
- `components/ui/accordion.tsx` — new shadcn/Radix primitive; `@radix-ui/react-accordion` was already a dependency but unused until now.

### Added after initial ship, same session

1. **Group by Topic / Difficulty toggle** — `group-toggle.tsx` (URL-state pill toggle) + grouping logic in `sheet-table.tsx`. Difficulty grouping order is Easy → Medium → Hard → Unspecified; Topic grouping preserves first-seen category order.
2. **Collapsible groups (accordion)** — `sheet-item-groups.tsx` wraps each group in an `AccordionItem` with **Expand all / Collapse all** controls. Caught and fixed a layout bug here: the group label and its `(count)` badge were separate flex children fighting the trigger's `justify-between`, pushing the count off to the far right disconnected from the label. Fixed by wrapping both in one `<span>`.

---

## Bugs found and fixed

Four of five reports came in as "styling is broken" or "not persisting" — none were actually styling or data-loss bugs.

### 1. `requireAccess()` 404'd the page for every user — fixed before first real test
Initially added `await requireAccess(FEATURES.SHEET_TRACKER)` to `page.tsx`, following the documented frontend convention in `frontend/CLAUDE.md`. Live testing showed the page always rendered the loading skeleton and never resolved. Root cause: `requireAccess()` depends on `GET /api/me/features`, which doesn't exist anywhere in this backend (confirmed via `grep`, and via repeated `404` responses in the backend logs). Confirmed no other page in the codebase actually calls `requireAccess()` — it's aspirational documentation without a backing endpoint. **Fix:** removed the call; auth is still enforced by the existing Go `RequireAuth` middleware.

### 2. Session expiry crashed `/sheets` instead of silently refreshing
**Reported as:** "style is fucked" (screenshot of the generic `error.tsx` crash screen).
**Actual error:** `Error: Invalid or expired session` thrown from `apiGet` in `lib/server/api.ts:40`.
**Root cause:** `frontend/middleware.ts` has a working silent-token-refresh mechanism — on an expired access token, it calls `/api/auth/refresh` with the refresh token cookie before the page even renders. It only runs for routes listed in `PROTECTED_PREFIXES`, and `/sheets` was never added (every other real route — `/dashboard`, `/courses`, `/assessments`, etc. — already had it).
**Fix:** added `"/sheets"` to `PROTECTED_PREFIXES` — one line.
**Verified:** the exact URL that crashed before now renders correctly on token expiry.

### 3. Subscribing/creating a sheet looked like it didn't persist
**Reported as:** "why this is not persisting."
**Actually:** data was written correctly every time — confirmed directly via `psql` against the running dev database, both before and after the reported issue.
**Root cause:** `browse-sheets-dialog.tsx` and `create-sheet-dialog.tsx` closed on success via `router.back()`, which returns to whatever page was in browser history before the dialog opened — combined with Next.js's client-side router cache, this could land on a stale view that didn't obviously reflect the new sheet, making a successful write look like it silently failed.
**Fix:** both dialogs now call `router.push(`${ROUTES.SHEETS}?sheet=${slug}`)` on success instead of `close()`, using the slug returned in the action's response — the new sheet becomes the visibly active tab immediately.
**Verified live:** clicking "Start tracking" on NeetCode 150 now closes the dialog and switches to the NeetCode 150 tab with its problems listed, in one motion.

### 4. Three dialogs missing the required mobile-responsive class
**Reported as:** "Start a sheet modal overlapping" (screenshot showed the header's "Create sheet" button clipped at the window edge, and a request to check the dialog itself).
**Root cause found:** `browse-sheets-dialog.tsx`, `create-sheet-dialog.tsx`, and `add-item-dialog.tsx` all used a bare `<DialogContent>` with no className. Every other dialog in the codebase (mentor reports, feedback prompts, etc.) uses `className="modal-responsive"`, required per `frontend/CLAUDE.md`: *"Never set a fixed max-width on a modal without a mobile fallback."* Without it, the dialog has no height constraint at all on narrow/short viewports.
**Fix:** added `modal-responsive` to all three. Confirmed via the live DOM that it resolves correctly (`w-full h-dvh rounded-none` on mobile, `sm:h-auto sm:max-w-lg sm:rounded-2xl` on desktop) — matches the exact utility already used successfully by ~5 other dialogs.

### 5. Header toolbar button clipping — **open, not reproduced**
**Reported as:** a screenshot showing the "Create sheet" button in the page header cut off at the right edge of the window.
**Investigated:**
- `.page-header` CSS (`globals.css:329`) is `flex items-center justify-between py-6 gap-4 flex-wrap` — unchanged, identical to every other page's header.
- Simulated the header's container at widths from 900px down to 1300–1360px (matching the screenshot's apparent size) by directly constraining `main.page-container`'s width via injected JS and measuring `getBoundingClientRect()` on the "Create sheet" button. At every tested width, the toolbar either wrapped cleanly below the title or fit with zero overflow — never reproduced clipping.
- The browser automation `resize_window` tool turned out to be a no-op in this environment — `window.innerWidth` never actually changed despite the tool reporting success — so a **true** resized viewport (which would also collapse the sidebar, unlike the container-width simulation) couldn't be tested.
**Status:** waiting on the user's actual window width or browser zoom level to reproduce precisely rather than patch speculatively.

---

## Verification performed

| Check | Method | Result |
|---|---|---|
| Go build / vet | Ran inside the live `mindforge_backend_dev` Docker container (bind-mounted source, hot-restarted) | Clean |
| Migrations 028 / 029 | Restarted backend, watched real Postgres apply them on boot | Applied, `migrations up to date` |
| Seed accuracy | Queried `sheet_items` counts per sheet directly | 75 / 70 / 145 / 95 as designed |
| Full API flow | `curl`: login → browse → subscribe → mark done → verify `revision_at` → create sheet → add item | All passed |
| Ownership enforcement | Attempted to add an item to a sheet not owned by the test user | Correctly returned `403` |
| TypeScript | `npm run type-check` (`tsc --noEmit`) | Clean throughout |
| ESLint (strict) | `eslint --max-warnings 0` on all touched files | Clean (only a pre-existing, unrelated boundaries-plugin config warning) |
| Live UI | Chrome browser automation: logged in as `student@mindforge.dev`, subscribed to sheets, cycled problem status, grouped by Topic/Difficulty, expanded/collapsed accordion sections | All confirmed working as intended |

One boundaries-lint violation was caught and fixed during this work: `lib/server/sheets.ts` (classified `shared-lib`) originally imported types from a separate `lib/sheets/types.ts` (classified `feature-lib`), which `eslint-plugin-boundaries` correctly flagged as a disallowed dependency direction. Fixed by moving all type definitions directly into `lib/server/sheets.ts` (matching the existing `lib/server/srs.ts` pattern) and deleting the separate types file.

---

## Descoped for later

Still fully specified in [docs/sheets.md](sheets.md), not built in Phase 1:

- CSV/JSON import of a custom sheet
- LeetCode profile progress sync (constrained to aggregate solved-counts + last ~20 recent AC's — LeetCode has no public API for a stranger's full solved history)
- Progress export (JSON/CSV)
- Combine and fork
- Cross-sheet search builder for assembling a custom sheet from the full problem catalogue
- Revision-reminder cron job (1d/3d/7d configurable cadence, reusing the existing `jobs`/email pipeline pattern from `internal/jobs/handlers/srs.go`)
