---
kind: lesson
type: system_design
id_key: interview-prep-45/day-05-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design an Analytics Pipeline"
position: 6
estimated_minutes: 75
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

An analytics pipeline, think Mixpanel, Segment, or an internal event tracker, ingests events like `page_view` and `purchase` from every client and service, then turns them into dashboards and reports. It tests instincts pure web-app design doesn't: streaming ingestion, storage trade-offs, and what to do when data shows up late. There's no single "right" architecture here, so the interview is really about whether you can justify your trade-offs out loud.

## Requirements

**Functional requirements**
- Ingest arbitrary events (`page_view`, `purchase`, `signup`, custom events) with a flexible schema.
- Generate aggregate reports: counts, funnels, time-series dashboards like "daily active users over the last 30 days."
- Support ad-hoc SQL-like queries from analysts.
- Support both near-real-time dashboards and exact historical reports.

**Non-functional requirements**
- High throughput: absorb bursty ingestion, potentially millions of events/sec at peak, without dropping data.
- Data accuracy: no silent data loss; duplicate and late events are handled explicitly, not ignored.
- Cost-efficient storage at a scale of petabytes, since raw event data is huge and mostly cold.
- Query latency: dashboards refresh in seconds to low minutes; a one-off historical query can take longer.

## Estimates

Assume 1 billion events a day from a mid-size product's tracking code.

- **Events/sec:** 1,000,000,000 / 86,400 ≈ 11,600/sec average, peaking around 10x during a launch or a flash sale, so roughly 116,000/sec.
- **Event size:** about 500 bytes each (event name, user ID, timestamp, properties), so 1B × 500 bytes = 500 GB/day raw.
- **Storage over a year:** 500 GB/day × 365 ≈ 180 TB raw. A columnar format like Parquet with compression typically shrinks that 5-10x, down to 20-35 TB compressed. That's exactly why data lakes use columnar formats instead of raw JSON for long-term storage.
- **Retention tiers:** hot data (last 7-30 days, fast queries) lives in a data warehouse; cold data moves to cheap object storage, queried on demand through something like Athena or Presto.

## API

```
POST /api/v1/events   (client SDK -> ingestion endpoint)
  body: { event_name, user_id, timestamp, properties: {...}, event_id }
  resp: 202 Accepted   (fire-and-forget, always fast)

GET /api/v1/reports/dau?from=2026-06-01&to=2026-07-01
GET /api/v1/reports/funnel?steps=signup,activate,purchase
POST /api/v1/query   (ad-hoc SQL against the warehouse, for analysts)
```

The ingestion endpoint has one job: respond fast. It validates shape, hands off to the pipeline, and returns `202 Accepted` without waiting for anything downstream. The client-generated `event_id` is what lets later stages dedupe.

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

Two timestamps do all the work in this design: **event time** (`timestamp`, when it really happened) and **processing time** (`ingested_at`, when your pipeline saw it). Keeping both separate is exactly what makes late-arriving data solvable, covered in the deep dive below.

```knowledge-check
{ "questions": [
    { "id": "system-design-analytics-datamodel-q1", "type": "mcq", "prompt": "Why does the raw_events table store both a timestamp (event time) and an ingested_at (processing time)?", "options": [
        {"id": "a", "text": "It's redundant, only one is ever needed"},
        {"id": "b", "text": "Because they can differ, especially for offline clients, and that gap is what lets late-arriving data be corrected later"},
        {"id": "c", "text": "Databases require two timestamp columns by convention"},
        {"id": "d", "text": "To make the table larger for compression testing"}
    ], "correct": "b", "explanation": "A mobile client can queue an event offline for hours before sending it. Keeping event time separate from processing time lets a batch job later fold that late event into the correct time bucket." }
] }
```

## High-level design

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

The ingestion API writes straight to the stream, the same "accept now, process later" pattern as a notification service. The stream is a durable buffer that absorbs bursts and lets independent consumers, both real-time and batch, read the same data without stepping on each other.

Picture two workers reading the same firehose at different speeds. The **stream processor** produces approximate, low-latency numbers ("events in the last 5 minutes") for live dashboards, trading perfect completeness for speed. The **batch processor** runs on a schedule over the full data lake, recomputing exact numbers including anything that arrived late, trading speed for correctness. Running both together is called a **Lambda architecture**.

