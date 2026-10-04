---
kind: lesson
type: system_design
id_key: interview-prep-45/day-12-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a File Storage Service (Dropbox)"
position: 10
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

Dropbox, or Google Drive, lets you upload files, sync them across devices, and share them with others. This is a genuinely different problem shape from a CRUD app or a feed: you're moving large binary data, not just database rows, and you need chunked uploads that can resume, deduplication, and a plan for when two devices edit the same file at once.

## Requirements

**Functional requirements**
- Upload and download files, organized into folders.
- Sync changes across multiple devices automatically.
- Share files and folders with other users.
- Handle large files with chunked, resumable uploads.
- Deduplicate identical file content across users.

**Non-functional requirements**
- Metadata needs fairly strong consistency: you shouldn't see a stale folder listing right after your own upload finishes. Syncing across devices can lag by a few seconds, that's fine.
- Durability: essentially never lose a file, matching the "eleven nines" real object storage services target.
- Availability: uploads and downloads should degrade gracefully during a partial outage, not fail outright.
- Bandwidth efficiency: never re-upload bytes that haven't changed.

> **Remember:** this design only works because it separates two very different problems: structured, transactional metadata (which folder a file is in) from large, immutable binary blobs (the file's actual bytes). Mixing them into one store is the mistake to avoid.

```knowledge-check
{ "questions": [
    { "id": "system-design-filestorage-requirements-q1", "type": "mcq", "prompt": "Why is it a mistake to store a file's raw bytes in the same database as its metadata (name, folder, owner)?", "options": [
        {"id": "a", "text": "It's not a mistake, this is the standard approach"},
        {"id": "b", "text": "Metadata and blob storage scale along completely different axes, and mixing them prevents each from scaling on its own"},
        {"id": "c", "text": "Databases cannot store binary data at all"},
        {"id": "d", "text": "It would make folder listing impossible"}
    ], "correct": "b", "explanation": "Metadata needs fast transactional queries at moderate size; blob bytes need to scale to petabytes with completely different access patterns. Separating them lets each scale independently." }
] }
```

## Estimates

Assume 50 million users, averaging 5 GB stored each.

- **Total logical storage:** 50M × 5 GB = 250 petabytes. Deduplication (many users storing the same popular files, OS images, common documents) brings the real physical number down meaningfully, but plan capacity off the logical total.
- **Daily upload traffic:** if 10% of users upload something daily, averaging 10 MB each, that's 5 million uploads/day × 10 MB = 50 TB/day of new traffic.
- **Chunk size:** 4 MB is a common choice: large enough that per-chunk overhead stays low, small enough that a failed chunk only costs 4 MB of re-upload, not the whole file.
- **Metadata:** 50M users × roughly 10,000 files each = 500 billion file records. At about 500 bytes per record, that's 250 TB of metadata alone, which needs its own sharded, horizontally scaled store, separate from where the bytes live.

## API

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

Splitting `chunks` (content-addressed, one row per unique piece of data, keyed by its own hash) from `file_chunks` (the ordered list of which chunks make up one specific file) is the one decision that makes both resumable upload and cross-user dedup work. A chunk is stored once, no matter how many files or users point at it.

```knowledge-check
{ "questions": [
    { "id": "system-design-filestorage-datamodel-q1", "type": "mcq", "prompt": "What does splitting chunks (content-addressed) from file_chunks (per-file ordering) enable?", "options": [
        {"id": "a", "text": "It's only for organizational neatness, with no functional benefit"},
        {"id": "b", "text": "It lets identical bytes be stored exactly once across every file and every user, while still tracking each file's own chunk order"},
        {"id": "c", "text": "It makes uploads slower but more secure"},
        {"id": "d", "text": "It removes the need for a folders table"}
    ], "correct": "b", "explanation": "Because a chunk is keyed by its content hash rather than by which file it belongs to, two files (or two users) that happen to share the same bytes automatically share one stored chunk." }
] }
```

## High-level design

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

## Deep dives

### How does resumable upload work, and why does it come almost for free?

The client splits the file into fixed-size chunks, hashes each one locally, and sends the list of hashes to `upload/init`. The server checks each hash against the `chunks` table and responds with only the ones it doesn't already have, whether from an earlier partial upload by this same client, or from another user entirely (cross-user dedup, covered next). The client uploads just those missing chunks.

If the connection drops halfway through, the client simply calls `init` again on retry, and the server reports whatever chunks are still missing. Resume isn't a special protocol bolted on top, it falls naturally out of content-addressing: the server already knows exactly what it has and doesn't.

### How does deduplication actually save storage?

Because chunks are stored by content hash rather than by owner or file, two different users uploading the same file, or two files sharing a common chunk like a document template, physically store that chunk exactly once. `ref_count` on the `chunks` table tracks how many `file_chunks` rows point at it, and garbage collection only deletes the underlying blob once that count hits zero. This is the single biggest storage-cost lever in the whole system: popular installers, templates, and stock assets let real physical storage land well below the logical total.

> **Remember:** dedup only saves storage; it never changes who can access a file. Ownership and permissions live entirely in the metadata layer (`files`/`shares`), so sharing a chunk's bytes never leaks another user's content.

```knowledge-check
{ "questions": [
    { "id": "system-design-filestorage-dedup-q1", "type": "mcq", "prompt": "If two different users upload the exact same file, does deduplication let User A see or access User B's copy?", "options": [
        {"id": "a", "text": "Yes, dedup merges their files into one shared file"},
        {"id": "b", "text": "No, only the underlying bytes are shared in blob storage. Access and ownership are enforced separately in the metadata layer"},
        {"id": "c", "text": "Yes, but only if both users are in the same folder"},
        {"id": "d", "text": "Deduplication is disabled whenever two different users are involved"}
    ], "correct": "b", "explanation": "Dedup operates purely at the storage layer to avoid keeping duplicate bytes. Each user still has their own files row, folder placement, and permissions, completely independent of who else's bytes happen to be identical." }
] }
```

### How does sync across devices, and conflict handling, work?

Each device keeps a local cursor, a token representing "the last change I've seen." On reconnect, or periodically, it calls `GET /sync/changes?since_cursor=` to pull only what changed since then, instead of re-listing the entire file tree. For near-real-time sync, a lightweight WebSocket or long-poll connection pushes a "something changed, go pull" signal, so devices don't have to poll aggressively; the actual change data still flows through the pull endpoint, keeping the protocol simple and resumable.

Conflicts happen when two devices edit the same file while offline and then both reconnect. Detect this with version numbers: each device remembers the version it last synced from, and if the server's current version has moved past that when the device tries to push its own edit, that's a real conflict, not a simple fast-forward. Don't silently overwrite one edit with the other. Write both: `filename.docx` and `filename (conflicted copy from Device B, 2026-07-16).docx`, exactly what Dropbox actually does, and let the person reconcile manually. True automatic merging only works for structured, mergeable formats (like a Google Docs-style editor), not arbitrary binary files.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Content-addressed chunking | Resume and cross-user dedup come for free | Client-side hashing cost; garbage collection needs correct ref-counting |
| Blob storage for bytes, database for metadata | Each layer scales on its own axis | Two systems to keep consistent: a file only "exists" once both agree |
| Push notification plus pull sync | Near-real-time without constant polling | A little extra complexity running a signaling channel alongside the pull API |
| Conflicted-copy resolution | Never silently loses data | Worse UX than a true merge, acceptable since true merge isn't possible for arbitrary binary files |

**Q: How do you avoid re-uploading a file that a different user already uploaded?**
A: Chunk hashing plus content-addressed storage. If another user's file shares identical chunks, or the whole file matches by `content_hash`, `upload/init` reports those chunks as already present and the client skips uploading them. Storage is physically shared through `ref_count`; access is still enforced entirely at the metadata layer, so dedup never leaks content between users.

**Q: What if two different chunks hash to the same value but aren't actually identical?**
A: Use a cryptographically strong hash like SHA-256, where a collision is astronomically unlikely, unlikely enough that essentially every production system treats a hash match as a content match. If extra caution is required, add a cheap secondary check like byte-length comparison before treating two chunks as identical.

**Q: How do you delete a file without breaking other files that share its chunks through dedup?**
A: Deleting a file removes its `file_chunks` rows and decrements `ref_count` on each chunk it referenced. The underlying blob is only queued for garbage collection once `ref_count` reaches zero, meaning no other file still needs it. That's exactly why ref-counting, not just tracking a file ID, is required for safe dedup-aware deletion.

```knowledge-check
{ "questions": [
    { "id": "system-design-filestorage-tradeoffs-q1", "type": "mcq", "prompt": "Why does deleting a file only decrement a chunk's ref_count instead of deleting the chunk's bytes immediately?", "options": [
        {"id": "a", "text": "Because deletes are processed asynchronously for performance reasons only"},
        {"id": "b", "text": "Because other files might still reference that same chunk through dedup, and deleting it immediately would corrupt them"},
        {"id": "c", "text": "Because blob storage does not support deletion"},
        {"id": "d", "text": "Ref counting is unnecessary and only adds complexity"}
    ], "correct": "b", "explanation": "A chunk can be shared by many files across many users. Only when ref_count reaches zero is it safe to know no one else still depends on those bytes." }
] }
```
