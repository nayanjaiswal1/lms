---
kind: lesson
type: system_design
id_key: interview-prep-45/day-15-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design Uber/Lyft"
position: 16
estimated_minutes: 70
source:
    - 45-day-interview-roadmap.md
---

Ride-hailing combines four hard problems at once: finding nearby drivers fast, tracking millions of moving points in real time, matching riders to drivers under a tight time limit, and pricing that reacts to supply and demand. Interviewers use it to check whether you can break a big, vague product into services with clean boundaries, and whether you understand why the naive approach, scan every driver, lock one match at a time, falls apart at scale.

## Requirements

**Functional requirements**
- A rider requests a trip from pickup to drop-off; the system estimates fare and ETA before confirming.
- The system matches the rider to a nearby available driver.
- Both parties see live location updates during the trip.
- Fare (base plus distance, time, and surge) is computed and payment captured at trip end.
- Trip history, receipts, and ratings are available afterward.

**Non-functional requirements**
- Fast matching: driver assignment should finish within about 3 seconds of the request.
- High availability: the dispatch path cannot go down during peak demand, like holidays or a big event letting out.
- Real-time location: a driver's position updates every 3-4 seconds and should reach the rider within about a second.
- Trip history and analytics can be eventually consistent; matching and payment need stronger guarantees, no double-assigning a driver, no double-charging a rider.
- Geographic partitioning: the system scales per city or region independently. Traffic in one city should never touch another city's shard.

> **Remember:** this design has three different subsystems with three different scaling problems: location is a volume problem, matching is a latency problem, and payment is a consistency problem. Keep them separate in your head and in your architecture.

```knowledge-check
{ "questions": [
    { "id": "system-design-uber-requirements-q1", "type": "mcq", "prompt": "Why does a ride-hailing system need three genuinely different scaling strategies instead of one?", "options": [
        {"id": "a", "text": "Because the interviewer expects three diagrams"},
        {"id": "b", "text": "Because location updates are a volume problem, matching is a latency problem, and payment is a consistency problem, each needing a different kind of store and guarantee"},
        {"id": "c", "text": "Because location, matching, and payment always use the same database in practice"},
        {"id": "d", "text": "There's actually only one real scaling problem here"}
    ], "correct": "b", "explanation": "Each subsystem has a fundamentally different bottleneck: raw write volume for location, response time for matching, and correctness for payment. Treating them as one undifferentiated problem misses what actually needs to scale." }
] }
```

## Estimates

Assume a mid-size ride-hailing company: 20 million daily active riders, 1 million active drivers, across 100 major metros.

- **Trips:** roughly 10 million trips/day, about 115/sec average, 5-8x that during rush hour, so 700-900/sec at peak.
- **Location pings:** 1 million drivers online at peak, each pinging every 4 seconds, is 1,000,000 / 4 ≈ 250,000 location writes/sec at peak. This is the dominant write load, far bigger than trip creation. Each ping is small, about 100 bytes, so roughly 25 MB/sec of ingest.
- **Matching requests:** 900 trips/sec, each triggering a "find nearby drivers" geospatial query. This read load is comparable to the write load and must be served from memory, not disk.
- **Trip records:** 10M/day × about 2 KB each ≈ 20 GB/day, roughly 7 TB/year, trivial for durable storage, so trip history goes to an ordinary relational store, well outside the hot path.

## API

```
POST /v1/trips/estimate
  body: { pickup: {lat,lng}, dropoff: {lat,lng}, product: "standard" }
  resp: { fare_estimate, eta_minutes, surge_multiplier }

POST /v1/trips
  body: { rider_id, pickup, dropoff, product }
  resp: { trip_id, status: "matching" }

GET /v1/trips/{trip_id}
  resp: { status, driver: {id, name, location}, eta }

POST /v1/drivers/{driver_id}/location
  body: { lat, lng, heading, timestamp }        # sent every ~4s from driver app

POST /v1/trips/{trip_id}/events
  body: { type: "driver_arrived" | "trip_started" | "trip_completed" }

POST /v1/trips/{trip_id}/rate
  body: { rating, comment }
```

Location updates and trip status also push over a persistent WebSocket, so both apps get sub-second updates without needing to poll.

## Data model

