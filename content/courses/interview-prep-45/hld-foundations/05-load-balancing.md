---
kind: lesson
id_key: interview-prep-45/hld-05-load-balancing
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Load Balancing, Proxies, and Scaling Out"
position: 5
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

"Add a load balancer" is the answer almost everyone reaches for the moment traffic grows, and by itself it earns you nothing. A load balancer is a server that sits in front of your other servers and spreads incoming requests across them. What actually earns points is knowing which layer it works at, which algorithm it uses and why, what happens when one of your servers dies mid-request, and what happens when the load balancer itself dies.

## Vertical vs horizontal, and what makes scaling out possible

**Vertical scaling** means buying a bigger machine. It's genuinely the right first move more often than interview prep suggests: there's no distributed-systems complexity to manage, no code changes needed, and a single modern machine can handle a lot. It does have a hard ceiling, and the cost climbs faster than the power once you're near the top of what one machine can do. It also leaves you with exactly one machine to lose.

**Horizontal scaling** means adding more machines instead of a bigger one. It has no real ceiling and it survives one machine dying, but it demands one property from your application: it must be **stateless**.

An app server is stateless when any one of its copies can answer any incoming request, because none of them is holding on to something the others don't have. In practice that means:

- Don't store login sessions in one server's own memory. Put them in Redis (a shared, fast data store), or use a signed token the client itself carries.
- Don't keep a private cache of changing shared data on one server. Share it through Redis, or accept, on purpose, that different servers might show slightly different data for a moment.
- Don't write files to local disk that matter later. Put them in object storage instead, a service built for storing files.
- Don't hardcode "the third server is the one that runs the nightly job." Use a scheduler that picks exactly one runner through leader election, a mechanism covered later in this section.

Say this out loud whenever you draw several copies of an app server on your diagram: "these are stateless, session data lives in Redis, so I can add or remove instances freely." That one sentence turns a plain box diagram into a considered design.

State never actually disappears. It just moves into fewer places: the database, the cache, and the queue. That's why so much of system design keeps coming back to those three boxes.

