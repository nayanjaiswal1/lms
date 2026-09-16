---
kind: lesson
id_key: interview-prep-45/hld-01-framework
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "The HLD Interview Framework"
position: 1
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Every high-level design interview is the same 45 minutes wearing a different costume. "Design Twitter", "Design Uber", "Design a payment system" — the domain changes, the procedure does not. Candidates who fail rarely fail on knowledge; they fail because they had no procedure and burned twenty minutes wandering. This lesson gives you the procedure. The rest of this section fills in the building blocks it calls for, and the **System Design** section applies it to 28 real questions.

The one thing to memorise from this lesson is the step order. Everything else you can re-derive at the whiteboard.

> **RESHADE** — **R**equirements, **E**stimation, **S**chema & API, **H**igh-level design, **A**rchitecture deep dive, **D**efend trade-offs, **E**dge cases.

## What the interviewer is actually scoring

You are not being scored on whether you name-drop Kafka. The scorecard behind the glass has roughly four rows:

| Row | What it means | How you lose the point |
|---|---|---|
| **Problem framing** | You narrowed an open problem into something buildable | Started drawing boxes before asking what the system must do |
| **Structured thinking** | You moved through the design in a visible, deliberate order | Jumped between topics; interviewer had to steer you |
| **Technical depth** | You can go one level below the box you drew | "I'd use a cache" and nothing more when pushed |
| **Trade-off reasoning** | You chose *and* said what the choice costs | Presented one design as if it had no downsides |

The last row is the one that separates a mid-level from a senior signal. A senior engineer never says "this is the best approach"; they say "I'm picking X because we're read-heavy and can tolerate a second of staleness — if the requirement were strict consistency I'd go with Y and eat the latency."

Say your reasoning out loud continuously. An interviewer cannot award points for thinking they cannot hear.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-scoring-q1", "type": "mcq",
      "prompt": "You propose a read replica to scale reads. Which follow-up sentence earns the trade-off point?",
      "options": [
        {"id":"a","text":"\"Replicas are the standard solution for read-heavy systems.\""},
        {"id":"b","text":"\"This adds replication lag, so a user who just posted might not see their own post — I'd route read-your-own-writes back to the primary.\""},
        {"id":"c","text":"\"We can add more replicas later if needed.\""},
        {"id":"d","text":"\"Postgres, MySQL, and MongoDB all support replicas.\""}
      ],
      "correct": "b",
      "explanation": "Trade-off reasoning = naming the cost of your choice and how you mitigate it. (b) states the concrete downside (replication lag), the user-visible symptom, and the mitigation. The others state facts or defer the problem." }
] }
```

## Step 1 — Requirements: turn an open prompt into a spec

Spend **5 minutes** here. Never skip it, and never let it run past eight minutes.

Split requirements in two, out loud, on the board:

**Functional requirements** — what a user can *do*. Write 3–5 verbs, no more. For "Design Twitter": post a tweet, follow a user, view a home timeline. Explicitly park the rest: "I'll treat DMs, search, and ads as out of scope unless you want them."

**Non-functional requirements** — the properties that actually decide the architecture:

| Question to ask | Why it changes the design |
|---|---|
| How many users / how much traffic? | Decides single DB vs. sharded, cache or no cache |
| Read-heavy or write-heavy? | Read-heavy → replicas + cache; write-heavy → partitioning, queues |
| Latency target? | 50 ms p99 rules out cross-region synchronous calls |
| Consistency vs. availability under partition? | Money → consistency; feeds/likes → availability |
| Durability — can we ever lose a record? | Payments no; analytics events sometimes yes |
| Global or single-region? | Global adds replication, geo-routing, data-residency law |

Then state the **scope cut** explicitly. Narrowing is a senior signal, not a dodge: "I'll design the write path and timeline read path end to end, and treat media upload as an S3 + CDN detail I'll come back to if there's time."

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-requirements-q1", "type": "mcq",
      "prompt": "Which of these is a NON-functional requirement?",
      "options": [
        {"id":"a","text":"A user can follow another user"},
        {"id":"b","text":"A timeline shows the 50 most recent posts"},
        {"id":"c","text":"Timeline loads in under 200 ms at p99 for 10M daily users"},
        {"id":"d","text":"A user can delete their own post"}
      ],
      "correct": "c",
      "explanation": "Functional = what the system does (a, b, d). Non-functional = how well it must do it — latency, scale, availability, consistency, durability. Non-functional requirements are what force the architecture." }
] }
```

## Step 2 — Estimation: get the numbers that shape the design

Spend **3–5 minutes**. The point is not arithmetic accuracy; it is to find out **which order of magnitude problem you're in**, because that decides the architecture.

