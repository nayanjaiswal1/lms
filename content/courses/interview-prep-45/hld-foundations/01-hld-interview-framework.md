---
kind: lesson
id_key: interview-prep-45/hld-01-framework
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "The System Design Interview Framework"
position: 1
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Picture a cooking exam. Every candidate gets a different dish to cook, but the judge checks the same five things every time: did you ask what the dish should taste like, did you check how many people you're feeding, did you plan the steps, did you cook them in the right order, and can you explain your choices. The dish changes. The judge's checklist does not.

A "system design interview" works the same way. You get 45 minutes to design something like Twitter, Uber, or a payment app on a whiteboard. This kind of interview is often called an HLD interview, short for High-Level Design, because you design the big boxes (services, databases, caches) rather than write real code. The system changes each time. The steps you walk through do not.

Most people who struggle here do not fail because they lack knowledge. They fail because they have no steps to follow, so they wander for twenty minutes before saying anything useful. This lesson gives you those steps.

The one thing to memorise is the order of the steps. You can work out the details at the whiteboard.

> **RESHADE** — **R**equirements, **E**stimation, **S**chema & API, **H**igh-level design, **A**rchitecture deep dive, **D**efend trade-offs, **E**dge cases.

## What the interviewer is actually scoring

You are not scored on how many technology names you can list. The interviewer is quietly filling in four boxes on a scorecard.

| Row | What it means | How you lose the point |
|---|---|---|
| **Problem framing** | You turned a vague ask into something you can actually build | You started drawing boxes before asking what the system must do |
| **Structured thinking** | You moved through the design in a clear order | You jumped between topics and the interviewer had to steer you back |
| **Technical depth** | You can go one level deeper than the box you drew | You said "I'd use a cache" and had nothing more to say when pushed |
| **Trade-off reasoning** | You picked an option and said what it costs | You presented your design as if it had no downsides |

The last row is what separates a junior answer from a senior one. A junior candidate says "this is the best approach." A senior candidate says something like: "I'm picking option X because we're read-heavy and can live with a one-second delay. If we needed perfect up-to-the-second data, I'd pick option Y and accept the slower response instead."

Say your reasoning out loud the whole time. The interviewer cannot give you credit for a good idea they never heard.

> **Remember:** a design with no stated cost is not a finished answer. Say what you're choosing, and say what it costs you.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-scoring-q1", "type": "mcq",
      "prompt": "You propose a read replica (an extra copy of the database used only for reads) to handle more traffic. Which follow-up sentence earns you the trade-off point?",
      "options": [
        {"id":"a","text":"\"Replicas are the standard solution for read-heavy systems.\""},
        {"id":"b","text":"\"This adds a small delay before new data reaches the replica, so a user who just posted might not see their own post right away. I'd send that user's next read back to the main database for a few seconds.\""},
        {"id":"c","text":"\"We can add more replicas later if needed.\""},
        {"id":"d","text":"\"Postgres, MySQL, and MongoDB all support replicas.\""}
      ],
      "correct": "b",
      "explanation": "Trade-off reasoning means naming the cost of your choice and how you'd soften it. Answer (b) names the real downside (a delay before data catches up), who notices it, and the fix. The others are just facts, or they put off the problem." }
] }
```

## Step 1 — Requirements: turn a vague prompt into a clear spec

Give this about five minutes. Do not skip it. If you're still here after eight minutes, move on anyway.

Split requirements into two kinds, out loud, on the board.

**Functional requirements** are what a user can *do*. Write down three to five actions, no more. For "design Twitter": post a message, follow a person, view a home feed. Say what you're leaving out too: "I'll treat direct messages, search, and ads as out of scope unless you'd like me to cover them."

**Non-functional requirements** are the numbers and properties that actually shape the design:

| Question to ask | Why it changes the design |
|---|---|
| How many users, how much traffic? | Decides one database or many, cache or no cache |
| Read-heavy or write-heavy? | Read-heavy needs replicas and caching; write-heavy needs splitting the data up and queues |
| How fast must it respond? | A 50 millisecond target for the slowest 1% of requests (called "p99 latency") rules out calls to a server on another continent |
| Consistency or availability if the network breaks? | Money needs to always be exactly correct; a feed or a like count can be a little stale |
| Can we ever lose a record? | A payment record: never. An analytics event: sometimes acceptable |
| One region or many? | Serving many regions adds copying data around, routing by location, and legal rules on where data can live |

Then say what you are choosing not to build. This is a strength, not a shortcut: "I'll design the posting flow and the feed end to end, and treat uploading photos as an S3-plus-CDN detail I'll come back to if there's time." (S3 is Amazon's storage service for files; a CDN, short for content delivery network, is a set of servers around the world that store a copy of a file close to each reader.)

> **Remember:** functional requirements say what a user can do. Non-functional requirements say how well, and those are the numbers that actually shape your design.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-requirements-q1", "type": "mcq",
      "prompt": "Which of these is a NON-functional requirement?",
      "options": [
        {"id":"a","text":"A user can follow another user"},
        {"id":"b","text":"A feed shows the 50 most recent posts"},
        {"id":"c","text":"The feed must load in under 200 milliseconds for 10 million daily users"},
        {"id":"d","text":"A user can delete their own post"}
      ],
      "correct": "c",
      "explanation": "Functional requirements are what the system does (a, b, d). Non-functional requirements are how well it must do it: speed, scale, staying online, correctness. Non-functional requirements are what actually force your architecture choices." }
] }
```

