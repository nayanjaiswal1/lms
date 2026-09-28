---
kind: lesson
id_key: interview-prep-45/day-09-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "REST API Design"
position: 1
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

"Design an API for X" is one of the most common backend interview prompts, because the answer shows whether you think in terms of resources, consistency, and room to grow, or just wire up whatever routes come to mind first. This lesson covers what "RESTful" actually means, how to shape full CRUD for a resource, the exact difference between POST, PUT, and PATCH, pagination that survives a large table, and the networking layers (DNS, routing, HTTPS) a request travels through before it ever reaches your code.

## What makes an API "RESTful": the Richardson Maturity Model

Picture three different ways to build a vending machine. The cheapest one has a single button: you tell the attendant what you want out loud, and they fetch it. A better one has one button per item. The best one also lights up which buttons are still in stock before you press anything. The Richardson Maturity Model grades APIs the same way, from "one endpoint for everything" up to "the API tells you what you can do next."

- **Level 0: one endpoint, everything is a message.** Every request goes to the same URL, usually a `POST`, with the real instruction buried in the body: `POST /api` with `{"action": "getUser", "id": 42}`. This is a function call disguised as HTTP. It is not REST.
- **Level 1: one URL per resource.** `/users/42`, `/orders/7` each name a specific thing, but every request might still be a `POST`.
- **Level 2: proper HTTP verbs and status codes.** Resources plus `GET`/`POST`/`PUT`/`PATCH`/`DELETE` used for what they actually mean, and status codes (`200`, `404`, `409`) that tell the client what happened without it having to parse the body. **This is what "RESTful API" means in practice for almost every real system**, including the one built in this lesson.
- **Level 3: HATEOAS.** Every response includes links to what you can do next (`"actions": {"cancel": "/orders/7/cancel"}`), so a client can navigate the API without hardcoding URL shapes ahead of time. Almost nobody fully implements this: it adds real client complexity for a benefit that mostly matters to browser-driven, hypermedia-style clients, not the typical mobile app or microservice caller.

The interview answer: know that Level 2 is the practical target for nearly every API you'll ever build, and be able to name what Level 3 would add and why most teams skip it.

> **Remember:** Level 2, resources plus correct HTTP verbs and status codes, is what "RESTful" means in practice. Level 3 (HATEOAS) is a known term you should recognize, not a bar you need to clear.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-maturity-q1", "type": "mcq",
      "prompt": "An API has separate URLs per resource (/users/42, /orders/7) and uses GET, POST, PUT, and DELETE correctly with matching status codes, but responses never include links to related actions. What Richardson Maturity Level is this?",
      "options": [
        {"id":"a","text":"Level 0"},
        {"id":"b","text":"Level 1"},
        {"id":"c","text":"Level 2, which is what most production APIs, including RESTful ones, stop at"},
        {"id":"d","text":"Level 3, since it uses proper URLs"}
      ],
      "correct": "c",
      "explanation": "Resources plus correctly used HTTP verbs and status codes is Level 2. Level 3 would additionally embed links to related actions in every response (HATEOAS), which most real systems skip." }
] }
```

## Designing full CRUD for a resource

Take a small blog: posts, comments on a post, and likes on a post. The data shapes first:

```python
# FastAPI example — posts, comments, likes
from fastapi import FastAPI, HTTPException, Query, status
from pydantic import BaseModel
from typing import Optional

app = FastAPI()


class PostCreate(BaseModel):
    title: str
    body: str
    author_id: int


class PostUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None


class Post(BaseModel):
    id: int
    title: str
    body: str
    author_id: int
    like_count: int
```

And the routes that operate on them:

```
POST   /posts                  create a post
GET    /posts                  list posts (paginated, filterable, sortable)
GET    /posts/{id}              fetch one post
PATCH  /posts/{id}              partial update
PUT    /posts/{id}              full replace
DELETE /posts/{id}              delete

GET    /posts/{id}/comments     list comments on a post (nested resource)
POST   /posts/{id}/comments     create a comment on a post

