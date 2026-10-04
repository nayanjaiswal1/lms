---
kind: lesson
type: system_design
id_key: interview-prep-45/day-24-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design an E-commerce Cart, Checkout, and Catalog"
position: 19
estimated_minutes: 80
source:
    - 45-day-interview-roadmap.md
---

An e-commerce store like Amazon has three parts that behave completely differently: a huge, read-heavy catalog people browse constantly, a cart that needs to feel instant, and a checkout flow that has to be perfectly correct, no overselling, no double charges, ever. This question is deliberately broad, so interviewers can watch you scope it: which part do you design deeply, and which do you sketch?

## Requirements

**Functional requirements**
- Browse and search a product catalog with availability shown per item.
- Add, remove, and update items in a cart, and the cart persists across sessions and devices.
- Checkout collects address and payment and confirms an order.
- Purchases decrement inventory correctly, with zero overselling.
- Returns and refunds update inventory and order state correctly.
- Recommendations, "customers also bought," personalized to the shopper.

**Non-functional requirements**
- Zero overselling, the same class of correctness problem as a ticket-booking system, applied to inventory counts instead of seats.
- High read throughput on the catalog; browsing vastly outnumbers buying.
- Cart operations must feel instant, since friction here is a direct cause of abandoned carts.
- Checkout correctness: no double-charging, no order created without a successful payment, or one clearly marked failed or pending.
- Idempotency: a retried checkout submission, from a double-click or a network retry, must never create a duplicate order or a duplicate charge.
- Consistency on inventory counts is required at the moment of purchase; eventual consistency is fine for search freshness and recommendations.

> **Remember:** cart storage optimizes for availability and speed; checkout optimizes for strict correctness. Conflating the two gives you either a sluggish cart or a checkout flow with a real consistency hole.

```knowledge-check
{ "questions": [
    { "id": "system-design-ecommerce-requirements-q1", "type": "mcq", "prompt": "Why do cart operations and checkout operations need different consistency guarantees?", "options": [
        {"id": "a", "text": "They don't, both should use the strongest possible consistency"},
        {"id": "b", "text": "A cart is low-stakes and recoverable, so it should favor speed and availability, while checkout involves real money and inventory, so it must favor strict correctness"},
        {"id": "c", "text": "Carts are always stored client-side only"},
        {"id": "d", "text": "Checkout doesn't actually need to be consistent, only fast"}
    ], "correct": "b", "explanation": "The cost of getting each one wrong is completely different: losing a cart edit is a minor annoyance fixed by re-adding an item, while a checkout consistency bug means a real double charge or a real oversold item." }
] }
```

## Estimates

Assume a large marketplace: 100 million active SKUs and 10 million orders a day.

- **Orders:** 10,000,000 / 86,400 ≈ 116/sec average, 500+/sec at peak during a flash sale or holiday rush.
- **Catalog browsing dominates:** with roughly 20 page views per completed order, catalog reads outnumber purchase writes by somewhere between 100:1 and 1000:1, the same read-skew shape seen in a social feed, which justifies the same response: aggressive caching, and a search index kept separate from the transactional inventory store.
- **Cart traffic:** if each shopper touches their cart about 8 times per session across 50 million daily sessions, that's 400 million cart operations/day, roughly 4,600/sec average, several times higher at peak. Cart size itself is tiny, a handful of line items, well under 10 KB, so this is a latency problem, not a storage problem.
- **Checkout attempts:** with cart abandonment commonly in the 60-80% range, 10 million completed orders imply roughly 33 million checkout attempts/day, about 380/sec average.
- **Inventory contention:** most SKUs see no contention at all, but a flash-sale item with limited stock creates the exact same 100:1 contention shape as a ticket on-sale, concentrated on a small number of hot rows.
- **Returns:** assume roughly 5% of orders are returned within 30 days, a real secondary write path that must never corrupt inventory counts.

## API

