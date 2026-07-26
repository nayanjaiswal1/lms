---
kind: lesson
type: system_design
id_key: interview-prep-45/day-18-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Airbnb"
position: 18
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Airbnb combines two hard problems interviewers love pairing: **search with geospatial and faceted filters** over a large, frequently-changing catalog, and **booking correctness** — guaranteeing no two guests can double-book the same property for overlapping dates under concurrent requests. It's a good test of whether you know when to reach for strong consistency versus when eventual consistency is fine.

## Requirements

**Functional**
- Hosts list properties with details, photos, pricing, and availability calendars.
- Guests search listings by location, dates, price, and amenity filters.
- Guests book a listing for a date range; booking must not overlap an existing reservation.
- Payments are processed and split (guest charge, host payout, platform fee) after booking.
- Guests and hosts leave reviews after a completed stay.

**Non-functional**
- No double-booking, ever — this is the one hard consistency requirement in the whole system.
- Search must be fast (sub-second) despite complex geo + filter queries over millions of listings.
- High availability for browsing/search; booking can tolerate slightly higher latency in exchange for correctness.
- Search results can be a few minutes stale (eventual consistency); booking state must be immediately consistent.

## Capacity estimates

- 7M active listings worldwide, 150M users, ~2M bookings/day.
- Bookings/day → 2M / 86,400 ≈ ~23 bookings/sec average, spiking maybe 5-10x for flash sales or peak booking windows (e.g., holiday planning season) → ~150-200 bookings/sec peak — moderate load, well within a well-indexed relational database's capability *if* you design the locking correctly.
- Search traffic dominates: assume 150M users doing a handful of searches/month during active trip planning → tens of millions of searches/day → hundreds of searches/sec average, bursting several times higher — most of this hits a search index, not the booking database.
- Listing data: 7M listings × ~5KB metadata + ~20 photos × ~200KB ≈ ~28 TB of images alone — served from object storage + CDN, same pattern as Spotify's audio.
- Availability calendar: each listing has ~365 days × a boolean/price entry ≈ negligible per listing, but 7M listings × 365 ≈ 2.5B calendar-day rows if modeled naively per-day — this shapes how you model availability (see data model below): sparse blocked-date storage beats a dense per-day row for most listings.

## API sketch

```
GET  /v1/search?lat=&lng=&radius_km=&checkin=&checkout=&guests=&filters=...
  resp: [{ listing_id, title, price_per_night, thumbnail, rating, distance_km }, ...]

GET  /v1/listings/{listing_id}
GET  /v1/listings/{listing_id}/availability?start=&end=

POST /v1/bookings
  body: { listing_id, checkin, checkout, guests, payment_method_id }
  resp: { booking_id, status: "confirmed" } | 409 Conflict { reason: "dates_unavailable" }

POST /v1/bookings/{booking_id}/cancel
POST /v1/listings/{listing_id}/reviews
  body: { rating, text }
```

`POST /v1/bookings` returning a `409` on a race-lost double-booking attempt is the detail interviewers listen for — it signals you've thought about the concurrency case, not just the happy path.

## Data model

```
Listing(listing_id PK, host_id, title, description, lat, lng, geohash,
        base_price_cents, amenities[], max_guests, status)
BlockedDate(listing_id FK, date, reason[booked|host_blocked], booking_id NULLABLE)
  -- sparse: only dates that are unavailable get a row, not all 365 days
Booking(booking_id PK, listing_id FK, guest_id, checkin, checkout,
        status[pending|confirmed|cancelled], total_price_cents, created_at)
Payment(payment_id PK, booking_id FK, guest_charge_cents, host_payout_cents,
        platform_fee_cents, status, idempotency_key)
Review(review_id PK, booking_id FK, author_id, target[host|guest], rating, text)
```

`BlockedDate` is sparse — most listing-days are available, so only booked/blocked dates get rows. A `UNIQUE(listing_id, date)` constraint is what actually prevents double-booking at the database level (see deep dive).

## High-level architecture

```
[Guest App]                         [Host App]
     |                                   |
              [API Gateway]
                    |
   +----------------+-----------------+
   |                |                 |
[Search Service] [Booking Service] [Listing Service]
   |                |                 |
[Search Index    [Booking DB       [Listing DB +
 (Elasticsearch,  (relational,      Object Storage/CDN
 geo + facets)]    strong           for photos]
   ^               consistency)]
   |                    |
   +---sync via CDC-----+
                         |
                  [Payment Service] --> external payment gateway
```

- **Listing Service** is the source of truth for listing metadata; changes propagate to the search index asynchronously via change-data-capture, which is why search results can lag reality by a few minutes (acceptable trade-off).
- **Booking Service** owns the one part of the system that must be strongly consistent: the availability check + reservation write happens as a single atomic operation against the booking database.
- **Search Service** is read-optimized and denormalized (Elasticsearch or similar) — it never talks to the booking database directly, so search load never contends with the booking write path.

## Component deep dives

### Booking system with date locking (the double-booking problem)

