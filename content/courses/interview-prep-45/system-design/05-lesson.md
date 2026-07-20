---
kind: lesson
type: system_design
id_key: interview-prep-45/day-05-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 5 — Analytics Pipeline"
position: 5
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

## Why interviewers ask this

An analytics pipeline (think: Mixpanel, Segment, or an internal event-tracking system) tests data-engineering instincts that pure web-app design doesn't: streaming ingestion, storage format trade-offs (row vs column), batch vs real-time processing, and out-of-order/late data. It's a favorite for senior/staff interviews because there's no single "right" architecture — you have to justify trade-offs explicitly.

## Requirements

### Functional
- Ingest arbitrary events from clients/services (`page_view`, `purchase`, `signup`, custom events) with a flexible schema.
- Generate aggregate reports: counts, funnels, time-series dashboards (e.g. "DAU over the last 30 days").
- Support ad-hoc querying by analysts (SQL-like).
- Support both near-real-time dashboards and historical batch reports.

### Non-functional
- **High throughput** — must absorb bursty ingestion (millions of events/sec at peak) without dropping data.
- **Data accuracy** — no silent data loss; duplicate/late events handled explicitly, not ignored.
- Cost-efficient storage at petabyte scale (raw event data is huge and mostly cold).
- Query latency: dashboards should refresh in seconds to low-minutes; ad-hoc historical queries can take longer.

## Capacity estimates

Assume 1B events/day from a mid-size product's tracking SDK.

- **Events/sec average:** 1,000,000,000 / 86,400 ≈ **11,600/sec**; peak (product launch, flash sale) 10x ≈ 116,000/sec.
- **Event size:** ~500 bytes (JSON: event name, user_id, timestamp, properties) → 1B × 500 B = **500 GB/day** raw ingestion.
- **Storage (1 year, raw + compressed):** raw 500 GB/day × 365 ≈ 180 TB/year; columnar formats (Parquet) with compression typically shrink this 5-10x ≈ **20-35 TB/year** compressed — this is why data lakes use columnar formats, not raw JSON, for long-term storage.
- **Retention tiering:** hot (queryable fast, last 7-30 days) in a data warehouse; cold (archived, rarely queried) in cheap object storage (S3/GCS), queried on-demand via a query engine like Athena/Presto.

## API sketch

```
POST /api/v1/events   (client SDK -> ingestion endpoint)
  body: { event_name, user_id, timestamp, properties: {...}, event_id }
  resp: 202 Accepted   (fire-and-forget, always fast)

GET /api/v1/reports/dau?from=2026-06-01&to=2026-07-01
GET /api/v1/reports/funnel?steps=signup,activate,purchase
POST /api/v1/query   (ad-hoc SQL against the warehouse, for analysts)
```

The ingestion endpoint must respond fast (`202 Accepted`, no waiting on downstream processing) — its only job is to validate shape and hand off to the pipeline. `event_id` (client-generated UUID) enables downstream dedup.

## Data model

```
raw_events (append-only, partitioned by date + event_name)
  event_id      uuid
  event_name    varchar
  user_id       bigint
  timestamp     timestamp   -- when the event occurred (client clock)
  ingested_at   timestamp   -- when we received it (server clock)
  properties    jsonb / map<string,string>

-- Aggregated / rollup tables (materialized by batch or stream jobs)
daily_active_users (date, count)
event_counts_hourly (event_name, hour_bucket, count)
funnel_results (funnel_id, date, step, user_count)
```

Two timestamps matter: **event time** (`timestamp`, when it actually happened) vs **processing time** (`ingested_at`, when the pipeline saw it). This distinction is exactly what makes late-arriving data solvable — see below.

## High-level architecture

```
Client SDKs / Services
        |
        v
  Ingestion API (stateless, horizontally scaled)
        |
        v
  Event Stream (Kafka / Kinesis) -- partitioned by user_id or event_name
        |
        +-----------------------------+
        v                             v
  Stream Processor              Batch Processor
  (Flink/Kafka Streams)         (Spark, scheduled hourly/daily)
  -> real-time rollups          -> full re-aggregation, corrections
        |                             |
        v                             v
  Real-time OLAP store         Data Lake (S3, Parquet) --> Data Warehouse (Redshift/BigQuery/Snowflake)
  (Druid/ClickHouse)                                              |
        |                                                          v
        v                                                  Ad-hoc query engine (Presto/Athena)
  Live Dashboards
```

- **Ingestion API** does minimal validation and immediately writes to the stream — decoupling "accept the event" from "process the event," same pattern as the notification service.
- **Stream (Kafka/Kinesis)** is the durable buffer that absorbs bursts and lets multiple independent consumers (real-time + batch) read the same data without contention.
- **Stream processor** computes approximate, low-latency rollups (e.g. "events in the last 5 minutes") for live dashboards — optimizing for speed over perfect completeness.
- **Batch processor** runs periodically (hourly/daily) over the full data lake, recomputing exact aggregates including any late-arriving data — optimizing for correctness over speed. This dual-path design is the classic **Lambda architecture**.

## Component deep dives

### Event ingestion pipeline (Kafka/Kinesis)