## Step 2 — Estimation: get the numbers that shape the design

This takes three to five minutes. You are not trying to be exact. You are trying to answer one question: is this a small problem, a medium problem, or a huge one? That answer decides everything else.

Picture deciding whether to cook for a family of four or cater a 500-person wedding, before you decide how many stoves you need. The estimate is that same check, done with real numbers.

The chain of numbers is always the same shape:

```
DAU  →  actions per user per day  →  requests/day  →  average QPS  →  peak QPS (×2–3)
                                  →  bytes per action  →  storage/day  →  storage/5yr
                                  →  bytes × QPS  →  bandwidth
```

Here DAU means daily active users, the number of people who use the app on a given day. QPS means queries per second, or how many requests hit your servers each second.

A worked example, the kind you'd say out loud in about 30 seconds:

- 10 million DAU. Each one reads their feed 10 times a day and posts 0.1 times a day (one post every 10 days, on average).
- Reads: 100 million a day, divided by 86,400 seconds in a day, is about **1,200 QPS** on average, and about **3,500 QPS** at the busiest moment.
- Writes: 1 million a day is about **12 QPS** on average. That's tiny.
- The ratio of reads to writes is **100 to 1**. This is a read-heavy system, so caching and extra read copies of the database matter far more than splitting up the writes.
- One post is about 300 bytes of text. A million posts a day is about 300 MB a day, or **half a terabyte over five years**. Text easily fits on one strong server. Photos and video are the real storage problem.

Notice what those five lines did for you. You now know to spend your design time on the read path, and you have a real reason why. That's the whole point of doing the math.

