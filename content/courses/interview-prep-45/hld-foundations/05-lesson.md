---
kind: lesson
id_key: interview-prep-45/hld-05-load-balancing
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Load Balancing, Proxies, and Scaling Out"
position: 5
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

"Add a load balancer" is the reflex answer to every scaling question, and on its own it earns nothing. What earns points is knowing which layer it operates at, which algorithm it uses and why, what happens when a backend dies mid-request, and what the load balancer itself does when *it* dies.

## Vertical vs horizontal, and what makes scaling out possible

**Vertical scaling** (a bigger machine) is genuinely the right first move more often than interviews suggest: no distributed-systems complexity, no code change, and modern single machines are enormous. It ends at a hard ceiling, costs superlinearly at the top end, and leaves you with one thing to lose.

**Horizontal scaling** (more machines) is unbounded and fault-tolerant, and it demands one property from your application: **statelessness**.

An app server is stateless when any request can be served by any instance. That means:

- No in-process session store → sessions in Redis, or a signed JWT the client carries.
- No in-process cache of mutable shared state → shared Redis, or accept per-node staleness deliberately.
- No local file writes that matter → object storage.
- No "the third instance is the one that runs the cron" → a scheduler with leader election.

Say this explicitly when you draw multiple app boxes: "these are stateless, session state is in Redis, so I can add or lose instances freely." It converts a generic diagram into a considered one.

