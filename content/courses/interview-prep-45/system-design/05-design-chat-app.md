---
kind: lesson
type: system_design
id_key: interview-prep-45/day-04-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Chat App (WhatsApp)"
position: 5
estimated_minutes: 75
source:
    - 45-day-interview-roadmap.md
---

A chat app like WhatsApp lets two people, or a group, send messages that arrive in real time when everyone's online and wait patiently when they're not. This is one of the best interview questions for separating candidates who've only built request/response APIs from those who understand a live, stateful connection at scale: it forces you to reason about persistent connections, message ordering, and what happens when a phone is switched off for three days.

## Requirements

**Functional requirements**
- One-on-one and group messaging.
- Message delivery status: sent, delivered, read (the WhatsApp checkmarks).
- Offline users receive queued messages the moment they reconnect.
- Media messages (photos, video, voice notes) alongside text.
- Messages are end-to-end encrypted: the server never sees plaintext.
- Typing indicators and online/last-seen presence.
- A message sent from a phone should also show up on a linked desktop client (multi-device).

**Non-functional requirements**
- Real-time delivery: sub-second latency for anyone currently online.
- Offline support: a message persists and delivers reliably no matter how long the recipient stays offline, even days.
- Message ordering within one conversation must look the same to every participant.
- Massive connection scale: hundreds of millions of devices holding a connection open at once.

> **Remember:** the hardest number in this design is not messages per second, it's connections held open at once. That's what makes a chat system architecturally different from a normal REST API.

```knowledge-check
{ "questions": [
    { "id": "system-design-chat-requirements-q1", "type": "mcq", "prompt": "What makes a chat system's scaling problem fundamentally different from a typical REST API's?", "options": [
        {"id": "a", "text": "Chat messages are larger than typical API payloads"},
        {"id": "b", "text": "It must hold hundreds of millions of persistent connections open at once, not just handle a burst of short-lived requests"},
        {"id": "c", "text": "Chat systems never need a database"},
        {"id": "d", "text": "REST APIs cannot use WebSockets"}
    ], "correct": "b", "explanation": "A REST API serves a request and moves on. A chat system has to keep a live connection open for every online user, which is a fundamentally different infrastructure problem than request throughput." }
] }
```

## Estimates

Assume 2 billion monthly active users, with about 500 million connected at any given peak moment.

- **Messages/sec:** at roughly 40 messages/user/day, 2B × 40 / 86,400 ≈ 900,000 messages/sec on average, several times higher during a real-world spike like New Year's Eve.
- **Message size:** a text message is small, around 1 KB including metadata and encryption overhead, so 900,000/sec × 1 KB ≈ 900 MB/sec. Trivial for the actual message pipeline.
- **Media:** roughly 5% of messages carry a photo or voice note, averaging 200 KB to 2 MB each. This is the real bandwidth driver, and it's handled by uploading straight to object storage and sending only a reference through the messaging pipeline, never the raw bytes.
- **Connections:** 500 million concurrent long-lived connections is the standout number. At around 10,000-40,000 connections per commodity server, that's tens of thousands of servers just to hold sockets open, architected completely separately from message processing.

Lead with the connection count, not the message volume, when you present your numbers. It's the constraint that actually shapes this design.

## API

Chat is push/pull over a persistent connection more than classic request/response, but the shape looks like this:

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

The client generates its own `msg_id` before the first send attempt. That one detail is what turns "the network might deliver this twice" into "the user never sees a duplicate": if a send is retried after a dropped acknowledgment, the server recognizes the same `msg_id` and treats it as a no-op.

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

The key detail: `Message.ciphertext` is opaque to the server. Encryption happens client-to-client, so the schema stores unreadable blobs, and the server's whole job is store-and-forward routing plus retention, never reading content.

## High-level design

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

Picture the **Connection Gateway tier** as a giant switchboard: a huge, horizontally scaled fleet whose only job is holding sockets open and knowing which node holds which user's connection, tracked in a shared registry (a distributed cache). The **Message Router** looks up the recipient. Online, it forwards straight to the gateway node holding that socket. Offline, it writes to a durable per-device queue and fires a push notification to wake the app, which reconnects and syncs later. Media bytes never touch this hot path, only a reference does, the same pattern Netflix uses for video and Airbnb uses for photos: bytes go through object storage and a CDN, never the transactional pipeline.

## Deep dives

### How does ordering work without a global clock?

Each message gets a `server_seq`, a number that only increases, scoped to one conversation, assigned by the router at write time. Clients use this to spot gaps: "I have 100 and 102, where's 101?" and request a resync. A simple per-conversation counter is enough; you don't need vector clocks or a global clock for a chat app.

### How do you turn at-least-once delivery into something that feels like exactly-once?

