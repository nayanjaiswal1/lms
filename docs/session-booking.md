# Mentor Session Booking

1:1 and whole-batch mentor sessions: mentor-published availability, slot-based
booking, purchasable session credits, cancellation rules, post-session
feedback and mentor notes, and automatic calendar projection.

Before this feature a "mentor session" was only a `calendar_events` row of
`event_type='mentor_session'` created ad hoc — no availability model, no limit
on how many a student could create, no cancellation rules, and no record of
what happened afterwards.

---

## Feature gate

| Axis | Mechanism |
|---|---|
| Org toggle | `org_session_booking_config.enabled`, surfaced as the `session_booking` feature key |
| Entitlement | None — every member of an enabled org is entitled |
| Admin surface | RBAC permission `mentoring.manage_session_booking` (default: `tenant_admin`, `instructor`) |

`enabled` **defaults to true**: session scheduling already worked for every org
before the booking domain existed, so shipping it off would silently withdraw a
capability people were already using. Turning it off is an explicit admin
opt-out — the same rule `ai_connector` follows.

`require_credits` **defaults to false**. Turning it on before the org has
published any `session_credit_packs` would leave every student at a zero
balance with nothing to buy, i.e. the feature bricked. It is a deliberate
second step once packs exist.

Frontend: `FEATURES.SESSION_BOOKING`, nav item mode `"hide"` (org-off means the
org does not run booking at all, and there is no plan to upsell onto).

---

## Booking policy

One row per org in `org_session_booking_config`. A missing row resolves to
these defaults in both Go (`sessions.DefaultConfig`) and SQL (column defaults).

| Setting | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Booking available at all |
| `require_credits` | `false` | A 1:1 booking costs one credit |
| `cancel_cutoff_hours` | 12 | Cancel earlier than this to get the credit back |
| `min_notice_hours` | 2 | A slot starting sooner is neither offered nor bookable |
| `booking_horizon_days` | 60 | How far ahead slots are published |
| `max_upcoming_per_student` | 3 | Scheduled sessions one student may hold at once |
| `default_duration_minutes` | 30 | Pre-selected session length |

`max_upcoming_per_student` is the limit whose absence prompted the feature.

---

## Availability → slots

A mentor publishes a **weekly pattern** (`mentor_availability_rules`) plus
**one-off overrides** (`mentor_availability_exceptions`). Slots are computed on
read by `sessions.ExpandSlots` and never persisted — a slot only becomes a row
when someone books it.

Precedence, highest first:

1. a **blocking** exception removes a slot outright (a day off means off, even
   where a weekly rule says otherwise);
2. an **opening** exception adds a window the weekly rules don't cover;
3. the weekly rules.

Then: slots overlapping an existing scheduled session come back
`taken: true`, and slots outside `[now + min_notice, now + horizon]` are
dropped entirely.

### Taken slots are returned, not hidden

The API returns busy windows flagged rather than filtered out. A grid with the
busy ones silently missing reads as "the mentor doesn't work then" — the UI
renders them disabled and visibly booked.

### Timezones

A rule stores an IANA `timezone`, not UTC minutes-of-week. "Every Tuesday
09:00" is a wall-clock promise: across a DST shift the UTC instant must move so
the mentor's morning doesn't. `ExpandSlots` resolves each date in the rule's
own zone via `time.Date`, which picks the correct offset per date. Covered by
`TestExpandSlots_WallClockSurvivesDST`.

A rule whose timezone no longer resolves is skipped rather than failing the
whole query; `validateRule` rejects an unknown zone at write time so this
cannot happen through the API.

---

## Booking

`POST /api/mentor-sessions` — either party may book. A student booking
themselves may omit `student_id`; a mentor booking a mentee supplies it.

One transaction: check the upcoming-session cap → check and lock the credit
balance → insert the session → append the `-1` ledger row. The calendar
projection happens **after** that transaction commits, because
`calendar.Service.CreateEvent` opens its own transaction on the same pool and
nesting it inside ours would deadlock against the advisory credit lock. A
booking whose calendar row failed is logged, still returned, and still visible
in the sessions list.

### Double-booking is a DB constraint, not a check

```sql
EXCLUDE USING gist (mentor_id WITH =, tstzrange(starts_at, ends_at) WITH &&)
  WHERE (status = 'scheduled')
```

plus the same constraint keyed on `student_id`. Two students pressing "book" on
the same slot in the same millisecond is the normal case for a popular mentor,
not an exotic race — an app-side "is this slot free?" `SELECT` cannot decide it
correctly, and re-reading availability first only widens the window it cannot
close. The loser gets `ErrSlotTaken` → HTTP 409, and the UI refreshes the grid.