POST   /posts/{id}/likes        like a post (idempotent-in-effect: liking twice = still liked)
DELETE /posts/{id}/likes/me     unlike
```

Nesting `/posts/{id}/comments` under the post communicates ownership, and reads cleanly as "comments on this post." A flat `/comments?post_id={id}` is easier to filter and sort generically. Both are defensible; say which one you picked and why out loud. The one rule that always holds: cap nesting at one or two levels. `/posts/{id}/comments/{id}/replies/{id}` is ugly to read and ugly to route. Beyond two levels, go flat with a query parameter instead.

> **Remember:** name resources as nouns, use nesting to show ownership one level deep, and switch to a flat resource with a query parameter once nesting would go past two levels.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-crud-q1", "type": "mcq",
      "prompt": "Why does /posts/{id}/comments/{id}/replies/{id} become a problem as a URL design, even though each level is a real resource?",
      "options": [
        {"id":"a","text":"FastAPI cannot route more than two path parameters"},
        {"id":"b","text":"Deep nesting gets hard to read and route; beyond one or two levels, flatten with a query parameter instead"},
        {"id":"c","text":"REST forbids nested resources entirely"},
        {"id":"d","text":"Nested resources cannot be paginated"}
      ],
      "correct": "b",
      "explanation": "Nesting is fine one level deep to show ownership, but it gets unreadable fast. The practical rule is to cap it at one or two levels and go flat with query parameters after that." }
] }
```

## POST vs PUT vs PATCH: idempotency

Think of a light switch versus a light dimmer you nudge up by one notch. Flipping the switch to "on" a hundred times leaves the light exactly as on as flipping it once: that's idempotent. Nudging the dimmer up by one notch a hundred times leaves it much brighter than nudging it once: that's not idempotent. HTTP methods carry the exact same distinction.

| Verb | Semantics | Idempotent? | Body |
|---|---|---|---|
| `POST` | Create a new resource (server assigns the ID), or a non-idempotent action | No | Full or partial resource, or an action payload |
| `PUT` | Replace a resource entirely at a known URL | Yes | The full resource; fields you leave out get cleared or defaulted |
| `PATCH` | Partially update a resource | Not guaranteed by the spec, but usually implemented as idempotent | Only the fields to change |

**Idempotent** means calling something N times has the same effect as calling it once. `PUT /posts/7` with the same body twice leaves the post in the same state both times. `POST /posts` called twice creates two posts. This is not academic: idempotent methods are safe to retry blindly after a network timeout, since you don't know whether the first request landed, but retrying can't make things worse. A non-idempotent method needs an idempotency key if you want that same retry safety.

```python
@app.patch("/posts/{post_id}", response_model=Post)
async def update_post(post_id: int, patch: PostUpdate):
    post = get_post_or_404(post_id)
    update_data = patch.model_dump(exclude_unset=True)  # only fields the client actually sent
    for field, value in update_data.items():
        setattr(post, field, value)
    save_post(post)
    return post


@app.put("/posts/{post_id}", response_model=Post)
async def replace_post(post_id: int, body: PostCreate):
    post = get_post_or_404(post_id)
    post.title = body.title       # PUT sets every field from the request body —
    post.body = body.body          # there is no partial PUT; that's what PATCH is for
    post.author_id = body.author_id
    save_post(post)
    return post
```

`exclude_unset=True` is what makes `PATCH` genuinely partial. Without it, fields the client never sent would come through as their defaults and silently overwrite existing data, turning your PATCH into an accidental PUT.

**Common mistake:** treating PATCH and PUT as interchangeable. A client sending a partial body to a PUT-shaped handler will unknowingly wipe out every field it didn't include.

> **Remember:** PUT replaces the whole resource and is always idempotent. PATCH changes only the fields sent. POST creates something new every time, so retries of a POST need an idempotency key.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-verbs-q1", "type": "mcq",
      "prompt": "A client's request to your API times out. It doesn't know if the request reached the server. For which method is it always safe to just retry the exact same request?",
      "options": [
        {"id":"a","text":"POST, since it always creates a fresh resource"},
        {"id":"b","text":"PUT, since calling it twice with the same body leaves the resource in the same state either way"},
        {"id":"c","text":"Neither is ever safe to retry"},
        {"id":"d","text":"Both are equally unsafe without an idempotency key"}
      ],
      "correct": "b",
      "explanation": "PUT is idempotent by definition: repeating it with the same body produces the same end state, so a blind retry after a timeout cannot cause harm. POST creates a new resource on every call, so retrying it risks a duplicate unless you add an idempotency key." }
] }
```

## Pagination, filtering, and sorting at scale

```python
@app.get("/posts", response_model=list[Post])
async def list_posts(
    author_id: Optional[int] = None,
    sort: str = Query("created_at", pattern="^(created_at|like_count)$"),
    order: str = Query("desc", pattern="^(asc|desc)$"),
    limit: int = Query(20, le=100),   # cap page size — never let a client ask for unbounded rows
    cursor: Optional[str] = None,      # opaque cursor, not a raw offset
):
    filters = {}
    if author_id is not None:
        filters["author_id"] = author_id

    posts, next_cursor = post_repository.list(
        filters=filters, sort=sort, order=order, limit=limit, cursor=cursor
    )
    return {"items": posts, "next_cursor": next_cursor}
