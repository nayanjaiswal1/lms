---
kind: lesson
type: system_design
id_key: interview-prep-45/day-24-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design E-commerce Cart/Checkout"
position: 24
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today zooms into the checkout flow that Day 23 treated at a high level: cart persistence, the checkout state machine, and inventory reservation in full detail. Interviewers narrow to this specific slice because checkout is where every consistency guarantee in an e-commerce system actually gets tested. Cart state must survive across devices/sessions, and the multi-step "reserve, pay, confirm" sequence must never leave the system in a half-completed, inconsistent state.

## Requirements

**Functional**
- Add/remove/update items in a cart; cart persists across sessions and devices.
- Checkout: address, payment, order confirmation.
- Reserve inventory during checkout so two shoppers can't both "win" the last unit.
- Handle payment success and failure paths cleanly, including abandoned checkouts.

**Non-functional**
- Cart operations are low-latency and should feel instant (this is a UI-critical path, users abandon carts over friction).
- Checkout correctness: no double-charging, no overselling, no order created without a corresponding successful payment (or clearly marked as failed/pending).
- Availability for cart operations (losing a cart add due to a transient backend blip is a real UX cost); stronger consistency required specifically at the moment of payment/order-commit.
- Idempotency: retried checkout submissions (double-click, network retry) must not create duplicate orders or duplicate charges.

## Capacity estimates

Assume the same marketplace scale as Day 23: 10M orders/day, and roughly 5x more checkout attempts than completed orders (cart abandonment is real; many industry figures put cart abandonment around 60-80%).
- Cart writes (add/update/remove): assume each shopper touches their cart ~8 times per session, 50M shopping sessions/day → 400M cart operations/day ≈ 4,600/sec average, several times that at peak.
- Checkout attempts: 10M completed orders / (1 - 0.7 abandonment) ≈ 33M checkout attempts/day ≈ 380/sec average.
- Cart size: typically small (a handful of line items), so cart storage per user is tiny (well under 10 KB). This is a latency problem, not a storage-volume problem.
- Idempotency key retention: checkout idempotency keys need to be held long enough to catch realistic retry windows (minutes, not days), a bounded TTL store, not permanent storage.

## API sketch

```
GET  /cart                                  -> { items[], subtotal }
POST /cart/items          { item_id, qty }   -> { items[], subtotal }
PUT  /cart/items/{item_id} { qty }
DELETE /cart/items/{item_id}

POST /checkout/init        { cart_id }                          -> { checkout_id, reserved_items[] }
POST /checkout/{id}/address    { shipping_address }
POST /checkout/{id}/payment    { payment_method }
POST /checkout/{id}/confirm    { idempotency_key }               -> { order_id, status }
GET  /checkout/{id}/status                                        -> { status }
```

## Data model

```
carts             id, user_id (or session_id for guests), updated_at
cart_items         cart_id, item_id, qty

checkouts          id, cart_id, status (started|reserved|paid|confirmed|failed|abandoned),
                   idempotency_key, created_at, expires_at
checkout_reservations  checkout_id, item_id, qty, warehouse_id   -- mirrors inventory.reserved_qty from Day 23

orders             id, checkout_id, user_id, total, status, created_at
order_items        order_id, item_id, qty, price_at_purchase
payments           id, order_id, provider_ref, amount, status, idempotency_key
```

The `checkouts` table is the piece that doesn't exist in a simpler CRUD design. It's the explicit state machine tracking a checkout attempt from start through payment through order confirmation, distinct from both the cart (pre-checkout, mutable, casual) and the order (post-checkout, immutable, authoritative).

## High-level architecture

```
Cart (low-latency, high availability):
Client --> Cart API --> Cart store (Redis, keyed by user_id/session_id, with a periodic
           durable sync to a relational table so a logged-out guest cart can survive a
           Redis restart, or so a login merges a guest cart into the user's account cart)

Checkout (strict correctness):
Client --> POST /checkout/init --> atomically reserve inventory per Day 23's
           available_qty/reserved_qty pattern --> checkout.status = "reserved"
                                                        |
Client --> POST /checkout/{id}/payment --> Payment provider (external) --> webhook/callback
                                                        |
                                     on success: checkout.status = "paid" --> create order
                                     (idempotent, keyed on checkout_id) --> checkout.status = "confirmed"
                                     --> commit reservation (reserved_qty -= qty, permanently sold)
                                                        |
                                     on failure/timeout: checkout.status = "failed" -->
                                     release reservation (available_qty += qty, reserved_qty -= qty)

Abandoned-checkout reaper (background): sweeps checkouts stuck in "started"/"reserved" past
a timeout (e.g., 15-30 min) and releases their reservations, same reaper pattern as Ticketmaster.
```

## Component deep dives

**Cart persistence.** Carts need to survive page refreshes, app restarts, and logins on a different device, but a cart is low-stakes compared to an order, so it should optimize for availability and low latency over strict durability. A common real-world design: cart state lives primarily in a fast key-value store (Redis) keyed by session (guest) or user id (logged in), with periodic/async persistence to a relational table so it isn't purely ephemeral. On login, a guest cart (keyed by session) is merged into the user's persistent cart (keyed by user_id). Merge conflicts (same item in both, different quantities) are resolved with a simple rule (e.g., sum quantities, or prefer the more recently updated cart) since this is a low-stakes UX decision, not a correctness-critical one.

