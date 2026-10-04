---
kind: lesson
type: system_design
id_key: interview-prep-45/day-18-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design Airbnb"
position: 17
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

Airbnb pairs two hard problems interviewers like testing together: search over a huge, constantly-changing catalog with location and filter queries, and booking correctness, guaranteeing two guests can never both book the same property for overlapping dates. It's a great test of knowing exactly when to reach for strong consistency and when eventual consistency is fine.

## Requirements

**Functional requirements**
- Hosts list properties with details, photos, pricing, and an availability calendar.
- Guests search listings by location, dates, price, and amenity filters.
- Guests book a listing for a date range; a booking must never overlap an existing reservation.
- Payments are processed and split (guest charge, host payout, platform fee) after booking.
- Guests and hosts leave reviews after a completed stay.

**Non-functional requirements**
- No double-booking, ever. This is the one hard consistency requirement in the whole system.
- Search must return results in under a second, despite complex location-and-filter queries over millions of listings.
- High availability for browsing and search; booking can tolerate a bit more latency in exchange for correctness.
- Search results can lag reality by a few minutes; booking state must be correct the instant it changes.

> **Remember:** search and booking have opposite priorities in this design. Search wants speed and can tolerate staleness; booking wants correctness and can tolerate a slightly slower write.

```knowledge-check
{ "questions": [
    { "id": "system-design-airbnb-requirements-q1", "type": "mcq", "prompt": "Why can Airbnb's search results be a few minutes stale while the booking system cannot tolerate any staleness?", "options": [
        {"id": "a", "text": "Search staleness and booking staleness are equally acceptable in practice"},
        {"id": "b", "text": "A stale search result at worst shows a listing that's actually unavailable, caught at booking time; a stale booking check could let two guests book the same dates"},
        {"id": "c", "text": "Search is technically incapable of being kept fresh"},
        {"id": "d", "text": "Booking staleness only matters for expensive listings"}
    ], "correct": "b", "explanation": "The cost of staleness differs completely between the two: search staleness is a minor inconvenience corrected at booking time, while booking staleness is a real double-booking, an unrecoverable correctness failure." }
] }
```

## Estimates

Assume 7 million active listings worldwide, 150 million users, and 2 million bookings a day.

- **Bookings/sec:** 2,000,000 / 86,400 ≈ 23/sec average, spiking 5-10x during a flash sale or peak booking season, so 150-200/sec at peak. That's a moderate load, well within a well-indexed relational database as long as the locking is designed correctly.
- **Search traffic dominates:** with 150 million users doing a handful of searches a month while planning trips, that's tens of millions of searches a day, hundreds per second on average, bursting well beyond that. Nearly all of this hits a search index, not the booking database.
- **Listing data:** 7 million listings, about 5 KB of metadata plus roughly 20 photos at 200 KB each, is about 28 TB of images alone, served from object storage and a CDN, the same pattern used for Spotify's audio.
- **Availability calendar:** if modeled as one row per listing per day, 7M listings × 365 days ≈ 2.5 billion rows. That number alone is a strong hint the calendar shouldn't be modeled densely, covered in the data model below.

## API

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

`POST /v1/bookings` returning a `409` when a booking loses a race is the detail worth calling out unprompted. It signals you've thought about the concurrency case, not just the happy path.

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

`BlockedDate` is sparse: since most listing-days are available, only booked or host-blocked dates get a row at all, which avoids the 2.5-billion-row problem above. A unique constraint on `(listing_id, date)` is what actually prevents double-booking at the database level, covered next.

## High-level design

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

The **Listing Service** is the source of truth for listing metadata, propagated to the search index asynchronously, which is exactly why search can lag reality by a few minutes. The **Booking Service** owns the one part of this system that must be strongly consistent: checking availability and writing the reservation happen as a single atomic operation. The **Search Service** is read-optimized and denormalized, and never talks to the booking database directly, so search load never competes with booking writes.

## Deep dives

### How do you actually prevent double-booking under real concurrency?

This is the centerpiece of the question. The wrong answer is "check availability, then insert," done as two separate steps. That's a classic race: two guests can both pass the availability check before either one's write actually lands.

The correct answer makes the reservation atomic using a database constraint, not application logic:

1. **A unique constraint on `(listing_id, date)` in `BlockedDate`.** Booking a 3-night stay inserts one row per date in a single transaction. If any date already has a row, the constraint violation rolls back the whole transaction. The database itself rejects the double-booking, no explicit locking code required. This is the simplest correct answer, and the one to lead with.
2. **A row-level lock on the listing** during the booking transaction, if you'd rather hold one lock instead of inserting N per-night rows. Simpler to reason about for long stays, and serializing all bookings for one listing is fine, since one listing's booking volume is naturally low.

