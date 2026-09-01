---
kind: lesson
type: system_design
id_key: interview-prep-45/day-17-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Google Docs"
position: 17
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Real-time collaborative editing is the design question that most directly tests distributed-systems theory: how do you let N people mutate the same document concurrently, on unreliable networks, and have every replica converge to the same final state without a central lock? Interviewers use this to see whether you understand OT vs. CRDT trade-offs, not just "use a database."

## Requirements

**Functional**
- Multiple users open and edit the same document simultaneously, seeing each other's changes live.
- Cursor/selection presence is visible to collaborators.
- Full edit history with undo/redo, per-user attribution.
- Documents support rich formatting (bold, headings, lists, comments), not just plain text.
- Offline edits sync and merge when connectivity returns.

**Non-functional**
- Low-latency propagation of edits to other viewers (sub-200ms on good networks).
- Eventual consistency across all replicas: every client must converge to the identical document state regardless of edit order/network timing.
- Availability over strict consistency: a user should be able to keep typing even if temporarily disconnected.
- Document size can grow large (hundreds of pages); the system must not re-transmit the whole document on every keystroke.

## Capacity estimates

1B total documents, 5M concurrently open editing sessions at peak.

An average active editing session generates ~1 keystroke/edit-op every ~0.5-1s while typing, so 5M sessions × ~1.5 ops/sec (accounting for idle time) ≈ **~1-2M ops/sec system-wide at peak**. But it's concentrated per-document: a single popular shared doc with 50 concurrent editors sees maybe 50-100 ops/sec, which is the number that actually matters for per-document server capacity.

Each edit op is tiny (~50-200 bytes: op type, position, content delta, revision number), so the wire cost of a keystroke is trivial. The hard part is ordering and merging, not bandwidth.

Document storage: average doc ≈ 50 KB of content plus operation history. Storing every historical op forever for 1B docs is expensive, so history is periodically compacted into snapshots (e.g., keep full op log for 30 days, then collapse to periodic snapshots).

Presence/cursor updates: 5M sessions × 1 cursor update/sec ≈ 5M/sec, much higher volume than content edits, and it's ephemeral (doesn't need durability), so it's handled on a separate lightweight channel from the document operation log.

## API sketch

```
WS  /v1/docs/{doc_id}/session          # persistent connection for the editing session
  client -> server: { op: {type, pos, content}, base_revision, client_id }
  server -> client: { op, revision, author_id }    # broadcast to all connected clients
  client -> server: { type: "cursor", pos, selection }
  server -> client: { type: "presence", user_id, cursor }

GET  /v1/docs/{doc_id}                 # fetch latest snapshot + revision number
GET  /v1/docs/{doc_id}/history         # revision list for undo/redo and version browsing
POST /v1/docs/{doc_id}/restore
  body: { revision }
```

The editing session itself is WebSocket-based; REST is only used for initial load and history browsing.

## Data model

```
Document(doc_id PK, title, owner_id, created_at, current_revision)
DocSnapshot(doc_id FK, revision, content_blob, created_at)   -- periodic full-state checkpoint
Operation(op_id PK, doc_id FK, revision, client_id, author_id, op_type, payload, applied_at)
DocumentAccess(doc_id FK, user_id FK, role[owner|editor|viewer])
Comment(comment_id PK, doc_id FK, anchor_position, author_id, text, resolved)
```

`Operation` is an append-only log. This is what makes undo/redo and version history possible: replaying operations from a snapshot up to a given revision reconstructs any past state.

## High-level architecture

```
[Client A] <---WS---+                    +---WS---> [Client B]
                     |                    |
              [Document Session Server]  (owns in-memory state
               for this doc_id, single    for one doc, or shard
               writer per document)       of docs)
                     |
              [Operation Transform / CRDT engine]
                     |
              [Operation Log] ---async---> [Snapshot Service]
                     |                          |
              [Presence/Cursor broadcast]  [Document Store: blob storage
               (ephemeral, in-memory)       for snapshots + metadata DB]
```

Each document is owned by exactly one **Document Session Server** instance at a time (consistent hashing routes all clients editing `doc_id` to the same server). This gives you a single point of ordering for that document without needing a distributed consensus protocol per keystroke.

That server holds the authoritative in-memory operational state, applies incoming ops in order, transforms/merges concurrent ops, and broadcasts the resulting op to all connected clients.

The operation log is persisted asynchronously (write-behind) so a server crash loses at most a few hundred milliseconds of unacknowledged ops, recoverable by replaying from the last durable revision.

## Component deep dives

### Operational Transformation (OT) vs. CRDT

This is the core of the interview. Know both and be ready to argue for one.

