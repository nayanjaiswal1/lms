---
kind: lesson
id_key: interview-prep-45/hld-03-networking
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Networking and Protocols for Design"
position: 3
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Every arrow you draw between two boxes is a network call, and interviewers probe those arrows: "how does the client find that server?", "how does the server push an update to the browser?", "why HTTP/2 there?". You do not need a networking degree — you need to know, for each arrow, which protocol carries it and what that choice costs.

## From URL to first byte

Know this sequence well enough to narrate it. It is asked directly ("what happens when you type a URL?") and it underpins CDN, load balancer, and TLS answers everywhere else.

```
1. DNS resolve      browser cache → OS cache → resolver → root → TLD → authoritative
                    returns an IP (or a CDN edge IP via geo/latency routing)
2. TCP handshake    SYN → SYN-ACK → ACK                       (1 round trip)
3. TLS handshake    TLS 1.3: 1 round trip (1.2 was 2)         (0-RTT on resume)
4. HTTP request     GET / with headers, cookies
5. Server work      LB → app → cache/DB → response
6. Response         HTML → browser parses → more requests for CSS/JS/images
```

Three facts that pay for themselves in interviews:

- **DNS is a routing tool, not just a lookup.** TTL controls how fast you can fail over; geo/latency-based DNS routes users to the nearest region; weighted records do gradual rollouts. A short TTL (30–60 s) buys fast failover at the cost of more DNS traffic.
- **Connection setup is expensive** — roughly 2 round trips before any application byte moves. Over a 150 ms link that is 300 ms of nothing. This is why keep-alive, connection pooling, and CDN edge termination matter so much.
- **Anycast** advertises one IP from many locations so the network routes each user to the closest site. It is how CDNs and DNS providers work, and how volumetric DDoS traffic gets absorbed across many sites.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-path-q1", "type": "mcq",
      "prompt": "You want to be able to fail traffic over to a standby region within a minute. What must you configure ahead of time?",
      "options": [
        {"id":"a","text":"A long DNS TTL, so clients cache the record and don't overload the resolver"},
        {"id":"b","text":"A short DNS TTL (e.g. 30–60 s), so clients pick up the new record quickly — plus health checks that trigger the change"},
        {"id":"c","text":"HTTP/3, because it reconnects faster"},
        {"id":"d","text":"TLS session resumption"}
      ],
      "correct": "b",
      "explanation": "Clients honour the TTL they were given, so a 24-hour TTL means a 24-hour tail of traffic to the dead region. Short TTLs are the price of DNS-based failover; the trade-off is more resolver queries." }
] }
```

## TCP vs UDP, and what QUIC changed

| | TCP | UDP |
|---|---|---|
| Delivery | Reliable, ordered, retransmits | Fire and forget, may drop or reorder |
| Setup | 3-way handshake | None |
| Congestion control | Yes | You build it or go without |
| Head-of-line blocking | Yes — one lost packet stalls everything behind it | No |
| Use for | APIs, databases, anything correctness-critical | Live video/voice, gaming, DNS, metrics |

The decision rule: **is a late packet worth more than no packet?** For a bank transfer, yes — retransmit. For a video call, no — a frame that arrives 400 ms late is worse than a dropped frame, so use UDP and conceal the loss.

**HTTP/3 runs over QUIC, which runs over UDP.** It rebuilds reliability, ordering, and congestion control in user space, which buys two things: independent streams (a lost packet stalls only its own stream, not the whole connection) and connection migration (your phone switching Wi-Fi→cellular keeps the connection alive because the connection ID, not the IP address, identifies it).

| Version | Key property |
|---|---|
| HTTP/1.1 | One request in flight per connection → browsers open ~6 connections per host |
| HTTP/2 | Multiplexed streams over one TCP connection, header compression, server push (now deprecated) — still suffers TCP head-of-line blocking |
| HTTP/3 | Same multiplexing over QUIC/UDP — no cross-stream head-of-line blocking, faster handshake, connection migration |

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-tcp-q1", "type": "mcq",
      "prompt": "HTTP/2 multiplexes many streams over one TCP connection. Which problem does that NOT solve, and HTTP/3 does?",
      "options": [
        {"id":"a","text":"Header size — HTTP/2 does not compress headers"},
        {"id":"b","text":"TCP-level head-of-line blocking: one lost packet stalls every multiplexed stream, because TCP must deliver bytes in order"},
        {"id":"c","text":"Encryption — HTTP/2 cannot use TLS"},
        {"id":"d","text":"The number of DNS lookups required"}
      ],
      "correct": "b",
      "explanation": "HTTP/2 removed application-level head-of-line blocking but sits on TCP, which still guarantees in-order byte delivery — so one dropped packet blocks all streams. QUIC tracks loss per stream, so only the affected stream waits." }
] }
```

## Client–server communication styles

The single most common protocol question: **"how does the client find out something changed?"** Four answers, in increasing order of power and cost.