Cancelled and completed rows are excluded from the constraint, so cancelling
10:00 frees 10:00 for rebooking.

### Batch sessions

`POST /api/batches/{batchID}/sessions`, gated by
`mentoring.manage_session_booking`. One `mentor_sessions` row with `batch_id`
set and `student_id` NULL; every batch member becomes a calendar attendee.

**No credits are charged for a batch session.** Staff scheduling a cohort class
is not something each member individually requested — debiting all of them
would be a silent mass charge. The upcoming-session cap likewise does not apply.

`mentor_sessions_subject_chk` makes "exactly one of student or batch" a schema
guarantee rather than a convention.

---

## Credits

`session_credit_ledger` is **append-only**; a balance is `SUM(delta)`. There is
no mutable balance column to drift out of sync with its own history, and every
movement carries its reason and the row that caused it.

| Reason | Delta |
|---|---|
| `purchase` | + pack size, on webhook confirmation |
| `admin_grant` / `admin_revoke` | ± admin action |
| `booking` | −1 |
| `cancellation_refund` | +1 |

Concurrency: a balance is an aggregate, so there is no row to
`SELECT … FOR UPDATE`. `Repo.lockUserCredits` takes
`pg_advisory_xact_lock` on `(user_id, org_id)` for the transaction — without it
two concurrent bookings can both read `balance = 1` and both insert a `-1`.

Idempotency: two partial unique indexes,
`session_credit_ledger_booking_uq` and `_refund_uq`, allow at most one charge
and one refund per session. A retried cancel inserts nothing and reports
`credit_refunded: false` rather than minting a credit from nothing.

An admin revoke cannot push a balance below zero — a negative balance would
silently swallow the student's next purchase.

### Buying a pack

Packs (`session_credit_packs`) ride the existing `payments.Provider` seam.
There is exactly one webhook URL per gateway, owned by the `mentoring` package
for historical reasons; when a delivery's `provider_ref` matches no course
purchase, it is offered to `mentoring.PackConfirmer` (implemented by
`sessions.Service.ConfirmPackPurchase`). `matched=false` means it belongs to
neither and is written off — a bool rather than a shared sentinel error, so
neither package imports the other's error values.

`session_pack_purchases.sessions` is **copied off the pack at checkout**, not
read through the FK: an admin editing a pack's size later must not retroactively
change what an already-paid purchase granted.

The amount/currency cross-check mirrors the course path — a valid signature
proves the delivery is authentically from the gateway, not that it concerns the
amount we asked it to charge.

A zero-price pack is credited immediately; several gateways reject a
zero-amount checkout outright.

> `price_cents` is in `PAYMENTS_CURRENCY` minor units. For an INR deployment
> these are **paise**.

---

## Cancellation

`POST /api/mentor-sessions/{id}/cancel`.

The credit comes back when **either**:

- the cancellation lands earlier than `cancel_cutoff_hours` before the start, **or**
- the **mentor** is the one cancelling — a student must never pay for the
  mentor's change of plans, however late it is.

A late *student* cancellation forfeits the credit, which is the entire point of
having a cutoff. `CancelResult` reports `credit_refunded`, `within_cutoff`, and
`cutoff_hours` so the UI states what happened instead of guessing.

A late cancellation is still *allowed* — the alternative is a student trapped
into attending.

