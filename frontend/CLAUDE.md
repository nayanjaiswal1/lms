# Frontend Rules (Non-Negotiable)

Deep rationale for non-obvious rules (z-index/Portal stacking, min-w-0 flex overflow, etc.) lives in [docs/frontend-gotchas.md](../docs/frontend-gotchas.md) — read it when a rule below doesn't make sense on its own, not by default.

## Design Skills

`/frontend-design` (aesthetic direction) and `/ui-ux-pro-max` (UX/accessibility/spacing/chart intelligence) are available. For `/ui-ux-pro-max`: ignore any color/typography/design-system suggestions it makes — use MindForge's existing tokens below instead. Use it only for UX patterns, accessibility, interaction timing, and chart selection. Query directly: `python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<query>" --design-system --stack nextjs`.

## Design Identity — Forge Palette

| Role | Light | Dark | Use for |
|---|---|---|---|
| `--primary` | amber-700 `#B45309` | amber-400 `#F59E0B` | Buttons, progress, CTAs, streaks, focus rings |
| `--ai` | cyan-700 `#0E7490` | cyan-400 `#22D3EE` | AI panels, hints, generated content, AI badges |

Amber = human actions. Cyan = AI. Never mix.

**Banned (ESLint `no-restricted-syntax` enforces):**
| Banned | Use instead |
|---|---|
| `text-amber-*`, `bg-amber-*` | `text-primary`, `bg-primary` |
| `text-cyan-*`, `bg-cyan-*` | `text-ai`, `bg-ai` |
| `text-gray-*`, `bg-zinc-*`, raw shades | `text-foreground`, `text-muted-foreground`, `bg-muted` |
| `bg-white`, `text-black` | `bg-background`, `text-foreground` |
| `bg-[#fff]`, `text-[#...]` | Add a CSS var to `globals.css` |
| `dark:*` | Never — `.dark` class + CSS vars handle it |
| `style={{ color: '...' }}` | CSS variable; inline style only for dynamic `--var` values |

Disabling any of these needs a written inline reason.

- Card padding `p-6`; compact selectable tiles (checkbox/chip rows) `p-4`; inputs `px-3 py-2.5`; buttons `px-5 py-2.5`; page gutter `.page-container` (`px-6 sm:px-8 lg:px-12`)
- Radius: `--radius-sm` badges, `--radius-md` inputs, `--radius-lg` cards, `--radius-xl` feature cards
- AI content: `.ai-surface` panel, `.ai-badge` chip — never amber
- Contrast is pre-verified (≥4.5:1) for `--primary`, `--ai`, `--muted-foreground`, `--success` — re-check at webaim.org/resources/contrastchecker before changing any token value
- Motion: `duration-fast/normal/slow` (120/200/350ms), `ease-smooth` for hover, wrap in `prefers-reduced-motion`. No bounce/spring — `.card-interactive` lift only
- Z-index: named layers only, `z-raised`(10) < `z-sticky`(200) < `z-overlay`(300) < `z-modal`(400) < `z-dropdown`(450) < `z-toast`(500). Never `z-[N]`. Popper-based components (Select/Dropdown/Tooltip/ContextMenu) must out-rank `z-modal` — see gotchas doc for why

## PWA Manifest & App Shell

`app/manifest.ts` (name/icons/shortcuts/colors), `app/layout.tsx` (fonts/ThemeProvider/viewport/metadata). Theme color: light `#B45309`, dark `#F59E0B`, must match `--primary`.

Icons in `public/icons/`: `icon-192(-maskable).png`, `icon-512(-maskable).png`, `shortcuts/{dashboard,learn,practice,quiz}.png` (96×96), plus `apple-icon.png` (180×180) and `favicon.ico` in `app/`. Generate with `npx pwa-asset-generator` or maskable.app. Maskable icons: logo inside the 80% safe zone. Never change `manifest.ts` colors without syncing `globals.css` tokens.

## Responsiveness (Day 1, not a follow-up)

