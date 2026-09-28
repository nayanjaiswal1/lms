---
kind: lesson
type: system_design
id_key: interview-prep-45/day-17-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design Google Docs"
position: 11
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

Google Docs lets many people edit the same document at once and see each other's changes appear live. This question tests distributed-systems thinking directly: how do you let several people mutate the same piece of data at the same time, over an unreliable network, and guarantee every device ends up showing the exact same final document, without a central lock freezing everyone else out?

## Requirements

**Functional requirements**
- Multiple users edit the same document at once and see each other's changes live.
- Cursor and selection presence is visible to collaborators.
- Full edit history with undo/redo, attributed to the right person.
- Rich formatting (bold, headings, lists, comments), not just plain text.
- Offline edits sync and merge automatically once connectivity returns.

**Non-functional requirements**
- Edits propagate to other viewers in under 200ms on a good network.
- Every replica must converge to the identical document, no matter the order edits arrive in or how the network delayed them.
- Availability over strict consistency: you should be able to keep typing even while briefly disconnected.
- A document can grow to hundreds of pages; the system must never re-send the whole thing on every keystroke.

> **Remember:** the interview isn't really asking "can you build a text editor," it's asking "do you know how two people's edits, arriving in different orders on different machines, still end up as the same document." That's the whole problem.

```knowledge-check
{ "questions": [
    { "id": "system-design-googledocs-requirements-q1", "type": "mcq", "prompt": "What is the core distributed-systems problem a Google Docs-style design has to solve?", "options": [
        {"id": "a", "text": "How to store text efficiently on disk"},
        {"id": "b", "text": "How every client converges to the same final document even when edits arrive in different orders over an unreliable network"},
        {"id": "c", "text": "How to render bold and italic text in a browser"},
        {"id": "d", "text": "How to authenticate users before they can edit a document"}
    ], "correct": "b", "explanation": "Storage and rendering are solved problems. The genuinely hard part unique to this design is making concurrent, out-of-order edits converge to one consistent result for everyone." }
] }
```

## Estimates

Assume 1 billion total documents, with 5 million editing sessions open concurrently at peak.

- An active session produces roughly one edit every half-second to a second while someone is typing, so system-wide that's on the order of 1-2 million operations/sec at peak. But what actually matters for capacity is per-document load: a single popular shared doc with 50 concurrent editors sees maybe 50-100 ops/sec, which is the number that decides how much one server needs to handle.
- Each edit is tiny, 50-200 bytes (operation type, position, content, revision number), so bandwidth per keystroke is trivial. The hard part is ordering and merging, not bytes on the wire.
- An average document is about 50 KB of content. Storing every historical operation forever for a billion documents is expensive, so history gets compacted into periodic snapshots over time.
- Cursor and presence updates run at roughly 5 million/sec, far higher volume than content edits, but they're ephemeral: losing one doesn't matter, so they run on a separate lightweight channel from the durable edit log.

## API

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

The live editing session runs over a WebSocket. REST only handles the initial document load and browsing history.

## Data model

```
Document(doc_id PK, title, owner_id, created_at, current_revision)
DocSnapshot(doc_id FK, revision, content_blob, created_at)   -- periodic full-state checkpoint
Operation(op_id PK, doc_id FK, revision, client_id, author_id, op_type, payload, applied_at)
DocumentAccess(doc_id FK, user_id FK, role[owner|editor|viewer])
Comment(comment_id PK, doc_id FK, anchor_position, author_id, text, resolved)
```

`Operation` is an append-only log. That single property is what makes undo/redo and version history possible at all: replaying operations from a snapshot up to any revision reconstructs the document exactly as it looked at that point.

## High-level design

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

Every document is owned by exactly one Document Session Server instance at a time; consistent hashing routes every client editing that `doc_id` to the same server. Picture one referee for each document: that single referee decides the order of every edit, so you get one clean point of ordering without needing a distributed consensus vote on every keystroke.

That server holds the live, in-memory state, applies incoming edits in order, resolves concurrent ones, and broadcasts the result to every connected client. The operation log is written to durable storage asynchronously, so a server crash loses at most a few hundred milliseconds of unacknowledged edits, recoverable by replaying from the last saved revision.

## Deep dives

### Operational Transformation vs. CRDTs: know both, pick one, and say why

This is the heart of the interview.

**Operational Transformation (OT).** Each client sends an edit relative to a known base revision. If the server already applied a different edit at that revision, it transforms the incoming edit against whatever happened in between, so it still lands correctly. If someone inserted 5 characters before your cursor position, your insert position shifts by 5 to compensate. This needs a central server to decide the canonical order, which is exactly what Google Docs actually uses. It's mature and fits naturally with a server you already need for other things (auth, presence), but the transform rules are notoriously tricky to get exactly right for every combination of operations.

**CRDT (Conflict-free Replicated Data Type).** The document is represented as a structure where every insert carries a globally unique, order-preserving identifier (client ID plus a logical clock), not just a plain integer position. Merges are commutative by construction, so any order of applying edits from any replica converges to the same state, with no central server required for correctness. This works naturally offline and peer-to-peer, but the per-character metadata can bloat storage, and deleted content needs periodic cleanup.

