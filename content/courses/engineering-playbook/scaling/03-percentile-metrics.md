---
kind: lesson
id_key: engineering-playbook/scaling/percentile-metrics
course: engineering-playbook
section: scaling
section_title: "Scaling"
section_position: 2
title: Percentile metrics (p50, p95, p99)
position: 2
estimated_minutes: 15
source:
  - interview-prep-notes.md
---

# Percentile metrics (p50, p95, p99)

## Mental model

100 customers stand in a line. Sort everyone's wait time from smallest to largest.

- **p50:** the 50th customer's wait. 50% of requests were faster. This is the **median**, the typical experience.
- **p95:** 95% of requests were faster; only 5% were slower.
- **p99:** only 1% were slower. This is **tail latency**, the worst-case users' experience.

Industry standards are p50, p90, p95, p99, and p99.9 for critical systems.

## Why the average is not enough

Out of 100 requests, 95 take 100 ms and 5 take 5 s.

- Average is about 345 ms (looks acceptable)
- p50 = 100 ms
- p99 = 5 s (the real problem shows up here)

Averages hide outliers. That is why SLOs are written like "p99 latency < 500 ms".

**Tail amplification:** if a page makes 10 backend calls and each call has a slow p99, the chance that a user hits at least one slow call is 1 - 0.99^10, about **10%**. A p99 is not a rare edge case.

## How to measure

**1. Direct calculation (for understanding)**

```python
import numpy as np
latencies = [...]  # in ms
print(np.percentile(latencies, [50, 95, 99]))
```

**2. Production: Prometheus histogram + Grafana.** Record request duration as a **histogram** (`prometheus-fastapi-instrumentator` or `prometheus_client` for FastAPI, `django-prometheus` for Django), then query:

```
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
```

Compose: add Prometheus and Grafana containers. k3s: the `kube-prometheus-stack` Helm chart brings it all. See the previous lesson, Scaling and metrics setup.

**3. AWS.** ALB's **TargetResponseTime** in CloudWatch supports the `p99` statistic. API Gateway, CloudFront and Lambda also expose p-statistics. For tracing use X-Ray or OpenTelemetry.

**4. Load tests.** `k6`, `locust` or `wrk` print p50/p95/p99. Best way to see the effect of scaling: run before (1 replica) and after (4 replicas) and compare.

## Things to watch

- **You cannot average percentiles.** The average of 4 replicas' p99 values is meaningless. Collect histogram buckets and aggregate them, then compute the quantile (the `sum(...) by (le)` in the query does exactly this).
- Choose bucket boundaries well (for example 50 ms, 100 ms, 250 ms, 500 ms, 1 s, 2.5 s); with poor buckets the percentile is approximate and wrong.
- Look at **error rate** and **throughput (RPS)** together with latency. These three make the dashboard.

## Connection to scaling

HPA usually scales on CPU. If CPU is 25% but p99 is bad (as in the single-process example in the first scaling lesson), CPU is the wrong signal. Advanced setups scale on a custom metric such as p95 latency or queue depth (KEDA).

## Interview line

> "Averages hide outliers, so I track p50 for the typical experience and p95/p99 for tail latency, using histograms, and I never average percentiles across instances; I aggregate the buckets."

## Check question

You have 4 replicas with p99 of 200 ms, 220 ms, 180 ms and 1.5 s. Do you average these to get the overall p99? Why or why not, and what could make one replica so different?

**Answer:** No. A percentile is a position in a sorted distribution, so averaging per-replica percentiles gives a number that is not the p99 of anything (here about 525 ms, which is wrong). Sum the histogram buckets across replicas and compute the quantile on the merged histogram. Replicas also serve different request counts, so a low-traffic replica would be overweighted. Reasons one replica is slow: a noisy neighbour or throttled CPU limit, memory pressure or swap, a cold cache, GC pauses, a slow connection to a DB replica or a different AZ, a stuck worker, or uneven load balancing (long-lived connections pinned to it).

## Key takeaways

- p50 is typical, p99 is tail; averages hide the tail.
- Record histograms, aggregate buckets, then compute quantiles.
- Never average percentiles across instances.
- Pair latency with error rate and RPS; scale on the signal that matches the problem.
