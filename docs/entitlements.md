# Tier & Entitlement System — Plan

> **Status: PARTIALLY IMPLEMENTED (2026-08-20).** The core engine (§3, §6 minus
> the atomic-quota SQL) and a real slice of §2's matrix are live — see
> "Implementation status" below for exactly what. §5 (add-ons) and §8's open
> product decisions remain unimplemented; the rest of this doc is still the
> original design proposal for them.

---

## 0. Implementation status (2026-08-20)

**Live:**
- `plan_limits`, `usage_counters`, `users.tier_id`, `organizations.tier_id`
  (migration `019_entitlements.sql`) and `backend/internal/entitlements`
  (`Service.ResolveAccount`/`GateEnabled`/`QuotaLimit`, monthly usage
  read/accrue, admin CRUD).
- Gate enforcement wired into `features.Service.Resolve`: two org-tier keys
  (`assessments`, `gitlab_integration`) and four individual-tier keys
  (`system_design`, `interview_board`, `load_test`, `certificates`). `Resolve`
  now also populates `LockedInfo` for these six keys (previously always `{}`).
- Quota enforcement wired into `labs.Service.StartSession` +
  `RecordSessionContainerUsage(Batch)`: individual-tier
  `lab_sessions_concurrent` (1/2/3) and `lab_hours` (3/15/40 per month, seeded
  from the existing marketing copy). Org accounts are unaffected — no
  org-tier row exists for either key, so they keep today's
  `org_lab_config`-only caps.
- Tier assignment: `PUT /api/admin/users/{id}/tier`,
  `PUT /api/admin/orgs/{id}/tier` (both platform-admin-only — nothing sells a
  tier upgrade yet, every paid CTA is still "Coming soon"). Org assignment
  also has a UI, on `/platform/features/{id}`.
- Admin limits editor: `/platform/pricing`'s tier cards now have a "Limits"
  button (gate switch / quota number input) for the ten wired keys above.
- User-facing: `GET /api/me/usage` (tier name + `lab_hours` usage) and the
  `/billing` page now render real `pricing_tiers` data, real `lockedInfo`
  CTAs, and a lab-hours usage bar — replacing the old static
  `frontend/lib/features.ts` `PLAN_TIERS` placeholder for this page.