```
Driver(driver_id PK, name, vehicle_info, status[online|offline|on_trip], rating)
DriverLocation(driver_id PK, geohash, lat, lng, heading, updated_at)   -- hot, in-memory
Rider(rider_id PK, name, payment_method_id, rating)
Trip(trip_id PK, rider_id, driver_id, status, pickup, dropoff,
     requested_at, matched_at, started_at, completed_at,
     fare_cents, surge_multiplier, distance_m)
TripEvent(event_id PK, trip_id FK, type, created_at)   -- append-only audit trail
Payment(payment_id PK, trip_id FK, amount_cents, status, idempotency_key)
```

`DriverLocation` deliberately lives apart from `Driver`. It's overwritten 250,000 times a second and read constantly, so it belongs in an in-memory geospatial store, never in the same durable relational database holding `Trip` and `Payment`.

```knowledge-check
{ "questions": [
    { "id": "system-design-uber-datamodel-q1", "type": "mcq", "prompt": "Why is DriverLocation stored separately from the durable Driver table, in an in-memory store instead of the relational database?", "options": [
        {"id": "a", "text": "Relational databases cannot store latitude and longitude values"},
        {"id": "b", "text": "It's overwritten hundreds of thousands of times per second, a write pattern a durable relational store isn't built for, and losing a stale location is harmless"},
        {"id": "c", "text": "In-memory stores are always more secure"},
        {"id": "d", "text": "Driver and DriverLocation must always be in separate databases by convention"}
    ], "correct": "b", "explanation": "The extreme write frequency and the fact that a location is stale within seconds anyway both point away from durable storage and toward a fast, in-memory geospatial store." }
] }
```

## High-level design

```
[Rider App]                          [Driver App]
     |  HTTPS/WS                          |  HTTPS/WS + periodic POST
     v                                     v
              [API Gateway / LB]
                     |
   +-----------------+------------------+
   |                 |                  |
[Trip Service]  [Location Service]  [Pricing Service]
   |                 |                  |
   |         [Geospatial Index]        [Surge Calculator]
   |          (Redis GEO / S2)         (reads live supply/demand)
   |                 |
   +----->[Matching Service]<----------+
                     |
              [Dispatch Queue]
                     |
        +------------+-------------+
        |                          |
  [Notification Service]    [Trip State Store]
   (push to driver app)      (Trip/Payment DB)
```

The **Location Service** ingests the 250,000/sec location stream and writes into an in-memory geospatial index for matching, plus a lightweight time-series store for support and fraud tooling, never touching the durable trip database. The **Trip Service** is the source of truth for trip state, orchestrating the sequence: requested, matching, matched, driver arriving, in progress, completed. The **Pricing Service** computes fare and surge, consulted both at estimate time and again at match time, when the fare is locked to avoid disputes.

## Deep dives

### How do you find nearby drivers without scanning every driver?

Store driver locations in geohashes or S2 cells rather than raw latitude and longitude, so "find drivers near me" becomes a lookup against a handful of cells instead of a scan of everyone. Redis's geospatial commands, backed by geohash-sorted sets, are the standard first answer; at very large scale, companies build a custom in-memory quadtree sharded by region, since a single-key model becomes a bottleneck at hundreds of thousands of writes a second.

Picture the map cut into roughly 1km² cells. A driver's update rewrites their entry in one cell. A rider's match request queries their own cell plus a ring of neighbors, expanding the ring only if too few drivers turn up. That turns an O(all drivers) scan into an O(drivers in a few cells) lookup.

> **Remember:** a geospatial index turns "search everyone" into "search the handful of cells near me." That's the entire trick behind fast nearest-driver matching.

```knowledge-check
{ "questions": [
    { "id": "system-design-uber-geospatial-q1", "type": "mcq", "prompt": "Why does dividing the map into geohash cells make nearby-driver search fast?", "options": [
        {"id": "a", "text": "It doesn't actually help; a full scan is equally fast"},
        {"id": "b", "text": "It narrows a search over every driver down to a search over just the cells near the rider, expanding only if too few drivers are found"},
        {"id": "c", "text": "Geohashing eliminates the need to store driver locations at all"},
        {"id": "d", "text": "It only works for drivers, not for riders"}
    ], "correct": "b", "explanation": "Instead of comparing a rider's location against every driver in the system, the query only has to check drivers already known to be in the same or a nearby cell, which is dramatically cheaper." }
] }
```