**The checkout state machine, explicitly.** Checkout is not one atomic operation. It's a sequence (`started` → `reserved` → `paid` → `confirmed`, with `failed`/`abandoned` branches) precisely because it coordinates with an external system (the payment provider) whose latency and failure modes are outside your control. Never model checkout as a single database transaction spanning "reserve inventory + call payment provider + create order," since you cannot roll back a call to an external payment API inside a DB transaction. Instead, each state transition is its own, independently retriable and idempotent step, and the `checkouts` table itself is the durable record of "how far did this attempt get," so a crash or retry at any point can resume or correctly unwind from the last known state instead of leaving inconsistent partial writes.

**Idempotency on the confirm step, specifically.** A user double-clicking "Place Order," or a client retrying after a network timeout that actually succeeded server-side, must not create two orders or charge twice. The fix: the client generates (or the checkout flow assigns at `init`) an idempotency key tied to that specific checkout attempt. `POST /checkout/{id}/confirm` is implemented so that a repeated call with the same `checkout_id`/idempotency_key returns the existing result (the already-created order) rather than creating a new one, typically enforced via a unique constraint on `orders.checkout_id` plus a check-before-insert, or an idempotency-key lookup table that short-circuits duplicate requests before they reach the payment provider a second time.

**Reservation timing and the abandoned-checkout reaper.** Inventory is reserved (Day 23's `available_qty`/`reserved_qty` split) as early as `checkout/init`, not at final confirm. This guarantees a shopper who's actively completing checkout won't lose the item to someone else mid-flow. But that reservation must expire if the shopper abandons checkout (closes the tab, gets distracted): a background reaper, identical in shape to Ticketmaster's hold-expiry reaper, sweeps `checkouts` stuck in `started`/`reserved` past a timeout window and releases their reservations back to available inventory. This timeout is a genuine product trade-off: too short and legitimate slow shoppers lose their cart's reserved items; too long and inventory sits needlessly locked during high-demand periods.

**Payment failure and partial-failure recovery.** If payment fails, the fix is straightforward: release the reservation, mark checkout `failed`, let the user retry. The harder case is ambiguous failure, when the payment provider call times out and you genuinely don't know if it succeeded. The correct response is never to blindly retry a raw charge call (risking a double charge). Instead, query the payment provider's status endpoint using the same idempotency key used for the original charge attempt (most payment providers, e.g., Stripe, support idempotency keys precisely for this reason) before deciding whether to retry or treat it as failed. This defers the ambiguity to the one system that actually knows the truth (the payment provider) rather than guessing.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Redis-backed cart with async durable sync | Fast, available cart operations that don't block on strict durability | A rare Redis failure could lose very recent cart edits before they sync; acceptable given carts are low-stakes and recoverable by re-adding items |
| Explicit checkout state machine (not one big transaction) | Correctly coordinates with an external payment provider; crash-safe at every step | More tables/states to design and test than a naive single-transaction approach |
| Reserve inventory at checkout/init, not at confirm | Prevents losing the item to a competing shopper mid-checkout | Requires an abandoned-checkout reaper to avoid inventory sitting locked indefinitely |
| Idempotency keys on confirm + payment charge | Eliminates double-order/double-charge risk from retries/double-clicks | Requires an idempotency-key store with bounded TTL and careful key scoping |

## Likely follow-up questions (with answers)

**Q: A user's payment succeeds, but the server crashes before it can create the order record. What happens on the next request?**
A: The client (having gotten no clear response) retries `POST /checkout/{id}/confirm` with the same idempotency key. The confirm handler first checks whether an order already exists for this `checkout_id` (or checks the payment provider's status using the original idempotency key) before attempting to charge or create anything new. Since the payment already succeeded upstream, the handler detects that state and proceeds to create the order (idempotently, so a second concurrent retry doesn't create two), rather than either double-charging or leaving the user charged with no order. This is exactly why the `checkouts` table's durable state and idempotency keys exist: to make "resume from wherever we actually got to" possible instead of guessing.

**Q: How is a logged-in user's cart merged with the cart they had as a guest before logging in?**
A: On login, look up both the session-keyed guest cart and the user-id-keyed persistent cart, then merge line items. A simple, low-stakes policy (e.g., sum quantities for items present in both, keep items unique to either) is sufficient since a cart merge conflict has no correctness implications, unlike a checkout conflict. The merged result becomes the user's persistent cart going forward, and the guest cart entry is discarded.

**Q: Why reserve inventory at checkout/init instead of waiting until payment actually succeeds?**
A: If reservation waited until payment success, a shopper could enter their address and payment details, spend a minute completing the form, and then be told at the very last step that the item sold out to someone else, a materially worse UX than reserving early. Reserving at `init` trades a temporary inventory lock (bounded by the abandoned-checkout reaper's timeout) for a checkout flow that, once started, is very unlikely to fail due to a stock race. The same trade-off Ticketmaster makes with its seat holds.

## Key takeaways

- Cart storage optimizes for availability and low latency; checkout optimizes for strict correctness. Know which guarantee applies to which layer and why they differ, since conflating the two leads to either a sluggish cart or a checkout flow with a real consistency hole.
- This lesson is the checkout section from Day 23 under a microscope. Recognize when an interview question is asking you to go deeper on a sub-system you've already sketched, rather than starting from zero.