Either way, a guest sees tentative availability in search results, but the reservation is only confirmed by winning the database-level atomic write at the actual moment of booking. Present a losing guest with a `409 Conflict` and a prompt to pick different dates, never a silent overwrite.

> **Remember:** never implement "check, then write" for anything where two people might both pass the check. Push the correctness check into the database itself, as a constraint the database enforces, not a race application code can lose.

```knowledge-check
{ "questions": [
    { "id": "system-design-airbnb-doublebooking-q1", "type": "mcq", "prompt": "Why is a unique constraint on (listing_id, date) a stronger fix for double-booking than checking availability in application code before inserting a booking?", "options": [
        {"id": "a", "text": "Both approaches are equally safe under concurrency"},
        {"id": "b", "text": "The constraint is enforced atomically by the database itself, closing the race window where two requests could both pass an application-level check before either writes"},
        {"id": "c", "text": "Application-level checks are always slower"},
        {"id": "d", "text": "A unique constraint prevents any two bookings from ever happening on the same listing"}
    ], "correct": "b", "explanation": "A check-then-write in application code has a window between the check and the write where a second request can slip through. A database constraint eliminates that window entirely, since the database rejects the conflicting write outright." }
] }
```

### How does search stay fast with dozens of filters over millions of listings?

Denormalize listing data, price, location, amenities, rating, an approximate availability signal, into a dedicated search index that handles combined location, facet, and full-text queries efficiently. Geospatial queries use the same geohash-style indexing idea as ride-hailing's nearby-driver search. Availability in the search index is a fast, approximate signal, "likely available," which is fine for filtering results even when slightly stale, because the actual booking attempt re-validates against the authoritative `BlockedDate` table regardless of what search showed.

### How does payment timing and review integrity work?

Payment happens after a booking is confirmed: charge the guest, and pay out the host on a delay, commonly 24 hours after check-in, to allow room for an early cancellation or dispute. An idempotency key on the payment request, tied to the booking ID, guarantees retries from a network blip or a client double-submit never double-charge.

Reviews are only allowed after a completed stay, enforced server-side, never just hidden in the UI. To reduce retaliatory reviews, Airbnb uses a **double-blind reveal**: both guest and host submit their reviews independently, and neither is shown publicly until both have submitted, or a fixed window (say 14 days) expires. Naming this mechanism is a strong answer if a review system comes up.

## Trade-offs and follow-up questions

| Concern | Choice | Trade-off |
|---|---|---|
| Double-booking prevention | A database unique constraint or row lock at booking time | Correct under concurrency, at the cost of slightly higher write latency per booking |
| Search freshness | Async sync from the listing database to the search index | Search can lag by minutes, but stays fully isolated from booking writes |
| Availability calendar | Sparse rows for blocked dates only | Scales with actual bookings, not listings times 365 |
| Payment timing | Capture at booking, payout to host after a delay | Protects against cancellation churn, adds payout-scheduling complexity |
| Review integrity | Double-blind submission with a reveal window | Reduces retaliatory reviews, adds a pending-review state to track |

**Q: Two guests click "book" on the same last-available night within the same millisecond. Walk through what happens.**
A: Both requests open a transaction attempting to insert the same `BlockedDate` row, or acquire the same listing lock. The database serializes them; whichever commits first succeeds, and the second hits the constraint violation. The Booking Service returns `409 Conflict` to the loser with a prompt to pick different dates. No external coordination service is needed; the database's own guarantees handle it.

**Q: How would you support instant-book versus host-approval-required listings?**
A: A `requires_approval` flag on the listing. For approval-required listings, booking creates a pending record and places a temporary hold on the dates, using the same unique-constraint mechanism so no one else can grab them, with an expiry. If the host doesn't approve in time, a background job releases the hold.

**Q: How do you keep search fast when filtering on dozens of amenity facets across millions of listings?**
A: This is exactly what a dedicated search engine is for. It maintains an inverted index per facet, so a query like "wifi and pool and pet-friendly within 10km" becomes a fast intersection of index lists rather than a table scan, which is why listing search is never served from the relational booking database.

```knowledge-check
{ "questions": [
    { "id": "system-design-airbnb-tradeoffs-q1", "type": "mcq", "prompt": "Why does Airbnb pay hosts on a delay (like 24 hours after check-in) rather than immediately at booking?", "options": [
        {"id": "a", "text": "To reduce transaction fees"},
        {"id": "b", "text": "To leave a window for early cancellations or disputes before money is irreversibly sent to the host"},
        {"id": "c", "text": "Because payment processors require a mandatory delay"},
        {"id": "d", "text": "Hosts prefer to be paid later"}
    ], "correct": "b", "explanation": "Delaying payout gives the system room to handle a cancellation or dispute cleanly before the funds have already left the platform, which is much harder to unwind after the fact." }
] }
```