State does not disappear, it *concentrates* — into the database, the cache, and the queue. That is why the rest of this section is mostly about those three.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-scaling-q1", "type": "mcq",
      "prompt": "An app stores logged-in user sessions in each server's memory. What breaks when you put three instances behind a round-robin load balancer?",
      "options": [
        {"id":"a","text":"Nothing — the load balancer replicates memory between instances"},
        {"id":"b","text":"Users appear randomly logged out, because a request routed to an instance that doesn't hold their session finds none"},
        {"id":"c","text":"TLS handshakes fail"},
        {"id":"d","text":"The database becomes the bottleneck"}
      ],
      "correct": "b",
      "explanation": "In-process session state makes instances non-interchangeable. The fixes are a shared session store (Redis), a self-contained token (JWT), or sticky sessions — and sticky sessions are the worst of the three because they break even balancing and lose sessions when an instance dies." }
] }
```

## L4 vs L7, and the algorithms

**Layer 4** balances on TCP/UDP connection info (IP + port). It cannot see the HTTP request. It is very fast, protocol-agnostic, and does connection-level balancing — one long-lived connection sticks to one backend for its whole life.

**Layer 7** terminates the connection, parses HTTP, and can route on path, header, cookie, or method. That unlocks path-based routing (`/api/*` → services, `/static/*` → CDN origin), header-based canaries, per-request balancing over HTTP/2, request rewriting, and response caching — at the cost of more CPU and being HTTP-specific.

| | L4 | L7 |
|---|---|---|
| Sees | IP, port | Full HTTP request |
| Balances | Per connection | Per request |
| Routing rules | None | Path, header, cookie, method |
| TLS | Passes through (or terminates) | Terminates, can re-encrypt |
| Throughput | Very high | Lower (parsing cost) |
| Typical | AWS NLB, IPVS | AWS ALB, nginx, Envoy, HAProxy |

**Algorithms — know when each is wrong:**

| Algorithm | Behaviour | Fails when |
|---|---|---|
| Round robin | Next backend in rotation | Requests have very different costs, or backends differ in size |
| Weighted round robin | Rotation biased by capacity | Same as above, but handles heterogeneous hardware |
| **Least connections** | Fewest in-flight requests wins | Rarely wrong — the sane default for varied request costs |
| Least response time | Fastest recent backend wins | Can stampede a newly-fast (empty, cold) node |
| IP hash / consistent hash | Same client (or key) → same backend | Uneven client distribution; needed for cache locality and sticky routing |
| Random two-choices | Pick 2 at random, take the less loaded | Almost as good as least-connections with far less coordination |

"Round robin by default, least-connections when request cost varies, consistent hashing when I need cache locality or session affinity" is a complete answer to "which algorithm?".

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-l4l7-q1", "type": "mcq",
      "prompt": "You need to route `/api/*` to the API service and `/images/*` to a media service, and send 5% of traffic carrying a `x-canary: true` header to a new build. What do you need?",
      "options": [
        {"id":"a","text":"An L4 load balancer, which is faster"},
        {"id":"b","text":"An L7 load balancer — only it parses the HTTP request, so only it can route on path and header"},
        {"id":"c","text":"DNS round robin"},
        {"id":"d","text":"Consistent hashing on client IP"}
      ],
      "correct": "b",
      "explanation": "L4 sees only IP and port, so path- and header-based rules are impossible there. Content-based routing is exactly the reason to pay L7's parsing cost." }
] }
```

## Health checks, draining, and failing over the balancer itself

A load balancer that keeps sending traffic to a dead backend is worse than no load balancer.

**Health checks come in two useful flavours:**

- **Liveness** — "is the process alive?" A failure means restart me.
- **Readiness** — "can I serve traffic right now?" A failure means take me out of rotation but don't kill me. This is the one the load balancer must use. A node warming its cache, or one whose database connection pool is exhausted, is live but not ready.

Make the readiness endpoint **shallow by default**. A `/health` that checks the database means one database blip marks every app node unhealthy at once and takes the whole fleet out of rotation — a classic self-inflicted outage. Check dependencies in a separate, non-routing-affecting endpoint.

**Passive health checking** complements active probes: eject a backend after N consecutive errors or timeouts (outlier detection), then let it back in gradually.

**Connection draining** on deploy: stop sending *new* requests to an instance, let in-flight requests finish (up to a timeout), then terminate. Without it every deploy throws 502s at whoever was mid-request.

**Who balances the balancer?** Say this before you are asked:

1. Run at least two LB nodes; DNS returns both IPs, or they share a floating/virtual IP with automatic failover.
2. Use the cloud's managed LB (ALB/NLB), which is itself a distributed, multi-AZ service.
3. **Anycast + DNS health checks** for cross-region failover: one IP advertised from many sites, and DNS with a short TTL pulling a dead region out.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-health-q1", "type": "mcq",
      "prompt": "Why is it dangerous for an app server's load-balancer health check to verify the database connection?",
      "options": [
        {"id":"a","text":"It makes the health check slightly slower"},
        {"id":"b","text":"A single database hiccup marks every app instance unhealthy simultaneously, so the load balancer removes the entire fleet and turns a partial degradation into a total outage"},
        {"id":"c","text":"Health checks are not allowed to make network calls"},
        {"id":"d","text":"It would expose database credentials"}
      ],
      "correct": "b",
      "explanation": "Health checks should describe the instance, not its dependencies. A shared dependency in a readiness probe correlates all instances' health — the fleet-wide removal is far worse than serving degraded responses while the DB recovers." }
] }
```

## Reverse proxy, API gateway, sidecar, service mesh

These four boxes overlap and interviewers like to hear you separate them.

| Box | Sits | Responsibilities |
|---|---|---|
| **Reverse proxy** (nginx, Envoy) | In front of servers | TLS termination, compression, static caching, basic routing, buffering slow clients |
| **API gateway** (Kong, ALB+Lambda, Apigee) | North–south edge | Everything a reverse proxy does, plus auth, rate limits, quotas, API keys, versioning, request/response transformation |
| **Sidecar proxy** (Envoy per pod) | Beside each service | Per-service mTLS, retries, timeouts, circuit breaking, tracing — with no application code |
| **Service mesh** (Istio, Linkerd) | Control plane over sidecars | Fleet-wide policy: mTLS everywhere, traffic splitting, retry budgets, uniform observability |

Two directions worth naming: **north–south** traffic is client↔system (gateway's job); **east–west** is service↔service (mesh's job).

**Service discovery** is the piece that makes any of this dynamic. Instances come and go, so something must maintain the list:

- **Server-side discovery**: clients call a stable load balancer address; the LB knows the current backends (registered via Consul/etcd, or Kubernetes Endpoints). Simple, one extra hop.
- **Client-side discovery**: clients fetch the instance list and balance themselves. One fewer hop, better balancing decisions, but every client language needs the logic — which is precisely why sidecars exist.

A load balancer's own failure mode to name: it is a bottleneck for **bandwidth**, not just requests. 75 Gbps of video egress cannot flow through one L7 proxy — that traffic must bypass it via a CDN or direct-to-object-storage signed URLs.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-proxy-q1", "type": "mcq",
      "prompt": "What does a sidecar proxy (e.g. Envoy per pod) give you that an edge API gateway does not?",
      "options": [
        {"id":"a","text":"TLS termination for external clients"},
        {"id":"b","text":"Per-service-to-service control — mTLS, retries, timeouts, circuit breaking and tracing on east–west calls — without changing application code in every language"},
        {"id":"c","text":"API key management for third-party developers"},
        {"id":"d","text":"Static asset caching"}
      ],
      "correct": "b",
      "explanation": "The gateway governs north–south traffic entering the system. A sidecar governs east–west traffic between internal services, which never passes through the edge — that is the gap a mesh fills." }
] }
```

## Key takeaways

**The recall card:**

```
Scale up first (simple, real ceiling) → scale out when you need HA or exceed one box
Scaling out requires statelessness: sessions → Redis/JWT, files → S3, cron → leader election
L4 = IP:port, per connection, fast     L7 = HTTP-aware, per request, routable
Default algorithm: round robin → least connections when request cost varies
                   → consistent hashing for cache locality / affinity
Readiness ≠ liveness. Never check shared dependencies in the routing health check.
Always: 2+ LBs, connection draining on deploy, outlier ejection on repeated errors
North–south = gateway. East–west = mesh/sidecar. Discovery = who's alive right now.
```

- **"Add a load balancer" is a sentence fragment.** Finish it: which layer, which algorithm, which health check, what happens on deploy, and who balances the balancer.
- **Sticky sessions are a smell**, not a solution — they unbalance the fleet and lose state on instance death. Externalise the state instead.
- **The load balancer can be a bandwidth bottleneck** long before it is a request bottleneck; heavy byte flows should route around it entirely.
