# Frontend Rules (Non-Negotiable)

---

## Design Identity — MindForge Forge Palette

MindForge has two intentional expressions of one brand. Do not drift from this.

### Brand constants (same across both themes)
| Role | Light value | Dark value | Meaning |
|---|---|---|---|
| `--primary` | amber-700 `#B45309` | amber-400 `#F59E0B` | Fire, progress, CTAs, streaks |
| `--primary-foreground` | white | black | Text on amber surfaces |
| `--ai` | cyan-700 `#0E7490` | cyan-400 `#22D3EE` | AI-generated content, hints, suggestions |
| `--ai-foreground` | white | black | Text on cyan surfaces |

### What these tokens mean in the UI
- **Amber (`primary`, `ring`)** — primary buttons, progress bars, streak counters, focus rings, active nav indicators, score highlights
- **Cyan (`ai`, `ai-foreground`)** — AI explanation panels, generated curriculum cards, hint tooltips, "AI" badge chips, AI chat bubbles

### Banned class patterns in components
The **ESLint linter enforces all of these as errors** (`eslint.config.mjs` → `no-restricted-syntax`).
Do not disable the rules without a written explanation in the comment.

| Banned | Correct alternative |
|---|---|
| `text-amber-*`, `bg-amber-*` | `text-primary`, `bg-primary` |
| `text-cyan-*`, `bg-cyan-*` | `text-ai`, `bg-ai` |
| `text-gray-*`, `bg-zinc-*`, any raw shade | `text-foreground`, `text-muted-foreground`, `bg-muted` |
| `bg-white`, `text-black` | `bg-background`, `text-foreground` |
| `bg-[#fff]`, `text-[#1a2b3c]` | Add a CSS variable to `globals.css` |
| `dark:bg-*`, `dark:text-*` | Never — `.dark` class handles this via CSS vars |
| `style={{ color: '...' }}` | Add a CSS variable; inline style only for dynamic `--var` values |

### Spacing & shape
- Card padding: `p-6` (24px)
- Input padding: `px-3 py-2.5` (12px / 10px)
- Button padding: `px-5 py-2.5` (20px / 10px)
- Page gutter: `px-6 sm:px-8 lg:px-12` — use `.page-container`
- Radius: use `--radius-sm` (4px) for badges, `--radius-md` (8px) for inputs, `--radius-lg` (10px) for cards, `--radius-xl` (16px) for feature cards

### AI surface components
- Use `.ai-surface` for AI-generated content panels (cyan-tinted bg + border)
- Use `.ai-badge` for the "AI" chip label
- Never style AI content with amber — amber = human actions, cyan = AI

### WCAG 2.2 AA contrast — verified values
| Token | Light | Dark | Contrast on bg |
|---|---|---|---|
| `--primary` | amber-700 `#B45309` | amber-400 `#F59E0B` | Light: 4.80:1 ✓ |
| `--ai` | cyan-700 `#0E7490` | cyan-400 `#22D3EE` | Light: 5.13:1 ✓ |
| `--muted-foreground` | zinc-500 `#71717A` | zinc-400 | Light: 5.02:1 ✓ |
| `--success` | darkened green | amber-range | Verified ≥ 4.5:1 |