The chain is always the same:

```
DAU  →  actions per user per day  →  requests/day  →  average QPS  →  peak QPS (×2–3)
                                  →  bytes per action  →  storage/day  →  storage/5yr
                                  →  bytes × QPS  →  bandwidth
```

A worked pass, 30 seconds at the board:

- 10M DAU, each reads their timeline 10× and posts 0.1×/day
- Reads: 100M/day ÷ 86,400 ≈ **1,200 QPS** average, **~3,500 QPS** peak
- Writes: 1M/day ≈ **12 QPS** average — trivial
- Read:write = **100:1** → this is a read-heavy system → cache and replicas are the story, not write sharding
- Tweet ≈ 300 bytes; 1M/day ≈ 300 MB/day ≈ **0.5 TB over 5 years** → text fits on one beefy node; media is the real storage problem

Notice what those five lines bought: you now know to spend your design time on the read path, and you have a defensible reason. That is the entire purpose of the estimate. The next lesson drills the numbers and the arithmetic shortcuts.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-estimation-q1", "type": "mcq",
      "prompt": "Your estimate shows 100:1 read:write and only 12 writes/sec. What should that immediately tell you about where to spend design time?",
      "options": [
        {"id":"a","text":"Shard the write path across many primaries first"},
        {"id":"b","text":"Writes fit on a single primary; the design problem is the read path — caching, replicas, precomputation"},
        {"id":"c","text":"The system needs strong consistency"},
        {"id":"d","text":"Use a NoSQL database because relational databases cannot handle 12 writes/sec"}
      ],
      "correct": "b",
      "explanation": "12 writes/sec is nothing — a laptop handles it. The estimate's job is to point your remaining 30 minutes at the part that is actually hard, which here is serving 3,500 reads/sec cheaply." }
] }
```

## Step 3 — API and data model: the contract before the boxes

Spend **5 minutes**. Two artefacts, both small.

**The API.** Three to five endpoints, request and response shape only. This forces you to commit to what the system exposes and surfaces design questions early (pagination, idempotency, auth).

```
POST /v1/tweets            {text, media_ids[]}        -> {tweet_id, created_at}
GET  /v1/timeline?cursor=  ...                        -> {tweets[], next_cursor}
POST /v1/users/{id}/follow  Idempotency-Key: <uuid>   -> 204
```

Two habits that read as senior: **cursor pagination, never offset** (offset drifts and gets slower the deeper you page), and an **idempotency key on any non-idempotent write** the client might retry.

**The data model.** Entities, their key fields, and the relationships — plus, critically, the **access patterns**, because those pick the storage engine.

```
User(id PK, handle UNIQUE, name, created_at)
Tweet(id PK, author_id FK, text, created_at)         index: (author_id, created_at DESC)
Follow(follower_id, followee_id)  PK(follower_id, followee_id)
                                  index: (followee_id)   -- "who follows me", for fan-out
```

Say the access pattern out loud next to each index: "the timeline query is 'tweets by everyone I follow, newest first', so I need the followee→follower direction indexed for fan-out." Choosing indexes from stated queries is exactly the reasoning a real schema review wants.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-api-q1", "type": "mcq",
      "prompt": "Why is cursor pagination (`?cursor=abc123`) preferred over offset pagination (`?page=500`) for a feed?",
      "options": [
        {"id":"a","text":"Cursors are shorter strings so requests are smaller"},
        {"id":"b","text":"Offset requires the DB to scan and discard all preceding rows (slower the deeper you go) and items shift between pages when new rows are inserted"},
        {"id":"c","text":"Offset pagination cannot be cached"},
        {"id":"d","text":"Cursor pagination guarantees strong consistency"}
      ],
      "correct": "b",
      "explanation": "`OFFSET 10000` makes the database walk 10,000 rows before returning anything, and a new insert at the head shifts every item one page later, so users see duplicates or skips. A cursor keyed on (created_at, id) seeks directly and is stable against inserts." }
] }
```

## Step 4 — High-level design: draw the request path

Spend **10 minutes**. Draw boxes and arrows, and narrate **one request end to end** through them. A diagram nobody walks through is just decoration.

The default skeleton — start here and delete what this problem doesn't need:

```
Client → DNS → CDN (static/media)
       → Load Balancer → API Gateway (auth, rate limit)
       → Application services
              ├── Cache (Redis)
              ├── Primary DB  →  Read replicas
              ├── Object store (S3) for blobs
              └── Message queue → async workers  →  search index / analytics / notifications
```

Rules that keep this step from going wrong:

1. **Draw only what a requirement demands.** Every box you cannot justify is a box you will be asked to defend and cannot.
2. **Split synchronous from asynchronous.** Anything not needed to return the user's response (notifications, thumbnails, analytics, search indexing, emails) goes behind a queue. Being able to draw that line is a strong signal.
3. **Narrate the write path, then the read path.** "POST /tweets hits the gateway, which authenticates and rate limits, the tweet service writes to the primary, publishes a `tweet.created` event, and returns 201 — the fan-out worker consumes that event asynchronously and pushes the tweet id into each follower's timeline cache."
4. **Stateless app servers.** Session and cache state lives in Redis, not in process memory, so any instance can serve any request and autoscaling actually works.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-hld-q1", "type": "mcq",
      "prompt": "Which piece of work belongs BEHIND a queue rather than in the synchronous request path of `POST /tweets`?",
      "options": [
        {"id":"a","text":"Validating the tweet text length"},
        {"id":"b","text":"Persisting the tweet so the author sees it in their profile"},
        {"id":"c","text":"Fanning the tweet out to 2 million followers' timeline caches"},
        {"id":"d","text":"Authenticating the caller"}
      ],
      "correct": "c",
      "explanation": "Anything the user's response does not depend on, and that scales with someone else's data size, goes async. Fan-out to 2M followers cannot block a 200 ms POST; validation, auth, and the durable write must happen before you return 201." }
] }
```

## Step 5 — Deep dive, bottlenecks, and the trade-off close

Spend the last **15 minutes** here. This is where the level is decided.

Either the interviewer picks the deep-dive topic ("how does the timeline stay fast for a celebrity with 50M followers?") or you pick it. If you pick, pick the box your own estimate proved was under pressure.

Run each bottleneck through the same four questions:

| Question | Example answer |
|---|---|
| Where does it break first? | Fan-out on write dies for celebrity accounts — one tweet = 50M cache writes |
| What's the fix? | Hybrid: fan-out on write for normal users, fan-out on read for celebrities; merge at read time |
| What does the fix cost? | Two code paths, a "celebrity" threshold to tune, slightly slower reads for followers of celebrities |
| How do I know it's working? | p99 timeline latency, fan-out queue depth, cache hit rate |

Then close deliberately, in three sentences:

1. **Recap the shape**: "read-heavy, so precomputed timelines in Redis backed by a sharded Postgres."
2. **Name the biggest risk**: "the fan-out worker is the piece most likely to fall over under a celebrity spike."
3. **Say what you'd do with more time**: "I'd design the multi-region story and the analytics pipeline next."

Failure modes worth naming before the interviewer does: single points of failure, a hot shard, a cache stampede after eviction, an unbounded queue, thundering-herd retries with no backoff.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-deepdive-q1", "type": "mcq",
      "prompt": "With 15 minutes left and no direction from the interviewer, which deep dive should you choose?",
      "options": [
        {"id":"a","text":"The component your own back-of-envelope estimate showed to be under the most pressure"},
        {"id":"b","text":"The component you know the most trivia about"},
        {"id":"c","text":"The authentication flow, since every system needs auth"},
        {"id":"d","text":"A rewrite of the design using microservices"}
      ],
      "correct": "a",
      "explanation": "The estimate exists precisely to point at the hard part. Diving there shows your numbers drove your design; diving into your comfort-zone topic shows the opposite." }
] }
```

## Key takeaways

**The 45-minute budget — commit this to memory:**

| Minutes | Step | Output on the board |
|---|---|---|
| 0–5 | Requirements | 3–5 functional bullets + non-functional table + explicit scope cut |
| 5–10 | Estimation | QPS, storage, read:write ratio, and the one conclusion they imply |
| 10–15 | API + data model | 3–5 endpoints, entities with keys, indexes justified by access patterns |
| 15–25 | High-level design | Boxes + arrows, one write path and one read path narrated |
| 25–40 | Deep dive | Bottleneck → fix → cost → metric, one or two times |
| 40–45 | Close | Recap, biggest risk, what you'd do next |

**Five sentences that earn points, memorised verbatim:**

1. "Before I design anything — what scale are we targeting, and is this read-heavy or write-heavy?"
2. "I'll scope to X and Y and treat Z as out of scope unless you want it."
3. "That gives 100:1 reads to writes, so the interesting problem is the read path."
4. "Anything the user's response doesn't depend on goes behind a queue."
5. "I'm choosing X; the cost is Y, and I'd mitigate it with Z."

**The three ways candidates lose this interview:** drawing boxes before asking requirements; presenting one design with no alternatives or costs; and going quiet during the deep dive instead of reasoning out loud. All three are procedure failures, not knowledge failures — which is why the procedure above is worth more than any single technology on the board.