### How does matching actually decide who gets the trip?

The naive approach, find nearby drivers and pick the closest, has real problems: two requests can race for the same driver, and "closest" isn't always best, a driver 2 minutes away about to drop off another rider might beat one 90 seconds away but stuck at a light.

Real systems batch requests: collect ride requests and available drivers over a short window, a second or two in dense areas, then solve a bipartite matching problem that minimizes total wait time across every pending request at once, rather than greedily matching one request at a time. That's why the car you get isn't always the literal closest one: the system is optimizing globally, not per-request.

Once a candidate match is chosen, the driver gets a push notification with a short accept window, 10-15 seconds. If declined or timed out, the request goes back into the pool for the next round, with that driver temporarily excluded. A distributed lock, or a single-writer-per-cell pattern, guarantees a driver is never offered two trips at once.

### How does surge pricing work, and what happens if it changes mid-wait?

Surge is a real-time supply-and-demand ratio computed per geographic cell: `surge_multiplier = f(open_requests_in_cell / available_drivers_in_cell)`, smoothed over a short rolling window and capped, say 1.0x to 5.0x, to avoid runaway pricing. It's recalculated every 30-60 seconds per cell and cached, since it's read on every fare estimate.

The multiplier gets locked into the trip record the moment a match happens, so the rider is charged what they were quoted, never a multiplier that changed while they were still waiting. This is a common follow-up question, and locking the price at match time is the answer.

### How do 250,000 location writes a second stay off the durable database?

They never touch it. Ingestion flows through a message queue partitioned by geographic region, with the Location Service as the consumer writing into the in-memory index. This also lets analytics and fraud pipelines consume the same stream independently, without adding any load to the hot matching path.

## Trade-offs and follow-up questions

| Concern | Choice | Trade-off |
|---|---|---|
| Driver location store | In-memory geospatial index, sharded by region | Fast reads and writes, but ephemeral, which is fine since a stale-by-seconds location doesn't matter |
| Matching | Batched bipartite matching every 1-2 seconds | Better global outcomes than greedy nearest-driver, at the cost of a small added latency window |
| Trip state consistency | One source of truth, driver assignment via a per-driver lock | Prevents double-dispatch, at the cost of coordination overhead |
| City partitioning | Shard location, matching, and pricing by metro region | Independent scaling and fault isolation, at the cost of special-casing rare cross-city trips |
| Payment | Charge asynchronously after trip completion, with idempotency keys | Avoids blocking trip completion on a payment gateway call, needs a reconciliation path for failures |

**Q: How do you prevent two riders from being matched to the same driver at the same instant?**
A: Treat "assign driver to trip" as an atomic compare-and-swap on the driver's status, or a per-driver lock with a short TTL. The matching service must flip the driver from available to pending-offer before sending the push notification; any competing match attempt fails that swap and retries with a different candidate.

**Q: The rider's app loses connectivity for 30 seconds mid-trip. What happens?**
A: The driver's location stream keeps flowing to the Location and Trip Services regardless of the rider's connectivity, since trip state lives entirely server-side. When the rider's app reconnects, it re-fetches the trip's current state rather than relying on missed push messages, and resubscribes to the live channel.

**Q: How would you extend this to support pooled rides with multiple riders per trip?**
A: The matcher becomes a constrained optimization problem instead of a one-to-one assignment, considering route overlap, added detour time per rider, and a maximum-detour limit. A reasonable answer at interview depth: solve a small routing subproblem per driver candidate, bounded to 2-3 open seats, without going deeper into full vehicle-routing algorithms unless asked.

```knowledge-check
{ "questions": [
    { "id": "system-design-uber-tradeoffs-q1", "type": "mcq", "prompt": "Why is the surge multiplier locked into the trip record at match time rather than recalculated at trip completion?", "options": [
        {"id": "a", "text": "Locking it has no real purpose, it's just convention"},
        {"id": "b", "text": "So the rider is charged exactly what they were quoted, not a different multiplier that may have changed while they were waiting"},
        {"id": "c", "text": "Because surge pricing cannot be recalculated more than once"},
        {"id": "d", "text": "Because drivers set their own surge multiplier manually"}
    ], "correct": "b", "explanation": "Locking the fare at match time avoids the real user complaint of being charged a different price than what was quoted, since surge naturally fluctuates minute to minute." }
] }
```