```

**Offset pagination** (`?page=3&page_size=20`) reads like the simple choice, but it degrades on a large table: `OFFSET 60000` still makes the database scan and throw away 60,000 rows before returning anything. It also gets confused under concurrent writes. If a new row is inserted while a user is on page 1, everything after it shifts by one, so paging forward skips or repeats rows for that user.

**Cursor pagination** (`?cursor=<opaque token>&limit=20`) encodes the last row you saw, for example its `created_at` and `id`, into an opaque token. The next query becomes `WHERE (created_at, id) < (last_created_at, last_id) ORDER BY created_at DESC, id DESC LIMIT 20`, an indexed range scan instead of a skip-then-scan. New inserts elsewhere in the table don't shift your position. For any "pagination at scale" question, lead with cursor pagination and say why offset breaks down.

> **Remember:** offset pagination scans and discards every row before the page you asked for; cursor pagination jumps straight there with an indexed range scan, and stays correct while rows are being inserted.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-pagination-q1", "type": "mcq",
      "prompt": "A table gets thousands of new rows a minute. Why does offset pagination (?page=3) become unreliable here, not just slow?",
      "options": [
        {"id":"a","text":"Offset pagination only works with fewer than 1,000 rows total"},
        {"id":"b","text":"A row inserted while a user pages through shifts every later row by one position, causing that user to skip or repeat rows"},
        {"id":"c","text":"Databases do not support the OFFSET keyword at scale"},
        {"id":"d","text":"Offset pagination requires a full table lock"}
      ],
      "correct": "b",
      "explanation": "Offset counts rows from the start on every request. A concurrent insert shifts every row after it by one position, so a user's page 2 can silently skip or duplicate a row compared to what they saw on page 1." }
] }
```

## REST vs SOAP

| | REST | SOAP |
|---|---|---|
| What it is | An architectural style, a set of constraints, not a protocol | A strict messaging protocol with a formal specification |
| Transport | HTTP, in practice | Transport-agnostic: HTTP, SMTP, TCP, message queues |
| Data format | Any; JSON is standard, XML or plain text also work | XML only, inside a rigid envelope |
| Contract | Loose, documented via OpenAPI/Swagger, not enforced by the protocol | Strict; a WSDL file formally defines every operation, type, and fault |
| Payload weight | Lightweight (JSON is compact) | Heavy (verbose XML, namespaces) |
| Built-in security | None; relies on HTTPS, OAuth, and so on, layered on top | WS-Security and WS-ReliableMessaging are part of the spec itself |
| Typical use today | Public APIs, mobile backends, microservices, the default for anything new | Legacy enterprise systems, banking and payment gateways, domains with a regulatory need for a formal contract |

The one-sentence interview answer: REST is a flexible, resource-oriented style that won because it's simple and maps naturally onto HTTP, while SOAP is a rigid, contract-first protocol still found in enterprise and financial systems, where the formal WSDL contract and built-in security guarantees outweigh the overhead. You'll almost certainly build a REST API, but you may still need to talk to a SOAP-based system, like a bank or an airline booking system, that predates REST's dominance.

