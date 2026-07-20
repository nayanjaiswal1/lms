---
kind: lesson
type: system_design
id_key: interview-prep-45/day-19-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 19 — Design WhatsApp"
position: 19
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Messaging systems test whether you understand delivery guarantees under unreliable mobile networks: ordering, at-least-once vs. exactly-once semantics, offline delivery, and end-to-end encryption without the server ever seeing plaintext. It's less about raw scale (messages are tiny) and more about correctness under partial failure — a favorite deep-dive area for senior interviews.

## Requirements

**Functional**
- Users send 1:1 and group text messages, with delivery/read receipts.
- Users send media (photos, video, voice notes).
- Users see "status" (ephemeral 24-hour stories).
- Messages are end-to-end encrypted — the server never has access to plaintext.
- Messages delivered even if the recipient is offline when sent (delivered on next connect).

**Non-functional**
- At-least-once delivery: a message must never be silently lost, even across app restarts or network drops.
- Ordering: messages within a single conversation should appear in a consistent order on all devices.
- Low latency for online users (sub-second delivery); durable queuing for offline users (delivery whenever they reconnect, even days later).
- Multi-device support: a message sent from a phone should also appear on a linked desktop/web client.
- Massive connection scale: hundreds of millions of concurrent persistent connections.

## Capacity estimates

