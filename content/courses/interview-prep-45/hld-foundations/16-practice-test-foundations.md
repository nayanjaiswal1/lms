---
kind: quiz
id_key: interview-prep-45/test-hld-foundations
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Practice Test: System Design Foundations"
position: 16
estimated_minutes: 25
pass_percentage: 70
duration_minutes: 25
source:
    - 45-day-interview-roadmap.md
    - checkpoints/01-quiz-week-1.md
    - checkpoints/03-quiz-week-3.md
    - checkpoints/05-quiz-week-5.md
questions:
  - id_key: interview-prep-45/quiz-week-1/q6
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a rate limiter design, which algorithm allows short bursts while enforcing a long-term average rate?"
    options:
      - text: "Token bucket"
        correct: true
      - text: "Fixed window counter"
      - text: "Leaky bucket"
      - text: "Round robin"
    explanation: "Token bucket accumulates tokens up to a burst capacity, so clients can burst briefly while the refill rate caps the sustained average. Leaky bucket smooths output to a constant rate instead."

  - id_key: interview-prep-45/quiz-week-3/q6
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "What does the CAP theorem say a distributed system must choose between during a network partition?"
    options:
      - text: "Consistency or availability — you cannot have both while partitioned"
        correct: true
      - text: "Latency or throughput"
      - text: "Durability or atomicity"
      - text: "Nothing — modern databases avoid the trade-off entirely"
    explanation: "When nodes can't communicate, you either reject requests to stay consistent (CP) or serve possibly-stale data to stay available (AP). Partition tolerance itself is non-negotiable."

  - id_key: interview-prep-45/quiz-week-5/q2
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a system design interview, what comes immediately after gathering functional requirements?"
    options:
      - text: "Back-of-the-envelope estimation — users, QPS, storage, read/write ratio"
        correct: true
      - text: "Choosing the programming language"
      - text: "Drawing the final architecture with every microservice"
      - text: "Writing the database schema in full detail"
    explanation: "Scale numbers drive every later decision: 100 QPS and 100k QPS produce different designs. Estimating first keeps you from designing for a scale the interviewer never asked about."

  - id_key: interview-prep-45/test-hld-foundations/estimation-ratio
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "A service handles 100 million requests a day. Roughly what is its average requests per second?"
    options:
      - text: "About 1,150"
        correct: true
      - text: "About 100"
      - text: "About 11,500"
      - text: "About 10"
    explanation: "A day has about 100,000 seconds. 100 million divided by 100,000 is 1,000, so about 1,000-1,150 requests per second on average. This is the single most useful shortcut for turning a daily number into a QPS number at the whiteboard."

  - id_key: interview-prep-45/test-hld-foundations/cache-invalidate
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "On a database write, why is deleting the matching cache key usually safer than overwriting it with the new value?"
    options:
      - text: "Two concurrent writers can overwrite the cache in the wrong order and leave a stale value stuck there forever; deleting forces the next read to repopulate from the real data"
        correct: true
      - text: "Deleting uses less memory than overwriting"
      - text: "Redis does not support overwriting an existing key"
      - text: "Overwriting always causes a cache miss anyway"
    explanation: "If writer A's slower update lands after writer B's faster one, an overwrite leaves the older value cached permanently. A delete has no such race: the next read simply goes to the source of truth."

  - id_key: interview-prep-45/test-hld-foundations/sharding-key-choice
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "You shard a table by `order_id`, but 95% of queries ask for \"all orders placed by customer X.\" What goes wrong?"
    options:
      - text: "Almost every common query becomes a scatter-gather across all shards, so latency tracks the slowest shard instead of any single one"
        correct: true
      - text: "Nothing, because hash partitioning always distributes evenly"
      - text: "The orders lose their uniqueness guarantee"
      - text: "Replication lag increases automatically"
    explanation: "Even distribution is only half of choosing a partition key. The other half is aligning the key with your dominant query — here that would be customer_id, not order_id."

  - id_key: interview-prep-45/test-hld-foundations/queue-vs-log
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Three independent teams — billing, analytics, and search — each need to process every order event, and search wants to replay all of history next month to rebuild its index. What fits best?"
    options:
      - text: "A distributed log (like Kafka), where each team is its own consumer group with its own offset, and retention makes replay possible"
        correct: true
      - text: "A single message queue with three consumers splitting the messages between them"
      - text: "Direct synchronous HTTP calls from the order service to all three teams"
      - text: "A shared table that all three teams poll"
    explanation: "A queue deletes a message once any one consumer takes it, so three consumers on one queue would only see a third of the events each. A log retains everything and lets each consumer group read at its own pace, including replaying from the start."

  - id_key: interview-prep-45/test-hld-foundations/consensus-cluster-size
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Why do production Raft or Paxos clusters almost always use an odd number of nodes, such as 3 or 5, instead of an even number like 4?"
    options:
      - text: "An even-sized cluster needs the same majority as the next odd size down, so the extra node adds cost and latency without adding fault tolerance"
        correct: true
      - text: "Consensus algorithms mathematically require a prime number of nodes"
      - text: "Even-sized clusters cannot elect a leader at all"
      - text: "Odd numbers are simply a long-standing convention with no technical reason"
    explanation: "A majority of 4 nodes is 3, and a majority of 5 nodes is also 3 — so a 4-node cluster tolerates only 1 failure, exactly like a 3-node cluster, while costing one extra machine and one extra vote's worth of latency."

  - id_key: interview-prep-45/test-hld-foundations/rate-limit-fixed-window
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A \"100 requests per minute\" limiter uses a fixed window that resets every 60 seconds. What is its known weakness?"
    options:
      - text: "A client can send 100 requests in the last second of one window and another 100 in the first second of the next, getting 200 requests in about one second"
        correct: true
      - text: "It uses far more memory than every other rate-limiting algorithm"
      - text: "It cannot be implemented using Redis"
      - text: "It never actually enforces the stated limit"
    explanation: "Fixed windows reset sharply at a clean boundary, so a client that times its bursts around the boundary can briefly send close to double the intended rate. Token bucket and the sliding window counter both avoid this boundary spike."

  - id_key: interview-prep-45/test-hld-foundations/cap-per-operation
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "An e-commerce system needs to never oversell the last item in stock, but is fine showing a slightly outdated review count. What is the strongest way to describe this in CAP terms?"
    options:
      - text: "The stock-decrement operation should be CP (refuse rather than risk an overselling error) while the review count can be AP (stay available and reconcile later)"
        correct: true
      - text: "The whole system should be built as CP, since money is involved somewhere"
      - text: "The whole system should be built as AP, since availability matters most to users"
      - text: "CAP does not apply here because there is only one database"
    explanation: "CAP is a choice you make per operation, not once for an entire system. The same system can refuse-rather-than-risk-wrong for inventory while staying available-and-reconciling for a cosmetic count like reviews."

  - id_key: interview-prep-45/test-hld-foundations/queue-dedupe
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A message queue guarantees at-least-once delivery, so a consumer may see the same message twice. What is the standard way to make processing a message safe to repeat?"
    options:
      - text: "Record the message's unique id in a table with a UNIQUE constraint before doing the work, so a repeat insert fails and the duplicate is skipped"
        correct: true
      - text: "Ask the message broker to guarantee exactly-once delivery instead"
      - text: "Process messages faster so duplicates become rare"
      - text: "Ignore the problem, since duplicates are extremely unlikely in practice"
    explanation: "No broker can guarantee true end-to-end exactly-once delivery once an external side effect is involved. The practical fix is at-least-once delivery plus an idempotent consumer, most simply built with a unique-constrained dedupe table."
---
This test covers the whole Foundations section: estimation, the request path, caching, databases, sharding, consistency, queues, coordination, and reliability. All eleven questions are multiple choice. Pass 70% to complete the section.