```
GET  /catalog/search?q=&cursor=                    -> { items[], next_cursor }
GET  /items/{id}                                     -> { details, price, available_qty }

GET  /cart                                  -> { items[], subtotal }
POST /cart/items          { item_id, qty }   -> { items[], subtotal }
PUT  /cart/items/{item_id} { qty }
DELETE /cart/items/{item_id}

POST /checkout/init        { cart_id }                          -> { checkout_id, reserved_items[] }
POST /checkout/{id}/address    { shipping_address }
POST /checkout/{id}/payment    { payment_method }
POST /checkout/{id}/confirm    { idempotency_key }               -> { order_id, status }
GET  /checkout/{id}/status                                        -> { status }

GET  /orders/{id}                                     -> { status, items[], tracking }
POST /orders/{id}/return   { item_ids[], reason }     -> { return_id, status }
GET  /recommendations?item_id=  or  ?user_id=
```

## Data model

```
items              id, name, description, price, category
inventory          item_id, warehouse_id, available_qty, reserved_qty   -- split available vs reserved

carts             id, user_id (or session_id for guests), updated_at
cart_items         cart_id, item_id, qty

checkouts          id, cart_id, status (started|reserved|paid|confirmed|failed|abandoned),
                   idempotency_key, created_at, expires_at
checkout_reservations  checkout_id, item_id, qty, warehouse_id   -- mirrors inventory.reserved_qty

orders             id, checkout_id, user_id, total, status, created_at
order_items        order_id, item_id, qty, price_at_purchase
payments           id, order_id, provider_ref, amount, status, idempotency_key
returns            id, order_id, item_id, qty, status (requested|received|refunded), created_at

-- search is a separate, async-indexed system
item_search        item_id, tokens[], category, price, rating
```

Two design decisions live in this schema. Splitting `available_qty` from `reserved_qty` on the inventory row, instead of one raw count, is what lets checkout reserve stock atomically without yet committing to a completed sale. And the `checkouts` table is the piece a simpler CRUD design wouldn't have: an explicit state machine tracking one checkout attempt from start through payment through order confirmation, distinct from the cart (pre-checkout, casual, mutable) and the order (post-checkout, immutable, authoritative).

```knowledge-check
{ "questions": [
    { "id": "system-design-ecommerce-datamodel-q1", "type": "mcq", "prompt": "Why does the inventory table split available_qty and reserved_qty instead of using one raw stock count?", "options": [
        {"id": "a", "text": "It's purely for reporting purposes"},
        {"id": "b", "text": "It lets checkout atomically claim stock the moment a purchase starts, without yet committing to a sale that payment might still fail"},
        {"id": "c", "text": "Databases require at least two columns per table"},
        {"id": "d", "text": "It has no functional purpose, only historical convention"}
    ], "correct": "b", "explanation": "Payment can take time and can fail. Splitting the count lets the system reserve stock immediately at checkout start, then either commit it on payment success or release it back to available on failure." }
] }
```

## High-level design

```
Browse/search path (read-heavy):
Client --> Search API --> item_search (async-indexed from items/inventory changes)
         --> Catalog API --> cached item details (in front of items/inventory DB)

Cart (low-latency, high availability):
Client --> Cart API --> Cart store (fast key-value store, keyed by user_id/session_id, with a
           periodic durable sync so a guest cart survives a restart, or a login merges a
           guest cart into the user's account cart)

Checkout (strict correctness):
Client --> POST /checkout/init --> atomically reserve inventory:
             UPDATE inventory SET available_qty = available_qty - qty, reserved_qty = reserved_qty + qty
             WHERE item_id=$id AND available_qty >= qty
           --> checkout.status = "reserved"
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
a timeout (e.g., 15-30 min) and releases their reservations.

Returns path:
Client --> Returns API --> return.status = requested --> (warehouse receives item) -->
           return.status = received --> inventory.available_qty += qty --> trigger refund -->
           return.status = refunded
```

## Deep dives

### How do you prevent overselling, exactly?

Same mechanism as a ticket-booking system: an atomic conditional update on the inventory row.

```
UPDATE inventory SET available_qty = available_qty - qty
WHERE item_id = $id AND available_qty >= qty
```