- 2B monthly active users, ~500M concurrently connected at peak (persistent connections held open for push delivery).
- Average user sends ~40 messages/day → 2B × 40 / 86,400 ≈ **~900,000 messages/sec** average, several times higher at peak (e.g., New Year's Eve is the classic real-world stress case WhatsApp has publicly discussed).
- Each text message is small (~1KB including metadata/encryption overhead) → 900K/sec × 1KB ≈ ~900 MB/sec text traffic — trivial for the message pipeline itself.
- Media messages: assume ~5% of messages carry media (photo/voice), average 200KB-2MB each → this is the actual bandwidth driver, handled by uploading to object storage and sending only a reference/thumbnail through the messaging pipeline, never the raw bytes.
- Connection state: 500M concurrent long-lived connections — this is the standout infrastructure number. At roughly 10K-40K connections per commodity server (practical limits from socket/file-descriptor tuning), you need on the order of tens of thousands of connection-holding servers just for the WebSocket/TCP layer, which is why this tier is architected completely separately from message processing.

The number to lead with: **connection count, not message volume, is the dominant scaling constraint** — this is what makes messaging systems architecturally distinct from, say, a REST CRUD API.

## API sketch

Messaging systems are push/pull over a persistent connection more than classic REST, but the shape is:

```
WS  /v1/connect                       # persistent connection, authenticated
  client -> server: { type: "send", to: user_id|group_id, ciphertext, msg_id (client-generated) }
  server -> client: { type: "ack", msg_id, server_seq }
  server -> client: { type: "message", from, ciphertext, server_seq }
  client -> server: { type: "delivered", msg_id }
  client -> server: { type: "read", msg_id }

GET  /v1/messages/sync?since_seq=...  # pull missed messages after reconnect
POST /v1/media/upload                  # media uploaded separately, returns a reference
POST /v1/groups
  body: { name, member_ids }
```

The client generates a unique `msg_id` client-side so retried sends (after a dropped ack) are deduplicated server-side — this is the mechanism that turns "at-least-once network delivery" into "effectively-once observed by the user."

## Data model

```
User(user_id PK, phone_number, public_key, devices[])
Device(device_id PK, user_id FK, push_token, last_seen)
Conversation(conversation_id PK, type[direct|group], member_ids[])
Message(message_id PK, conversation_id FK, sender_id, server_seq,
        ciphertext, sent_at, delivered_to[], read_by[])
  -- ciphertext only: server cannot read content, only routes it
MessageQueue(user_id/device_id, message_id, enqueued_at)
  -- per-device durable queue for offline delivery, drained on reconnect
Status(status_id PK, user_id FK, media_ref, posted_at, expires_at)
```

Key detail: `Message.ciphertext` is opaque to the server — encryption happens client-to-client (see deep dive), so the schema stores blobs, not readable text, and the server's job is purely store-and-forward routing plus retention/expiry.

## High-level architecture

```
[Sender Device] --(persistent conn)--> [Connection Gateway tier]
                                              |
                                     [Message Router/Dispatcher]
                                        /              \
                              recipient online?    recipient offline?
                                   |                      |
                        [route via Connection      [write to per-device
                         Gateway holding             durable queue,
                         recipient's socket]         trigger push
                                                      notification]
                                                            |
                                                   [on reconnect, drain
                                                    queue via sync API]

[Media]: uploaded directly to [Object Storage] by sender, reference
          shared through the message pipeline, fetched by recipient
          from [Object Storage/CDN] directly.
```

- **Connection Gateway tier** is a large, horizontally-scaled fleet purely responsible for holding persistent connections (WebSocket or a custom TCP protocol) and knowing "which gateway node holds which user's socket" via a shared connection-registry (e.g., in a distributed cache).
- **Message Router** looks up the recipient's online status/connection location; if online, it forwards the message directly to the gateway node holding that socket; if offline, it durably enqueues per-device and relies on push notifications (APNs/FCM) to wake the app, which then reconnects and syncs.
- Media never flows through the message router — only a reference does, keeping the hot messaging path lightweight (same pattern as Spotify's audio and Airbnb's photos: bytes go through object storage + CDN, not the transactional pipeline).

## Component deep dives

### Message storage & ordering

Assign each message a `server_seq` — a monotonically increasing sequence number scoped to the conversation, assigned by the router at write time. Clients use this sequence to detect gaps ("I have seq 100 and 102, where's 101?") and request a resync. Ordering doesn't need a global clock or vector clocks for a simple chat app — a per-conversation sequence counter (backed by the database or a coordination service like a distributed counter) is sufficient and far simpler.

### At-least-once delivery & deduplication

The client retries sending a message until it receives a server ack, and retries are idempotent because the client attaches its own `msg_id` (a UUID generated client-side before the first send attempt). The server's write path is `INSERT ... ON CONFLICT (msg_id) DO NOTHING`-style upsert, so a retried send that already succeeded is a no-op rather than a duplicate message. This is the standard pattern for turning unreliable at-least-once network delivery into effectively-once observed behavior — memorize this pattern, it reappears in payment idempotency (Day 25) and notification systems (Day 26).

### End-to-end encryption

The server must never see plaintext. The standard real-world answer is the **Signal Protocol** (Double Ratchet algorithm): each pair of devices establishes a shared secret via a Diffie-Hellman key exchange at conversation start, then every message advances a ratchet that derives a new encryption key, so compromising one message's key doesn't expose past or future messages (forward secrecy + post-compromise security). For groups, each member encrypts with a per-recipient key (or uses a more advanced sender-key scheme to avoid O(n) encryption per message in large groups). The server's role is reduced to routing opaque ciphertext blobs and managing public key distribution — it's a relay, not a participant in the crypto.

### Media storage

Sender uploads media directly to object storage (pre-signed upload URL, same pattern as other systems this week), optionally encrypting client-side before upload so the storage layer also never sees plaintext media. The message itself carries only a reference (storage key + decryption key, itself encrypted within the E2E-encrypted message payload) — this keeps the messaging pipeline's per-message size small and predictable regardless of attachment size.

### Message synchronization across devices

Multi-device support (phone + linked desktop/web) means a message must be delivered to every registered device for that user, not just one. Model delivery per-device rather than per-user: the `MessageQueue` and delivery/read receipts are tracked per `device_id`. When a new device is linked, it does a full history sync (bounded by a retention window) rather than replaying from the beginning of time.

## Scaling & trade-offs

| Concern | Choice | Trade-off |
|---|---|---|
| Connection handling | Dedicated Connection Gateway tier, separate from message processing | Isolates the hardest scaling problem (500M sockets) from business logic; requires a connection-registry lookup on every route |
| Delivery guarantee | At-least-once + client-generated idempotent `msg_id` | Simple, robust to retries; requires dedup logic on write |
| Ordering | Per-conversation monotonic sequence number | Simple and sufficient; not a global total order across all conversations (not needed) |
| Offline delivery | Per-device durable queue + push notification wake-up | Guarantees delivery without keeping sockets open 24/7; adds queue storage and drain-on-reconnect logic |
| Encryption | Signal Protocol (Double Ratchet), client-side only | True E2E privacy; server literally cannot help with content moderation or search — a real, known trade-off worth naming |

## Likely follow-up questions — with answers

**Q: A user's phone is off for three days. What happens to messages sent to them, and what happens when they come back online?**
A: Messages are durably enqueued in the per-device `MessageQueue` at send time (this doesn't depend on the recipient being reachable). Push notifications are best-effort attempts to wake the app but delivery doesn't depend on them succeeding. When the device reconnects, it calls the sync endpoint with its last-known `server_seq` per conversation, and the server drains the queue, delivering everything in order; the device acks each one, which removes it from the durable queue.

**Q: How do you handle a message sent to a group of 500 people efficiently?**
A: Fan-out-on-write: the router resolves the group's member list once and enqueues/dispatches the message to each member's per-device queue or live connection in parallel, rather than each recipient pulling from a shared group log on every poll (fan-out-on-read), because group chat is read far more often than any single group message is sent — the write-amplification cost is worth the read simplicity. For very large "broadcast list" style groups, a hybrid (fan-out to online users immediately, lazy-write for offline) keeps the write burst manageable.

**Q: How would you add server-side search over a user's own message history without breaking end-to-end encryption?**
A: You can't search server-side ciphertext meaningfully, so this has to happen client-side: the device decrypts messages locally and maintains its own local search index (e.g., SQLite FTS) on-device. This is a real, known limitation of E2E-encrypted messaging apps and a good thing to state plainly rather than hand-wave — it demonstrates you understand what E2E encryption actually costs the product.

## Key takeaways

- Connection count (hundreds of millions of persistent sockets) is the primary scaling axis, architecturally separate from message throughput — split the Connection Gateway tier from the Message Router.
- Client-generated idempotent message IDs are what turn unreliable at-least-once delivery into effectively-once observed behavior; this pattern reappears everywhere (payments, notifications).
- Per-conversation sequence numbers are enough for ordering — no need for vector clocks or a global order in a chat app.
- End-to-end encryption (Signal Protocol / Double Ratchet) means the server is a pure relay for ciphertext; be ready to name the real trade-off this creates (no server-side search or content moderation on message text).
- Media bytes flow through object storage + CDN, never through the messaging pipeline itself — only a reference does.

## Today's checklist

- [ ] Define functional requirements: messaging, groups, status
- [ ] Define non-functional requirements: delivery, ordering
- [ ] Design message storage
- [ ] Design end-to-end encryption
- [ ] Handle media storage
- [ ] Discuss message synchronization
