---
kind: lesson
type: system_design
id_key: interview-prep-45/day-27-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Logging/Monitoring System"
position: 27
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today's system is infrastructure for infrastructure — a logging/monitoring platform (think Datadog, Splunk, or an internal ELK stack) that every other system in this course quietly depends on. Interviewers ask this because it tests whether you understand the write-path/read-path split at extreme write volume, the difference between logs (arbitrary text, searched rarely but deeply) and metrics (structured numbers, queried constantly, aggregated), and how alerting has to trade detection speed against false-positive noise.

## Requirements

**Functional**
- Collect logs (structured/unstructured text events) from many services.
- Collect metrics (numeric time-series: request rate, latency, error rate, CPU).
- Search logs by service, time range, and free text/fields.
- Alert when a metric crosses a threshold or a log pattern indicates an incident.

**Non-functional**
- Extremely high write throughput — every service in the org emits logs/metrics continuously; this system cannot be the bottleneck or single point of failure for the rest of the infrastructure.
- Write path must never block the emitting application (a slow logging pipeline should never slow down the actual service being monitored).
- Query/search latency matters for incident response (someone debugging a live outage needs results in seconds, not minutes).
- Retention with tiered cost: recent data (hours to days) needs fast access; older data (weeks to months) can be slower/cheaper.
- Alerting must balance detection speed against false-positive fatigue.

## Capacity estimates

Assume a mid-to-large org: 5,000 service instances, each emitting logs and metrics continuously.
- Logs: each instance emits ~50 log lines/sec average (higher under load/errors) × 5,000 instances = 250,000 log lines/sec ≈ 21.6B lines/day. At ~300 bytes/line average, that's ~6.5 TB/day of raw log volume.
- Metrics: each instance reports ~50 distinct metrics (latency, error rate, CPU, memory, custom business metrics) every 10 seconds = 5 metrics/sec/instance × 5,000 = 25,000 metric points/sec ≈ 2.16B points/day. Metrics are far smaller per-point (a timestamp + a number + a few label tags, tens of bytes) but sampled far more frequently and queried far more often (dashboards refresh constantly) than logs are read.
- The order-of-magnitude gap between log volume (TB/day, mostly write-once-read-rarely) and metric query volume (constant dashboard/alert reads against a much smaller per-point footprint) is why logs and metrics are architecturally different systems under the hood, even when presented through one unified product.
- Retention: hot tier (fast query) commonly 7-14 days; cold tier (compressed, slower, cheaper storage) can extend to months/years for compliance or historical analysis.

## API sketch

```
POST /ingest/logs          { service, level, message, fields{}, timestamp }   -- high-volume, fire-and-forget from clients
POST /ingest/metrics        { metric_name, value, tags{}, timestamp }          -- high-volume

GET  /logs/search?query=&service=&from=&to=&cursor=      -> { logs[], next_cursor }
GET  /metrics/query?metric=&tags=&from=&to=&aggregation=  -> { series[] }       -- e.g. avg/p99/sum over time buckets

POST /alerts                { metric_or_query, condition, threshold, notify_channels[] }
GET  /alerts/{id}/history                                  -> { firings[] }
```

Ingestion endpoints are optimized purely for high-throughput accept-and-buffer, not for validation-heavy processing — anything expensive (parsing, indexing, enrichment) happens asynchronously downstream, never synchronously in the request that the emitting application is waiting on.

## Data model

```
-- Logs: append-only event stream, indexed for search
log_events        id, service, level, message, fields (JSON), timestamp
                  -- indexed into an inverted-index search engine (Elasticsearch-style),
                     not queried directly against a row store at read time

-- Metrics: time-series, optimized for range + aggregation queries
metric_points     metric_name, tags (label set), timestamp, value
                  -- stored in a time-series-optimized store, NOT a general relational table —
                     row-per-point relational storage does not scale to billions of points/day

-- Alerts
alert_rules        id, name, metric_or_query, condition, threshold, evaluation_window
alert_firings       id, alert_rule_id, fired_at, resolved_at, severity
```

## High-level architecture