If zero rows are affected, there wasn't enough stock, and checkout fails immediately with a clear "insufficient inventory" response, rather than proceeding into a state that would require an awkward rollback. For a high-contention flash-sale item, the same Redis-based reservation pattern used for ticket sales, an atomic decrement with a bound check, trades a small consistency window for much higher throughput than hitting the relational database on every attempt. Since inventory is a quantity rather than discrete labeled seats, the check `available_qty >= requested_qty` also naturally supports partial-fulfillment logic ("only 1 left, but you asked for 2"), which a seat system doesn't need.

### Why split reserved from available instead of decrementing straight to "sold"?

Payment processing takes real time, sometimes several seconds with fraud checks, and it can fail. If inventory were decremented straight to "sold" before payment confirms, a failed payment would mean carefully reversing a state that other concurrent purchases may already be relying on. Splitting into `available_qty` (purchasable right now) and `reserved_qty` (claimed, pending payment) makes the state machine explicit: reserve atomically when checkout starts, then either commit (payment succeeds, order confirmed) or release (payment fails or times out, stock returns to available). This needs a background reaper too, the same shape as releasing an expired ticket hold, for reservations stuck in "reserved" past a timeout, so an abandoned checkout doesn't lock inventory forever.

> **Remember:** reserve early, at the start of checkout, not at the final confirm step. Losing an item to a competing shopper in the middle of filling out a shipping form is a far worse experience than a small, bounded inventory lock.

```knowledge-check
{ "questions": [
    { "id": "system-design-ecommerce-reservation-q1", "type": "mcq", "prompt": "Why does inventory get reserved at checkout/init rather than waiting until payment actually succeeds?", "options": [
        {"id": "a", "text": "Reserving early has no real benefit"},
        {"id": "b", "text": "Waiting until payment success risks a shopper completing the entire checkout form only to be told at the last step that the item sold out"},
        {"id": "c", "text": "Payment providers require inventory to be reserved before they'll process a charge"},
        {"id": "d", "text": "Reserving late would make the database faster"}
    ], "correct": "b", "explanation": "Reserving at init trades a temporary, bounded inventory lock for a checkout flow that, once started, is very unlikely to fail due to a stock race partway through." }
] }
```

### How does cart persistence work, and how do guest and logged-in carts merge?

A cart needs to survive a page refresh, an app restart, and a login from a different device, but it's low-stakes compared to an order, so it should optimize for availability and speed over strict durability. The common real-world design: cart state lives primarily in a fast key-value store keyed by session (guest) or user ID (logged in), with periodic async persistence to a relational table so it isn't purely ephemeral. On login, a guest cart merges into the user's persistent cart; a simple rule (sum quantities for items in both, keep items unique to either) is enough, since a cart merge conflict has no correctness implications, unlike a checkout conflict.

### Why isn't checkout one big database transaction?

Checkout is a sequence, `started` → `reserved` → `paid` → `confirmed`, with `failed` and `abandoned` branches, precisely because it coordinates with an external system, the payment provider, whose latency and failure modes you don't control. You cannot roll back a call to an external payment API inside a database transaction, so checkout can't be modeled as one atomic operation spanning "reserve inventory, call payment provider, create order." Instead, each state transition is its own independently retriable, idempotent step, and the `checkouts` table itself is the durable record of how far an attempt got, so a crash or retry at any point can resume or correctly unwind from the last known state instead of leaving an inconsistent partial write behind.

### How do you stop a double-click or a network retry from creating two orders?

The client generates, or the checkout flow assigns at `init`, an idempotency key tied to that specific checkout attempt. `POST /checkout/{id}/confirm` is built so a repeated call with the same key returns the existing result, the order already created, rather than making a new one. This is typically enforced with a unique constraint on `orders.checkout_id` plus a check-before-insert, or a dedicated idempotency-key lookup table that short-circuits a duplicate request before it ever reaches the payment provider a second time.

