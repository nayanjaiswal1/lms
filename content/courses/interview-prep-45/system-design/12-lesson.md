---
kind: lesson
type: system_design
id_key: interview-prep-45/day-12-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 12 — File Storage Service (Dropbox style)"
position: 12
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Dropbox/Google Drive is asked because it forces you to reason about large binary data (not just rows in a DB), chunked/resumable uploads, deduplication, and multi-device sync conflicts — a genuinely different problem shape than CRUD or feed systems. It's also a great test of whether you separate metadata (structured, transactional) from blob storage (large, immutable, content-addressed).

## Requirements

**Functional**
- Upload/download files, organize into folders.
- Sync changes across multiple devices automatically.
- Share files/folders with other users.
- Handle large files via chunked upload with resume support.
- Deduplicate identical file content across users.

**Non-functional**
- Strong-ish consistency on metadata (you shouldn't see a stale folder listing after your own upload completes) but eventual consistency across devices is acceptable (a few seconds of sync lag is fine).
- Durability of stored files: effectively never lose data (target 99.999999999% / "11 nines," matching real object-storage SLAs).
- Availability: uploads/downloads should degrade gracefully, not fail outright, during partial outages.
- Bandwidth efficiency: don't re-upload unchanged bytes.

## Capacity estimates

Assume 50M users, average 5 GB stored each.
- Total logical storage: 50M × 5 GB = 250 PB. With deduplication (many users store the same popular files — OS images, common documents, stock media) realistic *physical* storage is meaningfully less, but plan capacity off the logical number.
- Daily active uploads: assume 10% of users upload something daily, average 10 MB/upload → 5M uploads/day × 10 MB = 50 TB/day of new upload traffic.
- Chunk size: 4 MB is a common choice — large enough to keep per-chunk overhead low, small enough that a failed chunk only costs 4 MB of re-upload, not the whole file.
- Metadata: 50M users × ~10,000 files average = 500B file records. At ~500 bytes/record that's 250 TB of metadata — this alone requires a sharded, horizontally-scaled metadata store, separate from blob storage.

## API sketch

```
POST /files/upload/init        { filename, size, folder_id, chunk_hashes[] }
  -> { upload_id, chunks_needed[] }         -- server tells client which chunks it doesn't already have (dedup)

PUT  /files/upload/{upload_id}/chunk/{chunk_index}   (binary body, with chunk hash header)
  -> { received: true }

POST /files/upload/{upload_id}/complete
  -> { file_id, version }

GET  /files/{file_id}/download                        -> presigned blob URL
GET  /folders/{folder_id}                              -> { files[], folders[] }
POST /files/{file_id}/share    { target_user_id, permission }

-- sync
GET  /sync/changes?since_cursor=                       -> { changes[], next_cursor }
```

## Data model

```
files
  id            UUID PK
  owner_id      UUID
  folder_id     UUID
  name          TEXT
  size          BIGINT
  content_hash  TEXT           -- hash of the full file (post-reassembly), used for dedup
  version       INT
  created_at, updated_at

chunks
  hash          TEXT PK        -- content hash of this chunk (e.g., SHA-256)
  blob_key      TEXT           -- pointer into blob storage (S3 key)
  ref_count     INT            -- how many files reference this chunk, for safe GC
  size          INT

file_chunks
  file_id       UUID
  chunk_index   INT
  chunk_hash    TEXT           -- FK to chunks.hash
  PRIMARY KEY (file_id, chunk_index)

folders
  id, owner_id, parent_id, name

shares
  file_id or folder_id, owner_id, target_user_id, permission (view/edit)
```

Splitting `chunks` (content-addressed, deduplicated, referenced by hash) from `file_chunks` (the ordered list of which chunks make up a given file) is what makes both chunked upload and cross-user dedup work — a chunk is stored once regardless of how many files/users reference it.

## High-level architecture

```
Client --> chunk the file locally, hash each chunk --> Upload API
                                                            |
                                        check chunk hashes against `chunks` table
                                        (skip chunks that already exist — dedup)
                                                            |
                                        upload only missing chunks --> Blob Storage (S3/GCS)
                                                            |
                              on complete: write file_chunks + files metadata (Postgres, sharded)
                                                            |
                                        publish "file_changed" event --> Sync service
                                                                              |
                                              notifies other devices (long-poll / websocket / push)
                                                                              |
                                              other devices pull /sync/changes, download new chunks
```

## Component deep dives

**Chunked upload with resume.** The client splits the file into fixed-size chunks (e.g., 4 MB), hashes each one, and calls `upload/init` with the list of chunk hashes. The server responds with only the chunks it doesn't already have (either from a previous partial upload by this client, or via cross-user dedup — see below). The client uploads just those chunks. If the connection drops mid-upload, on retry the client re-calls `init` and the server again reports only the still-missing chunks — resume is a natural consequence of content-addressing, not a special resume protocol.

**Deduplication.** Because chunks are stored content-addressed (keyed by hash, not by file/owner), two different users uploading the same file (or two files sharing a common chunk, e.g., a template document) physically store that chunk exactly once. `ref_count` on the `chunks` table tracks how many `file_chunks` rows point at it; garbage collection only deletes the underlying blob when `ref_count` hits zero. This is the single biggest storage-cost lever in the whole system — cite the concrete saving in an interview ("popular OS/software installers, common templates, stock assets — dedup can cut physical storage well below the logical total").

**Sync across devices.** Each device maintains a local cursor (a logical clock/version token) representing "the last change I've seen." On reconnect or periodically, it calls `GET /sync/changes?since_cursor=` to pull a delta of what changed since last sync, rather than re-listing the entire file tree. For near-real-time sync, a long-lived connection (WebSocket or long-polling) pushes a lightweight "something changed, go pull" notification so devices don't have to poll aggressively. The actual change data still flows through the pull endpoint — the push channel is just a wake-up signal, keeping the sync protocol simple and resumable.

**Handling sync conflicts.** Two devices edit the same file while offline, then both reconnect. Detect the conflict via version numbers (each device tracks the version it last synced from; if the server's current version has moved past that when a device tries to push its own edit, it's a conflict, not a fast-forward). Resolution: don't silently overwrite — write both versions (`filename.docx` and `filename (conflicted copy from Device B, 2026-07-16).docx`), matching what Dropbox actually does, and let the user manually reconcile. This is the pragmatic answer; true automatic merge only works for structured/mergeable formats (like Google Docs' operational transforms), not arbitrary binary files.

