---
kind: lesson
type: system_design
id_key: interview-prep-45/day-04-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 4 — Chat Application (WhatsApp style)"
position: 4
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---

## Why interviewers ask this

Chat systems force you to reason about real-time bidirectional connections (not just request/response), message ordering and delivery guarantees, and offline handling — three things most CRUD-style designs never touch. It's one of the best questions for separating candidates who've only built REST APIs from those who understand stateful connection management at scale.

## Requirements

### Functional
- 1-on-1 messaging and group chats.
- Message delivery status: sent, delivered, read (read receipts).
- Offline users receive queued messages when they reconnect.
- Media messages (images, files) alongside text.
- Typing indicators, online/last-seen status (stretch).

### Non-functional
- **Real-time delivery** — sub-second latency for online recipients.
- **Offline support** — messages persist and deliver reliably once the recipient reconnects; nothing is lost.
- Message ordering within a conversation must be consistent for all participants.
- High availability, horizontal scalability to hundreds of millions of concurrent connections (WhatsApp scale).

## Capacity estimates

Assume 500M daily active users, each sending ~40 messages/day.

- **Messages/day:** 500M × 40 = 20B messages/day.
- **Messages/sec average:** 20,000,000,000 / 86,400 ≈ **231,000/sec**; peak (evenings, holidays) 3-5x ≈ ~1M/sec.
- **Concurrent WebSocket connections:** if ~150M users are online at any moment, and one server handles ~50,000-100,000 concurrent connections (typical for a tuned WebSocket server), you need 150,000,000 / 75,000 ≈ **2,000 connection-handling servers**.
- **Storage:** message ~100 bytes (metadata) to a few KB (with small media refs) × 20B/day ≈ 2-4 TB/day of message data — this is why chat systems typically shard message storage aggressively and often move older messages to cold storage.

## API / protocol sketch

```
WebSocket connection: wss://chat.example.com/connect?token={jwt}

Client -> Server (over WS):
  { type: "message", to: conversation_id, client_msg_id, body, media_ref? }
  { type: "typing", conversation_id }
  { type: "read_receipt", conversation_id, up_to_msg_id }

Server -> Client (over WS):
  { type: "message", from, conversation_id, msg_id, body, sent_at }
  { type: "delivery_ack", client_msg_id, server_msg_id }
  { type: "presence", user_id, status: "online" | "offline", last_seen }

REST (for history / non-realtime):
  GET /api/v1/conversations/{id}/messages?before={msg_id}&limit=50
  POST /api/v1/conversations   (create group)
```

## Data model

```
conversations
  id            bigint PK
  type          enum(direct, group)
  created_at    timestamp

conversation_members
  conversation_id  bigint
  user_id          bigint
  joined_at        timestamp
  PRIMARY KEY (conversation_id, user_id)

messages
  id               bigint PK (time-sortable, e.g. Snowflake ID)
  conversation_id  bigint INDEX
  sender_id        bigint
  body             text
  media_ref        varchar NULL
  sent_at          timestamp
  -- partitioned/sharded by conversation_id

message_status
  message_id       bigint
  user_id          bigint  -- recipient
  status           enum(sent, delivered, read)
  updated_at       timestamp
  PRIMARY KEY (message_id, user_id)
```

Use a **Snowflake-style ID** (timestamp bits + shard bits + sequence bits) for `message_id` so IDs are globally unique, roughly time-sortable, and generated without a central coordinator — this directly gives you ordering without needing a separate "sequence number" concept.

## High-level architecture

```
Client A --WS--> Gateway Server A --\
                                     \
Client B --WS--> Gateway Server B ---+--> Message Router / Broker (Kafka, keyed by conversation_id)
                                     /              |
Client C --WS--> Gateway Server C -/                v
                                            Message Persistence Service --> Message DB (sharded by conversation_id)
                                                     |
                                            Presence Service (Redis: user_id -> which gateway server)
                                                     |
                                            Push Notification Service (offline recipients, via APNs/FCM)
```

- Each client holds a persistent **WebSocket connection** to one of many stateless-ish **gateway servers**.
- A **connection registry** (Redis: `user_id -> gateway_server_id`) lets any server know where to route a message for a given recipient — since sender and recipient may be connected to different gateway servers.
- Messages flow: client sends over its WebSocket → gateway server publishes to a **message broker** (Kafka, partitioned by `conversation_id` for ordering) → a persistence worker writes to the DB → the router looks up the recipient's gateway server (via the registry) and pushes the message down their WebSocket if online, or triggers a push notification if offline.