Never change these token values without re-checking contrast at [webaim.org/resources/contrastchecker](https://webaim.org/resources/contrastchecker/).

### Motion
- Use `duration-fast` (120ms), `duration-normal` (200ms), `duration-slow` (350ms) utility classes — defined in `@theme inline`
- Use `ease-smooth` for hover/transitions, `ease-in-out` for state changes
- Wrap every transition in `@media (prefers-reduced-motion: reduce)` override (already in `@layer base`)
- No bounce, spring, or scale-on-click — `translateY(-2px)` lift only via `.card-interactive`

### Z-index
Use named layers: `z-raised`, `z-dropdown`, `z-sticky`, `z-overlay`, `z-modal`, `z-toast`.
Never write `z-[400]` or `z-50` — it makes stacking context impossible to audit.

---

## PWA Manifest & App Shell

**Files:**
| File | Purpose |
|---|---|
| `app/manifest.ts` | Web app manifest — name, icons, shortcuts, colours |
| `app/layout.tsx` | Root layout — fonts, ThemeProvider, viewport, metadata |

**Theme colour** in `layout.tsx` switches per OS colour scheme:
- Light: `#B45309` (amber-700 = `--primary` light)
- Dark: `#F59E0B` (amber-400 = `--primary` dark)
This colours the browser chrome / status bar to match the brand.

**Required icon files** — generate with `npx pwa-asset-generator` or [maskable.app](https://maskable.app):
```
public/
  icons/
    icon-192.png              192×192  any      (Android launcher)
    icon-192-maskable.png     192×192  maskable (Android adaptive)
    icon-512.png              512×512  any      (splash / install prompt)
    icon-512-maskable.png     512×512  maskable (Android adaptive)
    shortcuts/
      dashboard.png           96×96
      learn.png               96×96
      practice.png            96×96
      quiz.png                96×96
  apple-icon.png              180×180           (placed in app/ for Next.js auto-handling)
  favicon.ico                                   (placed in app/ for Next.js auto-handling)
```
Maskable icons must keep the logo inside the **80% safe zone** (centre circle). The outer 10% on each edge will be cropped on some launchers.

**Never** change `manifest.ts` `background_color` or `theme_color` without updating the corresponding token in `globals.css` — they must stay in sync with `--background` and `--primary`.

---

## Responsiveness (Non-Negotiable — Handle on Day 1)

Every component is mobile-first from the moment it is written. Responsiveness is never a follow-up task.

---

### Breakpoint system

| Prefix | Viewport | What changes at this point |
|---|---|---|
| *(none)* | 0–639px | Mobile default — the baseline |
| `sm:` | ≥ 640px | Large phones, small tablets — 2-col grids unlock |
| `md:` | ≥ 768px | Tablets — form rows go side-by-side |
| `lg:` | ≥ 1024px | **Sidebar appears**, 3-col grids, desktop spacing |
| `xl:` | ≥ 1280px | Wide desktop — max-width containers kick in |

**Rule:** Write the mobile style first, then layer on `sm:`, `md:`, `lg:`. Never write a component that only works at desktop width.

---

### The three layout modes

Mobile (`<lg`): 1-col stack + bottom-nav, no sidebar. Tablet (`md`): 2-col grid, no bottom-nav. Desktop (`lg+`): sidebar + 3-col grid, no bottom-nav.

Use the shell utilities from `globals.css`:

```tsx
// _layout.tsx — app shell
<div className="app-shell">
  <nav className="app-sidebar">...</nav>          {/* hidden on mobile */}
  <div className="app-main">
    <header className="app-header">...</header>
    <main className="app-content">
      {children}
    </main>
  </div>
  <nav className="bottom-nav">...</nav>           {/* hidden on lg+ */}
</div>
```

---

### Rules — what you must always do

**1. Mobile-first always**
Write `flex-col` before `sm:flex-row`. Write `hidden` before `lg:flex`. Never assume desktop.

**2. Touch targets minimum 44×44px (WCAG 2.5.5)**
All interactive elements must have a minimum tap area of 44×44px.
- shadcn `<Button size="sm">` is 36px tall — wrap with `.touch-target` or use `size="default"`
- Icon-only buttons: add `className="touch-target"` or `p-3` to meet the minimum
- Bottom nav items: use `.bottom-nav-item` which enforces `min-h-11 min-w-[52px]`

**3. Use `h-dvh` / `min-h-dvh`, never `h-screen`**
`100vh` on mobile Safari includes the browser chrome, cutting off content behind the address bar.
`dvh` (dynamic viewport height) updates as the browser chrome shows/hides.
ESLint will error on `h-screen`.

**4. Use `w-full`, never `w-screen`**
`100vw` causes horizontal overflow on devices with a scrollbar.
ESLint will error on `w-screen`.

**5. Every table needs `.table-responsive`**
Wrap all `<table>` elements in a `.table-responsive` div.
Never let a table overflow the page horizontally — it breaks mobile layout completely.

**6. Modals are full-screen on mobile**
Use `.modal-responsive` on `<DialogContent>` so dialogs fill the screen on mobile and are centred on `sm+`.
Never set a fixed max-width on a modal without a mobile fallback.

**7. Safe area insets for notched devices**
Bottom nav, sheets, and drawers must account for the iPhone home indicator.
`.bottom-nav` already handles `env(safe-area-inset-bottom)`.
For any other fixed-bottom element add: `padding-bottom: env(safe-area-inset-bottom)`

**8. No fixed pixel widths without a responsive variant**
`w-[320px]` alone is an error — it overflows on a 375px phone with padding.
Always pair with a responsive variant: `w-full sm:w-[320px]`.
ESLint will warn on bare `w-[Npx]`.

**9. Sidebar on mobile = drawer, never squished**
On mobile, the sidebar must be completely hidden and accessible via a hamburger/drawer.
Never let the sidebar collapse to a narrow icon-only rail on mobile — use the `.sidebar-drawer` + `.sidebar-drawer-backdrop` pattern from globals.css instead.

---

### Defined responsive utilities (use these, never re-implement)

| Class | Behaviour |
|---|---|
| `.app-shell` | Top-level flex wrapper, `min-h-dvh` |
| `.app-sidebar` | `hidden lg:flex` — sidebar column |
| `.app-main` | `flex-1 flex flex-col min-w-0` |
| `.app-header` | Sticky header, `h-14`, backdrop blur |
| `.app-content` | Page padding — `p-4 pb-24 sm:p-6 sm:pb-6 lg:p-8` |
| `.sidebar-drawer` | Mobile slide-in drawer (`z-modal`) |
| `.sidebar-drawer-backdrop` | Backdrop behind drawer (`z-overlay`) |
| `.bottom-nav` | Fixed bottom nav, `lg:hidden`, safe-area aware |
| `.bottom-nav-item` | Nav item with 44px touch target |
| `.touch-target` | `min-h-11 min-w-11 flex-center` |
| `.table-responsive` | Horizontal scroll container for tables |
| `.stack-sm` | `flex-col sm:flex-row gap-3` |
| `.stack-md` | `flex-col md:flex-row gap-4` |
| `.stack-lg` | `flex-col lg:flex-row gap-6` |
| `.grid-responsive` | 1→2→3 col grid |
| `.grid-responsive-2` | 1→2 col grid |
| `.grid-responsive-4` | 2→2→4 col grid |
| `.grid-stats` | 2×2 on mobile, 4-across on sm+ |
| `.modal-responsive` | Full-screen on mobile, centred dialog on sm+ |

---

### Banned responsive patterns (ESLint enforces these)

| Banned | Why | Fix |
|---|---|---|
| `h-screen` | 100vh cuts off content on mobile Safari | `h-dvh` or `min-h-dvh` |
| `w-screen` | 100vw overflows on scrollbar devices | `w-full` |
| `w-[Npx]` alone | Fixed width breaks on small screens | `w-full sm:w-[Npx]` |
| `overflow-x-hidden` on html/body | Masks bugs, breaks sticky | Fix the overflowing element |
| Desktop-only design (no mobile style) | Page is broken on phones | Write mobile style first |

---

### Notch, camera cutout, and safe area insets

Ignoring safe areas puts UI behind the camera cutout or home-indicator bar. `app/layout.tsx` already sets `viewport.viewportFit = 'cover'` — never remove it, since `env(safe-area-inset-*)` is `0` without it.

`.app-header`, `.bottom-nav`, and `.sidebar-drawer` already apply their own insets — don't re-add padding to them. For anything else fixed to an edge, use these (defined in `globals.css`):

| Class | CSS property |
|---|---|
| `.safe-top` / `.safe-bottom` / `.safe-left` / `.safe-right` | single-edge `env(safe-area-inset-*)` |
| `.safe-x` / `.safe-y` | left+right / top+bottom |
| `.safe-inset` | all four sides |

E.g. a full-screen modal: `<div className="fixed inset-0 safe-inset z-modal">`.

---

### Images — always responsive

```tsx
// Always provide sizes so the browser picks the right source
<Image
  src={src}
  alt={alt}
  fill                              // or width + height
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
  className="object-cover"
/>
```

Never use `<img>` — `next/image` handles lazy loading, sizing, and format optimisation.

---

## Linter — Rules Not Stated Elsewhere in This File

Run `pnpm lint:strict` for zero-warning enforcement (CI must run this, not `next lint`). Everything else ESLint enforces here is already covered by name above (banned class patterns, banned responsive patterns), in Accessibility (aria-label), TypeScript (`any`, `!`), and Feature-Based Organization (import boundaries) — not repeated twice.

Two `no-restricted-syntax` / `@poupe/eslint-plugin-tailwindcss` rules with no other section: `fetch()` inside `useEffect` is banned, and arbitrary Tailwind values are flagged in favor of theme tokens.

**When you must disable a rule**, use an inline comment with a reason:
```tsx
{/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
<div style={{ '--progress': `${pct}%` } as React.CSSProperties} />
```

---

## Theming — Single Source of Truth

**All design tokens live in `app/globals.css` only. No exceptions.**

- Light and dark themes are defined as CSS variables in `globals.css` under `:root` and `.dark`
- `next-themes` `<ThemeProvider>` wraps the app in `layout.tsx` — that is the only theme wiring needed
- Theme switches automatically via the `.dark` class on `<html>` — no component needs to know about it

**The `dark:` Tailwind prefix is banned in component files.**
If you are writing `dark:bg-gray-900` or `dark:text-white` anywhere outside `globals.css`, you are using the wrong token. Use the semantic token (`bg-background`, `text-foreground`) and the theme handles it.

**Raw color classes are banned in component files.**
Never write `bg-white`, `bg-gray-100`, `text-black`, `text-gray-500`, `border-gray-200`, etc. in a component.
Always use semantic tokens: `bg-background`, `bg-card`, `bg-muted`, `text-foreground`, `text-muted-foreground`, `border-border`.

**Fonts:**
- `--font-plus-jakarta` → `Plus Jakarta Sans` (headings, UI labels) — loaded via `next/font/google` in `layout.tsx`
- `--font-jetbrains-mono` → `JetBrains Mono` (code, quiz answer options) — loaded via `next/font/google` in `layout.tsx`
- Never use `font-geist-*` — MindForge uses Plus Jakarta Sans and JetBrains Mono only

**Adding a new color or style pattern:**
1. Add the CSS variable to both `:root` and `.dark` in `globals.css`
2. Register it in the `@theme` block in `globals.css`
3. Use it in components via the semantic class name — done

---

## Layout & Spacing — `@layer components` in `globals.css`

Common layout patterns are defined once in `globals.css` under `@layer components`.
Components use those class names — they do NOT repeat the underlying Tailwind chain.

**Defined patterns (use these, do not re-implement):**

| Class | What it does |
|---|---|
| `.page-container` | `mx-auto max-w-7xl px-6 sm:px-8 lg:px-12` |
| `.page-container-sm` | `mx-auto max-w-3xl px-6 sm:px-8` |
| `.page-header` | `flex items-center justify-between py-6 gap-4 flex-wrap` |
| `.page-title` | `text-3xl font-bold tracking-tight` |
| `.section-title` | `text-2xl font-semibold tracking-tight` |
| `.card-base` | card with border + shadow-card |
| `.card-raised` | elevated card with shadow-raised |
| `.card-interactive` | card-base + hover lift (`translateY(-2px)`) |
| `.ai-surface` | cyan-tinted panel for AI-generated content |
| `.ai-badge` | inline "AI" chip label |
| `.mastery-none/learning/practiced/mastered` | SRS flashcard states |
| `.difficulty-beginner/intermediate/advanced` | difficulty level badges |
| `.progress-track` + `.progress-fill` | animated progress bar |
| `.form-stack` | `flex flex-col gap-4` |
| `.card-grid` | `grid gap-6 sm:grid-cols-2 lg:grid-cols-3` |
| `.prose-content` | base typography for rich-text read views |
| `.empty-state` | centred empty state container |
| `.divider-label` | horizontal rule with centred text label |
| `.kbd` | keyboard shortcut key visual |
| `.skeleton` | loading placeholder |

If you find yourself writing the same multi-class string twice, it belongs in `globals.css` as a named utility, not repeated in two components.

---

## Typography — Auto-Applied via `@layer base`

Base element styles are set globally in `globals.css`. Components do not style headings, paragraphs, or links — the browser picks up the base styles automatically.

- `h1`–`h4` sizes, weights, and tracking are set globally
- `p` line-height and color (`text-foreground`) set globally
- `a` color (`text-primary`) and hover state set globally
- `code` font and background set globally
- `body` gets `bg-background text-foreground font-sans antialiased` globally

You never write `text-4xl font-bold tracking-tight` on an `<h1>` in a component — it already has that style.

---

## Forms

### Shared field abstraction (required)

- Repeated `FormField` + `FormItem` + `FormLabel` + `FormControl` + `FormMessage`
  plumbing must be extracted into a typed primitive in `components/ui/`. Use
  `<FormInputField />` for standard text, email, and password inputs instead of
  duplicating that JSX in feature forms.
- Keep each form's field declarations explicit and type-safe. Do not turn a fixed
  API contract into a config-driven form merely to reduce lines of JSX.
- Add a focused typed primitive for genuinely different controls such as select,
  checkbox, radio, date, or file input. Do not grow `<FormInputField />` into a
  conditional component that handles unrelated control types.
- Apply an existing shared field primitive across the codebase whenever the same
  form-control structure appears; feature code should contain field intent and
  copy, not repeated library wiring.

### Form behavior
- Every form uses **react-hook-form** + **zod** — no raw `useState` for form fields
- Schema declared above the component in the same file: `const Schema = z.object({...})`
- Infer the form type from the schema: `type FormData = z.infer<typeof Schema>`
- Validation errors render via shadcn `<FormMessage />` — never a custom error `<p>`
- Submit button pending state via `useFormStatus()` — not a separate `useState`
- Submit handler receives typed, validated data — no manual field reads

---

## Feature-Based Organization

Components, routes, and data logic are organized by feature, not by type — `components/<feature>/`, `app/(app)/<feature>/`, `lib/<feature>/` (e.g. `courses/`, `labs/`, `rewards/`, `assessments/`). Only promote a component to `components/shared/` when an *unrelated* feature reuses it (see below) — never place new components in a type-based folder like `components/cards/` or `components/modals/`.

**This is enforced automatically** by `eslint-plugin-boundaries` in `eslint.config.mjs` — a feature may only import `components/ui/`, `components/shared/`, cross-cutting `lib/` files, or its own feature folder. A genuinely deliberate cross-feature integration (e.g. courses embedding a labs widget) must be added as an explicit allow-listed edge in the `boundaries/dependencies` rule config, with a comment explaining why — it is not something to work around by importing directly.

---

## Shared Components (`components/shared/`)

| Component | File | Notes |
|---|---|---|
| `<CodeEditor>` | `components/shared/code-editor.tsx` | Lazy-loaded Monaco Editor (`next/dynamic`, ssr: false). Props: `language`, `value`, `onChange`, `readOnly`, `height`, `className`. Uses `var(--font-jetbrains-mono)`. Skeleton shown while loading. |
| `<AccessGate>` | `components/shared/access-gate.tsx` | Permission/feature gate wrapper |
| `<BrandMark>` | `components/shared/brand-mark.tsx` | Logo mark |
| `<ThemeToggle>` | `components/shared/theme-toggle.tsx` | Light/dark toggle |
| `<WithFeature>` | `components/shared/with-feature.tsx` | Feature-flag HOC |

---

## Design System
- UI primitives from `components/ui/` (shadcn) only — no raw `<input>`, `<button>`, `<select>`, `<textarea>`
- Compose larger patterns from `components/shared/` — never duplicate a layout pattern
- No style props — components own their appearance; callers pass data and callbacks only
- Variants go through `cva()` inside the component — callers pass `variant` or `size`, not class strings
- Always use `cn()` from `lib/utils` for className merging — never string concatenation
- `globals.css` contains only design tokens, base element styles, and utilities that
  are reused across multiple unrelated components or features.
- Component- or feature-specific selectors must not be added to `globals.css`.
  Keep those Tailwind classes in the owning component, or use a colocated CSS
  module when Tailwind cannot express the styling clearly.
- Repetition alone does not make a style global when every use belongs to one
  component family. Extract a shared component first; promote styling to a global
  utility only when unrelated parts of the application reuse the same pattern.

---

## Component Constraints
- **Max 300 lines per file** — split into sub-components or hooks when approaching the limit
- **Max 2 `useState` calls per component** — more state goes into a custom hook or URL params
- **No `useEffect`** — use server components, `use()`, SWR/React Query, or URL state instead
- One component per file
- Props interface declared above the component in the same file

---

## `"use client"` Discipline
- Add `"use client"` only when the component uses browser APIs, event handlers, or hooks
- Everything else is a Server Component by default — no exceptions
- Keep client boundaries as deep (leaf) as possible — never make a layout or full page a client component
- A page that needs one interactive widget: make the widget `"use client"`, keep the page a server component

---

## TypeScript
- No `any` — use `unknown` and narrow, or infer from zod schemas
- No non-null assertion `!` unless the value is provably non-null at that point
- Named exports for all components — default export only for Next.js pages and layouts (framework requirement)

---

## URL-Driven UI State
- Search query, active filters, sort order, current page, and open modal ID go in the URL
- Use `nuqs` for typed URL search params — not `useSearchParams` directly
- A page refresh must restore the exact UI state the user was in
- No `useState(false)` for "is modal open" — use a URL param (e.g. `?modal=invite`)

---

## Data Fetching & Mutations
- Fetch in **Server Components** by default — pass data down as props
- Loading and error states use `<Suspense>` + `error.tsx` boundaries — no `isLoading` booleans
- Use shadcn `<Skeleton>` for loading placeholders — no spinners
- Hand-author skeleton shapes per route in `loading.tsx` — do not add Boneyard or similar auto-generated-skeleton tooling; the manual `<Skeleton>` + `loading.tsx` pattern already covers all routes with no extra build-step dependency
- Mutations use **server actions** — no manual `fetch` calls in components
- Server action naming: `<verb><Noun>Action` — e.g. `createCourseAction`, `deleteCardAction`
- Action errors are returned as state — never thrown to the client
- `useActionState` (React 19) consumes server action results

---

## Next.js Built-ins — Always Use, Never Bypass
- Images → `next/image` with explicit `width`/`height` or `fill` — no raw `<img>`
- Internal links → `next/link` — no raw `<a href>` for internal routes
- Fonts → `next/font` — no Google Fonts `<link>` tags in HTML
- 404 → `notFound()` from `next/navigation` in server components
- Redirects → `redirect()` from `next/navigation` — no `router.push` in server components

---

## Heavy Dependencies — Dynamic Import Always
- Monaco Editor, React Flow, TipTap, Recharts → `dynamic(() => import(...), { ssr: false })`
- Never statically import a heavy client-only library at the page level

---

## Feedback
- Success/error notifications via shadcn **Sonner** toast — no `alert()`, no custom toast state

---

## File & Import Conventions
- File names: `kebab-case.tsx` — component name inside is PascalCase
- Imports: always use `@/` alias — never `../../relative/paths`
- No barrel `index.ts` re-export files — they slow bundling and hide dependencies
- Route paths as constants in `lib/routes.ts` — no hardcoded `"/dashboard"` strings in components

---

## Feature Flags & Subscription Gating

**Every gated feature uses `<AccessGate>` from day 1.** Two axes, both resolved server-side, frontend just trusts them: **org toggle** (admin turns a feature ON/OFF for the whole org — OFF means fully hidden, no lock/CTA) and **user entitlement** (plan / add-on / org-granted seat — resolved into `orgFeatures`, `entitlements`, `lockedInfo` by `getFeatureConfig()` in root `app/layout.tsx`, cached 60s, exposed via `<FeatureFlagProvider>` and the `useIsEntitled()` / `useIsOrgFeatureEnabled()` / `useLockedInfo()` hooks).

**Mode decision guide** for `<AccessGate feature={FEATURES.X} mode="lock|badge|hide">`:

| Situation | Mode | What user sees |
|---|---|---|
| Org ON, user not entitled — show what they're missing (default, prefer this for discoverability) | `lock` | Content blurred + lock icon + CTA from `lockedInfo` |
| Nav/sidebar item user doesn't have | `badge` | Item visible + "Add-on"/"Upgrade" badge |
| Feature the user must never know exists | `hide` | Nothing rendered (use sparingly) |
| Org OFF entirely | N/A | Renders nothing automatically |

Lock CTA text always comes from `lockedInfo.unlock_via` (`"addon"` → "Add X", `"plan"` → "Upgrade Plan", `"org_admin"` → "Contact your admin", `"plan_or_addon"` → show both) — the component never invents CTA copy.

**Server-side guard `page.tsx` too — UI gates are UX, not security:** `await requireAccess(FEATURES.WIKI)` (404 if org-OFF, redirect to `/billing?feature=X` if not entitled), or `requireOrgFeature()` / `requireEntitlement()` for a single-axis check.

**`<AccessGate>` is never written at a component's call site** — pick one:
| Situation | Pattern |
|---|---|
| Component always belongs to one feature (WikiCard) | `export const WikiCard = withFeature(WikiCardBase, FEATURES.WIKI)` — bakes the gate in once, callers never wrap it |
| Sidebar / nav / feature grid | Config-driven: add `feature`/`mode` to the nav-item object (`lib/nav.ts`), the renderer applies the gate |
| Entire page/route | Server guard at the top of `page.tsx`; the rendered tree needs no internal gate |
| Section within a mixed page | `<AccessGate>` directly — the one valid call-site use |

**Banned:** any `if (user.plan === 'pro')` / `if (user.subscription === ...)` comparison in a component; hardcoded plan or feature strings (`"pro"`, `"wiki"`) instead of `PLANS.*`/`FEATURES.*`; deciding lock CTA text client-side; fetching feature config client-side (root layout already fetches once).

---

## Config & Server-Driven Options

**No option list, dropdown, or enum is hardcoded in a component.**

- Role lists, difficulty levels, status values, language options, category lists, plan tiers, verdict options — all come from the server (API response or server component prop) or from a constants file (`lib/constants.ts`)
- Components receive `options: { label: string; value: string }[]` as a prop — they never define the array themselves
- If an option list is static (never changes per org/user), it lives in `lib/constants.ts` — one place, imported everywhere
- If an option list varies per org or user, it is fetched server-side and passed down as props
- No `const ROLES = ["admin", "instructor", "student"]` inside a component file
- Filter panels, sort dropdowns, and status selectors all derive their options from a single source — changing a value in one place updates every UI that uses it

---

## Accessibility
- Semantic HTML: `<main>`, `<nav>`, `<header>`, `<section>`, `<article>` — no `<div>` soup for structure
- Icon-only buttons must have `aria-label`
- Never override shadcn's focus ring or keyboard navigation styles
