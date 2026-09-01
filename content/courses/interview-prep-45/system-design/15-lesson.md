---
kind: lesson
type: system_design
id_key: interview-prep-45/day-15-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Uber/Lyft"
position: 15
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Ride-hailing is a staple system design question because it forces you to combine geospatial indexing, real-time state (millions of moving points), a matching algorithm under latency pressure, and a pricing model that reacts to supply/demand, all at once. Interviewers use it to see whether you can decompose a "big vague" product into services with clear contracts, and whether you understand why naive approaches (scan every driver, lock every match) fall apart at scale.

## Requirements

**Functional**
- Riders request a trip from pickup to drop-off; system estimates fare and ETA before confirming.
- System matches the rider to a nearby available driver.
- Both parties see live location updates during the trip.
- Fare is computed (base + distance + time + surge) and payment is captured at trip end.
- Trip history, receipts, and ratings are available afterward.

**Non-functional**
- Low-latency matching: driver assignment should complete in under ~3 seconds of the request.
- High availability: the dispatch path cannot go down during peak hours (holidays, event let-outs).
- Real-time location: driver position updates every 3-4 seconds, visible to rider within ~1 second.
- Eventual consistency is acceptable for history/analytics; matching and payment need stronger guarantees (no double-assigning a driver, no double-charging a rider).
- Geographic partitioning: the system must scale per-city/per-region independently. London traffic shouldn't touch a São Paulo shard.

## Capacity estimates

Assume a mid-size ride-hailing company:

20M daily active riders, 1M active drivers, 100 major metros. Average 10M trips/day gives ~115 trips/second average, ~5-8x that at peak (rush hour), so ~700-900 trips/sec peak.

Location pings: 1M drivers online at peak, each pinging every 4 seconds, so 1,000,000 / 4 ≈ **250,000 location writes/sec** at peak. This is the dominant write load, not trip creation. Each location ping is small (~100 bytes: driver_id, lat, lng, heading, timestamp), so 250,000 × 100 bytes ≈ 25 MB/sec ingest.

Matching requests: 900 trips/sec each triggering a "find nearby drivers" query over a geospatial index. This read load is comparable to the write load and must be served from memory, not disk.

Trip records: 10M/day × ~2KB (route, fare breakdown, timestamps) ≈ 20 GB/day, ~7 TB/year, trivial for durable storage, so trip history goes to a standard relational or document store, not the hot path.

The takeaway to say out loud in an interview: location data is the volume problem, matching is the latency problem, and trip/payment records are the consistency problem. Three different subsystems with three different scaling strategies.

## API sketch

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

Location updates and trip status are also pushed over a persistent WebSocket/long-poll channel so both apps get sub-second updates without polling.

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

`DriverLocation` deliberately lives apart from `Driver`. It's overwritten 250K times/sec and read constantly, so it belongs in an in-memory geospatial store (Redis GEO, or a custom quadtree/S2-cell service), not in the durable relational database that holds `Trip` and `Payment`.

## High-level architecture

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

**API Gateway** terminates TLS, does auth, routes by path, and rate-limits per rider/driver.

**Location Service** ingests the 250K/sec location stream. Writes fan out to an in-memory geospatial index for matching queries and to a lightweight time-series store for "replay the last N minutes" (used by support and fraud tooling). Nothing here touches the durable trip database.

**Matching Service** owns the actual "who gets this trip" decision (see deep dive below).

**Trip Service** is the source of truth for trip state and orchestrates the state machine: requested → matching → matched → driver_arriving → in_progress → completed.

**Pricing Service** computes base fare and surge, consulted both at estimate time and at trip-completion time (fare is locked at match time to avoid disputes).

## Component deep dives

### Geospatial indexing

Store driver locations in **geohashes** or **S2 cells** rather than raw lat/lng so "find drivers near me" becomes a prefix/cell lookup instead of a full scan. Redis's `GEOADD`/`GEOSEARCH` (backed by geohash-sorted sets) is the standard interview answer for a first cut; at very large scale, companies build a custom in-memory quadtree sharded by region, because Redis GEO's single-key model becomes a bottleneck at hundreds of thousands of writes/sec.