The client keeps retrying a send until it gets a server acknowledgment. Those retries are safe because the client attaches its own `msg_id`, a UUID generated before the very first attempt. The server's write is an upsert (`INSERT ... ON CONFLICT (msg_id) DO NOTHING`), so a retried send that already succeeded is simply a no-op instead of a duplicate message. Memorize this pattern: it reappears almost unchanged in payment idempotency and in notification systems.

> **Remember:** the network can duplicate a message, but a client-generated ID plus an upsert on the server makes the duplicate invisible to the user.

```knowledge-check
{ "questions": [
    { "id": "system-design-chat-idempotency-q1", "type": "mcq", "prompt": "How does a chat system avoid showing a duplicate message when a client retries a send after a dropped acknowledgment?", "options": [
        {"id": "a", "text": "It doesn't, duplicates are an accepted cost of the design"},
        {"id": "b", "text": "The client attaches a UUID it generated before the first attempt, and the server upserts on that ID so a retry becomes a no-op"},
        {"id": "c", "text": "The server waits several seconds before accepting any message to avoid duplicates"},
        {"id": "d", "text": "Duplicates are only possible on the recipient's device, never the server"}
    ], "correct": "b", "explanation": "A client-generated idempotency key checked with an upsert is what turns unreliable at-least-once delivery into a duplicate-free experience for the user." }
] }
```

### How does end-to-end encryption change the design?

The server must never see plaintext, so it becomes purely a relay. The real-world standard is the **Signal Protocol**, using something called the Double Ratchet algorithm: each pair of devices sets up a shared secret through a key exchange when the conversation starts, and every message afterward advances a "ratchet" that derives a fresh key. Compromising one message's key doesn't expose past or future messages. For groups, each member either gets their own encrypted copy of the key, or the system uses a more advanced scheme to avoid encrypting the same message once per recipient in large groups.

Media follows the same idea: the sender uploads to object storage, often encrypting client-side first, so the storage layer never sees plaintext media either. The message itself carries only a reference plus a decryption key, both wrapped inside the encrypted message payload.

### How does a message reach every registered device for one person?

Multi-device support means a message has to reach every device linked to an account, not just one. Model delivery per-device, not per-user: the message queue and delivery/read receipts are tracked by `device_id`. When someone links a new device, it does a bounded history sync rather than replaying every message ever sent.

### How do you handle a message to a 500-person group?

Fan-out-on-write: the router resolves the group's member list once and dispatches the message to each member's queue or live connection in parallel. Group chats are read far more often than any single message is sent, so the extra write work is worth the simpler read path. For very large broadcast-style groups, a hybrid works better: fan out immediately to online members, and write lazily for offline ones, to keep the write burst manageable.

## Trade-offs and follow-up questions

| Concern | Choice | Trade-off |
|---|---|---|
| Connection handling | A dedicated Connection Gateway tier, separate from message processing | Isolates the hardest scaling problem (500M sockets) from business logic, at the cost of a registry lookup on every route |
| Delivery guarantee | At-least-once plus a client-generated idempotent `msg_id` | Simple and reliable, needs dedup logic on write |
| Ordering | A per-conversation monotonic sequence number | Simple and sufficient, not a global order across all conversations, which isn't needed anyway |
| Offline delivery | A per-device durable queue plus a push notification to wake the app | Guarantees delivery without keeping every socket open 24/7 |
| Encryption | Signal Protocol (Double Ratchet), client-side only | True end-to-end privacy, but the server genuinely cannot help with search or moderation on message content |

**Q: A user's phone is off for three days. What happens to messages sent to them?**
A: They sit in that user's per-device durable queue, written at send time regardless of whether the recipient is reachable. Push notifications are a best-effort attempt to wake the app, not a delivery mechanism the system depends on. When the device reconnects, it syncs from its last known sequence number, and the server drains the queue in order.

**Q: How do you handle a message to a very large group efficiently?**
A: Fan-out-on-write for normal groups, since reads vastly outnumber writes. For huge broadcast-style groups, mix in a fan-out-on-read style approach for offline members, the same hybrid idea used for celebrity accounts in a social feed.

**Q: How would you add server-side search over someone's messages without breaking end-to-end encryption?**
A: You can't, not meaningfully. The server only ever sees ciphertext. Search has to happen client-side: the device decrypts messages locally and keeps its own on-device search index. This is a real, known cost of end-to-end encryption, worth stating plainly rather than glossing over.

```knowledge-check
{ "questions": [
    { "id": "system-design-chat-tradeoffs-q1", "type": "mcq", "prompt": "Why can't a WhatsApp-style server offer full-text search across a user's message history?", "options": [
        {"id": "a", "text": "Full-text search is technically impossible at any scale"},
        {"id": "b", "text": "The server only ever sees encrypted ciphertext, so it cannot index or search message content"},
        {"id": "c", "text": "Search would violate message ordering guarantees"},
        {"id": "d", "text": "Users don't want search in a chat app"}
    ], "correct": "b", "explanation": "End-to-end encryption means the server never has plaintext to index. Any search has to happen on the device, where the content is actually decrypted." }
] }
```