## Deep dives

### How does the pipeline handle data that arrives late?

A mobile client can queue events offline and send them hours or days later, so the event's `timestamp` looks old even though `ingested_at` is now.

Stream processors use a **watermark**: an estimate of "we've probably seen everything up to this point in event time." Aggregation windows stay open a bit past their nominal end to admit slightly-late data before finalizing. But some data arrives later than even a generous watermark allows, so the nightly or hourly **batch job re-aggregates from the immutable raw data lake** using event time, folding in anything that missed the stream's window. This is exactly why keeping raw, replayable data is non-negotiable, and why real-time dashboard numbers should be labeled "approximate, subject to revision."

> **Remember:** real-time numbers are a fast, approximate guess; the batch job is the source of truth that corrects it later. That's not a bug, it's the design.

```knowledge-check
{ "questions": [
    { "id": "system-design-analytics-latedata-q1", "type": "mcq", "prompt": "Why might a real-time dashboard show a slightly different number than the official report generated the next day?", "options": [
        {"id": "a", "text": "This means something is broken in the pipeline"},
        {"id": "b", "text": "The real-time number is an approximate, bounded-watermark estimate, while the batch job recomputes from complete data including late arrivals"},
        {"id": "c", "text": "Real-time dashboards always overcount events"},
        {"id": "d", "text": "The two numbers should always match exactly"}
    ], "correct": "b", "explanation": "This is expected Lambda-architecture behavior. Labeling the real-time number as approximate sets the right expectation instead of treating the discrepancy as a bug." }
] }
```

### Data lake vs. data warehouse: where does data actually live?

| | Data lake (S3 + Parquet) | Data warehouse (Redshift/BigQuery/Snowflake) |
|---|---|---|
| Schema | Schema-on-read, flexible | Schema-on-write, structured |
| Cost | Cheap per GB | More expensive, optimized for query speed |
| Use case | Raw archive, ML training data, exploration | Fast structured queries, BI dashboards |
| Query engine | Presto/Athena/Spark, pay per query | Built-in, columnar, indexed |

The typical pattern: land raw events in the cheap, durable, replayable data lake first, then load structured or pre-aggregated subsets into the warehouse for fast dashboard queries. Don't pipe a raw, high-cardinality event stream directly into an expensive warehouse; pre-aggregate first.

### Deep dive: adding A/B testing on top of the pipeline

A/B testing doesn't need its own pipeline, it rides on the analytics pipeline you just built, and it's a common follow-up: "how would you know if a change actually helped?" An A/B test splits users into a control group (current experience) and a treatment group (the change), then compares a target metric between them to see whether the change actually caused a difference, not just correlated with one.

**A worked example.** You test a redesigned checkout button against conversion rate: 100,000 users see the old button, 100,000 see the new one. Over the test window, 8,200 of the control group check out (8.2%) versus 8,600 of the treatment group (8.6%), a 0.4 percentage-point lift, about 4.9% relative.

Before calling it a win, ask two questions. **Is this real or noise?** A significance test on those two proportions gives a p-value; below your threshold (commonly 0.05) means the gap probably isn't random chance in who got assigned where. **Is it big enough to matter?** A statistically real 0.4-point lift might still be too small to justify shipping it, or it might be exactly the kind of small, compounding win worth taking. Report the actual effect size alongside the p-value, not just "significant: yes or no."

Then check guardrails. Suppose the new button's heavier animation library added 200ms to page load in the treatment group. Even with a clean conversion win, that's a real cost the conversion number alone would never show you, which is why a test is never judged on one metric.

**Assigning users consistently.** Almost always assign by user ID, hashed into a bucket, not by session or request. A user should see the same experience every visit, or the test ends up measuring confusion instead of the real change: `hash(user_id + experiment_name) % 100`. This is deterministic, so you don't need to store an assignment per user anywhere.

**Sample size and duration.** Compute the minimum sample size needed to detect the smallest effect worth caring about, before launching, given a target statistical power (commonly 80%) and significance level (commonly 5%). A one-week minimum is common even once you hit that sample size, to average out weekday-vs-weekend behavior.