> **Remember:** an estimate that doesn't end in a "so..." sentence earned nothing. The numbers only matter if they point at which part of the design is hard.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-estimation-q1", "type": "mcq",
      "prompt": "Your estimate shows 100 reads for every 1 write, and only 12 writes per second. What should that tell you about where to spend your design time?",
      "options": [
        {"id":"a","text":"Split the write path across many databases first"},
        {"id":"b","text":"Writes are easy for a single database; the real problem is the read path, so focus on caching, extra read copies, and precomputing results"},
        {"id":"c","text":"The system needs perfect, always-up-to-date consistency"},
        {"id":"d","text":"Use a NoSQL database, because a normal relational database can't handle 12 writes a second"}
      ],
      "correct": "b",
      "explanation": "12 writes a second is nothing; a laptop could handle it. The estimate's job is to point your remaining 30 minutes at the part that's actually hard, which here is serving 3,500 reads a second cheaply." }
] }
```

## Step 3 — API and data model: the contract before the boxes

Give this about five minutes. Two small pieces of work, nothing more.

**The API.** Write down three to five endpoints: just the request and the response shape, nothing else. An endpoint is one specific URL a client can call, like "create a post" or "get my feed." Writing these down forces you to decide what the system actually offers, and it surfaces good questions early, like how you page through results, how you avoid double-submits, and who is allowed to call what.

```
POST /v1/tweets            {text, media_ids[]}        -> {tweet_id, created_at}
GET  /v1/timeline?cursor=  ...                        -> {tweets[], next_cursor}
POST /v1/users/{id}/follow  Idempotency-Key: <uuid>   -> 204
```

Two habits that make you look experienced. First, use **cursor pagination**, never page numbers. A cursor is a bookmark, like a scrap of paper marking your place in a book: it tells the server exactly where you left off, so the next page is always correct even if new posts arrive. A page number, by contrast, drifts and gets slower the further you page. Second, add an **idempotency key** to any write the client might accidentally send twice, such as after a lost network reply. An idempotency key is a unique ID the client generates once per action; the server uses it to recognize a repeat and avoid doing the work twice.

**The data model.** List your entities, their key fields, and how they relate. Just as important: write down the **access patterns**, meaning the actual questions your code will ask the database, because those questions decide which storage engine and which indexes you need.

```
User(id PK, handle UNIQUE, name, created_at)
Tweet(id PK, author_id FK, text, created_at)         index: (author_id, created_at DESC)
Follow(follower_id, followee_id)  PK(follower_id, followee_id)
                                  index: (followee_id)   -- "who follows me", for fan-out
```

Say the access pattern out loud next to each index. For example: "the feed query is 'posts by everyone I follow, newest first,' so I need an index in the followee-to-follower direction to look up who to notify when someone posts." Choosing your indexes from the queries you actually wrote is exactly the reasoning a real database review wants to see.

> **Remember:** pick every index from a query you actually wrote down. An index that no query needs is just a slower write.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-api-q1", "type": "mcq",
      "prompt": "Why is cursor pagination (a bookmark like `?cursor=abc123`) preferred over page-number pagination (`?page=500`) for a feed?",
      "options": [
        {"id":"a","text":"Cursors are shorter strings, so requests are smaller"},
        {"id":"b","text":"Page numbers force the database to read and throw away every earlier row first, getting slower the deeper you page, and items shift between pages when new rows are added"},
        {"id":"c","text":"Page-number pagination cannot be cached"},
        {"id":"d","text":"Cursor pagination guarantees perfectly up-to-date data"}
      ],
      "correct": "b",
      "explanation": "Asking for page 500 makes the database walk through 10,000 earlier rows before it can answer, and a new post at the top pushes every row one page later, so users see duplicates or missing items. A cursor jumps straight to the right spot and stays correct even as new rows are added." }
] }
```

## Step 4 — High-level design: draw the request path

Give this about ten minutes. Draw boxes and arrows, and talk through **one request from start to end** as it passes through them. A diagram nobody explains out loud is just decoration.

Here is a starting skeleton. Draw it, then delete whatever this particular problem doesn't need.

```
Client → DNS → CDN (static/media)
       → Load Balancer → API Gateway (auth, rate limit)
       → Application services
              ├── Cache (Redis)
              ├── Primary DB  →  Read replicas
              ├── Object store (S3) for blobs
              └── Message queue → async workers  →  search index / analytics / notifications
```

Four rules keep this step on track.

1. **Draw only what a requirement demands.** Every box you can't justify is a box you'll be asked to defend, and you won't be able to.
2. **Split synchronous work from asynchronous work.** Synchronous means the user is waiting for it right now; asynchronous means it can happen a moment later, in the background. Anything the response doesn't depend on, like sending notifications, generating thumbnails, or logging analytics, goes behind a queue instead of blocking the reply.
3. **Narrate the write path, then the read path.** For example: "A post request hits the gateway, which checks who the user is and whether they've hit their rate limit. The service saves the post to the main database, announces a 'post created' event, and replies. A separate worker picks up that event later and pushes the new post id into each follower's feed cache."
4. **Keep app servers stateless.** Stateless means a server holds nothing in its own memory between requests; session and cache data lives in Redis (a shared, fast, in-memory data store) instead. That way any server can handle any request, and adding more servers actually works.