- Partition by `user_id` if you need per-user ordering (e.g. session reconstruction) or by `event_name` if you want independent scaling/consumption per event type. Most analytics pipelines partition by a hash of `user_id` to spread load evenly while keeping one user's events roughly ordered.
- Retention on the topic (e.g. 7 days) lets you replay if a downstream consumer needs to reprocess after a bug fix — this replayability is one of the biggest reasons to use Kafka over a simpler queue here.

### Storage: data lake vs data warehouse

| | Data lake (S3 + Parquet) | Data warehouse (Redshift/BigQuery/Snowflake) |
|---|---|---|
| Schema | Schema-on-read, flexible | Schema-on-write, structured |
| Cost | Cheap ($/GB storage) | More expensive but optimized for query speed |
| Use case | Raw archive, ML training data, ad-hoc exploration | Fast structured queries, BI dashboards |
| Query engine | Presto/Athena/Spark (pay per query) | Built-in, columnar, indexed |

**Typical pattern:** land raw events in the data lake first (cheap, durable, replayable), then load structured/aggregated subsets into the warehouse for fast dashboard queries. Don't put raw high-cardinality event streams directly into an expensive warehouse — pre-aggregate first.

### Real-time vs batch processing

- **Real-time (stream processing)** answers "what's happening right now" — approximate counts within seconds, used for live dashboards, alerting, fraud detection.
- **Batch processing** answers "give me the exact number" — runs over complete data (including corrections/late data), used for billing, official reports, historical analysis.
- Serving both from one Lambda-architecture pipeline is standard; some teams simplify to a **Kappa architecture** (stream-only, reprocess by replaying the log) if batch correctness needs are modest — mention this as an alternative if asked to simplify.

### Late-arriving data

- A mobile client can queue events offline and send them hours/days later — event `timestamp` is old, but `ingested_at` is now.
- **Windowed aggregation with watermarks:** stream processors (Flink) use a "watermark" — an estimate of "we've likely seen all events up to this event-time" — and hold aggregation windows open a bit past their nominal end to admit slightly-late data, then finalize.
- **Batch correction:** the nightly/hourly batch job re-aggregates from the immutable raw data lake using event time, so even data that arrives very late (beyond the stream's watermark tolerance) gets folded into the next batch run — this is why keeping raw, replayable data is non-negotiable, and why real-time numbers are labeled "approximate, subject to revision."

## Scaling & trade-offs

- **Throughput vs latency:** batching writes (micro-batches into the warehouse) trades a few seconds of latency for much higher write throughput and lower cost than row-by-row inserts.
- **Exactly-once vs at-least-once:** true exactly-once end-to-end is hard; most pipelines use at-least-once ingestion + idempotent aggregation (dedupe on `event_id`) to achieve effectively-once results.
- **Cardinality control:** unbounded `properties` fields (arbitrary user-supplied keys) can blow up storage/indexing cost — enforce a schema registry or property allowlist for high-volume events.

## Likely follow-up questions — with answers

**Q: How do you avoid double-counting an event that a flaky client SDK sent twice?**
A: Client generates a UUID `event_id` per event; downstream dedup (a Redis set with TTL for the stream path, or a `SELECT DISTINCT event_id` / merge-on-insert for the batch path) drops repeats. Idempotent aggregation logic (e.g. counting distinct `event_id`s, not raw row counts) reinforces this.

**Q: Real-time dashboards show slightly different numbers than the next day's official report — is that a bug?**
A: No — expected behavior of a Lambda architecture. Real-time numbers are computed by the stream processor with a bounded watermark and are explicitly approximate; the batch job recomputes from complete, immutable raw data including late arrivals, producing the authoritative number. Label real-time dashboards as "approximate, live" to set correct expectations.

**Q: How would you support ad-hoc SQL queries from data analysts without letting one bad query take down the pipeline?**
A: Isolate query compute from ingestion compute entirely — analysts query the data lake/warehouse via a separate query engine (Presto/Athena/BigQuery), which has its own resource limits and doesn't touch the ingestion path (Kafka, stream processors) at all. Add query timeouts and cost/row-scan limits per query.

## Key takeaways
- Decouple ingestion (fast, dumb, always-accept) from processing (stream for speed, batch for correctness) — the Lambda architecture pattern.
- Event time vs processing time is the key concept for handling late-arriving data; watermarks let stream processors admit slightly-late events before finalizing a window.
- Data lake (cheap, raw, replayable) feeds a data warehouse (fast, structured, query-optimized) — don't put raw firehose data directly into the expensive warehouse.
- Dedup via client-generated `event_id` gives you effectively-once results on top of an at-least-once pipeline.
- Real-time numbers are approximate by design; batch recomputation is the source of truth — say this explicitly in interviews.

## Today's checklist
- [ ] Define functional requirements: track events, generate reports
- [ ] Define non-functional requirements: high throughput, data accuracy
- [ ] Design event ingestion pipeline (Kafka/Kinesis)
- [ ] Design storage: data lake vs data warehouse
- [ ] Design real-time vs batch processing
- [ ] Handle late-arriving data
