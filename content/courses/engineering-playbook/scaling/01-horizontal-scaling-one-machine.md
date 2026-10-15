---
kind: lesson
id_key: engineering-playbook/scaling/horizontal-scaling-one-machine
course: engineering-playbook
section: scaling
section_title: "Scaling"
section_position: 2
title: Horizontal scaling on a single machine
position: 0
estimated_minutes: 15
source:
  - interview-prep-notes.md
---

# Horizontal scaling on a single machine

Running several copies of your app on **one** server gives you little extra raw performance, but a lot of reliability and operational benefit.

## Mental model

A shop has one counter and one person behind it. You add 4 counters in the same shop. The floor space (CPU/RAM) is unchanged, but:

- If one cashier gets stuck, the other 3 keep serving.
- Instead of one customer at a time, 4 are served in parallel.

## What you actually gain

**1. Full multi-core use (the biggest practical win).**
Python (Django/FastAPI under uvicorn) and Node.js mostly use **one core per process** (the GIL, or a single-threaded event loop). On an 8-core machine, one container leaves 7 cores idle. Running several workers/replicas uses them all. This is why `gunicorn -w 4` and `uvicorn --workers 4` are standard.

**2. Zero-downtime deploys.**
Update one replica, wait for its health check, then roll through the rest. With a single container, a restart is downtime.

**3. Fault isolation.**
If one process crashes (memory leak, unhandled exception), the load balancer drops it and the others keep taking traffic.

**4. Blast radius of slow requests.**
One heavy or stuck request ties up one process, not the whole app.

**5. Future-proofing.**
Replicas force the app to be **stateless** (sessions in Redis, uploads in object storage). When you later move to multiple machines, the code does not change.

## What you do NOT gain

- **Total capacity is unchanged.** 10 replicas on a 2-CPU box will not give 5x throughput; context switching can make it slower.
- **Single point of failure.** If the machine dies, everything dies. Real high availability needs separate machines or availability zones.
- **Shared bottlenecks.** DB, disk and network are still the same.
- **More RAM.** Each process has its own memory footprint.

## Thumb rule for the count

- Async servers (uvicorn/FastAPI, Node): about **1 worker per core**.
- Sync servers (gunicorn sync workers, where a worker blocks during I/O): the classic **`2 x cores + 1`**, because workers spend time waiting on I/O.

Going beyond this stops helping.

## In Docker

```bash
docker compose up -d --scale api=4
```

Put nginx in front; Docker's internal DNS resolves the service name to all replicas, giving round-robin. Alternatively run `uvicorn --workers 4` inside one container. Both use all cores; separate containers give better isolation and rolling updates.

## Interview line

> "On a single machine, horizontal scaling gives us multi-core utilization, zero-downtime deploys and process-level fault isolation. It does not protect against hardware failure or add real capacity; for that we need multiple nodes."

## Check question

Your machine has 4 cores, you run one FastAPI container, CPU shows 25%, and requests are slow. What does this tell you, and what do you do?

**Answer:** 25% of 4 cores is exactly one core fully busy. The single process is CPU-saturated on its one core while three cores sit idle. Run 4 workers (`--workers 4`) or 4 replicas behind the load balancer. If it is still slow afterwards, look at blocking calls inside async handlers or the DB, since those are shared bottlenecks.

## Key takeaways

- Same machine: more reliability and core usage, not more total capacity.
- One Python/Node process uses roughly one core; replicas fix that.
- Replica count is about the core count, not "as many as possible".
- Stateless app design is the price, and it pays off when you add machines.