> **Remember:** REST is a style layered on HTTP with a loose, documented contract. SOAP is a strict, self-describing protocol still common in banking and legacy enterprise systems.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-soap-q1", "type": "mcq",
      "prompt": "Why would a bank's payment gateway still use SOAP today instead of a REST API?",
      "options": [
        {"id":"a","text":"SOAP is always faster than REST over HTTP"},
        {"id":"b","text":"SOAP's formal WSDL contract and built-in security/reliability guarantees fit a legacy, regulated system, and switching a working integration has little upside"},
        {"id":"c","text":"REST cannot transmit XML data"},
        {"id":"d","text":"SOAP is a newer standard than REST"}
      ],
      "correct": "b",
      "explanation": "SOAP is older than REST, not newer. Its appeal in finance and legacy enterprise systems is the strict, machine-checkable WSDL contract and the reliability/security features built into the protocol itself, which matter more there than payload size." }
] }
```

## How HTTPS keeps a connection private: the TLS handshake

Plain HTTP sends every byte in the clear. Anyone sitting on the network path between you and the server, a public Wi-Fi hotspot, a compromised router, an ISP, can read or change it in transit. HTTPS wraps HTTP inside TLS (the successor to SSL) encryption. Here's the handshake that sets that encryption up, worth being able to explain step by step:

1. The client connects and lists the TLS versions and cipher suites it supports ("ClientHello").
2. The server answers with its chosen cipher suite and its certificate, which contains its public key and is signed by a Certificate Authority.
3. The client checks the certificate: is it signed by a CA the client trusts, does the domain name match, and has it not expired?
4. The client and server briefly use asymmetric cryptography (slow, but fine for a small handshake) to agree on a shared symmetric session key.
5. Every byte from here on is encrypted with that fast symmetric key.

This is exactly what blocks a person-in-the-middle attack: an eavesdropper who intercepts the connection can't read the traffic without the session key, and can't forge a valid certificate for a domain they don't own, because a browser will flag a forged one as untrusted.

A few practical details that come up: HTTP defaults to port 80, HTTPS to port 443. Certificates come in tiers: Domain Validated (DV) just proves you control the domain and can be automated with Let's Encrypt; Organization Validated (OV) checks the requesting organization; Extended Validation (EV) is the strictest, though its old green-address-bar signal has since been dropped by most browsers. An HTTPS page that loads one HTTP resource, an image or a script, creates "mixed content," a hole an attacker can exploit; modern browsers block active mixed content (scripts) outright and warn on passive mixed content (images).

> **Remember:** the TLS handshake uses slow asymmetric crypto only to agree on a fast symmetric session key, then encrypts everything else with that key. A forged certificate for a domain the attacker doesn't own is what the handshake is built to catch.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-tls-q1", "type": "mcq",
      "prompt": "Why does TLS use slow asymmetric cryptography only briefly during the handshake, instead of for the whole connection?",
      "options": [
        {"id":"a","text":"Asymmetric crypto is illegal to use for bulk data in most countries"},
        {"id":"b","text":"Asymmetric crypto is too slow for streaming data, so it's used only to safely agree on a fast symmetric session key, which then encrypts the rest of the traffic"},
        {"id":"c","text":"Browsers do not support asymmetric crypto past the handshake"},
        {"id":"d","text":"Symmetric keys are less secure, so they are used only briefly"}
      ],
      "correct": "b",
      "explanation": "Asymmetric crypto is computationally expensive, which is fine for a one-time handshake but too slow for every byte of a connection. TLS uses it only to bootstrap a shared symmetric key, then switches to that fast key for everything else." }
] }
```

## How a hostname turns into a server: DNS and routing

Two small pieces of networking that get asked back-to-back in a "fundamentals" round, precisely because each one is quick to cover on its own.

**DNS** turns a hostname like `api.example.com` into an IP address through a hierarchical lookup: root nameservers point to nameservers for the top-level domain (`.com`), which point to the authoritative nameserver for `example.com` itself, which finally answers with the actual IP. That result gets cached at the OS, the browser, and the resolver, according to a TTL (time to live) on the DNS record. This caching is exactly why a DNS change can take time to reach everyone even after the authoritative record has already been updated: every cache holding the old answer has to wait out its own TTL first.

**A routing table** is what a router consults to decide where to send a packet next. It maps network destinations to a next-hop address, and a router only knows the next hop, not the full path. A packet crosses the network one hop at a time, each router forwarding it a little closer, until it reaches the network the destination lives on.

> **Remember:** DNS resolves a name to an address through a chain of nameservers, and every cache along that chain waits out its own TTL before it asks again. Routing moves a packet one hop closer at a time; no single router knows the whole path.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-rest-api-design-dns-q1", "type": "mcq",
      "prompt": "A team updates a DNS record, but some users still reach the old server for several minutes afterward. What explains this?",
      "options": [
        {"id":"a","text":"DNS updates are always instant, so this points to a misconfigured record"},
        {"id":"b","text":"The old answer is still cached somewhere along the resolution chain (OS, browser, or resolver) until that cached copy's TTL runs out"},
        {"id":"c","text":"Routing tables, not DNS, control which server a request reaches"},
        {"id":"d","text":"Only the authoritative nameserver's cache matters, and it always updates instantly"}
      ],
      "correct": "b",
      "explanation": "DNS results are cached at several layers (OS, browser, resolver), each governed by the record's TTL. Even after the authoritative record changes, a cache that already has the old answer keeps serving it until its own TTL expires." }
] }
```

The next lesson, API Versioning and Error Handling, picks up where the brief versioning mention here leaves off: the real trade-offs between versioning strategies, and a standardized way to shape errors so every client can handle them the same way.
