---
kind: lesson
id_key: interview-prep-45/hld-04-api-design
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "API Design and Idempotency"
position: 4
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

The API is the first real, concrete thing you produce in a design interview, and it's the part most people rush through. Done well, it takes about four minutes and quietly answers half a dozen questions the interviewer would otherwise have to ask you: how do you page through results, how do you handle new versions, what happens if the client sends the same request twice, and who's allowed to call this in the first place.

## Resource modelling and the URL contract

REST is just a set of naming habits for URLs, and the whole point of following them is that someone reading your API should be able to guess the next endpoint without being told.

```
GET    /v1/users/{id}                    fetch one
GET    /v1/users/{id}/tweets?cursor=...  a sub-collection
POST   /v1/tweets                        create
PATCH  /v1/tweets/{id}                   partial update
DELETE /v1/tweets/{id}                   delete
POST   /v1/tweets/{id}/retweet           an action that isn't CRUD
```

A few rules worth saying out loud.

**Put nouns in the path, and let the HTTP method carry the verb.** `POST /v1/createTweet` is the classic mistake; the "create" belongs in the method, not the URL. When an action genuinely isn't a simple create, read, update, or delete (retweeting, publishing, cancelling), it's fine to add an action word as a sub-path, like `retweet` above. Just say so, rather than twisting the model to avoid it.

**Nest one level deep, then stop.** `/users/{id}/tweets` reads fine. `/users/{id}/tweets/{tid}/comments/{cid}/likes` does not; instead, expose `/comments/{cid}/likes` directly.

**HTTP status codes carry real meaning**, so use the right one: `200` means it worked, `201` means something new was created, `202` means it's accepted and being processed in the background, `204` means it worked and there's nothing to return, `400` means the request itself was malformed, `401` means the caller isn't identified, `403` means they are identified but not allowed to do this, `404` means it doesn't exist, `409` means it conflicts with the current state, `422` means the request was well-formed but doesn't make sense, `429` means the caller has been rate-limited (with a `Retry-After` header telling them when to try again), `500` means it's your bug, and `503` means the server is overloaded or degraded.

**Errors should have one consistent, machine-readable shape.** For example: `{"error": {"code": "INSUFFICIENT_FUNDS", "message": "...", "request_id": "..."}}`. The `code` is for the client's own logic to react to, the `message` is for a human to read, and the `request_id` is what your support team uses to find the exact request in the logs.

**The HTTP method matters more than the URL.** Picture pressing an elevator call button. Pressing it five times doesn't summon five elevators; one press has the same effect as five. Now picture radioing a colleague and saying "add one more passenger" five times: that really does add five passengers. That difference between the two is exactly what these two words describe:

- **Safe** means the call doesn't change anything at all. `GET`, `HEAD`, and `OPTIONS` are safe.
- **Idempotent** means repeating the call has the same effect as calling it once. `GET`, `PUT`, and `DELETE` are idempotent by convention; `POST` is not. Calling `PUT /users/1 {name:"A"}` twice still leaves one user named A. Calling `POST /tweets` twice creates two separate tweets, which is exactly the problem the idempotency key below is built to solve.