> **Remember:** any single server instance must be replaceable at any moment. If losing one instance loses data a user needed, that data was stored in the wrong place.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-scaling-q1", "type": "mcq",
      "prompt": "An app stores logged-in user sessions in each server's own memory. What breaks when you put three of these servers behind a load balancer that rotates requests evenly?",
      "options": [
        {"id":"a","text":"Nothing, because the load balancer copies memory between the servers automatically"},
        {"id":"b","text":"Users appear randomly logged out, because a request can land on a server that never saw their original login and so has no session for them"},
        {"id":"c","text":"Encrypted connections fail to set up"},
        {"id":"d","text":"The database becomes the bottleneck"}
      ],
      "correct": "b",
      "explanation": "Storing sessions in one server's own memory means the servers are no longer interchangeable. The fixes are a shared session store like Redis, a self-contained token like a JWT, or always sending the same user to the same server (sticky sessions). Sticky sessions are the worst of the three: they unbalance the load and lose that user's session entirely if that one server goes down." }
] }
```

## L4 vs L7, and the algorithms

Picture a mail sorter who only glances at the envelope's address, compared with a receptionist who actually opens the letter and reads what it asks for. The sorter is faster, because it reads less. The receptionist can make smarter decisions, because it reads more. Load balancers come in these same two kinds.

**Layer 4** load balancing decides where to send traffic based only on the connection itself: the IP address and port. It never looks inside the actual message being sent. It's very fast, it works for any kind of traffic, and once a connection is set up, it sticks to the same server for its entire lifetime.

**Layer 7** load balancing ends the connection at the balancer itself, reads the actual HTTP request, and can route based on the URL path, a header, a cookie, or the method used. That's what makes path-based routing possible, like sending `/api/*` to one service and `/static/*` to a CDN, along with routing a small slice of traffic to a new build based on a header, and even rewriting or caching responses. It costs more CPU, and it only works for HTTP-style traffic.

| | L4 | L7 |
|---|---|---|
| Sees | IP address and port only | The full HTTP request |
| Balances | Per connection | Per request |
| Can route by | Nothing beyond IP and port | Path, header, cookie, method |
| Encrypted connections | Passes through, or ends them | Ends them, and can re-encrypt |
| Throughput | Very high | Lower, because it has to parse each request |
| Typical tools | AWS NLB, IPVS | AWS ALB, nginx, Envoy, HAProxy |

**The algorithms, and when each one is the wrong choice:**

| Algorithm | What it does | Fails when |
|---|---|---|
| Round robin | Sends each new request to the next server in turn | Requests cost very different amounts of work, or servers have different capacity |
| Weighted round robin | Same idea, but bigger servers get more turns | Same weakness as round robin, just handles unequal hardware better |
| **Least connections** | Sends the request to whichever server currently has the fewest in-flight requests | Rarely a bad choice; a safe default when requests cost different amounts |
| Least response time | Sends the request to whichever server answered fastest recently | Can overwhelm a server that just came back online empty and looks fast for a moment |
| IP hash or consistent hash | The same client, or the same key, always lands on the same server | Traffic can be unevenly spread across clients; needed when you want cache hits to stay on one server, or a session to stick to one machine |
| Random two choices | Pick two servers at random, send it to whichever of the two has less load | Nearly as good as least-connections, with much less coordination needed |

A complete answer to "which algorithm would you use?" is: "round robin by default, least-connections when requests cost different amounts, and consistent hashing when I need cache locality or a session to stick to one machine."

> **Remember:** L4 reads the envelope, L7 reads the letter. Reach for L7 the moment you need to route by path, header, or cookie.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-l4l7-q1", "type": "mcq",
      "prompt": "You need to send `/api/*` to the API service, `/images/*` to a media service, and 5% of traffic carrying a specific header to a new build. What do you need?",
      "options": [
        {"id":"a","text":"An L4 load balancer, because it's faster"},
        {"id":"b","text":"An L7 load balancer, because only it reads the actual HTTP request and can therefore route on path and header"},
        {"id":"c","text":"DNS round robin"},
        {"id":"d","text":"Consistent hashing on the client's IP address"}
      ],
      "correct": "b",
      "explanation": "An L4 balancer only ever sees the IP address and port, so path-based and header-based rules are simply impossible for it to apply. Routing by the content of a request is exactly the reason to accept L7's extra parsing cost." }
] }
```

## Health checks, draining, and failing over the balancer itself

A load balancer that keeps sending traffic to a server that's already dead is worse than having no load balancer at all.

**There are two useful kinds of health check, and they answer different questions.**

- **Liveness** asks "is the process still alive?" If it fails, the answer is to restart that process.
- **Readiness** asks "can this server actually handle traffic right now?" If it fails, the answer is to stop sending it traffic, without killing it. This is the check a load balancer must use. A server that's still warming up its cache, or one whose database connections are all in use, is alive but not ready.

Keep the readiness check **shallow by default**, meaning it should only check the server itself, not everything it depends on. A readiness check that also verifies the database connection means one short database hiccup marks every single app server unhealthy at the exact same moment, taking your entire fleet out of rotation at once. That's a self-inflicted outage. Check deeper dependencies through a separate check that doesn't affect routing.

**Passive health checking** works alongside active checks: after a server fails a number of requests or times out repeatedly, take it out of rotation automatically, then let it back in gradually once it recovers. This is sometimes called outlier detection.

**Connection draining** matters during a deploy: stop sending *new* requests to a server that's shutting down, but let its requests already in flight finish, up to a timeout. Skip this step and every deploy throws errors at whoever happened to be mid-request.

**Who watches the load balancer itself?** Say this before the interviewer has to ask.

1. Run at least two load balancer machines. Either DNS returns both addresses, or they share one address with automatic failover between them.
2. Use your cloud provider's managed load balancer, which is itself already spread across multiple machines and zones.
3. For failing over between entire regions, combine anycast (one address advertised from many sites) with DNS health checks using a short TTL, so DNS itself pulls a dead region out of rotation.

> **Remember:** liveness asks "is it alive?" Readiness asks "can it serve traffic right now?" The load balancer should always ask readiness, and readiness should never depend on a shared dependency.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-health-q1", "type": "mcq",
      "prompt": "Why is it dangerous for an app server's readiness check to also verify its database connection?",
      "options": [
        {"id":"a","text":"It makes the health check slightly slower"},
        {"id":"b","text":"A single database hiccup marks every app instance unhealthy at the same moment, so the load balancer removes the entire fleet at once, turning a partial problem into a total outage"},
        {"id":"c","text":"Health checks are not allowed to make network calls"},
        {"id":"d","text":"It would reveal database credentials"}
      ],
      "correct": "b",
      "explanation": "A readiness check should describe the instance itself, not its dependencies. Putting a shared dependency in it ties every instance's health to the same failure, and removing the whole fleet is far worse than serving slightly degraded responses while the database recovers." }
] }
```

## Reverse proxy, API gateway, sidecar, service mesh

These four ideas overlap, and interviewers like hearing you tell them apart.

| Box | Sits | Job |
|---|---|---|
| **Reverse proxy** (like nginx or Envoy) | In front of your servers | Ends encrypted connections, compresses responses, caches static files, does basic routing, shields slow clients from your app |
| **API gateway** (like Kong, or AWS's ALB with Lambda, or Apigee) | At the edge, between the outside world and your system | Everything a reverse proxy does, plus checking who's calling, rate limits, quotas, API keys, versioning, and reshaping requests and responses |
| **Sidecar proxy** (like Envoy running next to each service) | Right beside each individual service | Handles encrypted service-to-service calls, retries, timeouts, and tracing for that one service, without the service's own code needing to know |
| **Service mesh** (like Istio or Linkerd) | A control layer managing every sidecar | Fleet-wide rules: encryption everywhere, splitting traffic between versions, retry limits, and consistent monitoring |

Two directions are worth naming clearly. **North-south** traffic flows between the outside world and your system; that's the gateway's job. **East-west** traffic flows between your own internal services; that's the mesh's job.

**Service discovery** is what makes any of this work as servers come and go. Something has to keep track of which servers currently exist.

- **Server-side discovery**: clients call one stable load balancer address, and the load balancer itself knows the current list of servers, kept up to date by a tool like Consul, etcd, or Kubernetes. It's simple, at the cost of one extra network hop.
- **Client-side discovery**: clients fetch the current list themselves and pick which server to call. It saves that extra hop and can make smarter choices, but every client, in every programming language, needs that same logic built in, which is exactly why sidecars exist: they carry that logic once, outside the application code.

One failure mode worth naming for a load balancer itself: it can run out of **bandwidth** just as easily as it can run out of capacity for requests. Streaming 75 gigabits per second of video out cannot pass through a single load balancer; that traffic has to go around it entirely, through a CDN or through direct, signed links to object storage.

> **Remember:** a gateway handles traffic between the outside world and your system (north-south). A sidecar mesh handles traffic between your own services (east-west). They solve different problems.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-05-proxy-q1", "type": "mcq",
      "prompt": "What does a sidecar proxy running next to each service give you that an edge API gateway does not?",
      "options": [
        {"id":"a","text":"Ending encrypted connections for outside clients"},
        {"id":"b","text":"Control over service-to-service calls, like encryption, retries, timeouts, and tracing, without changing application code in every service's own language"},
        {"id":"c","text":"Managing API keys for outside developers"},
        {"id":"d","text":"Caching static files"}
      ],
      "correct": "b",
      "explanation": "The gateway governs north-south traffic coming in from outside. A sidecar governs east-west traffic between your own internal services, which never passes through the edge at all; that's the exact gap a service mesh fills." }
] }
```

## Quick recap

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
