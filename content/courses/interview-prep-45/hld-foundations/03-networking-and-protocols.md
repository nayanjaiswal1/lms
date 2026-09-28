---
kind: lesson
id_key: interview-prep-45/hld-03-networking
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Networking and Protocols for Design"
position: 3
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Every arrow you draw between two boxes on a system design diagram is really a phone call between two computers. Interviewers like to poke at those arrows: how does the client find the right server, how does the server push an update to the browser, why pick one protocol over another. You don't need a networking degree for this. You need to know, for each arrow, which protocol carries it and what that choice costs you.

## From URL to first byte

Learn this sequence well enough to explain it out loud. Interviewers ask it directly ("what happens when you type a URL and press enter?"), and it's the foundation for questions about CDNs, load balancers, and secure connections.

```
1. DNS resolve      browser cache → OS cache → resolver → root → TLD → authoritative
                    returns an IP (or a CDN edge IP via geo/latency routing)
2. TCP handshake    SYN → SYN-ACK → ACK                       (1 round trip)
3. TLS handshake    TLS 1.3: 1 round trip (1.2 was 2)         (0-RTT on resume)
4. HTTP request     GET / with headers, cookies
5. Server work      LB → app → cache/DB → response
6. Response         HTML → browser parses → more requests for CSS/JS/images
```

DNS (Domain Name System) is the phone book of the internet: it turns a name like "example.com" into a numeric address. TCP is the connection-setup handshake computers use before sending data. TLS is the layer that encrypts the connection, so nobody in between can read it.

Three facts that pay off in interviews.

**DNS is a routing tool, not just a phone book.** Every DNS record has a TTL (time to live), a number of seconds saying how long a client may keep using the old answer before asking again. A short TTL, say 30 to 60 seconds, lets you redirect traffic to a different server quickly if something breaks, at the cost of clients asking DNS more often. DNS can also send users to the nearest region, or shift a small percentage of traffic to a new version gradually.

**Setting up a connection is expensive.** It takes roughly two round trips before a single byte of your actual data moves. Picture asking a favour from someone in another country by mail: two letters have to cross the ocean before you've even started the real conversation. Over a connection with a 150 millisecond round trip, that's 300 milliseconds spent on nothing. This is why keeping connections open (called keep-alive), reusing a pool of connections, and letting a CDN handle the connection close to the user all matter so much.

**Anycast** is a trick where one IP address is advertised from many physical locations at once, and the network automatically routes each user to whichever location is closest. It's how CDNs and DNS providers work, and it's also how a flood of attack traffic gets spread thin across many sites instead of overwhelming one.