| Style | How it works | Latency | Server cost | Use when |
|---|---|---|---|---|
| **Short polling** | Client asks every N seconds | Up to N sec | Wasteful — most responses empty | Simplicity wins; updates are rare and staleness is fine |
| **Long polling** | Request held open until data or timeout, then re-issued | Near real-time | One held connection per client | Real-time-ish without WebSocket support |
| **SSE** (Server-Sent Events) | One long-lived HTTP response, server streams events, browser auto-reconnects | Real-time | One connection per client | **Server→client only**: feeds, notifications, live scores, LLM token streams |
| **WebSocket** | HTTP `Upgrade` → full-duplex TCP connection | Real-time | One connection per client, stateful servers | **Bidirectional**: chat, collaborative editing, multiplayer, trading |

Two design consequences interviewers push on:

1. **WebSocket and SSE make servers stateful.** A connection is pinned to one machine, so you need sticky routing, a shared pub/sub layer (Redis, NATS, Kafka) to deliver a message to whichever server holds the recipient's connection, and a deploy story that drains connections gracefully. This is why "just use WebSockets" is not a free answer.
2. **Connection count becomes a capacity number.** 1M concurrent users on WebSockets is 1M open sockets; at ~50k–100k per node that is 10–20 gateway nodes doing nothing but holding connections.

If you only need server→client push, **prefer SSE**: it is plain HTTP, works through most proxies, reconnects automatically, and halves the complexity.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-realtime-q1", "type": "mcq",
      "prompt": "A dashboard needs live price updates pushed from server to browser; the browser never sends anything back on that channel. What is the best fit?",
      "options": [
        {"id":"a","text":"WebSocket, because it is the standard for real-time"},
        {"id":"b","text":"Server-Sent Events — one-directional, plain HTTP, automatic reconnection, far less operational complexity"},
        {"id":"c","text":"Short polling every 100 ms"},
        {"id":"d","text":"gRPC bidirectional streaming from the browser"}
      ],
      "correct": "b",
      "explanation": "SSE is purpose-built for server→client streams over ordinary HTTP. Choosing WebSocket when you never need the client→server direction buys you sticky sessions and a heavier protocol for nothing." }
] }
```

## Service-to-service: REST, gRPC, GraphQL, and message queues

| | REST/JSON | gRPC/protobuf | GraphQL | Message queue |
|---|---|---|---|---|
| Shape | Resource + verbs | RPC with typed contract | One endpoint, client-specified query | Async publish/consume |
| Payload | Text, human-readable | Binary, compact and fast | JSON | Anything |
| Contract | OpenAPI (optional) | `.proto` (enforced, codegen) | Schema (enforced) | Event schema (often loose) |
| Streaming | SSE / chunked | First-class, bidirectional | Subscriptions | Native |
| Browser support | Native | Needs a proxy (grpc-web) | Native | No |
| Best for | Public APIs, simple internal calls | Internal service-to-service at scale | Aggregating many resources for varied clients | Decoupling, buffering, fan-out |

Rules of thumb that read well:

- **Public / partner-facing → REST.** Everyone can call it with `curl`, caching works, no toolchain required.
- **Internal high-volume east–west → gRPC.** Binary encoding and HTTP/2 multiplexing cut latency and CPU; the generated stubs stop drift between teams.
- **Many clients with different data needs → GraphQL.** It solves over-fetching and under-fetching; it costs you query-cost control (depth limits, complexity budgets, persisted queries), harder HTTP caching, and the N+1 resolver problem (fixed with DataLoader-style batching).
- **Caller doesn't need the result now → a queue, not a call.** Synchronous chains multiply failure: five services at 99.9% each in a chain give 99.5% overall.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-rpc-q1", "type": "mcq",
      "prompt": "Two internal services exchange 50k requests/sec of structured data. Why is gRPC usually preferred over REST/JSON here?",
      "options": [
        {"id":"a","text":"gRPC responses can be cached by CDNs, JSON cannot"},
        {"id":"b","text":"Binary protobuf encoding plus HTTP/2 multiplexing cuts payload size, CPU spent on serialization, and per-request connection overhead — and the .proto contract is enforced at compile time"},
        {"id":"c","text":"gRPC guarantees exactly-once delivery"},
        {"id":"d","text":"REST cannot be used between backend services"}
      ],
      "correct": "b",
      "explanation": "At high east–west volume, JSON parsing CPU and payload size are real costs, and untyped contracts drift between teams. gRPC fixes both. It gives no delivery guarantees beyond what the transport provides, and it is worse for public/browser access." }
] }
```

## Key takeaways

**The decision table — memorise the left column and the trigger:**

| Question | Answer |
|---|---|
| Client needs updates, server→client only | SSE |
| Client and server both push | WebSocket (+ sticky routing + shared pub/sub) |
| Updates rare, staleness fine | Short polling |
| Public API | REST/JSON over HTTP |
| Internal, high volume, typed | gRPC |
| Many client shapes, one round trip | GraphQL (+ depth limits, DataLoader) |
| Caller doesn't need the result now | Message queue |
| Loss-tolerant, latency-critical media | UDP / WebRTC |
| Fast regional failover | Short DNS TTL + health checks |
| Static assets, global audience | CDN at the edge, anycast |

- **Every arrow is a protocol choice with a cost.** Naming the cost (statefulness, connection count, proxy support, caching loss) is what makes the answer senior.
- **Round trips dominate latency, not bandwidth.** Cut the number of calls before you optimise the size of each one.
- **Stateful connections change your architecture**, not just your protocol: sticky routing, a pub/sub backbone, connection-drain deploys, and a per-node connection budget.