Key idea: partition the world into cells (e.g., ~1km² each). A driver's location update rewrites their entry in one cell. A rider's match request queries the rider's cell plus a ring of neighboring cells, expanding the ring only if too few drivers are found. This turns an O(drivers) scan into an O(drivers in a few cells) lookup.

### Matching / dispatch algorithm

Naive: for each ride request, find nearby drivers, pick the closest, done. Problems: two requests can race for the same driver, and "closest" isn't always best (a driver 2 minutes away who's about to drop off another rider may beat one 90 seconds away but stuck at a light).

Real systems batch: collect ride requests and available drivers over a short window (e.g., every 1-2 seconds in dense areas), then solve a **bipartite matching** problem (a simplified Hungarian-algorithm-style assignment) that jointly minimizes total wait time across all pending requests rather than greedily matching one at a time. This is why your Uber sometimes doesn't get the literal closest car: the system is optimizing globally, not per-request.

Once a candidate match is chosen, the driver gets a push notification with a short accept window (e.g., 10-15 seconds). If declined or timed out, the rider request goes back into the pool for the next matching round with that driver temporarily excluded. Use a distributed lock or a single-writer-per-cell pattern to guarantee a driver isn't offered two trips simultaneously.

### Surge pricing

Surge is a real-time supply/demand ratio computed per geographic cell: `surge_multiplier = f(open_requests_in_cell / available_drivers_in_cell)`, smoothed over a short rolling window and capped (e.g., 1.0x-5.0x) to avoid runaway pricing. The multiplier is recalculated every 30-60 seconds per cell and cached; it's read on every fare estimate. Lock the multiplier into the trip record at match time so the rider is charged what they were quoted, not a multiplier that changed mid-trip. This is a frequent interview follow-up: "what if surge changes while the rider is waiting?"

### Driver location updates at scale

250K writes/sec cannot hit a relational database. Ingest through a message queue (Kafka) partitioned by geographic region, with the Location Service as consumer writing into the in-memory index. This also lets analytics/fraud pipelines consume the same stream independently without touching the hot path.

## Scaling & trade-offs

| Concern | Choice | Trade-off |
|---|---|---|
| Driver location store | In-memory geospatial index (Redis GEO / custom quadtree), sharded by region | Fast reads/writes, but data is ephemeral, acceptable since a stale-by-seconds location is fine |
| Matching | Batched bipartite matching per cell, every 1-2s | Better global outcomes than greedy nearest-driver, at the cost of a small added latency window |
| Consistency of trip state | Single source of truth (Trip Service + DB), driver assignment via distributed lock per driver | Prevents double-dispatch; adds coordination overhead |
| City partitioning | Shard everything (location index, matching, pricing) by metro region | Independent scaling and fault isolation; cross-city trips (rare) need special-casing |
| Payment | Charge asynchronously after trip completion, with idempotency keys | Avoids blocking trip completion on a payment gateway call; requires a reconciliation/retry path for failures |

## Likely follow-up questions — with answers

**Q: How do you prevent two riders from being matched to the same driver at the same instant?**
A: Treat "assign driver to trip" as a compare-and-swap on the driver's status field (or a per-driver distributed lock, e.g. Redis `SET NX` with a short TTL). The matching service must atomically flip the driver from `available` to `pending_offer` before sending the push notification; any other match attempt for that driver fails the CAS and retries with a different candidate.

**Q: The rider's app loses connectivity for 30 seconds mid-trip. What happens?**
A: The driver's location stream keeps flowing to the Location Service and Trip Service regardless of the rider's connectivity. The trip's authoritative state lives server-side. When the rider's app reconnects, it does a `GET /v1/trips/{trip_id}` to resync rather than relying on missed push messages, and resubscribes to the WebSocket channel.

**Q: How would you extend this design to support driver-side batching (multiple riders per trip, e.g. UberPool)?**
A: The matching service becomes a constrained optimization problem instead of one-to-one assignment. It needs to consider route overlap, added detour time per rider, and a max-detour SLA. This is usually answered at a level of "I'd change the matcher to solve a small vehicle-routing subproblem per driver candidate, bounded by a max of 2-3 open seats," which is enough depth unless the interviewer explicitly wants to go deeper into VRP algorithms.