> **Remember:** DNS's TTL is a dial you control, not a fixed detail. A short TTL is what lets you redirect traffic away from a dead region within a minute.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-path-q1", "type": "mcq",
      "prompt": "You want to be able to redirect traffic to a standby region within a minute if the main one fails. What must you set up ahead of time?",
      "options": [
        {"id":"a","text":"A long DNS TTL, so clients cache the address and don't overload the DNS server"},
        {"id":"b","text":"A short DNS TTL (30 to 60 seconds), so clients pick up the new address quickly, plus health checks that trigger the switch"},
        {"id":"c","text":"HTTP/3, because it reconnects faster"},
        {"id":"d","text":"A feature that resumes an old encrypted session"}
      ],
      "correct": "b",
      "explanation": "Clients honour whatever TTL they were given, so a 24-hour TTL means a 24-hour tail of traffic still going to the dead region. A short TTL is the price you pay for fast DNS-based failover; the cost is more frequent DNS lookups." }
] }
```

## TCP vs UDP, and what QUIC changed

TCP and UDP are the two basic ways computers send data to each other over a network.

| | TCP | UDP |
|---|---|---|
| Delivery | Reliable, in order, resends lost data | Fire and forget, may drop or reorder |
| Setup | A three-step handshake first | None |
| Handling network congestion | Built in | You build it yourself, or go without |
| Head-of-line blocking (one lost piece stalling everything behind it) | Yes | No |
| Use for | APIs, databases, anything that must be correct | Live video or voice calls, games, DNS, metrics |

Ask yourself one question to decide between them: is a late piece of data worth more than a missing one? For a bank transfer, yes: resend it until it arrives, so use TCP. For a video call, no: a video frame that arrives 400 milliseconds late is worse than one that's simply dropped and skipped, so use UDP and hide the gap.

**HTTP/3 runs on top of QUIC, and QUIC runs on top of UDP.** QUIC rebuilds reliability, ordering, and congestion handling itself, instead of relying on TCP to do it. That buys two things. First, independent streams: a lost piece of data only stalls its own stream, not the whole connection. Second, connection migration: if your phone switches from Wi-Fi to mobile data mid-call, the connection survives, because it's identified by a connection ID rather than by your IP address.

| Version | Key property |
|---|---|
| HTTP/1.1 | Only one request in flight per connection, so browsers open about 6 connections per site |
| HTTP/2 | Many requests share one TCP connection, headers are compressed, but it still suffers TCP's head-of-line blocking |
| HTTP/3 | Same sharing, but over QUIC and UDP, so one lost piece of data no longer stalls every other stream; it also connects faster and survives a network switch |

> **Remember:** TCP guarantees every byte arrives in order, so one lost piece of data stalls everything behind it. UDP drops that guarantee, which is exactly why live video prefers it.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-tcp-q1", "type": "mcq",
      "prompt": "HTTP/2 lets many requests share one TCP connection. Which problem does that NOT solve, but HTTP/3 does?",
      "options": [
        {"id":"a","text":"Header size, because HTTP/2 does not compress headers"},
        {"id":"b","text":"TCP still delivers bytes strictly in order, so one lost piece of data stalls every shared stream, not just its own"},
        {"id":"c","text":"Encryption, because HTTP/2 cannot use TLS"},
        {"id":"d","text":"How many times DNS has to be looked up"}
      ],
      "correct": "b",
      "explanation": "HTTP/2 removed the stalling that happened at the application level, but it still runs on TCP, which insists on delivering bytes in order. So one dropped piece of data still blocks every stream sharing that connection. QUIC tracks loss per stream instead, so only the affected stream has to wait." }
] }
```

## Client-server communication styles

The single most common question interviewers ask about protocols is: "how does the client find out something changed?" There are four answers, each more powerful and more expensive than the last.

| Style | How it works | Delay | Cost to the server | Use when |
|---|---|---|---|---|
| **Short polling** | Client asks again every few seconds | Up to that many seconds | Wasteful, since most answers are "nothing changed" | Simple is fine, updates are rare, some staleness is okay |
| **Long polling** | The request stays open until there's data or it times out, then the client asks again | Near real-time | One open connection per client | Real-time-ish, without support for WebSockets |
| **SSE** (Server-Sent Events) | One long-lived response that the server streams events into; the browser reconnects on its own if it drops | Real-time | One connection per client | **Server to client only**: feeds, notifications, live scores |
| **WebSocket** | A regular HTTP request that "upgrades" into a two-way connection | Real-time | One connection per client, and the server has to remember who's connected | **Both directions**: chat, shared editing, multiplayer games, trading |

Two consequences interviewers like to push on.

**WebSocket and SSE make your servers stateful.** Stateful means the server remembers something between requests, in this case, which client is connected to which machine. That connection is pinned to one specific server, so you need "sticky routing" (always sending that client back to the same server), a shared messaging layer like Redis, NATS, or Kafka to deliver a message to whichever server actually holds the connection, and a careful way of closing connections gradually during a deploy. Saying "just use WebSockets" without mentioning any of that is an incomplete answer.

**The number of connections becomes a real capacity number you have to plan for.** One million people connected over WebSockets means one million open connections at once. If one server can comfortably hold 50,000 to 100,000 of them, that's 10 to 20 servers whose only job is holding connections open.

If you only need the server pushing to the client, **prefer SSE**. It's plain HTTP, it works through most existing infrastructure without special handling, it reconnects automatically, and it's roughly half the complexity of a WebSocket.