The answer worth giving out loud: "I'd use OT with a central per-document session server, because I already need a centralized server for presence, access control, and history. Since there's a natural single point of truth per document anyway, OT's server-authoritative model fits. I'd reach for a CRDT if the product needed true offline-first peer-to-peer sync with no guaranteed connection to a central server."

> **Remember:** OT needs a referee (a central server); CRDTs don't need one, but pay for that freedom in extra per-character metadata.

```knowledge-check
{ "questions": [
    { "id": "system-design-googledocs-otcrdt-q1", "type": "mcq", "prompt": "Why does Google Docs use Operational Transformation with a central server rather than a CRDT?", "options": [
        {"id": "a", "text": "CRDTs cannot represent text documents"},
        {"id": "b", "text": "Docs already needs a central server for presence, access control, and history, so OT's server-authoritative model fits naturally without the extra per-character metadata CRDTs require"},
        {"id": "c", "text": "OT is always faster than CRDTs in every scenario"},
        {"id": "d", "text": "CRDTs only work for numeric data, not text"}
    ], "correct": "b", "explanation": "The choice follows from the architecture: since a central point of truth already exists for other reasons, OT's simpler server-authoritative merge model is the better fit than paying CRDT's metadata overhead for a decentralization guarantee that isn't actually needed." }
] }
```

### How does a concrete conflict actually get resolved?

Two users, A and B, both start at revision 10. A inserts "cat" at position 5. B, also based on revision 10, deletes characters 3 through 7. Both edits reach the server. It applies A's insert first (now revision 11), then transforms B's delete against A's insert: since A's 3 new characters landed inside B's delete range, the transform adjusts B's delete range to account for them, producing a delete that removes the originally intended content correctly even though the document shifted underneath it. The transformed operation is applied as revision 12 and broadcast to both clients, so they converge on the same final text.

### How does undo work when other people have kept editing?

A naive undo, just revert the last operation, breaks the moment someone else has edited that same region since. The standard fix is **selective undo**: transform the inverse of your own operation against everything that happened after it, using the same transform logic that resolves concurrent edits, so your undo removes only your own contribution even if the document has moved on. Undo and redo stacks are per-user, never global.

### How is history stored without keeping every keystroke forever?

Take periodic snapshots, say every 500 operations or every few minutes of active editing, and keep the operation log since the last snapshot for replay and undo. Beyond a retention window, older logs get compacted away, keeping only occasional snapshots for long-term version history. Recent history stays fine-grained; old history gets coarser.

## Trade-offs and follow-up questions

| Concern | Choice | Trade-off |
|---|---|---|
| Concurrency model | OT with a single-writer session server per document | Simple correctness story, but needs consistent-hash routing and failover if that server dies |
| Merge algorithm | OT, not CRDT | Matches Google Docs' real architecture; a CRDT would suit offline-first/peer-to-peer better, at the cost of metadata overhead |
| Presence and cursors | Separate ephemeral, in-memory channel | High-frequency, loss-tolerant traffic never touches the durable log |
| History | Operation log plus periodic snapshots, compacted over time | Bounds storage growth while keeping recent undo fine-grained |
| Offline editing | The client buffers edits locally and replays them on reconnect using the same transform logic | Works well for short disconnects; a long offline session risks a large, painful merge |

**Q: The Document Session Server for a popular doc crashes mid-edit. What happens?**
A: Clients detect the dropped connection, reconnect, and consistent hashing routes them to a server instance for that `doc_id`, which rehydrates by loading the latest snapshot and replaying the log since. Any unpersisted edits are gone from the log, but each client resends its own unacknowledged edits after reconnecting, so no user-visible data is lost as long as clients retry.

**Q: How do you scale beyond one server per document when thousands of people are viewing the same doc, like a company all-hands?**
A: Separate the read/broadcast path from the write path. Keep one authoritative writer for ordering, but have it publish accepted edits to a pub/sub layer that many read-only broadcast nodes subscribe to, so thousands of viewer connections aren't all terminating on the one server doing the transform math.

**Q: How would comments fit into this model?**
A: Anchor each comment to a stable position or range in the document, using the same position-transform logic as edits, so the anchor shifts correctly as surrounding text changes. Store comments in a separate table, since they have different lifecycle and permission rules than the document's own content.

```knowledge-check
{ "questions": [
    { "id": "system-design-googledocs-tradeoffs-q1", "type": "mcq", "prompt": "Why does undo need to be a selective, per-user operation instead of simply reverting the last change made to the document?", "options": [
        {"id": "a", "text": "Because undo is never actually needed in a collaborative editor"},
        {"id": "b", "text": "Because another user may have edited the same region since, and blindly reverting the last change could destroy their work"},
        {"id": "c", "text": "Because the document format doesn't support deletion"},
        {"id": "d", "text": "Because undo only works for single-user documents"}
    ], "correct": "b", "explanation": "In a multi-user document, the 'last change' might not even be yours. Selective undo transforms the inverse of your own operation against everything since, so it only removes your contribution." }
] }
```