Cancelling clears the calendar entry too (best-effort; the booking is already
cancelled, so failing the request would leave the caller thinking it wasn't).

---

## Outcome, feedback, notes

**Outcome** — only the mentor marks a session `completed` or `no_show`, and
only after it has started. A student marking their own no-show away would erase
the record the policy depends on. Only a `scheduled` session can transition, so
an outcome cannot be flipped back and forth afterwards.

**Feedback** — both parties rate once each, 1–5 plus an optional comment, only
after the session has ended and never on a cancelled one.
`UNIQUE (session_id, author_id)` makes a resubmit an edit rather than a second
rating that would skew the mentor's average.

**Notes** — one document per session, owned by the mentor, `visible_to_student`
**defaults false**. A mentor's working notes about a mentee are private by
default and shared deliberately, never the reverse. `Repo.GetNotes` filters in
SQL, so private notes never leave the database on a student's request.

---

## Mentee progress

`GET /api/session-booking/mentees/{studentID}` — what a mentor opens before the
next session: full shared history plus totals, first/last session, the average
rating that mentee gave, and the next scheduled session.

---

## Calendar projection

A booking is the record; the calendar is the projection. Every session creates
a `calendar_events` row through `calendar.Service.CreateEvent` with
`event_type='mentor_session'`, `entity_type='mentor_session'`,
`entity_id=<session id>`, linked back by `mentor_sessions.calendar_event_id`.

Going through the calendar service rather than inserting the row directly is
what makes sessions appear on both parties' calendars **and** in the existing
personal ICS feed with no extra code. Reschedule updates the event; cancel
deletes it.

`calendar_event_id` is `ON DELETE SET NULL` — losing the projection must never
delete the booking record.

---

## API

Everything below is under `RequireAuth` + `RequireCSRF`. Only the admin group
carries route-level RBAC; booking, cancelling, rescheduling, and rating your own
session are authorized per-row inside the service, because a plain learner does
all of those.

| Method | Path | Notes |
|---|---|---|
| `GET` | `/api/session-booking/config` | Policy + caller's balance |
| `GET` | `/api/session-booking/availability/me` | Mentor's own rules + exceptions |
| `PUT` | `/api/session-booking/availability/me` | Replaces the whole weekly pattern |
| `POST` | `/api/session-booking/availability/me/exceptions` | One-off block or opening |
| `DELETE` | `/api/session-booking/availability/me/exceptions/{id}` | |
| `GET` | `/api/mentors/{mentorID}/slots?from=&to=` | Free **and** taken slots; max 62-day window |
| `POST` | `/api/mentor-sessions` | Book 1:1 |
| `GET` | `/api/mentor-sessions?scope=upcoming\|past\|all` | |
| `GET` | `/api/mentor-sessions/{id}` | Session + feedback + notes |
| `POST` | `/api/mentor-sessions/{id}/cancel` | Returns `CancelResult` |
| `POST` | `/api/mentor-sessions/{id}/reschedule` | |
| `POST` | `/api/mentor-sessions/{id}/outcome` | Mentor only |
| `POST` | `/api/mentor-sessions/{id}/feedback` | Both parties |
| `PUT` | `/api/mentor-sessions/{id}/notes` | Mentor only |
| `GET` | `/api/session-booking/mentees/{studentID}` | Mentor only |
| `GET` | `/api/session-booking/credits` | Balance + ledger |
| `GET` | `/api/session-booking/packs` | `?all=true` includes archived |
| `POST` | `/api/session-booking/packs/{packID}/checkout` | |
| `PATCH` | `/api/session-booking/config` | 🔒 `manage_session_booking` |
| `POST` `PATCH` | `/api/session-booking/packs[/{packID}]` | 🔒 |
| `POST` | `/api/session-booking/credits/grant` | 🔒 |
| `POST` | `/api/batches/{batchID}/sessions` | 🔒 Whole-cohort session |

### Error mapping

| Error | HTTP | Meaning |
|---|---|---|
| `ErrSlotTaken` | 409 | Lost the exclusion-constraint race — refresh the grid |
| `ErrTooManyUpcoming` | 409 | At `max_upcoming_per_student` |
| `ErrInsufficientCredits` | 402 | Balance is zero and the org requires credits |
| `ErrBookingDisabled` | 403 | Org toggle is off |
| `ErrInvalid` | 422 | Message is safe to display |

---

## DB schema

`backend/db/migrations/013_mentor_session_booking.sql`

| Table | Purpose |
|---|---|
| `org_session_booking_config` | Org toggle + booking policy |
| `mentor_availability_rules` | Weekly recurring windows, in the mentor's zone |
| `mentor_availability_exceptions` | One-off blocks and openings |
| `session_credit_packs` | What an org sells |
| `session_pack_purchases` | Pack checkout, confirmed by webhook |
| `session_credit_ledger` | Append-only credit movements |
| `mentor_sessions` | The booking |
| `mentor_session_feedback` | Both parties' ratings |
| `mentor_session_notes` | The mentor's write-up, private by default |

Requires the `btree_gist` extension for the `uuid WITH =` half of the exclusion
constraints. The down migration deliberately does not drop it — the `CREATE
EXTENSION IF NOT EXISTS` is a no-op when something else installed it first.

---

## Frontend

| Route | Purpose |
|---|---|
| `/sessions` | Upcoming + past sessions |
| `/sessions/[sessionId]` | Detail, feedback, notes, cancel/reschedule/outcome |
| `/sessions/credits` | Balance, ledger, pack store |
| `/mentoring/availability` | Mentor's weekly editor + overrides |
| `/mentoring/mentees/[studentId]` | Mentor's view of one mentee |
| `/settings/session-booking` | 🔒 Policy, packs, credit grants |

All server calls go through `lib/server/sessions.ts` — never a raw `fetch`.
