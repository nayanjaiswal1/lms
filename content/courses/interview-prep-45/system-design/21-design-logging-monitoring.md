---
kind: lesson
type: system_design
id_key: interview-prep-45/day-27-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Logging and Monitoring System"
position: 21
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

A logging and monitoring platform, think Datadog, Splunk, or an internal setup built on the ELK stack, is infrastructure for infrastructure: every other system quietly depends on it. This question tests whether you understand splitting the write path from the read path at extreme volume, the real difference between logs and metrics, and how alerting has to trade detection speed against false-positive noise.

## Requirements

**Functional requirements**
- Collect logs (structured or unstructured text events) from many services.
- Collect metrics (numeric time series: request rate, latency, error rate, CPU).
- Search logs by service, time range, and free text or fields.
- Alert when a metric crosses a threshold, or a log pattern signals an incident.

**Non-functional requirements**
- Extremely high write throughput. Every service in the organization emits continuously; this system cannot become the bottleneck for everything else.
- The write path must never block the emitting application. A slow logging pipeline should never slow down the actual service being watched.
- Query and search latency matters for incident response: someone debugging a live outage needs results in seconds.
- Tiered retention: recent data (hours to days) needs fast access; older data (weeks to months) can be slower and cheaper.
- Alerting must balance detection speed against false-positive fatigue.

> **Remember:** a monitoring system that can slow down or crash the applications it watches has failed at its one job. Everything about the write path in this design exists to prevent that.

```knowledge-check
{ "questions": [
    { "id": "system-design-logging-requirements-q1", "type": "mcq", "prompt": "Why is \"never block the emitting application\" treated as a non-negotiable requirement for a monitoring system?", "options": [
        {"id": "a", "text": "It's a nice-to-have that can be relaxed under normal conditions"},
        {"id": "b", "text": "A monitoring system's entire purpose is to observe other services, so if it slows or crashes them, it has actively made the thing it's supposed to help worse"},
        {"id": "c", "text": "Blocking only matters for metrics, not for logs"},
        {"id": "d", "text": "Applications are expected to handle monitoring outages themselves"}
    ], "correct": "b", "explanation": "The whole point of observability tooling is to watch the real system without becoming part of its critical path. A monitoring system that can take down what it monitors defeats its own purpose." }
] }
```

## Estimates

Assume a mid-to-large organization: 5,000 service instances, each emitting continuously.

- **Logs:** if each instance emits about 50 log lines/sec on average (more under load or errors), that's 250,000 log lines/sec across the fleet, about 21.6 billion lines a day. At roughly 300 bytes per line, that's about 6.5 TB/day of raw log volume.
- **Metrics:** if each instance reports about 50 distinct metrics every 10 seconds, that's 5 metric points/sec/instance × 5,000 = 25,000 points/sec, about 2.16 billion points a day. Each point is small, a timestamp, a number, and a few tags, tens of bytes, but sampled far more frequently and queried far more often (every dashboard refresh, every alert check) than logs are ever read.
- The gap between log volume (terabytes a day, mostly written once and read rarely) and metric query volume (constant reads against a much smaller footprint) is exactly why logs and metrics end up as architecturally different systems under one product.
- **Retention:** a hot tier for fast queries commonly covers 7-14 days; a cold, compressed tier extends to months or years for compliance and historical analysis.

## API

```
POST /ingest/logs          { service, level, message, fields{}, timestamp }   -- high-volume, fire-and-forget from clients
POST /ingest/metrics        { metric_name, value, tags{}, timestamp }          -- high-volume

GET  /logs/search?query=&service=&from=&to=&cursor=      -> { logs[], next_cursor }
GET  /metrics/query?metric=&tags=&from=&to=&aggregation=  -> { series[] }       -- e.g. avg/p99/sum over time buckets

POST /alerts                { metric_or_query, condition, threshold, notify_channels[] }
GET  /alerts/{id}/history                                  -> { firings[] }
```

Ingestion endpoints are optimized purely for high-throughput accept-and-buffer, not for validation-heavy processing. Anything expensive, parsing, indexing, enrichment, happens asynchronously downstream, never inside the request the emitting application is waiting on.

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

## High-level design

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
                             system (reuse the channel-routing pattern from
                             the notification service design)
