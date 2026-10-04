---
kind: lesson
id_key: interview-prep-45/day-17-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Distributed Systems Basics"
position: 6
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

The moment your backend runs on more than one machine, you inherit a new class of failure: what happens when the network drops a packet, or two machines both think they're in charge? This lesson covers the CAP theorem, retrying safely, and the idempotency pattern that makes retries safe in the first place.

## CAP theorem: the choice you actually have to make

CAP says a distributed system can guarantee only two of three properties **during a network partition**, a moment when some nodes can't talk to others:

- **Consistency**: every read sees the most recent write, or an error.
- **Availability**: every request gets a real, non-error response.
- **Partition tolerance**: the system keeps working despite dropped or delayed messages between nodes.

Here's the catch: partitions *will* happen on any real network, so partition tolerance isn't really optional. The actual choice is **CP vs AP**, and only during a partition. A CP system (a Postgres primary with synchronous replication, etcd, ZooKeeper) refuses a write it can't confirm is durable across nodes, giving up availability. An AP system (Cassandra in its default configuration, DynamoDB) keeps answering requests on both sides of the partition and reconciles conflicts afterward, giving up strict consistency.

The right question isn't "which system is better," it's which failure mode actually fits the feature. A payments ledger wants CP: better to reject a write than record two different balances. A social media like-counter wants AP: better to show a slightly stale count than go down entirely.

> **Remember:** partition tolerance isn't a real choice, it's a fact of networks. The actual decision is CP vs AP, and it should follow from what the feature can tolerate, not a general preference.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedbasics-cap-q1", "type": "mcq",
      "prompt": "Why is 'pick two of three' a misleading way to describe CAP in practice?",
      "options": [
        {"id":"a","text":"Because partitions happen on any real network, so partition tolerance isn't optional; the real choice is CP versus AP, and only during an actual partition"},
        {"id":"b","text":"Because CAP does not apply to systems with more than 3 nodes"},
        {"id":"c","text":"Because consistency and availability can always be achieved together with enough hardware"},
        {"id":"d","text":"Because partition tolerance only matters for systems using UDP"}
      ],
      "correct": "a",
      "explanation": "Networks partition in the real world, so giving up partition tolerance isn't a realistic option. The meaningful trade-off only appears during an actual partition, between staying consistent (CP) and staying available (AP)." }
] }
```

## Eventual consistency and read-your-own-writes

**Eventual consistency** is a guarantee that if no new writes happen, every replica *eventually* converges to the same value, with no fixed bound on how long that takes, though in practice it's usually milliseconds to seconds. It's what AP systems offer instead of strong consistency. Concretely: you write to replica A, a read hits replica B a moment later and gets the old value, and a read shortly after that gets the new one once replication catches up.

The common complaint about this in interviews is **read-your-own-writes**: a user posts a comment, refreshes, and doesn't see it, because their read landed on a lagging replica. Standard fixes: route a user's reads to the primary (or the replica that served their last write) for a short window afterward, or use a session token that pins reads to a replica at least as fresh as that user's last write.

> **Remember:** eventual consistency means replicas converge, eventually, with no fixed deadline. Read-your-own-writes is the specific, user-visible bug this causes if you don't route a user's own reads carefully.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedbasics-eventual-q1", "type": "mcq",
      "prompt": "A user posts a comment, refreshes immediately, and doesn't see it, even though the write succeeded. What is the standard fix?",
      "options": [
        {"id":"a","text":"Route that user's reads to the primary, or to a replica known to be at least as fresh as their last write, for a short window after writing"},
        {"id":"b","text":"Nothing can be done; this is an unavoidable cost of using replicas"},
        {"id":"c","text":"Switch the entire system to strong consistency permanently"},
        {"id":"d","text":"Ask the user to wait exactly 60 seconds before refreshing"}
      ],
      "correct": "a",
      "explanation": "This is the read-your-own-writes problem: a read landed on a replica that hasn't caught up yet. Pinning that user's reads to a sufficiently fresh source for a short window is the standard, targeted fix." }
] }
```

## Retry with exponential backoff and full jitter