**Operational Transformation:** each client sends ops relative to a known base revision. When the server (or another client) has already applied a different op at that revision, it transforms the incoming op against the intervening ops so it applies correctly to the current state (e.g., if someone inserted 5 characters before your cursor position, your insert position shifts by 5). This requires a central server to serialize and broadcast the canonical order, which is what Google Docs actually uses. Pros: mature, works well with a central server you already need for other reasons (auth, presence). Cons: the transform functions are notoriously tricky to get correct for all op-type combinations (insert/insert, insert/delete, delete/delete), and it's easy to introduce subtle divergence bugs.

**CRDT (Conflict-free Replicated Data Type):** represent the document as a data structure (e.g., a sequence CRDT like RGA or Logoot) where every insert gets a globally unique, order-preserving identifier derived from client ID plus logical clock, not just an integer position. Merges are commutative and associative by construction, so any order of applying ops from any replica converges to the same state, with no central server required for correctness (though you still want one for network efficiency/presence). Pros: works naturally offline and peer-to-peer, no central bottleneck for merge logic. Cons: metadata overhead per character/element can bloat storage, and tombstones for deleted content need periodic garbage collection.

**Answer to give in an interview:** "I'd use OT with a central per-document session server, because we already need centralized presence, access control, and history. Since we have a natural single point of truth per document anyway, OT's simpler server-authoritative model is a good fit. I'd reach for a CRDT if the product needed true offline-first peer-to-peer sync without guaranteed connectivity to a central server."

### Conflict resolution walkthrough

Two users, A and B, both start at revision 10. A inserts "cat" at position 5. B, also based on revision 10, deletes characters 3-7. Both ops arrive at the server. The server applies A's op first (now revision 11), then must transform B's delete against A's insert: since A inserted 3 characters at position 5, which falls inside B's delete range, the transform adjusts B's delete range to account for the new characters, producing a delete that removes the intended original content plus correctly handles the newly inserted overlap (the specific rule set is what OT libraries encode). The transformed op is applied, revision 12, and broadcast to both clients so they converge.

### Undo/redo

Naive undo (revert the last op) breaks in a multi-user context. If you undo your last insert but someone else has since edited that region, a blind revert corrupts their work. The standard approach is **selective undo**: transform the inverse of your own op against every op that happened after it, the same way OT transforms concurrent ops, so undo only removes your specific contribution even if the document has moved on. Undo/redo stacks are per-user, not global.

### Storage strategy

Don't store every keystroke forever as the primary read path. Take periodic snapshots (e.g., every 500 ops or every few minutes of active editing) and keep the op log since the last snapshot for replay/undo. Older op logs beyond a retention window (e.g., 30-90 days) get compacted away, keeping only daily/weekly snapshots for long-term version history: full granularity for recent history, coarse granularity for old history.

## Scaling & trade-offs

| Concern | Choice | Trade-off |
|---|---|---|
| Concurrency model | OT with single-writer session server per document | Simple correctness story per doc; requires consistent-hash routing and failover handling if that server dies |
| Merge algorithm | OT (not CRDT) | Matches Google Docs' actual architecture; CRDT would be better for offline-first/P2P but adds metadata overhead |
| Presence/cursors | Separate ephemeral, in-memory channel | High-frequency, loss-tolerant traffic never touches the durable op log |
| History | Op log + periodic snapshots, compacted over time | Bounds storage growth while preserving recent fine-grained undo and long-term coarse version history |
| Offline editing | Client buffers ops locally, replays against server on reconnect using the same transform logic | Works well for short disconnects; long offline sessions risk large, painful merges |

## Likely follow-up questions — with answers

**Q: What happens if the Document Session Server for a popular doc crashes mid-edit?**
A: Clients detect the dropped WebSocket, reconnect, and consistent hashing routes them to a (possibly new) server instance for that `doc_id`. That server rehydrates its in-memory state by loading the latest snapshot and replaying the op log since. Any ops the old server hadn't yet durably persisted are lost from the log, but each client can resend its own unacknowledged ops after reconnecting (they buffer locally until ack'd), so no user-visible data loss occurs as long as clients retry unacknowledged ops.

**Q: How do you scale beyond one server per document if a single doc has thousands of simultaneous viewers (e.g., a company all-hands doc)?**
A: Separate the read/broadcast fan-out from the write path: keep a single authoritative writer for ordering, but have it publish accepted ops to a pub/sub layer (e.g., Redis pub/sub or a fan-out service) that many read-only broadcast nodes subscribe to, so thousands of viewer connections don't all terminate on the one server doing the OT math.

**Q: How would comments and suggestions ("Suggesting mode") fit into this model?**
A: Model comments as anchored to a stable position/range in the document (using the same position-transform logic as edits, so a comment anchor shifts correctly when text before it is inserted/deleted) and store them in a separate table rather than as part of the document content stream. They have different lifecycle and permission rules (resolve/reply) than the document text itself.