```

## Deep dives

### Why aren't logs and metrics just one system?

Logs are unstructured-ish text, written far more often than read, and searched deeply, full-text, arbitrary field filters, but rarely, usually by one engineer investigating a specific incident. Metrics are strictly numeric, written frequently and read even more frequently, since every dashboard panel and every alert evaluation is a metrics read, and they need fast time-range aggregation like an average or a p99 over a window, not text search.

Those completely different access patterns justify genuinely different storage engines underneath: an inverted-index search engine for logs, and a purpose-built time-series database for metrics that stores and compresses timestamp-value-tag tuples far more efficiently than a general row store would. A design that tries to cram both into the same general-purpose database underperforms at both jobs.

> **Remember:** logs and metrics look similar on the surface, both are "data about what happened," but their read patterns are opposites: logs are read rarely and deeply, metrics are read constantly and numerically. That difference is what forces two separate storage engines.

```knowledge-check
{ "questions": [
    { "id": "system-design-logging-splitstore-q1", "type": "mcq", "prompt": "Why do logs and metrics need genuinely different storage engines instead of sharing one general-purpose database?", "options": [
        {"id": "a", "text": "It's purely a historical accident, not a real technical need"},
        {"id": "b", "text": "Their access patterns are fundamentally different: logs are searched deeply but rarely, while metrics are read constantly for numeric aggregation, and each pattern needs its own optimized engine"},
        {"id": "c", "text": "Logs and metrics cannot both exist in the same organization"},
        {"id": "d", "text": "Metrics are always more important than logs, so they get their own database"}
    ], "correct": "b", "explanation": "A single general-purpose store optimized for neither full-text search nor time-series aggregation would perform worse at both jobs than two purpose-built systems would." }
] }
```

### How does the write path avoid ever slowing down the application it's monitoring?

Every emitting service runs a lightweight local agent that batches log lines and metric points in a local buffer and ships them asynchronously, rather than the application making a synchronous network call per line or point. This is non-negotiable. If the ingestion pipeline is degraded or unreachable, the agent buffers locally, bounded, with a sensible drop policy under sustained backpressure, rather than blocking the application's own thread.

Both ingestion endpoints then write straight into a high-throughput durable buffer the instant they receive data, decoupling "accept the data" from "process, index, and store the data." Downstream stream processors consume from that buffer to parse, enrich, downsample, and index at whatever pace the storage backend can sustain. This buffer is exactly what absorbs a traffic spike, a service emitting a burst of error logs during an incident, ironically exactly when you most need the logging system to not fall over, without ever pushing that backpressure onto the emitting applications.

### How do you avoid paying to store every raw data point forever?

A common pattern: keep raw-resolution data in a hot tier for a short window, days, then progressively downsample into 1-minute, then 1-hour rollups as data ages into cold storage. Recent debugging genuinely needs fine-grained resolution, but a dashboard showing CPU usage over the last six months doesn't need every 10-second sample, and storing it that way wastes enormous space for no real query benefit. The same tiering idea applies to logs: hot and fully indexed for recent data, compressed and archived, often with reduced indexing fidelity, for older data kept mainly for compliance or rare historical lookup.

Log search itself always hits the inverted-index engine, never the raw ingestion buffer or a full-table scan, with indexing happening asynchronously as part of the pipeline, the same separate-the-write-path-from-the-read-index pattern that shows up in search-heavy designs elsewhere. A brief indexing lag of a few seconds between a log being emitted and becoming searchable is an accepted trade-off.

### How does alerting avoid paging someone for a one-second blip?

An alert evaluator continuously checks metric values against alert rules. The core tension: evaluate too eagerly on noisy, single-point data and you get flapping alerts that page someone for a meaningless blip, which causes alert fatigue and makes people start ignoring real incidents too. Evaluate too conservatively, long averaging windows, high thresholds, and you're slow to catch a genuine problem.

The standard fix is a sustained-condition requirement: "error rate must exceed 5% for 3 consecutive 1-minute windows," not a single sample, combined with severity tiering, a brief mild breach logs for later review but doesn't page anyone, while a sustained severe breach pages on-call immediately. For highly variable traffic, rate-of-change or anomaly detection against a learned baseline beats a static threshold, since normal daily or weekly cycles shouldn't trigger a "traffic dropped" alert just because 3am traffic is naturally low.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Separate log store (search index) vs. metric store (time-series DB) | Each is optimized for its actual access pattern | Two storage systems to run instead of one |
| Local agent buffering, async shipping | The emitting application is never slowed by monitoring | A small window of possible data loss if the buffer overflows during a sustained outage |
| Ingestion buffer ahead of processing | Absorbs traffic spikes without back-pressuring producers | Adds a component and a small end-to-end delay before data is queryable |
| Tiered retention with downsampling | Massive storage savings for old data | Old data loses fine-grained resolution, acceptable since it's rarely needed at that detail |
| Sustained-condition alerting, not single-sample | Fewer false-positive pages, less alert fatigue | Slightly slower detection of genuine, brief incidents |

**Q: During a major incident, log volume spikes 20x as every affected service logs errors aggressively. How does the system avoid falling over exactly when it's needed most?**
A: The local agent buffer and the ingestion buffer are both sized to absorb multi-x traffic spikes without back-pressuring the emitting services, since ingestion is decoupled from processing. If the downstream indexer genuinely can't keep up, indexing lag increases, logs become searchable a bit later than usual, rather than ingestion failing outright or applications slowing down. That's graceful degradation instead of a hard failure, exactly the trade-off the write-path requirement demands.

**Q: How would you detect a slow, gradual anomaly, like a slow traffic decline, that a simple threshold alert would miss?**
A: Compare current metric behavior against a learned baseline for the same time of day and day of week, accounting for normal cyclical patterns, and alert on a significant deviation from that baseline rather than a fixed number. This catches a genuinely anomalous slow decline that a threshold calibrated for a sudden drop would miss.

**Q: Why not just log everything and compute metrics from log queries instead of running two systems?**
A: Computing aggregates like average latency or p99 by querying raw log text at read time doesn't scale to dashboard-refresh and alert-evaluation frequencies. A time-series database precomputes exactly the structure needed for fast range and aggregation queries, while a log search index is built for a completely different query shape. Using logs as a metrics backend pays an expensive full-text-search cost for what should be a cheap numeric aggregation.

```knowledge-check
{ "questions": [
    { "id": "system-design-logging-tradeoffs-q1", "type": "mcq", "prompt": "Why does the system respond to an ingestion overload by increasing search indexing lag rather than dropping incoming logs or slowing the emitting applications?", "options": [
        {"id": "a", "text": "Dropping logs would actually be the better choice here"},
        {"id": "b", "text": "Because the write path must never block applications, graceful degradation (slower search availability) is the correct trade-off compared to a hard failure"},
        {"id": "c", "text": "Indexing lag is always zero regardless of load"},
        {"id": "d", "text": "The system has no way to detect an overload"}
    ], "correct": "b", "explanation": "Given the stated requirement that the write path must never block the emitting application, letting search results arrive a bit later during extreme load is the acceptable failure mode, not dropping data or slowing down services." }
] }
```
