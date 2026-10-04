---
kind: quiz
id_key: interview-prep-45/test-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Practice Test: System Design Case Studies"
position: 23
estimated_minutes: 30
pass_percentage: 70
duration_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - checkpoints/02-quiz-week-2.md
    - checkpoints/03-quiz-week-3.md
    - checkpoints/05-quiz-week-5.md
    - system-design/07-lesson.md
    - system-design/14-lesson.md
    - system-design/21-lesson.md
questions:
  - id_key: interview-prep-45/quiz-week-2/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a Twitter-style feed design, what is the main trade-off between fan-out-on-write and fan-out-on-read?"
    options:
      - text: "Fan-out-on-write precomputes timelines for fast reads but is expensive for accounts with millions of followers"
        correct: true
      - text: "Fan-out-on-read is always cheaper in every dimension"
      - text: "Fan-out-on-write reduces storage usage"
      - text: "There is no difference for celebrity accounts"
    explanation: "Pushing each post into every follower's timeline makes reads O(1) but writes explode for celebrities — real systems use a hybrid: fan-out-on-write for normal users, fan-out-on-read for high-follower accounts."

  - id_key: interview-prep-45/quiz-week-3/q8
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a Ticketmaster-style booking system, what prevents two users from buying the same seat?"
    options:
      - text: "A short-lived reservation hold (row lock or expiring hold) taken before payment completes"
        correct: true
      - text: "Optimistically letting both pay and refunding one later, as the primary design"
      - text: "Caching seat availability in the browser"
      - text: "Processing all bookings on a single thread forever"
    explanation: "The standard design reserves the seat atomically (SELECT ... FOR UPDATE or an expiring hold in Redis) for a payment window; if payment doesn't complete, the hold lapses and the seat returns to inventory."

  - id_key: interview-prep-45/quiz-week-5/q6
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Designing YouTube-scale video storage, the standard serving approach is:"
    options:
      - text: "Store transcoded segments in blob storage and serve through a CDN, keeping metadata in a database"
        correct: true
      - text: "Store video bytes as BLOB columns in PostgreSQL"
      - text: "Stream every request from the original upload server"
      - text: "Keep all videos in Redis for speed"
    explanation: "Video bytes belong in object storage (S3-style), delivered from CDN edges near users; databases hold only metadata (title, owner, segment manifest). Databases handle neither the size nor the bandwidth."

  - id_key: interview-prep-45/test-system-design/url-shortener-keygen
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Why is a Key Generation Service (pre-generated pool of unique keys) better than checking for a collision on every write in a URL shortener?"
    options:
      - text: "It removes the collision-check round trip from the write path entirely, since uniqueness is guaranteed by construction"
        correct: true
      - text: "It makes short codes longer, which is more secure"
      - text: "It eliminates the need for a database"
      - text: "It allows every server to share one global counter safely"
    explanation: "Checking for a collision on every write adds a retry loop that gets worse as the table fills up. A pre-generated key pool guarantees uniqueness up front, so writes never need to check at all."

  - id_key: interview-prep-45/test-system-design/rate-limiter-store-down
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "The shared Redis counter store for a distributed rate limiter goes down in the middle of a traffic spike. What is the standard response?"
    options:
      - text: "Fail open (allow requests through) for most APIs, accepting some risk of abuse in exchange for availability, and lean on other safeguards as backup"
        correct: true
      - text: "Fail closed and reject every request until Redis recovers, no matter the endpoint"
        correct: false
      - text: "Crash the API gateway so the problem is obvious"
      - text: "Silently double every client's limit until Redis returns"
    explanation: "Most production gateways fail open, since a false 429 rejecting real traffic is usually worse than a short unmetered window, and rely on autoscaling and circuit breakers as a backstop. Security-critical endpoints are the exception, where failing closed is the safer default."

  - id_key: interview-prep-45/test-system-design/notification-sent-not-delivered
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A notification's status is stuck at \"sent\" but never reaches \"delivered\" after ten minutes. Which explanation fits the design covered in this section?"
    options:
      - text: "The provider accepted the message but its own delivery confirmation is delayed, lost, or, for a channel like SMS, simply never reliably reported back"
        correct: true
      - text: "The notification was definitely never actually sent, despite the status"
      - text: "Notifications cannot have a status field, so this scenario is impossible"
      - text: "The user's device is always at fault whenever this happens"
    explanation: "\"Sent\" means the provider accepted the message; \"delivered\" depends on a separate confirmation signal that differs wildly by channel, push has real receipts, email has partial signals, SMS is often opaque. A timeout-based reconciliation job is the standard way to catch notifications stuck in this state."

  - id_key: interview-prep-45/test-system-design/chat-partition-conversation-id
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a chat system, why does the message broker get partitioned by conversation_id instead of by user_id?"
    options:
      - text: "So all messages in one conversation are processed in order by the same partition, which is what actually needs consistent ordering for every participant"
        correct: true
      - text: "Because partitioning by user_id is technically impossible in a message broker"
        correct: false
      - text: "Because conversation_id values are always smaller numbers than user_id values"
      - text: "It has no real effect on ordering, only on storage cost"
    explanation: "Ordering needs to be consistent per conversation, not per user, since a user can be in many conversations at once. Partitioning by conversation_id keeps every message in one conversation flowing through the same ordered stream."

  - id_key: interview-prep-45/test-system-design/analytics-event-vs-processing-time
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In an analytics pipeline, what is the difference between event time and processing time, and why does it matter?"
    options:
      - text: "Event time is when something actually happened on the client; processing time is when the pipeline saw it. Keeping both lets late-arriving data be corrected later without treating the pipeline as broken"
        correct: true
      - text: "They are two names for the same timestamp, kept for redundancy"
      - text: "Event time is always later than processing time"
      - text: "Processing time is only relevant for batch jobs, never for streaming"
    explanation: "A mobile client can queue an event offline for hours. Separating event time from processing time is what lets a batch job later fold a late-arriving event into the correct time bucket, rather than treating a real-time dashboard's momentary undercount as a bug."

  - id_key: interview-prep-45/test-system-design/multitenancy-three-models
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the concrete cost-versus-isolation trade-off across the three multi-tenancy models (Pool, Bridge, Silo)?"
    options:
      - text: "Pool (shared schema) is cheapest but weakest isolation; Silo (separate database per tenant) is strongest isolation but most expensive; Bridge (separate schema, shared database) sits in between"
        correct: true
      - text: "All three models cost the same, only their names differ"
      - text: "Silo is always the correct choice regardless of tenant count or budget"
      - text: "Pool offers the strongest isolation because it uses only one database"
    explanation: "Isolation and cost move together: sharing more infrastructure (Pool) is cheap but relies on discipline (backed by Row-Level Security) to prevent leaks, while dedicating a full database per tenant (Silo) is the strongest guarantee at the highest cost."

  - id_key: interview-prep-45/test-system-design/atleastonce-idempotent-effectively-once
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Why does at-least-once delivery combined with an idempotent handler behave like exactly-once, without the system ever actually guaranteeing exactly-once delivery?"
    options: 
      - text: "Because the handler checks a deterministic dedup key before doing the real work, so a duplicate delivery becomes a safe no-op even though the message itself was delivered more than once"
        correct: true
      - text: "Because idempotent handlers make the network guarantee exactly-once delivery automatically"
      - text: "Because at-least-once delivery is actually the same thing as exactly-once delivery"
      - text: "Because retries are disabled once a handler is marked idempotent"
    explanation: "True exactly-once delivery across an unreliable network isn't achievable. The practical fix is at-least-once delivery plus an idempotent handler: the delivery mechanism can duplicate a message, but the handler's own dedup check makes running twice produce the same effect as running once."

  - id_key: interview-prep-45/test-system-design/filestorage-refcount
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What does ref_count on the chunks table protect against in a Dropbox-style file storage design?"
    options:
      - text: "Deleting a chunk's underlying bytes while another file still depends on them through content-addressed deduplication"
        correct: true
      - text: "A user uploading a file that is too large for one chunk"
      - text: "Two users editing the same file at the same time"
      - text: "A chunk's hash colliding with another chunk's hash"
    explanation: "Because identical bytes can be shared across many files and users through dedup, deleting one file must only decrement the shared chunk's ref_count. The underlying bytes are only removed once ref_count reaches zero, meaning nothing else still needs them."

  - id_key: interview-prep-45/test-system-design/uber-geospatial-index
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why is a full table scan with a latitude/longitude range filter not good enough for Uber-style nearest-driver matching, and what replaces it?"
    options:
      - text: "It doesn't scale to thousands of writes per second across millions of drivers; a geospatial index (geohash cells or a quadtree) narrows the search to just a few nearby cells instead"
        correct: true
      - text: "A full table scan is actually the standard, correct approach at any scale"
      - text: "Latitude and longitude cannot be stored in a database at all"
      - text: "The fix is simply adding more database read replicas"
    explanation: "A geospatial index divides the map into cells so a nearby-driver query only has to check a handful of cells near the rider, instead of comparing against every driver in the system." 

  - id_key: interview-prep-45/test-system-design/otcrdt-vs-transport
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "In a Google Docs-style system, what is the actual difference between what OT/CRDTs solve and what a WebSocket transport layer solves?"
    options:
      - text: "OT and CRDTs resolve how concurrent edits merge into one consistent document; the transport layer only delivers the edits between clients and the server"
        correct: true
      - text: "They solve the exact same problem, so only one is ever needed"
      - text: "WebSockets handle merging, while OT and CRDTs only handle network delivery"
      - text: "OT and CRDTs replace the need for any network transport at all"
    explanation: "Delivering an edit and correctly merging a concurrent edit are two separate problems. A WebSocket (or any transport) can deliver messages reliably while still needing OT or a CRDT to decide how two people's simultaneous edits combine into one final document."

  - id_key: interview-prep-45/test-system-design/whatsapp-no-serverside-search
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why can't a WhatsApp-style server offer full-text search across a user's message history, given its end-to-end encryption design?"
    options:
      - text: "The server only ever sees encrypted ciphertext, so there is no plaintext for it to index or search"
        correct: true
      - text: "Full-text search is technically impossible to build for any messaging app"
      - text: "Search would violate the message ordering guarantee"
      - text: "WhatsApp simply hasn't built the search feature yet, for unrelated reasons"
    explanation: "End-to-end encryption means the server relays ciphertext it cannot read. Any search has to run on the device, where the content is actually decrypted, which is a real, known cost of this encryption design."

  - id_key: interview-prep-45/test-system-design/waitingroom-vs-ratelimiter
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "What does a waiting room accomplish during an extreme-demand event that a plain rate limiter does not?"
    options:
      - text: "It sequences and fairly admits users at a rate matched to actual downstream throughput, instead of simply rejecting excess traffic outright"
        correct: true
      - text: "It increases the total number of seats or items available"
      - text: "It removes the need for any inventory or seat-locking logic at all"
      - text: "It is functionally identical to a rate limiter, just renamed"
    explanation: "A rate limiter punishes or rejects traffic over a threshold. A waiting room instead converts a flood of simultaneous requests into a controlled, fair admission rate matched to real checkout throughput, keeping contention off the hot path entirely rather than just rejecting the excess."
---
This test covers the whole Case Studies section: the core case studies (URL shortener, rate limiter, notification service, job queue, chat, analytics, multi-tenant SaaS, social feed, autocomplete, file storage, Google Docs, code review, Netflix, YouTube, Spotify, Uber, Airbnb, Ticketmaster, e-commerce checkout, payments, logging) and the patterns that repeat across them. Pass 70% to complete the section.