> **Remember:** draw only what a requirement demands, and anything the user isn't waiting on goes behind a queue.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-hld-q1", "type": "mcq",
      "prompt": "Which piece of work belongs BEHIND a queue rather than in the path the user is waiting on, when someone posts a tweet?",
      "options": [
        {"id":"a","text":"Checking the tweet's text isn't too long"},
        {"id":"b","text":"Saving the tweet so the author sees it on their own profile"},
        {"id":"c","text":"Pushing the new tweet into 2 million followers' feed caches"},
        {"id":"d","text":"Checking who the caller is"}
      ],
      "correct": "c",
      "explanation": "Anything the user's own response doesn't depend on, especially something whose size depends on someone else's data (like follower count), should happen later, in the background. Updating 2 million feeds can't happen inside a fast reply; the validation, the login check, and the actual save must happen before you reply." }
] }
```

## Step 5 — Deep dive, bottlenecks, and the trade-off close

Give the last fifteen minutes to this step. This is where your level gets decided.

Either the interviewer names the deep-dive topic ("how does the feed stay fast for a celebrity with 50 million followers?") or you pick it yourself. If you're picking, pick the box your own estimate showed was under the most pressure.

Run every bottleneck (the part of the system that breaks first under load) through the same four questions.

| Question | Example answer |
|---|---|
| Where does it break first? | Updating every follower's feed at post time breaks for celebrity accounts; one tweet means 50 million cache writes |
| What's the fix? | A hybrid: update feeds at post time for normal users, but build a celebrity's followers' feeds at read time instead, and merge the two |
| What does the fix cost? | Two separate code paths, a "celebrity" threshold you have to tune, and slightly slower reads for people who follow a celebrity |
| How do you know it's working? | Feed latency at the 99th percentile, how far behind the update worker is, and the cache hit rate |

Then close with three short sentences.

1. **Recap the shape.** "This is read-heavy, so I precomputed feeds in Redis, backed by a database split across several servers."
2. **Name the biggest risk.** "The worker that updates feeds is the piece most likely to fall over during a celebrity spike."
3. **Say what you'd do next with more time.** "I'd design the multi-region setup and the analytics pipeline next."

Name failure modes before the interviewer asks about them: a single point of failure (one thing whose crash takes down everything), one database shard getting far more traffic than the others, a wave of requests all hitting an empty cache at once, a queue that grows without limit, and retries with no backoff piling on top of each other.

> **Remember:** dive into the box your own estimate proved was under pressure, not the box you feel safest talking about.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-01-deepdive-q1", "type": "mcq",
      "prompt": "With 15 minutes left and no direction from the interviewer, which deep dive should you choose?",
      "options": [
        {"id":"a","text":"The part your own back-of-the-envelope estimate showed was under the most pressure"},
        {"id":"b","text":"The part you happen to know the most trivia about"},
        {"id":"c","text":"The login flow, since every system needs one"},
        {"id":"d","text":"A full rewrite of the design using many small services"}
      ],
      "correct": "a",
      "explanation": "The estimate exists to point you at the hard part. Diving there shows your numbers actually drove your design. Diving into your comfort topic instead shows the opposite." }
] }
```

## Quick recap

**The 45-minute budget:**

| Minutes | Step | Output on the board |
|---|---|---|
| 0–5 | Requirements | 3–5 functional bullets, a non-functional table, and an explicit scope cut |
| 5–10 | Estimation | QPS, storage, read-to-write ratio, and the one conclusion they point to |
| 10–15 | API + data model | 3–5 endpoints, entities with keys, indexes justified by access patterns |
| 15–25 | High-level design | Boxes and arrows, one write path and one read path narrated out loud |
| 25–40 | Deep dive | Bottleneck, fix, cost, metric, done once or twice |
| 40–45 | Close | Recap, biggest risk, what you'd do next |

**Five sentences worth learning by heart:**

1. "Before I design anything, what scale are we targeting, and is this read-heavy or write-heavy?"
2. "I'll scope to X and Y, and treat Z as out of scope unless you'd like it covered."
3. "That's 100 reads for every write, so the interesting problem is the read path."
4. "Anything the user's response doesn't depend on goes behind a queue."
5. "I'm choosing X. The cost is Y, and I'd soften it with Z."