Retrying immediately on a struggling downstream service makes things worse: a thundering herd of retries piles onto a service that's already struggling. Exponential backoff spaces retries out; jitter stops many clients from retrying in lockstep.

```python
import random, time

def retry_with_backoff(fn, max_attempts=5, base_delay=0.5, max_delay=30.0):
    for attempt in range(max_attempts):
        try:
            return fn()
        except (ConnectionError, TimeoutError):
            if attempt == max_attempts - 1:
                raise
            delay = min(max_delay, base_delay * (2 ** attempt))
            delay = random.uniform(0, delay)   # full jitter
            time.sleep(delay)
```

"Full jitter," picking a random delay between 0 and the computed maximum rather than a fixed exponential value, is the detail that separates a correct answer from a memorized one. It decorrelates retry timing across many clients hitting the same failing service at once, which is why it beats no-jitter and "equal jitter" backoff under real contention.

> **Remember:** full jitter picks a random delay up to the backoff ceiling, not the ceiling itself. That randomness is what stops many clients from retrying in lockstep.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedbasics-jitter-q1", "type": "mcq",
      "prompt": "Why does full jitter (a random delay between 0 and the computed backoff) outperform a fixed exponential delay under heavy contention?",
      "options": [
        {"id":"a","text":"It makes each individual client's retries happen faster"},
        {"id":"b","text":"It decorrelates retry timing across many clients, so they don't all retry at the exact same moment and re-overwhelm the struggling service"},
        {"id":"c","text":"It uses less CPU than a fixed delay"},
        {"id":"d","text":"It guarantees every retry will succeed"}
      ],
      "correct": "b",
      "explanation": "A fixed exponential delay computed from the same failure moment means every client retries at the same instant. Full jitter spreads that mass of retries out over a range, reducing the chance of a second, synchronized overload." }
] }
```

## Idempotency: making retries safe to send twice

"How do you handle a network partition?" for a write, the honest answer is you can't always tell whether your write succeeded or just the response got lost. So the client retries, and the server has to make that retry safe. That's idempotency: applying the same request N times has the same effect as applying it once.

```python
@transaction.atomic
def create_payment(request):
    body = json.loads(request.body)
    idempotency_key = request.headers.get("Idempotency-Key")
    if not idempotency_key:
        return JsonResponse({"error": "Idempotency-Key header required"}, status=400)

    existing = IdempotencyRecord.objects.select_for_update().filter(key=idempotency_key).first()
    if existing:
        return JsonResponse(existing.response_body, status=existing.response_status)  # don't re-charge

    payment = Payment.objects.create(amount=body["amount"], account_id=body["account_id"])
    response_body = {"payment_id": payment.id, "status": "created"}
    IdempotencyRecord.objects.create(key=idempotency_key, response_status=201, response_body=response_body)
    return JsonResponse(response_body, status=201)
```

The idempotency key is generated once, client-side, before the first attempt, and sent on every retry of that same logical request. The lookup-and-insert happens inside the same transaction as the actual write, so a crash between "create the payment" and "record the key" is impossible: either both commit or neither does. `POST` endpoints that mutate money, inventory, or anything non-repeatable should support this header. `PUT`/`DELETE` are naturally idempotent by HTTP's own rules, though a `PUT` is only idempotent if it's a full replace, not a partial increment.

> **Remember:** the idempotency key is generated once by the client, before the first attempt, and reused on every retry. Generating a new key per retry defeats the entire mechanism.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-distributedbasics-idempotency-q1", "type": "mcq",
      "prompt": "A client generates a new Idempotency-Key for every retry of the same failed request. What breaks?",
      "options": [
        {"id":"a","text":"Nothing; a new key each time is the correct approach"},
        {"id":"b","text":"The server sees each retry as a brand-new request, so it processes the payment again on every retry, which is exactly what the idempotency key was supposed to prevent"},
        {"id":"c","text":"The server rejects all requests with a 400 error"},
        {"id":"d","text":"Only the first request ever succeeds"}
      ],
      "correct": "b",
      "explanation": "The whole mechanism depends on the same key being reused across retries of one logical request, so the server can recognize a repeat and return the original result instead of repeating the side effect." }
] }
```