```
Service instances --> local lightweight agent (buffers, batches, never blocks the app)
                             |
                  (logs)                              (metrics)
                     |                                     |
          Log ingestion pipeline                Metrics ingestion pipeline
          (Kafka-style buffer -->                (Kafka-style buffer -->
           stream processor -->                    aggregator/downsampler -->
           indexer)                                 time-series DB)
                     |                                     |
          Search index (Elasticsearch-style)      Time-series store (Prometheus/
          -- hot tier fast, cold tier               InfluxDB/TimescaleDB-style)
          compressed/archived                       -- hot + downsampled cold tiers
                     |                                     |
                     +------------------+------------------+
                                        |
                             Query API (search, dashboards)
                                        |
                             Alert evaluator (polls/streams metrics
                             against alert_rules) --> fires --> notification
                             system (reuse Day 26's channel-routing design)
```

## Component deep dives

**Why logs and metrics are different systems, not one.** Logs are high-cardinality, unstructured-ish text, written far more often than they're read, and searched deeply (full-text, arbitrary field filters) but rarely (an engineer investigating a specific incident). Metrics are low-cardinality-per-series, strictly numeric, written frequently and *read even more frequently* (every dashboard panel, every alert evaluation is a metrics read), and need efficient time-range aggregation (avg/p99/rate-of-change over a window), not text search. These access patterns justify genuinely different storage engines under the hood: an inverted-index search engine for logs (Elasticsearch and equivalents), and a purpose-built time-series database for metrics (Prometheus, InfluxDB, TimescaleDB) that stores and compresses (timestamp, value, tags) tuples far more efficiently than a general row store would. A design that tries to store both in the same general-purpose database will underperform both use cases.

**Local agent buffering — protecting the emitting application.** Every emitting service runs a lightweight local agent (or sidecar) that batches log lines and metric points in memory/local-disk buffer and ships them asynchronously in batches, rather than the application making a synchronous network call per log line or metric point. This is non-negotiable: a monitoring system that can slow down or crash the applications it's supposed to be observing has failed at its actual job. If the ingestion pipeline is degraded or unreachable, the agent should buffer locally (bounded, with sensible drop/overflow policy under sustained backpressure) rather than block the application thread.

**Ingestion pipeline — buffer, then process asynchronously.** Both log and metric ingestion endpoints write into a high-throughput buffer (a Kafka-style log, or an equivalent durable queue) immediately on receipt, decoupling "accept the data" from "process/index/store the data." Downstream stream processors consume from this buffer to parse, enrich, downsample (metrics), and index (logs) at whatever pace the storage backend can sustain — this buffer is what absorbs traffic spikes (a service emitting a burst of error logs during an incident, ironically exactly when you most need the logging system not to fall over) without back-pressuring all the way to the emitting applications.

**Metric downsampling and tiered retention.** Storing every raw 10-second metric point forever is neither necessary nor affordable. A common pattern: keep raw-resolution data in a hot tier for a short window (days), then progressively downsample (aggregate into 1-minute, then 1-hour rollups) as data ages into cold storage — recent debugging needs fine-grained resolution, but a dashboard showing "CPU usage over the last 6 months" doesn't need every 10-second sample, and pretending it does wastes enormous storage for no queryable benefit. The same tiering logic applies to logs: hot/fast-indexed for recent data, compressed/archived (and often only partially re-indexed, or indexed with reduced fidelity) for older data kept mainly for compliance/rare historical lookup.