The trickiest case is an ambiguous failure: the payment call times out and you genuinely don't know whether it succeeded. Never blindly retry a raw charge call here, that risks a real double charge. Instead, query the payment provider's own status endpoint using the same idempotency key as the original attempt (most providers support exactly this) before deciding whether to retry or treat it as failed. This defers the ambiguity to the one system that actually knows the truth.

### How do multiple warehouses and returns fraud get handled?

Real marketplaces track inventory per warehouse, not as one global count, and checkout has to pick which warehouse fulfills an order, usually the nearest one with enough stock. That turns the single-row atomic update into a routing decision first, then the same reserve-then-commit pattern against the chosen warehouse's row. If no single warehouse has enough stock, an order can split across warehouses into multiple shipments.

A return is its own multi-step workflow that has to survive partial failure: requested, then received at the warehouse, verified before crediting inventory to prevent a refund claimed without the item actually being returned, then inventory restored, then refund issued. Model this as an explicit state machine rather than one transaction, since "received at the warehouse" is an external, asynchronous event that can't live inside a database transaction. Each transition should be independently idempotent, since a step like issuing a refund may itself need retries against a flaky payment provider.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Available/reserved split with an atomic conditional update | Zero overselling without long-held locks | Needs a reservation-timeout reaper for abandoned checkouts |
| Redis-backed cart with async durable sync | Fast, available cart operations | A rare failure could lose very recent cart edits, acceptable since carts are low-stakes and recoverable |
| Explicit checkout state machine, not one transaction | Correctly coordinates with an external payment provider, crash-safe at every step | More states to design and test than a naive single-transaction approach |
| Reserve inventory at checkout/init, not at confirm | Prevents losing the item to a competing shopper mid-checkout | Needs an abandoned-checkout reaper so inventory doesn't sit locked indefinitely |
| Idempotency keys on confirm and on the payment charge | Eliminates double-order and double-charge risk from retries | Needs an idempotency-key store with a bounded TTL and careful scoping |
| Explicit returns state machine | Survives partial failure, prevents return fraud via receipt verification | Refunds aren't instant; the user sees a multi-step status |

**Q: A flash sale drops 1,000 units of a popular item, and 50,000 people try to buy it in the first minute. How is this different from a ticket on-sale, if at all?**
A: Structurally identical: the same 100:1 contention shape, just applied to a quantity instead of discrete seats. The same atomic conditional decrement, or Redis-based reservation, prevents overselling, and the same reserve-then-commit pattern applies. If demand is extreme enough, a waiting-room layer ahead of checkout keeps the same contention off the hot path.

**Q: A user's payment succeeds, but the server crashes before it can create the order record. What happens on the next request?**
A: The client retries confirm with the same idempotency key. The handler first checks whether an order already exists for this checkout, or checks the payment provider's status using the original key, before attempting to charge or create anything new. Since payment already succeeded upstream, it detects that and creates the order idempotently, rather than double-charging or leaving the user charged with no order.

**Q: How do you prevent a user from claiming a refund without actually returning the item?**
A: The returns state machine requires an explicit "received at warehouse" transition, verified by staff or a scanning process, before inventory is restored and a refund triggers. Nothing is credited purely on the basis of a customer's request, the same principle as verifying a claimed action before trusting it, used elsewhere for view-count fraud.

```knowledge-check
{ "questions": [
    { "id": "system-design-ecommerce-tradeoffs-q1", "type": "mcq", "prompt": "Why must a payment timeout never be handled by simply retrying the raw charge call?", "options": [
        {"id": "a", "text": "Retrying is always fine as long as it's fast"},
        {"id": "b", "text": "A timeout means the outcome is genuinely unknown, and blindly retrying the charge risks a real double charge if the original request actually succeeded"},
        {"id": "c", "text": "Payment providers block all retries automatically"},
        {"id": "d", "text": "Retrying would violate the idempotency key format"}
    ], "correct": "b", "explanation": "The correct response to an ambiguous timeout is to check the payment provider's own status endpoint with the original idempotency key, deferring to the system that actually knows what happened, rather than guessing and risking a double charge." }
] }
```