**Explicitly not built** (would be dead config/UI per CLAUDE.md's
no-stub rule if added without a reader — revisit once a real driver exists):
- `what_now`/`revision_digest` are **not** tier-gated — they're deliberately
  per-user beta grants with "no unlock path to advertise"
  (`frontend/lib/features.ts`'s own comment); tier-gating them would
  contradict that.
- AI practice/hints daily quota, mentor session credits, sheet-tracker
  multi-sheet, seats — no plan_limits rows, no enforcement. Each needs a
  real call site in its own domain package first.
- §5 (add-on marketplace / Stripe purchase flow) — not built. There's
  nothing to attach an add-on to yet: every paid tier's CTA is still
  disabled, so building a store on top of a product nobody can buy is
  premature. Revisit once §8's tier-upgrade-purchase question is answered.
- §8's open product decisions are all still open — nothing here forces an
  answer (e.g. quota enforcement is a hard block by construction, since no
  soft-allow/overage path was built; that's an implementation default, not
  a resolved product decision).

---

## 1. Codebase research (as of 2026-08-20)

### 1.1 Pricing tiers are presentational only

`backend/internal/pricing/models.go`:

```go
// Tier is one row of a marketing pricing table — the individual (Free/Plus/
// Pro) or org (Starter/Growth/Enterprise) landing page section. Presentational
// only: there is no billing backend behind CTADisabled, same as the static
// PLAN_TIERS placeholders this replaced (see frontend/lib/features.ts).
```

- Table: `pricing_tiers` (migration `backend/db/migrations/004_pricing_tiers.sql`) — `id, audience (individual|org), position, name, price, billing_note, tagline, features (jsonb), cta_label, cta_disabled, cta_href, highlighted, updated_by, updated_at`.
- Full CRUD exists: `internal/pricing/{models,repo,service,handler,routes}.go`. `Service.Update` validates required fields and enforces `cta_href` is set exactly when `cta_disabled = false`.
- Admin UI: `frontend/app/platform/pricing/{page.tsx,pricing-tier-card.tsx,edit-pricing-tier-dialog.tsx,actions.ts}` — lets a platform admin edit price/copy/CTA without a redeploy.
- Rendered publicly via `frontend/lib/server/pricing.ts` on `landing-pricing.tsx` (used by both `landing-page.tsx` and `org-landing-page.tsx`).
- **Nothing links a purchased/selected tier to what a user or org can actually do.** No `tier_id`/`plan_id` column exists anywhere else in the schema.
- Seed data (in the migration) already implies specific numeric limits in the marketing copy — e.g. "1 lab session at a time" (Free), "Up to 15 lab-hours a month, 2 sessions at once" (Plus), "Up to 40 lab-hours a month, priority queue" (Pro), "2 mentor session credits every month" (Pro), "Up to 10 members" (org Starter), "Unlimited seats" (org Growth) — **none of these are enforced in code today.**

### 1.2 Payments — real Stripe integration, one-time purchases only

`backend/internal/payments/stripe.go`:
- Real `StripeProvider` against Stripe Checkout (`Mode: payment`, hosted page), confirmed via webhook (`ParseWebhook`, signature-verified).
- Idempotency key derived from `PurchaseID` so retries can't double-charge.
- Handles the `checkout.session.completed` vs `checkout.session.async_payment_succeeded` distinction correctly (async payment methods fire *completed* before funds clear).
- `Refund` reverses a `PaymentIntent` in full.
- Used today for **course purchases** and **mentor session credit packs** (`internal/mentoring/service_purchase.go`, `checkout_test.go`, `webhook_test.go`) — all one-time `Mode: payment` sessions, not recurring subscriptions. There is no `Mode: subscription` usage anywhere, so a tier "subscription" concept does not exist in the payments layer yet.

### 1.3 Feature gating — boolean-only, hardcoded key lists, no tier link

`backend/internal/features/{models,service,repo}.go`:

- `FeatureConfig{OrgFeatures, Entitlements, LockedInfo}` is resolved per request via `Service.Resolve(ctx, userID, orgID)`.
- Three hardcoded Go slices drive everything:
  - `alwaysOrgEnabled` (16 keys) — org-level toggles, default **on**, overridable per-org via `org_feature_flags`.
  - `alwaysEntitled` (14 keys, = `alwaysOrgEnabled` minus `what_now`/`revision_digest`) — once an org has a feature on, every member gets it by default, overridable per-member via `user_feature_flags`.
  - `userToggleable` (= `alwaysEntitled` minus `ai_connector`/`session_booking`) — the subset an org admin can grant/revoke per member.
- `ai_connector` and `session_booking` deliberately bypass the generic table and read dedicated `org_settings` columns instead (documented reason: avoid forking that state into two sources of truth).
- Individual permission grants (`what_now`, `revision_digest`) go through `user_permission_overrides` as `features.<key>` permission codes (`Repo.GrantedFeatureKeys`), gated additionally by the org-level toggle.
- **Everything here is boolean.** There is no numeric quota concept anywhere — no lab-hours counter, no mentor-credit counter, no AI-call counter, no seat count enforcement. Marketing copy promises numeric limits; code enforces none of them.
- `LockedFeatureInfo{UnlockVia, CTALabel, Reason}` already exists in `models.go` as the intended shape for "why is this locked / how do I unlock it" — but `Resolve()` always returns it as an empty map (`map[string]LockedFeatureInfo{}`). The contract is defined but unused.

### 1.4 Conclusion from research

Two systems exist in parallel and don't talk to each other:
1. **Pricing tiers** — real, editable, DB-backed, purely marketing.
2. **Feature flags** — real, DB-backed, boolean, manually toggled by admins — with no connection to which tier an account is on, and no support for numeric limits at all.

Building tier-based restriction means connecting these two, and adding a metering layer that doesn't exist today.

---

## 2. Feature × Tier matrix (proposed — not yet confirmed)

**Individual — Free / Plus / Pro**

| Feature | Free | Plus | Pro | Type |
|---|---|---|---|---|
| Course enrollment (free) | Unlimited | Unlimited | Unlimited | gate |
| Challenges & quizzes | ✅ | ✅ | ✅ | gate |
| Flashcards (SM-2) | ✅ | ✅ | ✅ | gate |
| AI revision digest | ❌ | Weekly | Daily | gate + freq |
| AI practice/hints | 5/day | 50/day | Unlimited (fair-use) | quota |
| What Now (AI roadmap) | ❌ | ✅ | ✅ | gate |
| Lab sessions | 1 concurrent · 3 hrs/mo | 2 concurrent · 15 hrs/mo | 3 concurrent · 40 hrs/mo, priority | quota |
| Certificates | ❌ | ✅ | ✅ | gate |
| Sheet tracker | 1 sheet | Multi + overlap | Multi + overlap | quota |
| System design canvas | ❌ | ❌ | ✅ | gate |
| Interview board (live) | ❌ | ❌ | ✅ | gate |
| Load test simulator | ❌ | ❌ | ✅ | gate |
| Mentor session credits | 0 | 0 | 2/mo | quota |
| Wiki (personal) | Notes only | ✅ | ✅ | gate |
| GitLab integration | ❌ | ❌ | ✅ | gate |
| AI Connector (MCP) | ❌ | ❌ | ✅ | gate |

**Org — Starter / Growth / Enterprise**

| Feature | Starter | Growth | Enterprise | Type |
|---|---|---|---|---|
| Seats | ≤10 | Unlimited | Unlimited | quota |
| Roles, shared library/wiki, batch chat | ✅ | ✅ | ✅ | gate |
| Proctored assessments + auto-grading | ❌ | ✅ | ✅ | gate |
| Anonymous public tests | ❌ | ✅ | ✅ | gate |
| Mentor booking + credit pool | ❌ | ✅, admin-set pool | ✅, larger pool | quota |
| GitLab integration | ❌ | ✅ | ✅ | gate |
| SSO / custom domain | ❌ | ❌ | ✅ | gate |
| Audit log / compliance exports | ❌ | ❌ | ✅ | gate |
| AI token budget | Shared platform default | Per-seat allowance | Custom/dedicated | quota |

---

## 3. Data model

| Table | Purpose |
|---|---|
| `pricing_tiers` *(exists)* | Marketing copy — reused as-is, becomes the FK target for limits |
| `plan_limits` *(new)* | `(tier_id, feature_key, kind: gate\|quota\|unlimited, bool_value, numeric_value, period)` — one row per tier × feature |
| `addons` *(new)* | `(id, feature_key, name, delta, price_cents, billing_type: one_time\|recurring, audience)` |
| `addon_purchases` *(new)* | `(id, account_id, addon_id, quantity, status, stripe_ref, starts_at, ends_at)` |
| `usage_counters` *(new)* | `(account_id, feature_key, period_start, period_end, used_count)`, unique index on `(account_id, feature_key, period_start)` |

`account_id` resolves to a `user_id` for individual plans or an `org_id` for org plans — same shape, one code path for both audiences.

`features.Resolve()` changes from reading three hardcoded Go slices to reading `plan_limits` for the account's tier; the slices remain only as the valid-key allowlist (reject typos on admin writes).

---

## 4. Admin configuration UI

Extends the existing `/platform/pricing` editor (same "list of rows, edit in place" pattern as `edit-pricing-tier-dialog.tsx`) with a limits tab, rendered per `kind`:
- `gate` → checkbox
- `quota` → number input + period dropdown, with an "Unlimited" override checkbox
- No generic form-builder — feature keys are a fixed, known list, not user-defined fields. Reuses the exact editing pattern the pricing copy editor already has, so no new UI paradigm.

---

## 5. Add-on flow (user-facing)

1. "My Plan" page (extends `frontend/app/(app)/billing/page.tsx`) shows usage bars; near/at cap surfaces a "Get more" CTA.
2. Add-on marketplace (reuses `pricing-tier-card.tsx` visual pattern) lists purchasable deltas: extra lab-hours, extra mentor credits, extra seats, or unlocking a gate feature early.
3. Checkout reuses the existing `payments.Provider` / `StripeProvider` — same Checkout Session + webhook pipeline already used for course and session-credit purchases (§1.2), new product type only, no new payment code.
4. Webhook fulfillment writes `addon_purchases`. Effective limit at check time = base tier limit + sum of active add-on deltas.

---

## 6. Enforcement — `CheckAndConsume`

One shared helper every quota-gated action calls (lab start, AI message, mentor booking) — avoids each domain package (labs, mentoring, practice_ai...) reimplementing "check then increment":

```
kind == unlimited → return nil immediately, never touches usage_counters
kind == gate      → check entitlements list, no counter involved
kind == quota     → atomic UPDATE:

    UPDATE usage_counters SET used_count = used_count + $amount
    WHERE account_id = $1 AND feature_key = $2 AND period_start = $3
      AND used_count + $amount <= $limit
    RETURNING used_count
```

One round trip, race-safe without app-level locking (concurrent requests can't both pass the check), no cron reset job — the current period's row is created lazily on first use via upsert (`INSERT ... ON CONFLICT DO UPDATE`).

### Performance notes

- At MindForge's scale this is not a bottleneck — a single indexed Postgres write per action handles far more throughput than needed here. Index `usage_counters` on `(account_id, feature_key, period_start)`.
- Cache the *limit value* (tier + active add-ons — changes only on upgrade/downgrade/add-on purchase/admin edit) per account; only the live counter needs a DB hit per action.
- Continuous usage (lab-hours) accrues and flushes periodically (e.g. on session end or a few-minute heartbeat), not on every tick.
- Don't add Redis pre-emptively. Only reach for it (e.g. atomic `INCR`+`EXPIRE` for the AI-call counter specifically) if that counter is later measured as hot — adding it now would just create a second source of truth for a problem that doesn't exist yet.

---

## 7. Error classification

| Result | Meaning | Response |
|---|---|---|
| `err != nil` | Infra failure (DB down, timeout) | 500, generic retry message |
| `err == nil`, 0 rows affected | Genuine quota hit | 403, `code: "quota_exceeded"` |
| Not in entitlements list | Gate is off | 403, `code: "not_entitled"` |

Sentinel Go errors (`ErrQuotaExceeded`, `ErrNotEntitled`) map to a stable `code` string in the JSON body — never serialize `err.Error()` to the client. Frontend switches on `code`, not message text, so copy can change without breaking frontend logic.

`kind == unlimited` is excluded from the counter path entirely (§6) — an unlimited plan cannot structurally reach the quota-exceeded branch, so there's no message to misclassify.

### Who the error is shown to

Depends on who owns the plan:
- **Individual account** → requester is the billing owner → show the upgrade/add-on CTA directly.
- **Org account** → add `actionable_by: "self" | "admin"` to the response, resolved from the requester's org role:
  - Non-admin member → neutral message ("ask your org admin"), no CTA — they have no permission to act on it.
  - Org admin → the real upgrade/buy-addon CTA.

Org-scoped usage bars (seats, AI budget, mentor pool) belong on the **admin's** view, not the member's — members only need to know whether the specific thing they tried is available right now, not org-wide consumption numbers. Add a passive ~80%-usage banner on the admin dashboard so admins see a pool running low before a member gets blocked by it.

---

## 8. Open decisions (need product input before build)

- Hard block at 100% quota, or soft-allow with a warning + overage billing?
- Add-ons: per-user only, or can an org admin buy a pooled add-on for the whole org?
- Seat counting: per active member, or per invited-including-pending?
- Should `plan_limits` support per-org overrides (negotiated custom deals) on top of the tier default, or is that handled as an Enterprise-only fully custom row?
- Should the numeric limits already implied in the seed marketing copy (§1.1) be treated as the committed launch numbers, or are they placeholders to redo?