> **Remember:** safe means "doesn't change anything." Idempotent means "repeating it changes nothing further." A `POST` is neither, by default.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-04-rest-q1", "type": "mcq",
      "prompt": "A client is logged in, but is trying to delete someone else's post. Which status code is correct?",
      "options": [
        {"id":"a","text":"401 Unauthorized"},
        {"id":"b","text":"403 Forbidden"},
        {"id":"c","text":"400 Bad Request"},
        {"id":"d","text":"500 Internal Server Error"}
      ],
      "correct": "b",
      "explanation": "401 means \"I don't know who you are,\" because credentials are missing or invalid. 403 means \"I know exactly who you are, and you may not do this.\" Some APIs deliberately return 404 instead of 403, to avoid revealing that the resource even exists; that's a legitimate design choice worth mentioning." }
] }
```

## Idempotency: the retry problem

This is the single most valuable API topic to know for interviews, because it shows up in every payment, booking, and messaging design.

Picture paying at a shop with a card. The machine charges your card, but the receipt printer jams before it prints anything. Nobody knows if the payment went through, so the shopkeeper taps your card again "just in case." Without a safeguard, you've now paid twice. That is exactly the failure at the API level: a client sends a payment request, the server charges the card, and the reply is lost somewhere on the network. The client, seeing no reply, tries again. Without protection, the customer is charged twice.

The standard fix is an idempotency key:

```
POST /v1/payments
Idempotency-Key: 8f14e45f-ea24-4e0b-b8d1-5a3c7f1e2b90
{ "amount_cents": 49900, "currency": "INR", "order_id": "ord_123" }
```

The idempotency key is a random ID the client generates once for this one logical action, and sends along with every attempt at it. Here is what the server does with it.

1. Look up the key in a store built for this purpose (Redis, or a database table), scoped to that particular caller.
2. **If it's not there yet:** insert it marked `in_progress`, guarded by a **unique constraint on the key**. That constraint is what makes this safe when two retries arrive at almost the same moment; only one of them can win the insert. Then do the actual work, save the response and its status, and mark it `completed`.
3. **If it's there and `completed`:** return the exact same response you already saved. Do not repeat the work.
4. **If it's there and still `in_progress`:** return a `409 Conflict` and let the client try again shortly.
5. Let keys expire after 24 to 48 hours, so the store doesn't grow forever.

Two details that show real understanding.

**The unique constraint is what makes this correct, not the lookup.** "Check if it exists, then insert" without a database constraint is a race: two retries arriving together can both pass the check before either one finishes inserting.

**Idempotency is not the same as blocking a second, genuine payment.** If the user truly wants to pay twice, they send a brand new key. The key represents one logical action, generated once by the client, not once per network attempt.

Where you can't add a dedicated key, use a **natural idempotency key** already present in the data, such as an `order_id` with a unique constraint on it, or a chat message's client-generated `message_id`.

> **Remember:** the UNIQUE constraint is what makes an idempotency key correct, not the lookup before it. A check without a constraint is a race two retries can both win.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-04-idem-q1", "type": "mcq",
      "prompt": "Why does a correct idempotency implementation need a UNIQUE database constraint on the key, rather than just checking if it exists before writing?",
      "options": [
        {"id":"a","text":"To make lookups faster"},
        {"id":"b","text":"Because two retries arriving at almost the same time can both find no existing record and both proceed. Only the database constraint guarantees exactly one of them wins"},
        {"id":"c","text":"Because keys must be stored in sorted order"},
        {"id":"d","text":"To let the key expire automatically"}
      ],
      "correct": "b",
      "explanation": "Checking then acting is a classic race condition. The unique constraint turns it into a single atomic step: the loser gets a constraint violation and returns the already-saved result instead of charging the card again." }
] }
```

## Pagination, filtering, and partial responses

Picture a librarian who, every single time you ask for book number 100,000 on a shelf, walks past the first 99,999 books one by one before handing you the right one. That's page-number pagination. A better librarian just remembers exactly where your bookmark was and starts from there.

**Never page through a feed using page numbers.** A query like "skip the first 100,000 rows, then give me 20" forces the database to walk through and discard 100,000 rows every single time, and a new row inserted at the top shifts every later page, so users end up seeing duplicates.

**Use cursor pagination instead**, where the cursor is a bookmark encoding exactly the sort position of the last row the client saw:

```sql
SELECT id, text, created_at
FROM tweets
WHERE author_id = $1
  AND (created_at, id) < ($2, $3)   -- the decoded cursor; id breaks ties
ORDER BY created_at DESC, id DESC
LIMIT 21;                            -- fetch one extra to know if there's a next page
```

Return `{"items": [...], "next_cursor": "eyJ0IjoiMjAy..."}`. Making the cursor an opaque, encoded string (rather than a plain page number) means you can change the underlying sort order later without breaking any client that's using it.

| | Page number | Cursor |
|---|---|---|
| Cost of a deep page | Grows with how far you page | Stays roughly constant, an index lookup |
| Stable when new rows arrive | No | Yes |
| Can jump straight to page 500 | Yes | Not really, but rarely needed |
| Total count of items | Easy to get | Needs a separate, rough estimate |

**Filtering and asking for only some fields** looks like `?status=active&created_after=2026-01-01&fields=id,name`. Only allow filtering and sorting on a fixed list of fields you've approved. An open-ended filter parameter that reaches the database directly is both a security hole (an attacker can inject their own query logic) and a way for one careless client to scan your entire production table.