> **Remember:** ask which direction the data needs to flow. Server-to-client only means SSE. Both sides talking means WebSocket, and WebSocket makes your servers stateful.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-realtime-q1", "type": "mcq",
      "prompt": "A dashboard needs live price updates pushed from the server to the browser, and the browser never sends anything back on that same channel. What fits best?",
      "options": [
        {"id":"a","text":"WebSocket, because it's the standard choice for anything real-time"},
        {"id":"b","text":"Server-Sent Events: one direction only, plain HTTP, automatic reconnection, and far less to operate"},
        {"id":"c","text":"Short polling every 100 milliseconds"},
        {"id":"d","text":"A two-way streaming connection from the browser"}
      ],
      "correct": "b",
      "explanation": "SSE is built exactly for server-to-client streams over ordinary HTTP. Choosing WebSocket when you never need the browser to talk back buys you sticky connections and a heavier protocol for no reason." }
] }
```

## Service-to-service: REST, gRPC, GraphQL, and message queues

| | REST/JSON | gRPC/protobuf | GraphQL | Message queue |
|---|---|---|---|---|
| Shape | A resource with actions on it | A remote call with a typed contract | One endpoint, the client asks for exactly the fields it wants | Publish now, someone else reads it later |
| Payload | Plain text, human-readable | Binary, compact and fast | JSON | Anything |
| Contract | An optional description (OpenAPI) | A `.proto` file, checked and code-generated | An enforced schema | A loosely-defined event shape |
| Streaming | Via SSE or chunked responses | Built in, both directions | Via subscriptions | Built in |
| Works in a browser | Natively | Needs an extra proxy layer | Natively | No |
| Best for | Public APIs, simple internal calls | High-volume calls between your own services | Many clients that each want different data | Decoupling services, buffering spikes, broadcasting to several listeners |

A few rules of thumb that hold up well.

**Public or partner-facing calls: use REST.** Anyone can call it with a basic tool like `curl`, caching works the normal HTTP way, and no special toolchain is required.

**High-volume calls between your own internal services: use gRPC.** Its binary format and the way it shares connections cut latency and CPU cost, and the generated code keeps two teams' services from drifting out of sync with each other.

**Many different clients each needing different data: use GraphQL.** It solves the problem of a client getting too much data or too little in one response. It costs you extra work controlling how expensive a single query can be, makes normal HTTP caching harder, and introduces the "N+1" problem, where fetching a list quietly triggers one extra database query per item; that's fixed with request batching.

**The caller doesn't need the answer right now: use a queue, not a direct call.** Chaining calls together multiplies your chance of failure. Five services in a row, each working 99.9% of the time, only work together about 99.5% of the time.

> **Remember:** public and simple calls for REST. Internal and high-volume for gRPC. Many different kinds of clients for GraphQL. No need for an answer right now for a queue.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-03-rpc-q1", "type": "mcq",
      "prompt": "Two of your own internal services exchange 50,000 structured requests a second. Why is gRPC usually preferred over REST with JSON here?",
      "options": [
        {"id":"a","text":"gRPC responses can be cached by a CDN, but JSON responses cannot"},
        {"id":"b","text":"Its compact binary format plus sharing one connection across many requests cuts payload size, CPU spent encoding and decoding, and per-request overhead, and its typed contract is checked before the code even runs"},
        {"id":"c","text":"gRPC guarantees a message is delivered exactly once"},
        {"id":"d","text":"REST simply cannot be used between backend services"}
      ],
      "correct": "b",
      "explanation": "At high internal volume, the CPU cost of parsing JSON and the size of each payload are real problems, and an untyped contract drifts between teams over time. gRPC fixes both. It gives no delivery guarantee beyond whatever the underlying connection provides, and it's a poor fit for public or browser access." }
] }
```

## Quick recap

| Question | Answer |
|---|---|
| Client needs updates, server to client only | SSE |
| Client and server both need to push | WebSocket, plus sticky routing and a shared messaging layer |
| Updates are rare, staleness is fine | Short polling |
| Public API | REST/JSON over HTTP |
| Internal, high volume, typed | gRPC |
| Many client shapes, one round trip | GraphQL, plus depth limits and batching |
| Caller doesn't need the result right now | Message queue |
| Loss-tolerant, latency-critical media | UDP or WebRTC |
| Fast regional failover | Short DNS TTL plus health checks |
| Static assets, worldwide audience | CDN at the edge, anycast |