## Component deep dives

### WebSocket connection handling

- Gateway servers are **stateful** (hold live connections) but the routing/business logic behind them is stateless — this is the key architectural distinction from a normal REST service.
- On connect, the server authenticates (JWT), registers `user_id -> server_id` in Redis, and subscribes to that user's inbound message stream.
- On disconnect (including ungraceful — client crash, network drop), a heartbeat/ping-pong mechanism detects staleness and cleans up the registry entry after a timeout.
- Use **sticky sessions are not required** here — because routing goes through the shared registry, a reconnect can land on any gateway server.

### Message ordering and consistency

- Ordering is enforced **per conversation**, not globally — partition the Kafka topic by `conversation_id` so all messages in one conversation are processed by the same partition/consumer in order.
- Client-side: each client tags outgoing messages with a `client_msg_id` for de-duplication (in case of retry) and displays messages sorted by the server-assigned time-sortable `message_id`.
- For groups, "everyone sees the same order" is achieved by the server being the single source of truth for order — clients never locally reorder based on receipt time.

### Message delivery guarantees

Three-state delivery model, same as WhatsApp's checkmarks:
1. **Sent** — server has durably persisted the message (write to DB acknowledged).
2. **Delivered** — recipient's device has received it (their gateway server pushed it down an active WebSocket, or a background sync confirmed receipt).
3. **Read** — recipient's client sent a `read_receipt` event.

Offline delivery: if the recipient isn't connected to any gateway server, the message stays in the DB with status `sent`; a push notification (FCM/APNs) alerts the device; on next app open/reconnect, the client fetches undelivered messages via `GET /conversations/{id}/messages` and the server marks them `delivered` once fetched.

## Scaling & trade-offs

- **At-least-once delivery + client-side dedupe** (via `client_msg_id`) is more practical than trying for exactly-once across a WebSocket that can drop mid-flight.
- **Fan-out for groups:** for large groups, fan-out-on-write (push to every member's queue immediately) works for small/medium groups; extremely large groups (broadcast channels) may switch to fan-out-on-read to avoid write amplification — same trade-off as the social feed problem (Day 9/10).
- **Sharding messages by `conversation_id`** keeps all of one conversation's history co-located for fast pagination, at the cost of potential hot shards for extremely active group chats.
- **End-to-end encryption** (mentioned for completeness): if required, the server only routes opaque encrypted blobs and never sees plaintext — this doesn't change the architecture above, just what's inside the `body` field.

## Likely follow-up questions — with answers

**Q: How do you route a message to a recipient who's connected to a different server than the sender?**
A: A shared presence/connection registry (Redis) maps `user_id -> gateway_server_id`. The sender's server looks up the recipient's server and forwards the message to it (via internal RPC or the message broker), which then pushes it down the recipient's live WebSocket.

**Q: What happens if a user is connected but the push to their WebSocket fails mid-flight?**
A: The message is already durably persisted before any push attempt, so nothing is lost — it just remains in `sent` status. The client's periodic reconnect/sync logic (or a retry from the gateway) will re-attempt delivery, and the client's dedupe on `message_id` prevents duplicates from showing twice.

**Q: How would you scale to support group chats with 100,000+ members (broadcast-style)?**
A: Switch that conversation type to fan-out-on-read: don't write a copy of the message to every member's queue; instead store it once and have each member's client pull recent messages for the channel, similar to how large Slack/Discord channels or Twitter fan-out for celebrity accounts works (see Day 10).

## Key takeaways
- Gateway servers hold stateful WebSocket connections; a shared registry (Redis) decouples "who's connected where" from message routing logic.
- Order is enforced per-conversation via partitioned message brokers, not globally.
- Sent/delivered/read is a three-state model — persistence gives you "sent" durability independent of whether the recipient is online.
- At-least-once delivery plus client-side `client_msg_id` dedupe is the realistic guarantee, not exactly-once.
- Large group broadcasts need fan-out-on-read instead of fan-out-on-write to avoid write amplification.

## Today's checklist
- [ ] Define functional requirements: 1-on-1 chat, groups, read receipts
- [ ] Define non-functional requirements: real-time, offline support
- [ ] Design WebSocket connection handling
- [ ] Design database schema for messages
- [ ] Design message ordering and consistency
- [ ] Handle message delivery guarantees