This is the question's centerpiece. The wrong answer is "check availability, then insert" as two separate steps — that's a classic TOCTOU (time-of-check-to-time-of-use) race: two guests can both pass the "is it available?" check before either writes their booking.

The correct answer: make the reservation **atomic** using a database constraint, not application logic. Two solid approaches:

1. **Unique constraint on `(listing_id, date)` in `BlockedDate`**: when a guest books a 3-night stay, insert one row per date in a single transaction. If any date already has a row, the unique constraint violates and the whole transaction rolls back — the database itself rejects the double-booking, no explicit locking code needed. This is the simplest correct answer and the one to lead with.
2. **Row-level lock on the listing during the booking transaction** (`SELECT ... FOR UPDATE` on a listing-level lock row) if you want a single lock rather than N per-night rows — simpler to reason about for long stays, but serializes all bookings for a listing (fine, since one listing's booking volume is inherently low).

Either way: the guest sees search results with tentative availability, but the actual reservation is only confirmed by winning the database-level atomic write at booking time. Present this to a losing guest as a `409 Conflict` with a prompt to pick different dates — never silently overwrite.

### Search with filters

Denormalize listing data (price, location, amenities, rating, current approximate availability) into a search index (Elasticsearch) that supports combined geo-radius + facet + full-text queries efficiently. Geospatial queries use the same geohash/cell-indexing idea as Day 15's Uber design. Availability in the search index is a fast-but-approximate signal ("likely available") — it's fine for filtering search results even if slightly stale, because the actual booking attempt re-validates against the authoritative `BlockedDate` table.

### Handling payments

Split payment happens after a booking is confirmed: charge the guest, hold funds (common pattern: capture immediately, payout to host on a delay, e.g., 24 hours after check-in, to allow for early cancellation/dispute windows), and record the platform fee. Use an idempotency key on the payment request tied to the `booking_id` so retries (network blips, client double-submits) never double-charge — same pattern as Day 25's payment system design.

### Review system

Reviews are only allowed after a completed stay (`booking.status == completed` and checkout date has passed), enforced server-side, not just in the UI. To avoid retaliatory reviews influencing honesty, use a **double-blind reveal**: both guest and host submit reviews independently, and neither is shown publicly until both have submitted or a fixed window (e.g., 14 days) expires — this is a real Airbnb mechanism worth naming if the interviewer asks about review system design.

## Scaling & trade-offs

| Concern | Choice | Trade-off |
|---|---|---|
| Double-booking prevention | DB unique constraint / row lock at booking time, not application-level check-then-write | Correct under concurrency; slightly higher write latency per booking (acceptable given booking volume is moderate) |
| Search freshness | Async CDC sync from listing DB to search index | Search can lag by minutes; keeps search load fully isolated from booking writes |
| Availability calendar storage | Sparse `BlockedDate` rows, not dense per-day rows | Scales with actual bookings, not listings × 365 |
| Payment timing | Capture on booking, payout to host after a delay window | Protects against cancellation/dispute churn; adds payout-scheduling complexity |
| Review integrity | Double-blind submission with reveal window | Reduces retaliatory/biased reviews; adds a pending-review state to track |

## Likely follow-up questions — with answers

**Q: Two guests click "book" on the same last-available night within the same millisecond. Walk through exactly what happens.**
A: Both requests reach the Booking Service and each opens a transaction attempting to insert a `BlockedDate(listing_id, date)` row (or acquire the listing's row lock). The database serializes the two transactions; the first to commit succeeds, the second hits the unique constraint violation (or waits on the lock and then sees the date already taken), and the Booking Service returns `409 Conflict` to the loser with a message to pick different dates. No distributed lock or external coordination service is needed — the relational database's ACID guarantees handle it.

**Q: How would you support instant-book vs. host-approval-required listings?**
A: Add a `requires_approval` flag on `Listing`. For approval-required listings, the booking flow creates a `Booking` in `pending` status and places a **temporary hold** on the dates (still via the same unique-constraint mechanism, so no one else can book those dates) with an expiry (e.g., 24 hours); if the host doesn't approve in time, a background job releases the hold by deleting the pending `BlockedDate` rows.

**Q: How do you keep search fast when filtering on dozens of amenity facets across millions of listings?**
A: This is exactly what a dedicated search engine is for — Elasticsearch (or similar) maintains inverted indexes per facet field, so a query like "wifi AND pool AND pet-friendly within 10km" is a fast intersection of posting lists rather than a table scan; this is why listing search is deliberately not served from the relational booking database.

## Key takeaways

- The one hard consistency requirement is the booking write — solve it with a database-level unique constraint or lock, never a check-then-write race in application code.
- Everything else (search, browsing, listing display) can and should be eventually consistent and served from a denormalized, async-synced search index.
- Model availability sparsely (blocked dates only), not as a dense calendar table — it scales with actual usage, not catalog size × days.
- Idempotency keys on payment requests prevent double-charging on client retries — a pattern that recurs across nearly every payment-adjacent system design question.
- Double-blind review reveal is a concrete, nameable mechanism for review integrity — worth citing directly if asked.