| Prefix | Viewport | Unlocks |
|---|---|---|
| *(none)* | 0–639px | Mobile baseline |
| `sm:` | ≥640px | 2-col grids |
| `md:` | ≥768px | Side-by-side form rows |
| `lg:` | ≥1024px | **Sidebar appears**, 3-col grids |
| `xl:` | ≥1280px | Max-width containers |

Mobile-first: write the unprefixed style first, layer `sm:`/`md:`/`lg:` on top. Mobile (`<lg`) = 1-col + bottom-nav, no sidebar. Desktop (`lg+`) = sidebar + 3-col grid, no bottom-nav. Shell utilities: `.app-shell` / `.app-sidebar` / `.app-main` / `.app-header` / `.app-content` / `.bottom-nav`.

**Rules:**
1. Mobile-first — `flex-col` before `sm:flex-row`, `hidden` before `lg:flex`
2. Touch targets ≥44×44px (WCAG 2.5.5) — use `.touch-target` or `size="default"`, not shadcn's default `sm` button
3. `h-dvh`/`min-h-dvh`, never `h-screen` (ESLint error) — `100vh` hides content behind mobile Safari chrome
4. `w-full`, never `w-screen` (ESLint error) — overflows on scrollbar devices
5. Every `<table>` wrapped in `.table-responsive` **and** every `<tr>` has `whitespace-nowrap` — the wrapper alone doesn't stop cell wrap/row-overlap; scope `whitespace-normal` to individual `<td>`s that must wrap
6. Modals: `.modal-responsive` on `<DialogContent>` — full-screen mobile, centered `sm+`
7. Safe-area insets for notched devices — `.bottom-nav`/`.app-header`/`.sidebar-drawer` handle it already; anything else fixed-bottom needs `padding-bottom: env(safe-area-inset-bottom)`
8. No bare `w-[Npx]` (ESLint warns) — always pair `w-full sm:w-[Npx]`
9. Sidebar on mobile = full drawer (`.sidebar-drawer` + `.sidebar-drawer-backdrop`), never a squished icon rail
10. Any grid/flex cell rendering a code/slug/UUID/email needs `min-w-0` on the item + `truncate` or `break-all` on the text, or it spills into the next cell — flex/grid items don't shrink below content width by default

