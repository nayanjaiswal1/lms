---
kind: quiz
id_key: interview-prep-45/test-backend-systems
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Practice Test: Caching, Queues and Distributed Systems"
position: 8
estimated_minutes: 24
pass_percentage: 70
duration_minutes: 24
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
    - checkpoints/02-quiz-week-2.md
    - checkpoints/03-quiz-week-3.md
questions:
  - id_key: interview-prep-45/quiz-week-2/q8
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "In a job queue system, how do you safely handle a worker that dies mid-task?"
    options:
      - text: "Use visibility timeouts / heartbeats so the job returns to the queue, and make task handlers idempotent"
        correct: true
      - text: "Mark the job completed as soon as a worker picks it up"
      - text: "Delete the job when the worker crashes"
      - text: "Rely on the worker to always finish"
    explanation: "Acknowledge only after completion; if the worker's lease or heartbeat lapses, the broker redelivers. Because redelivery means possible re-execution, handlers must be idempotent, the core Celery interview answer."

  - id_key: interview-prep-45/quiz-week-3/q7
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "What is the classic failure mode of a Redis distributed lock with a TTL?"
    options:
      - text: "A paused/slow client's lock expires, another client acquires it, and both run the critical section"
        correct: true
      - text: "The lock can never expire, causing deadlock"
      - text: "Redis rejects SET NX under load"
      - text: "TTL locks prevent all concurrency bugs"
    explanation: "If the holder stalls (a GC pause, network delay) past the TTL, the lock is released while it still thinks it owns it. Mitigations: fencing tokens, lock renewal (watchdog), or accepting at-least-once semantics with idempotency."

  - id_key: interview-prep-45/test-backend-systems/cache-invalidation
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "After updating a row in the database, why delete the matching cache key instead of writing the new value into the cache directly?"
    options:
      - text: "Deleting forces the next read to fetch the real value from the source of truth, avoiding a race where an out-of-order write leaves a stale value stuck in the cache"
        correct: true
      - text: "Deleting is always a faster Redis operation than SET"
      - text: "Redis does not allow overwriting an existing key"
      - text: "There is no real difference between the two approaches"
    explanation: "Two writers updating the cache directly can land in the wrong order, leaving the older value stuck. Deleting removes that possibility: the worst case is one extra cache miss, not a permanently wrong value."

  - id_key: interview-prep-45/test-backend-systems/eviction-policy
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A Redis instance holds both disposable cache entries and session data that must never be silently evicted. Which family of eviction policy fits?"
    options:
      - text: "allkeys-lru"
      - text: "volatile-lru, since it only evicts keys that were explicitly given a TTL"
        correct: true
      - text: "noeviction"
      - text: "allkeys-random"
    explanation: "A volatile-* policy only considers TTL'd keys for eviction, leaving untimed data like session state untouched under memory pressure."

  - id_key: interview-prep-45/test-backend-systems/sorted-set-leaderboard
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why does a Redis sorted set fit a leaderboard better than repeatedly re-sorting a plain list?"
    options:
      - text: "It combines a skip list for fast ordered range reads with a hash table for fast lookup by member, keeping order incrementally instead of re-sorting"
        correct: true
      - text: "Sorted sets store data in a random order for security"
      - text: "Sorted sets can only hold string values"
      - text: "Lists in Redis cannot store more than 100 items"
    explanation: "A ZSET's skip-list-plus-hash-table structure keeps members in order as scores change, giving fast ranked reads without a fresh sort on every update."

  - id_key: interview-prep-45/test-backend-systems/streams-vs-pubsub
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A subscriber disconnects for 30 seconds while messages are sent. What is the key difference between Redis streams and pub/sub here?"
    options:
      - text: "A stream persists the entries, so the consumer can catch up on reconnecting; pub/sub delivers only to whoever is listening right now and drops the rest"
        correct: true
      - text: "Both mechanisms behave identically in this scenario"
      - text: "Pub/sub persists messages; streams do not"
      - text: "Neither mechanism can recover from any disconnect"
    explanation: "Streams are durable, append-only logs a consumer can replay. Pub/sub is fire-and-forget: a message sent while nobody is subscribed is gone immediately."

  - id_key: interview-prep-45/test-backend-systems/celery-idempotency
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Celery's default delivery guarantee is at-least-once, not exactly-once. What does that require of every task?"
    options:
      - text: "The task's side effect must be idempotent, since redelivery can cause it to run more than once"
        correct: true
      - text: "Nothing extra; Celery guarantees each task runs exactly once by default"
      - text: "Every task must be wrapped in a database transaction"
      - text: "Tasks must never call external APIs"
    explanation: "At-least-once delivery means a worker crash after execution but before acking can cause the same task message to be redelivered and re-run. The task's effect, not the delivery mechanism, has to tolerate that."

  - id_key: interview-prep-45/test-backend-systems/kafka-ordering
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A system needs every event for one order processed in order, but doesn't care about ordering between different orders. What's the standard Kafka approach?"
    options:
      - text: "Key each event by order_id, so all of one order's events land in the same partition and stay ordered, while different orders spread across partitions"
        correct: true
      - text: "Use exactly one partition for the whole topic"
      - text: "Kafka guarantees global ordering automatically across all partitions"
      - text: "Use a separate consumer group for every order"
    explanation: "Kafka only orders records within a single partition. Keying by the entity that needs ordering routes its events to one partition consistently, without capping the whole topic to one partition's throughput."

  - id_key: interview-prep-45/test-backend-systems/outbox-pattern
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Why does writing an event to an outbox table in the same transaction as the business write solve the 'DB commits but the event is never published' problem?"
    options:
      - text: "The event's existence becomes tied to the business write actually committing, since both are in one transaction; a separate relay process then publishes it, which is why the consumer still needs to be idempotent"
        correct: true
      - text: "It guarantees the event is published instantly, with no relay process needed"
      - text: "It replaces the need for a message broker entirely"
      - text: "It only works if the business write and the event go to different databases"
    explanation: "The transactional write guarantees the outbox row exists if and only if the business data committed. Actual delivery still happens afterward through a relay, which can itself fail partway, so outbox alone gives at-least-once delivery."

  - id_key: interview-prep-45/test-backend-systems/cap-tradeoff
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "During an actual network partition, a payments ledger refuses to accept a write it cannot confirm is durable across nodes. What choice does this represent?"
    options:
      - text: "CP: choosing consistency over availability during the partition"
        correct: true
      - text: "AP: choosing availability over consistency"
      - text: "This has nothing to do with CAP theorem"
      - text: "Partition tolerance is being sacrificed here"
    explanation: "Refusing a write it can't confirm is durable, rather than risking two diverging values, is the CP choice: sacrificing availability to preserve consistency during the partition."

  - id_key: interview-prep-45/test-backend-systems/full-jitter
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why does full jitter (a random delay between 0 and the backoff ceiling) beat a fixed exponential delay when many clients fail at once?"
    options:
      - text: "It decorrelates retry timing across clients, so they don't all retry at the exact same moment and re-overwhelm the recovering service"
        correct: true
      - text: "It makes each individual client retry faster overall"
      - text: "It eliminates the need for a maximum retry count"
      - text: "It only matters when there is exactly one client retrying"
    explanation: "A fixed exponential delay computed from the same failure moment means every client retries in lockstep. Full jitter spreads retries across a range, avoiding a second synchronized spike."

  - id_key: interview-prep-45/test-backend-systems/fencing-token
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "What problem does a fencing token solve that a Redlock-style lock alone does not?"
    options:
      - text: "It stops a stale write from a former lock holder from still landing on the protected resource, since the resource itself rejects any token lower than the last one it accepted"
        correct: true
      - text: "It eliminates the need for a TTL on the lock entirely"
      - text: "It makes lock acquisition faster across multiple Redis nodes"
      - text: "It replaces the need for a quorum of instances"
    explanation: "A lock only tracks who currently holds it, not whether a delayed write from a former holder still arrives. A fencing token lets the protected resource itself enforce ordering, rejecting stale writes regardless of what the lock currently shows."
---
This test covers Redis caching and eviction, sorted sets and streams, Celery and background worker reliability, Kafka ordering and delivery guarantees, async pipeline patterns like the outbox, CAP theorem, retries, and distributed locks. Pass 70% to complete the section.