**Metadata storage at scale.** The `files`/`folders` tables are sharded (commonly by `owner_id`, since most queries are "list this user's files/folders") on a horizontally-scalable relational store. This keeps per-user operations (list folder, rename, move) fast and colocated, while cross-user operations (shared folders) require a lookup into the sharing table that can point across shards.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Content-addressed chunking | Free resume + cross-user dedup | Chunk hashing adds client-side CPU cost; garbage collection needs ref-counting correctness |
| Blob storage (S3-style) for bytes, DB for metadata | Each layer scales on its own axis (blob storage scales near-infinitely; metadata DB scales via sharding) | Two systems to keep consistent — a file "exists" only once both metadata and blobs agree |
| Push notification + pull sync | Near-real-time without expensive long-poll-only or aggressive-poll-only trade-offs | Slight complexity of maintaining a lightweight signaling channel alongside the pull API |
| Conflicted-copy resolution | Never silently loses data | Worse UX than true merge; acceptable because true merge isn't generally possible for binary files |

## Likely follow-up questions — with answers

**Q: How do you avoid re-uploading a file that a different user already uploaded?**
A: Chunk hashing plus content-addressed storage — if another user's file happens to share identical chunks (or the whole file matches by content_hash), the `upload/init` response reports those chunks as already present and the client skips uploading them entirely. Storage is physically shared via the `chunks` table's ref-counting; ownership/access is still enforced entirely at the metadata layer (`files`/`shares`), so dedup never leaks one user's content to another — it only avoids storing identical bytes twice.

**Q: What happens if two chunks from different files hash to the same value but aren't actually the same content (hash collision)?**
A: Use a cryptographically strong hash (SHA-256) where collision probability is astronomically low — low enough that essentially every production system treats hash equality as content equality. If paranoia is required (e.g., regulatory), add a cheap secondary check (byte-length match, or a second independent hash) before treating chunks as identical, but in practice SHA-256 alone is the industry-standard answer.

**Q: How do you delete a file's storage without breaking other files that share its chunks via dedup?**
A: Deleting a file removes its `file_chunks` rows and decrements `ref_count` on each referenced chunk in the `chunks` table. The underlying blob is only queued for garbage collection when `ref_count` reaches zero — meaning no other file still depends on that chunk. This is exactly why ref-counting (not just storing the file id) is required for safe dedup-aware deletion.

## Key takeaways

- Split metadata (structured, sharded relational DB) from blob storage (large, immutable, content-addressed object store) — they scale on different axes and should never be the same system.
- Content-addressed chunking gives you resumable uploads and cross-user deduplication as a natural side effect, not as separate features to build.
- Ref-counting on chunks is mandatory for safe garbage collection once you have dedup — never delete a blob just because one file stopped referencing it.
- Sync is a pull-based delta protocol (cursor-based `/sync/changes`) with a lightweight push channel as a wake-up signal, not a full-state push on every change.
- Conflicting concurrent edits to binary files are resolved by writing a conflicted copy, not silent overwrite or automatic merge — merge only works for structured, mergeable formats.
- Shard metadata by owner_id for cheap per-user file/folder operations; cross-user sharing is a separate lookup layer on top.

## Today's checklist

- [ ] Write functional requirements: upload, download, sync.
- [ ] Write non-functional requirements: consistency, deduplication, durability target.
- [ ] Design the file storage architecture (metadata DB vs blob store split).
- [ ] Design chunked upload with resume for large files.
- [ ] Handle sync conflicts between devices.
- [ ] Discuss metadata storage sharding at scale.
