---
kind: lesson
type: system_design
id_key: interview-prep-45/day-23-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 23 — Design Amazon/Library System"
position: 23
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today's prompt is deliberately broad ("Amazon/Library System") because interviewers use it to see whether you can scope an ambiguous problem yourself. We'll design the e-commerce inventory-and-catalog core (the part that generalizes to a library's "item availability" problem too): product catalog, inventory management with correct stock counts under concurrent purchases, recommendations, and returns — the connective tissue between yesterday's YouTube catalog problem and tomorrow's checkout/payment problems.

## Requirements

**Functional**
- Browse/search a product catalog with availability shown per item.
- Purchase decrements inventory correctly, with zero overselling.
- Recommendations ("customers also bought," personalized).
- Returns and refunds update inventory and order state correctly.

**Non-functional**
- Zero overselling — the same class of correctness requirement as Ticketmaster's zero-double-booking, applied to inventory counts instead of seats.
- High read throughput on the catalog (browsing dominates purchasing, similar read:write skew to the feed systems from week one).
- Consistency on inventory counts at the moment of purchase; eventual consistency acceptable for "customers also bought" and search index freshness.
- Returns must reliably reconcile inventory and refund state even if a step fails partway through (multi-step workflow correctness).

## Capacity estimates

Assume a large marketplace: 100M active SKUs, 10M orders/day.
- Orders: 10M / 86,400 ≈ 116 orders/sec average, 500+/sec peak (flash sales, holiday peaks).
- Catalog browsing: assume 20 page views per order on average across all shoppers (most browse without buying) → catalog reads dominate at roughly 100:1 to 1000:1 versus purchase-writes, same shape as the feed/Twitter read-skew from week one — justifying the same response: aggressive caching of catalog/product-detail pages, search index separate from the transactional inventory store.
- Inventory contention: not every SKU is contended, but flash-sale items (a specific popular SKU with limited stock) create the exact 100:1-contention shape from Ticketmaster on a small subset of hot rows.
- Returns: assume 5% of orders are returned within 30 days — a meaningful secondary write path that must not corrupt inventory counts.

## API sketch

```
GET  /catalog/search?q=&cursor=                    -> { items[], next_cursor }
GET  /items/{id}                                     -> { details, price, available_qty }
POST /cart/items          { item_id, qty }
POST /checkout              { cart_id, payment_info, shipping_address }  -> { order_id, status }
GET  /orders/{id}                                     -> { status, items[], tracking }
POST /orders/{id}/return   { item_ids[], reason }     -> { return_id, status }
GET  /recommendations?item_id=  or  ?user_id=
```

## Data model

```
items              id, name, description, price, category
inventory          item_id, warehouse_id, available_qty, reserved_qty   -- split available vs reserved
orders             id, user_id, status, total, created_at
order_items        order_id, item_id, qty, price_at_purchase
returns            id, order_id, item_id, qty, status (requested|received|refunded), created_at

-- search is a separate, async-indexed system (same pattern as Twitter's search, Day 10)
item_search        item_id, tokens[], category, price, rating
```

Splitting `available_qty` from `reserved_qty` on the inventory row (rather than one raw count) is what lets checkout reserve stock atomically without yet committing to a completed sale — the same hold-then-commit shape as Ticketmaster's seat holds, applied to inventory units instead of seats.

## High-level architecture

```
Browse/search path (read-heavy):
Client --> Search API --> item_search (Elasticsearch, async-indexed from items/inventory changes)
         --> Catalog API --> cached item details (Redis in front of items/inventory DB)

Purchase path (must be correct under contention):
Client --> Checkout API --> atomically reserve inventory:
             UPDATE inventory SET available_qty = available_qty - qty, reserved_qty = reserved_qty + qty
             WHERE item_id=$id AND available_qty >= qty
           --> on success: create order (status=pending) --> process payment
           --> on payment success: reserved_qty -= qty, order.status = confirmed
           --> on payment failure: available_qty += qty, reserved_qty -= qty (release reservation), order.status = failed

Returns path:
Client --> Returns API --> return.status = requested --> (warehouse receives item) -->
           return.status = received --> inventory.available_qty += qty --> trigger refund -->
           return.status = refunded
```

## Component deep dives

**Preventing overselling.** Same fundamental mechanism as Ticketmaster's seat holds (Day 20): an atomic conditional update on the inventory row — `UPDATE inventory SET available_qty = available_qty - qty WHERE item_id = $id AND available_qty >= qty`. If the affected row count is zero, there wasn't enough stock, and checkout fails immediately with a clear "insufficient inventory" response rather than proceeding to a state that would require an awkward rollback. For high-contention flash-sale SKUs, the same Redis-based reservation pattern from Ticketmaster (atomic decrement with a bound check, e.g., a Lua script for atomicity in Redis) trades a small consistency window for much higher throughput than hitting the relational DB directly on every purchase attempt.

**Reserved vs. available quantity — why not just decrement directly to "sold."** Payment processing takes time (seconds, sometimes longer with 3D-Secure or fraud checks) and can fail. If inventory were decremented straight to "sold" before payment confirms, a failed payment would require carefully reversing a state that other concurrent purchases may have already built on top of. Splitting into `available_qty` (what's purchasable right now) and `reserved_qty` (claimed, pending payment) makes the state machine explicit: reserve atomically at checkout start, then either commit (payment succeeds — reserved stock is consumed, order confirmed) or release (payment fails/times out — reserved stock returns to available). This mirrors Ticketmaster's hold-then-checkout pattern precisely, including needing a background reaper that releases reservations stuck in "reserved" past a timeout (e.g., an abandoned checkout where the client never calls back).

**Inventory across multiple warehouses.** Real marketplaces don't have one inventory count per item — they have per-warehouse counts, and checkout needs to pick which warehouse fulfills a given order (typically nearest-to-shipping-address with sufficient stock, to minimize shipping time/cost). This turns the single-row atomic update into a routing decision first ("which warehouse(s) can fulfill this") followed by the same atomic reserve-then-commit pattern against the chosen warehouse's row. If no single warehouse has enough stock, the order may split across warehouses (multiple shipments) — a detail worth mentioning if the interviewer pushes on realism.

**Handling returns and refunds correctly.** A return is itself a multi-step workflow that must survive partial failure: request received → physical item received at warehouse (verified before crediting inventory, to prevent return fraud where a refund is claimed without actually returning the item) → inventory restored (`available_qty += qty`) → refund issued to the original payment method. Model this explicitly as a state machine (`returns.status` transitions) rather than one big transaction, since "physical item received at warehouse" is an external, asynchronous event that can't be part of a database transaction. Each state transition should be independently idempotent (safe to retry/replay) since a step like refund issuance may itself need retries against a flaky payment provider.

**Recommendations.** Same offline-batch-plus-cached-serving pattern as Netflix/YouTube (Days 13, 22): collaborative filtering ("customers who bought X also bought Y") blended with content-based signals (category, price range, brand), computed from the order history event stream, refreshed periodically, served from a cache. Cold start for a brand-new item with no purchase history falls back to content-based similarity until enough co-purchase data accumulates — the identical cold-start pattern from every recommendation system this course has covered.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Available/reserved split + atomic conditional update | Zero overselling without long-held locks | Requires a reservation-timeout reaper to release abandoned checkouts |
| Redis-based reservation for hot SKUs | High throughput under flash-sale contention | A second system that must stay consistent with the DB source of truth |
| Separate search index (Elasticsearch) | Catalog search scales independently of the transactional inventory path | Indexing lag; search results can briefly lag real inventory changes |
| Per-warehouse inventory rows | Enables shipping-cost/time optimization, supports split shipments | More complex checkout routing logic than a single global count |
| Explicit returns state machine | Survives partial failure, prevents return fraud via receipt verification | Refund isn't instant — user sees a multi-step status instead of immediate credit |

## Likely follow-up questions — with answers

**Q: A flash sale drops 1,000 units of a popular item, and 50,000 people try to buy it in the first minute. How does this differ from your Ticketmaster design, if at all?**
A: Structurally identical — this is the 100:1-contention shape from Ticketmaster applied to inventory quantity instead of discrete seats. The same atomic conditional decrement (or Redis-based reservation with a Lua script for atomicity) prevents overselling, and the same hold-then-commit pattern (reserve at checkout start, commit or release based on payment outcome) applies. If the flash-sale traffic is extreme enough, a waiting-room admission layer (also from Ticketmaster) ahead of checkout keeps the same contention off the hot path. The one addition: since inventory is a quantity, not discrete labeled seats, the conditional check is `available_qty >= requested_qty`, allowing partial fulfillment logic (e.g., "only 1 left, but you requested 2") that a seat system doesn't need.

**Q: How do you prevent a user from claiming a refund without actually returning the item?**
A: The returns state machine requires an explicit "received at warehouse" transition, verified by warehouse staff/scanning process, before inventory is restored and refund is triggered — `available_qty` is never incremented and no refund is issued purely on the basis of a customer's return *request*. This is the return-fraud-prevention equivalent of view-count fraud detection (Day 22) — never credit a claimed action until an independent, verifiable signal confirms it happened.

**Q: Your catalog search index and the real-time inventory count can disagree briefly — a search result shows an item as in-stock that just sold out. Is that acceptable, and how do you bound it?**
A: Yes — this is the same eventual-consistency trade-off as search freshness in the Twitter design (Day 10). The search index is fed asynchronously from inventory-change events, so there's an indexing lag (typically seconds). It's acceptable because the *authoritative* check happens at checkout time via the atomic conditional update against the real inventory row — the search result is only ever a hint to click into an item, not the final word on availability. Bound the lag by monitoring indexer queue depth and alerting if it grows unboundedly, which would signal a real freshness problem rather than the expected few-second lag.

## Key takeaways

- Overselling prevention is the same atomic-conditional-update mechanism as Ticketmaster's double-booking prevention, applied to a quantity instead of a discrete resource — recognize and reuse the pattern.
- Splitting `available_qty`/`reserved_qty` (instead of one raw count) makes the reserve-then-commit-or-release state machine explicit and is what makes payment failures cleanly reversible.
- Per-warehouse inventory turns checkout into a routing decision (which warehouse fulfills this) layered on top of the same atomic reservation logic.
- Returns are a multi-step, partially-external workflow — model them as an explicit state machine with idempotent transitions, and never credit inventory/refund without an independent verification step (fraud prevention).
- Catalog search is a separate, asynchronously-indexed system exactly like Twitter's search — the authoritative stock check always happens at checkout against the real inventory row, not against the search index.
- Recommendations reuse the same offline-batch-plus-cache pattern and cold-start fallback seen in every recommendation system this course covers — it's a solved shape, not a new problem each time.

## Today's checklist

- [ ] Write functional requirements: inventory, recommendations.
- [ ] Write non-functional requirements: consistency on inventory counts.
- [ ] Design inventory management with atomic reserve-then-commit and zero overselling.
- [ ] Design the recommendation system (collaborative + content-based, cold start).
- [ ] Design the returns/refunds workflow as an explicit state machine.
- [ ] Discuss scalability: read-heavy catalog caching vs. write-contended checkout path.