**Search architecture for logs.** Log search queries hit the inverted-index engine, never the raw ingestion buffer or a naive full-table scan — indexing happens asynchronously as part of the ingestion pipeline (same "separate the write-optimized path from the read-optimized index" pattern seen in Twitter's search, Day 10, and the e-commerce catalog search, Day 23). A brief indexing lag (seconds) between a log being emitted and it becoming searchable is an accepted trade-off, since even sub-minute lag is fine for incident response relative to how quickly a human can act on search results anyway.

**Alerting — trading detection speed against false-positive fatigue.** An alert evaluator continuously (or on a short polling interval) checks metric values against `alert_rules` conditions. The core design tension: evaluate too eagerly on noisy, single-point data and you get flapping alerts that page someone for a one-second blip (alert fatigue causes real incidents to get ignored); evaluate too conservatively (long averaging windows, high thresholds) and you're slow to detect real problems. The standard mitigation is a sustained-condition requirement — e.g., "error rate must exceed 5% for 3 consecutive 1-minute evaluation windows" rather than firing on a single sample — plus severity tiering (a brief, mild threshold breach pages nobody automatically but logs for later review; a sustained, severe breach pages on-call immediately) and using rate-of-change/anomaly detection rather than static thresholds where traffic patterns are highly variable (e.g., normal daily/weekly cyclicality shouldn't trigger a "traffic dropped" alert at 3am just because 3am traffic is naturally low).

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Separate log store (search index) vs. metric store (time-series DB) | Each optimized for its actual access pattern | Two storage systems to run instead of one |
| Local agent buffering, async shipping | Emitting application is never slowed by monitoring | Small window of potential data loss if the agent/buffer overflows during a sustained outage |
| Kafka-style ingestion buffer ahead of processing | Absorbs traffic spikes without back-pressuring producers | Adds a component and a small end-to-end latency before data is queryable |
| Tiered retention with downsampling | Massive storage/cost savings for old data | Old data loses fine-grained resolution — acceptable since old fine-grained data is rarely needed |
| Sustained-condition alerting (not single-sample) | Fewer false-positive pages, less alert fatigue | Slightly slower detection of genuine, brief incidents |

## Likely follow-up questions — with answers

**Q: During a major incident, log volume spikes 20x as every affected service logs errors aggressively. How does the system avoid falling over exactly when it's needed most?**
A: The local agent buffers and the Kafka-style ingestion buffer are both explicitly sized/designed to absorb multi-x traffic spikes without back-pressuring the emitting services — this is the entire reason ingestion is decoupled from processing/indexing. If the downstream indexer genuinely can't keep up with the surge, indexing lag increases (logs become searchable a bit later than usual) rather than ingestion failing outright or blocking applications — a graceful degradation (slower search availability) instead of a hard failure (dropped logs or slowed applications), which is the correct trade-off given the stated non-functional requirement that the write path must never block the emitting application.

**Q: How would you detect an anomaly (like a slow traffic decline) that a simple threshold alert would miss?**
A: Use rate-of-change or statistical/seasonal baseline comparison instead of a static threshold — compare current metric behavior against a learned baseline for the same time-of-day/day-of-week (accounting for normal cyclical patterns), and alert on significant deviation from that baseline rather than an absolute number. This catches genuinely anomalous slow declines that a fixed threshold (calibrated for, say, a sudden 50% drop) would miss, at the cost of a more complex evaluation model that needs enough historical data to establish a reliable baseline.

**Q: Why keep logs and metrics as separate systems instead of just logging everything and computing metrics from log queries?**
A: Computing aggregate metrics (average latency, p99, request rate) by querying raw log text at read time doesn't scale to dashboard-refresh and alert-evaluation frequencies — a time-series database precomputes and stores exactly the (timestamp, value, tags) structure needed for fast range/aggregation queries, while a log search index is optimized for a completely different query shape (full-text/field search over unstructured text). Using logs as your metrics backend means paying an expensive full-text-search-shaped cost for what should be a cheap numeric-aggregation-shaped query — the wrong tool measured against the actual read pattern.

## Key takeaways

- Logs and metrics are architecturally different systems (inverted-index search vs. time-series database) because their access patterns genuinely differ — write-once-read-rarely-and-deeply vs. write-frequently-read-even-more-frequently-and-numerically.
- A local agent that buffers and ships asynchronously is what guarantees the monitoring system can never slow down or crash the applications it observes — this is the system's most important non-functional requirement.
- An ingestion buffer (Kafka-style) decoupling accept-from-process is what lets the system absorb the traffic spikes that incidents themselves cause, without falling over exactly when it's needed most.
- Tiered retention with progressive downsampling trades old-data resolution for storage cost — recent data needs fine granularity, old data mostly doesn't.
- Alerting design is fundamentally a trade-off between detection speed and false-positive fatigue — sustained-condition rules and severity tiering are the standard mitigation, not single-sample thresholds.
- This system reuses the "separate write-optimized ingestion from read-optimized index, accept async lag" pattern seen throughout the course (Twitter search, e-commerce catalog search) — recognize it as a repeat, not a new problem.