**Rate limiting is part of the API contract, not an afterthought.** Return the caller's budget in response headers, so well-behaved clients can pace themselves:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1757145600
Retry-After: 30          (on 429)
```

> **Remember:** a cursor is a bookmark, not a page number. It survives new rows being inserted at the top; a page number does not.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-04-pagination-q1", "type": "mcq",
      "prompt": "Why does a cursor for a feed sorted newest-first usually encode both the timestamp and the row's id, instead of just the timestamp?",
      "options": [
        {"id":"a","text":"To make the cursor longer and harder to guess"},
        {"id":"b","text":"Because several rows can share the exact same timestamp, and without a tie-breaker the page boundary can skip some rows or repeat them"},
        {"id":"c","text":"Because timestamps cannot be indexed"},
        {"id":"d","text":"To support jumping to an arbitrary page number"}
      ],
      "correct": "b",
      "explanation": "Cursor pagination needs every row to have a unique position in the ordering. If ten posts share the exact same millisecond, comparing only against the timestamp either drops all ten or returns them twice. Adding the row's own id as a tie-breaker makes the sort order unique." }
] }
```

## Versioning, compatibility, and the API gateway

**Put a version in the URL from day one**, like `/v1/`. It's the simplest option, and it's easy to work with: it shows up in your logs, a load balancer can route on it directly, and it's simple to cache. Putting the version in a header instead is technically purer, but it's much harder to debug.

The real skill isn't picking a versioning scheme. It's **avoiding the need for a v2 at all**, by only ever making changes that don't break existing clients:

| Safe to ship | Breaks existing clients |
|---|---|
| Add a new optional field to a response | Remove or rename a field |
| Add a new optional request parameter | Make a previously optional parameter required |
| Add a new endpoint | Change a field's type or unit |
| Add a new possible value to a list, if clients already ignore values they don't recognise | Change what an existing value means |
| Loosen a validation rule | Tighten a validation rule |

When you truly must break something, run both the old and new versions side by side, announce a date when the old one stops working, add a `Deprecation` header to warn callers, and track which clients are still using the old version so you know exactly who you're about to affect.

**The API gateway** is the one place that handles concerns shared by every service, so each service doesn't have to rebuild them itself:

```
Client → Gateway ──▶ auth (verify JWT / API key)
                 ──▶ rate limiting + quotas
                 ──▶ request validation
                 ──▶ routing / versioning
                 ──▶ TLS termination, compression
                 ──▶ logging, tracing headers, metrics
                 ──▶ services
```

Keep business logic out of the gateway. A gateway that starts making decisions about, say, whether an order is valid, turns into one giant service with a single owner and a single point of failure, just wearing a gateway's name.

> **Remember:** a change is safe to ship without a new version if an old client can simply ignore it and keep working. Adding something is usually safe. Renaming, removing, or changing the type of something usually is not.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-04-versioning-q1", "type": "mcq",
      "prompt": "Which change to an existing endpoint is backward compatible for clients already running in production?",
      "options": [
        {"id":"a","text":"Renaming the response field `userName` to `user_name`"},
        {"id":"b","text":"Adding a new optional query parameter that defaults to today's current behaviour"},
        {"id":"c","text":"Changing the `amount` field from rupees to paise"},
        {"id":"d","text":"Making the previously optional `currency` field required"}
      ],
      "correct": "b",
      "explanation": "Additions that come with a safe default don't break anyone. Renaming a field, silently changing its unit, and making an optional field required all break existing callers. The silent unit change is the most dangerous of the three, because nothing errors out; the numbers are simply wrong." }
] }
```

## Quick recap

```
□ 3–5 endpoints, nouns + HTTP verbs, /v1/ prefix
□ Cursor pagination on every list  → {items[], next_cursor}
□ Idempotency-Key on every non-idempotent write, backed by a UNIQUE constraint
□ Consistent error envelope: {error:{code, message, request_id}}
□ Rate-limit headers + 429 + Retry-After
□ Auth at the gateway: who calls this, and what scope do they need?
□ Whitelisted filter/sort fields — never pass client strings to the query planner
```