**Defined utilities (reuse, don't reimplement):** `.app-shell` `.app-sidebar` `.app-main` `.app-header` `.app-content` `.sidebar-drawer(-backdrop)` `.bottom-nav(-item)` `.touch-target` `.table-responsive` `.stack-sm/md/lg` `.grid-responsive(-2/-4)` `.grid-stats` `.modal-responsive`

**Banned:** `h-screen`, `w-screen`, bare `w-[Npx]`, `overflow-x-hidden` on html/body, desktop-only styles, `<tr>` without `whitespace-nowrap`, hand-written breakpoint-chain grids duplicating `.grid-responsive*`.

Safe area classes: `.safe-top/-bottom/-left/-right`, `.safe-x/-y`, `.safe-inset`. `app/layout.tsx` sets `viewport.viewportFit = 'cover'` — never remove it.

Images: always `next/image` with `sizes`, never raw `<img>`.

## Linter

`pnpm lint:strict` for zero-warning CI (not `next lint`). Covers everything above plus: `fetch()` in `useEffect` banned, arbitrary Tailwind values flagged. Disabling a rule needs an inline `eslint-disable-next-line` comment with a reason.

## Theming

All tokens live in `app/globals.css` only (`:root` / `.dark`), wired via `next-themes` in `layout.tsx`. `dark:*` prefix and raw color classes (`bg-white`, `text-gray-500`, etc.) are banned in components — use semantic tokens. Fonts: `--font-plus-jakarta` (headings/UI), `--font-jetbrains-mono` (code/quiz options) — never `font-geist-*`. New color: add to `:root` + `.dark` + `@theme` block in `globals.css`, then reference by semantic class.

## Layout & Spacing (`globals.css` `@layer components`)

Reuse, don't reimplement: `.page-container(-sm)` `.page-header` `.page-title` `.section-title` `.card-base/-raised/-interactive` `.ai-surface` `.ai-badge` `.mastery-*` `.difficulty-*` `.progress-track/-fill` `.form-stack` `.card-grid` `.prose-content` `.empty-state` `.divider-label` `.kbd` `.skeleton`. Same multi-class string twice → promote to a named utility in `globals.css`.

## Typography

Base element styles (`h1`–`h4`, `p`, `a`, `code`, `body`) are set globally in `@layer base`. Never re-style them per component.

## Forms

- Extract repeated `FormField`+`FormItem`+`FormLabel`+`FormControl`+`FormMessage` into `<FormInputField />` (`components/ui/`) for text/email/password
- New control shape (select/checkbox/radio/date/file) → new typed primitive, don't overload `<FormInputField />`
- Don't turn a fixed API contract into a config-driven form just to cut JSX lines
- react-hook-form + zod always, no raw `useState` for fields. Schema above component: `const Schema = z.object({...})`, type via `z.infer`. Errors via `<FormMessage />`. Pending state via `useFormStatus()`

## Feature-Based Organization

`components/<feature>/`, `app/(app)/<feature>/`, `lib/<feature>/`. Promote to `components/shared/` only when an unrelated feature reuses it. Enforced by `eslint-plugin-boundaries` — cross-feature imports need an explicit allow-listed edge in `boundaries/dependencies` with a comment, not a workaround import.

## Shared Components (`components/shared/`)

| Component | File | Notes |
|---|---|---|
| `<CodeEditor>` | `code-editor.tsx` | Lazy Monaco (`next/dynamic`, ssr:false), `var(--font-jetbrains-mono)` |
| `<AccessGate>` | `access-gate.tsx` | Permission/feature gate |
| `<BrandMark>` | `brand-mark.tsx` | Logo |
| `<ThemeToggle>` | `theme-toggle.tsx` | Light/dark toggle |
| `<WithFeature>` | `with-feature.tsx` | Feature-flag HOC |

## Design System

- `components/ui/` (shadcn) primitives only — no raw `<input>`/`<button>`/`<select>`/`<textarea>`
- No style props — variants via `cva()`, callers pass `variant`/`size` not classes
- `cn()` from `lib/utils` for className merging, never string concat
- `globals.css` = tokens/base/cross-feature utilities only; component-specific CSS stays in the component or a colocated CSS module
- Extract a shared component before promoting styling to a global utility

## Component Constraints

Max 300 lines/file (split into sub-components/hooks). Max 2 `useState`/component (else a custom hook or URL params). No `useEffect` — server components, `use()`, SWR/React Query, or URL state instead. One component per file. Props interface above the component.

## `"use client"` Discipline

Only for browser APIs/handlers/hooks. Everything else is a Server Component. Keep client boundaries leaf-level — never a whole layout/page.

## TypeScript

No `any` (use `unknown` + narrow, or infer from zod). No `!` unless provably non-null. Named exports except Next.js pages/layouts.

## URL-Driven UI State

Search/filters/sort/page/open-modal live in the URL via `nuqs`, not `useSearchParams` or `useState`. Refresh must restore exact UI state.

## Data Fetching & Mutations

Fetch in Server Components, pass down as props. Loading/error via `<Suspense>` + `error.tsx`, shadcn `<Skeleton>` (hand-authored per route in `loading.tsx`, no auto-skeleton tooling) — no `isLoading` booleans, no spinners. Mutations via server actions only, named `<verb><Noun>Action`. Errors returned as state, never thrown. `useActionState` consumes results.

## Server-Side API Calls (`lib/server/api.ts`)

All server-side fetches go through these — never raw `fetch()` with manual auth headers:
- `apiGet<T>(path)` — server component reads, throws to `error.tsx`
- `apiPost<T>(path, payload)` — one-shot POSTs, throws
- `apiAction<T>(method, path, payload?, extraHeaders?)` — server actions, returns `ActionResult<T>`, never throws (`extraHeaders` for one-off headers like `Idempotency-Key`, don't add new positional params instead)
- `apiUpload<T>(path, formData)` — multipart uploads, returns `ActionResult<T>`, omits `Content-Type` so the browser sets the boundary

Client components calling the backend directly (not via server action) use `apiFetch<T>()` from `lib/client/api.ts` — don't redeclare it locally.

A raw `fetch()` with a hand-built `Cookie` header is ESLint-flagged (`no-restricted-syntax`, `Property[key.name="Cookie"]`). Genuine exceptions (pre-session bootstrap, `forwardSetCookies`, Edge middleware) need an inline `eslint-disable-next-line` with a reason — see `lib/server/api.ts`, `middleware.ts`, `app/login/actions.ts` for precedent.

`export type { ActionResult }` must never appear in a `"use server"` file — Next.js registers every export as a server reference at runtime, and a type-only export erases to a missing reference that crashes the page. Import `ActionResult` from `@/lib/server/api` directly instead.

```ts
// "use server" actions file:
export async function uploadAssetAction(formData: FormData): Promise<ActionResult<{ url: string; storage_key: string }>> {
  return apiUpload<{ url: string; storage_key: string }>("/api/upload", formData);
}
```

## Next.js Built-ins

`next/image` (no raw `<img>`), `next/link` (no raw `<a>` for internal routes), `next/font` (no Google Fonts `<link>`), `notFound()`, `redirect()` (no `router.push` in server components).

## Heavy Dependencies

Monaco, React Flow, TipTap, Recharts → `dynamic(() => import(...), { ssr: false })`. Never static-import at page level.

## Feedback

Sonner toast only — no `alert()`, no custom toast state.

## File & Import Conventions

`kebab-case.tsx` files, PascalCase components, `@/` alias always (no `../../relative`), no barrel `index.ts` re-exports, route paths as constants in `lib/routes.ts` (no hardcoded strings).

## Feature Flags & Subscription Gating

Every gated feature uses `<AccessGate>` from day 1. Two server-resolved axes: org toggle (admin on/off) and user entitlement (plan/add-on/seat) — exposed via `<FeatureFlagProvider>` and `useIsEntitled()` / `useIsOrgFeatureEnabled()` / `useLockedInfo()`.

| Situation | Mode | Result |
|---|---|---|
| Org ON, not entitled (default, prefer for discoverability) | `lock` | Blurred + lock icon + CTA from `lockedInfo` |
| Nav item user lacks | `badge` | Visible + "Add-on"/"Upgrade" badge |
| Must stay unknown | `hide` | Nothing rendered (rare) |
| Org OFF | N/A | Renders nothing automatically |

CTA text always from `lockedInfo.unlock_via` — never invented client-side.

**Always guard `page.tsx` server-side too** — UI gates are UX, not security: `await requireAccess(FEATURES.X)`, or `requireOrgFeature()`/`requireEntitlement()`.

`<AccessGate>` call-site rule: single-feature component → `withFeature(Base, FEATURES.X)` wrapper baked in once; nav/sidebar → config-driven (`feature`/`mode` on the nav-item object); whole page → server guard only, no internal gate; mixed page section → `<AccessGate>` inline (the one valid direct use).

**Banned:** `if (user.plan === 'pro')` comparisons in components, hardcoded plan/feature strings instead of `PLANS.*`/`FEATURES.*`, client-side lock CTA text, client-side feature-config fetching (root layout fetches once).

## Config & Server-Driven Options

No option list/dropdown/enum hardcoded in a component. Static lists → `lib/constants.ts`, imported everywhere. Per-org/user lists → fetched server-side, passed as props. Components take `options: {label, value}[]`, never define the array. One source of truth per option set.

## Accessibility

Semantic HTML (`<main>`/`<nav>`/`<header>`/`<section>`/`<article>`), `aria-label` on icon-only buttons, never override shadcn's focus ring or keyboard nav.