**Primary metric vs. guardrail metrics.** Pick one primary metric the test is meant to move, and a small set of guardrails that must not regress, like page load time or error rate. A test can win on its primary metric while quietly breaking something else, exactly like the page-load example above.

**How it fits the architecture:**

```
User request
     |
     v
Experiment Assignment Service  <-->  Experiment Config Store (which experiments are live, split %)
     |
     v (bucket: control | treatment, deterministic via hashed user_id)
Application serves the appropriate variant
     |
     v
Event Logging (impressions + downstream metric events) --> Analytics Pipeline --> Dashboard
```

Assignment sits on the critical path of every request touched by an experiment, so it's a local hash computation, not a network call, with experiment configs cached on app servers rather than fetched per request. Every metric event needs to carry which variant the user was in at the time, logged alongside the business event so analysis can be re-sliced later by platform or region without rerunning the experiment.

**Common pitfalls to name.** **Peeking:** checking results repeatedly and stopping the moment they look significant inflates the false-positive rate, since every peek is another chance to catch a random fluctuation. Decide the duration in advance. **Novelty effect:** a change can perform well simply because it's new, with the effect fading over time; a too-short test mistakes this for a durable win. **Sample ratio mismatch:** if the actual observed split (say 96,000/104,000 instead of roughly 100,000/100,000) deviates meaningfully from the intended split, something is broken in assignment or logging, and no other result from that test should be trusted until it's root-caused.

```knowledge-check
{ "questions": [
    { "id": "system-design-analytics-abtesting-q1", "type": "mcq", "prompt": "Why is a statistically significant result not automatically a reason to ship a change?", "options": [
        {"id": "a", "text": "Statistical significance is meaningless in A/B testing"},
        {"id": "b", "text": "A real but tiny effect might not be worth the engineering cost, and a guardrail metric like page load time could have regressed"},
        {"id": "c", "text": "Significant results are always false positives"},
        {"id": "d", "text": "You should only ever look at the p-value, never the effect size"}
    ], "correct": "b", "explanation": "A test result needs both a real effect size worth acting on and a check that no guardrail metric quietly got worse, not just a pass/fail significance label." }
] }
```

## Trade-offs and follow-up questions

**Throughput vs. latency.** Batching writes into the warehouse in micro-batches trades a few seconds of delay for much higher write throughput and lower cost than inserting row by row.

**Exactly-once vs. at-least-once.** True end-to-end exactly-once is hard to achieve. Most pipelines use at-least-once ingestion plus idempotent aggregation, deduping on `event_id`, to get effectively-once results.

**Cardinality control.** An unbounded `properties` field, where clients can send any key they want, can blow up storage and indexing cost. Enforce a schema registry or an allowlist of properties for high-volume events.

**Q: How do you avoid double-counting an event a flaky client sent twice?**
A: The client generates a UUID `event_id` per event. Downstream dedup, a Redis set with a TTL on the stream path, or a merge-on-insert on the batch path, drops repeats. Aggregation counts distinct `event_id`s, not raw rows.

**Q: How would you support ad-hoc analyst queries without one bad query taking down the pipeline?**
A: Isolate query compute from ingestion compute entirely. Analysts query through a separate engine (Presto, Athena, BigQuery) with its own resource limits, never touching Kafka or the stream processors. Add query timeouts and row-scan limits.

```knowledge-check
{ "questions": [
    { "id": "system-design-analytics-tradeoffs-q1", "type": "mcq", "prompt": "Why should analyst ad-hoc SQL queries run through a separate query engine rather than against the live ingestion pipeline?", "options": [
        {"id": "a", "text": "Analysts don't need SQL access at all"},
        {"id": "b", "text": "A single expensive or badly written query could otherwise degrade or take down the ingestion path that every other consumer depends on"},
        {"id": "c", "text": "Separate engines are always cheaper"},
        {"id": "d", "text": "It has no real benefit, it's just convention"}
    ], "correct": "b", "explanation": "Isolating query compute from ingestion compute means one bad analyst query can be capped with a timeout without ever threatening the pipeline that every dashboard and downstream job relies on." }
] }
```
