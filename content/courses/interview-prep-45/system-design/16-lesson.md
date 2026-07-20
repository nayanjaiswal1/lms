---
kind: lesson
type: system_design
id_key: interview-prep-45/day-16-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Day 16 — Design Spotify"
position: 16
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
A music-streaming design interview tests a different muscle than ride-hailing: it's dominated by **large immutable binary content** (audio files) served at massive read fan-out, plus a recommendation pipeline that runs asynchronously and never blocks the listening experience. The interesting decisions are all about CDN strategy, adaptive bitrate delivery, and how offline/online state reconciles — not about coordinating concurrent writers.

## Requirements

**Functional**
- Users search for and stream tracks, albums, and podcasts.
- Users create, edit, and share playlists.
- App recommends tracks/playlists based on listening history.
- Users can download tracks for offline playback (subscription feature).
- Artists/labels upload and manage catalog metadata and audio files.

**Non-functional**
- Low startup latency: audio should start playing within ~200ms of pressing play.
- High availability: streaming must degrade gracefully (lower bitrate) rather than fail outright on poor networks.
- Massive read-heavy fan-out: a handful of popular tracks account for a disproportionate share of daily streams (long-tail catalog, hot-head traffic).
- Licensing constraints: some tracks are region-restricted or must be pulled from the catalog quickly.
- Consistent playlist state across a user's devices (phone, desktop, web) with reasonable sync latency (a few seconds is fine).

## Capacity estimates

- 500M monthly active users, ~200M daily active, average 1 hour of listening/day.
- Average track ≈ 3.5 minutes → ~17 track-plays per user per day → 200M × 17 ≈ **3.4B track starts/day** → ~40,000 track starts/sec average, several times that at evening peak.
- Audio file size: a 3.5-minute track encoded at 128kbps ≈ 3.5 × 60 × 128 kbit / 8 ≈ 3.4 MB per quality tier; store 3 tiers (e.g., 96/160/320 kbps) ≈ ~10 MB per track across tiers.
- Catalog size: 100M tracks × ~10 MB (all tiers) = **1 PB of audio storage** — this is why virtually all of it sits in object storage (S3/GCS) behind a CDN, never served directly from app servers.
- Streaming bandwidth: 200M DAU × 1 hour/day × ~1 Mbps average stream rate ≈ enormous aggregate bandwidth — almost entirely absorbed by CDN edge caches, since a small fraction of tracks (the "hot" catalog) accounts for the majority of plays (classic Zipfian distribution).
- Metadata (track/album/artist/playlist rows) is comparatively tiny — tens of millions of rows, fits comfortably in a normal relational/document database with caching.

The number to lead with in an interview: **this system is CDN-bound, not database-bound.** The core engineering problem is getting bytes to listeners cheaply and fast, not transaction throughput.

## API sketch

```
GET  /v1/search?q=...&type=track,album,artist
GET  /v1/tracks/{track_id}
GET  /v1/tracks/{track_id}/stream?quality=high
  resp: 302 redirect to a signed CDN URL, or an HLS/DASH manifest

POST /v1/playlists
  body: { name, description }
PUT  /v1/playlists/{playlist_id}/tracks
  body: { track_id, position }
GET  /v1/playlists/{playlist_id}

GET  /v1/users/{user_id}/recommendations
POST /v1/playback-events
  body: { track_id, event: "play"|"skip"|"complete", position_ms, device_id }

POST /v1/tracks/{track_id}/download   # returns an encrypted offline bundle + license
```

Playback events are fire-and-forget, sent to an async ingestion pipeline (not the synchronous request path) — they feed both recommendations and royalty accounting.

## Data model

```
Track(track_id PK, title, artist_id, album_id, duration_ms, isrc, explicit, available_regions[])
Artist(artist_id PK, name, bio)
Album(album_id PK, title, artist_id, release_date)
AudioAsset(track_id FK, quality_tier, storage_url, codec, bitrate)
Playlist(playlist_id PK, owner_id, name, is_public, updated_at)
PlaylistTrack(playlist_id FK, track_id FK, position, added_at)
User(user_id PK, plan[free|premium], region)
PlaybackEvent(event_id PK, user_id, track_id, event_type, position_ms, ts)  -- append-only, streamed to analytics
UserTasteProfile(user_id PK, embedding_vector, updated_at)  -- derived, rebuilt offline
```

`AudioAsset` is separated from `Track` because a track has multiple encoded variants (bitrates/codecs) and the actual bytes live in object storage — the DB row only holds the pointer (URL/key), never the audio itself.

## High-level architecture

```
[Client: mobile/desktop/web]
        |
   [API Gateway]
        |
  +-----+-----------------+------------------+
  |                       |                  |
[Catalog/Search      [Playback/Streaming  [Playlist Service]
 Service]              Service]                 |
  |                       |                 [Metadata DB]
[Search Index          issues signed URL /
 (Elasticsearch)]       manifest, doesn't
  |                      proxy audio bytes
[Metadata DB]                 |
                        [CDN edge cache] <---- [Object Storage: S3/GCS, origin]
                               ^
                               |
                     actual audio bytes served
                     directly from edge to client

[Playback Events] --async--> [Event Queue (Kafka)] --> [Recommendation Pipeline]
                                                    --> [Royalty/Analytics Pipeline]
```

- **Playback Service** never proxies audio through app servers — it authenticates the request, checks licensing/region/subscription, and returns a signed, time-limited CDN URL (or an HLS/DASH manifest for adaptive bitrate). The client then talks to the CDN directly.
- **Search** uses Elasticsearch (or similar) for fuzzy/fielded search over track/artist/album metadata, kept in sync with the metadata DB via change-data-capture.
- **Recommendation Pipeline** runs offline/near-real-time on the playback event stream — it is decoupled entirely from the serving path, so a slow or broken recommender never affects playback.

## Component deep dives

### Adaptive streaming & CDN strategy

Encode each track into multiple bitrate tiers and chunk it (HLS or DASH: short segments, a few seconds each) so the client can switch quality mid-stream based on measured bandwidth without restarting playback. The origin (object storage) is fronted by a CDN with edge PoPs close to users; because popularity follows a power law, a small hot set of tracks stays cache-warm at nearly every edge, and cache hit rates for "top" content approach ~100%, which is what keeps origin bandwidth costs manageable at this scale.

For startup latency, prefetch the first few seconds of the most likely next track (e.g., next item in queue) while the current one is still playing.

### Playlist sync across devices

Model playlists as a small ordered list with a monotonically increasing `updated_at`/version per playlist. Each client caches the playlist locally and does a conditional fetch (`If-None-Match` / version check) rather than polling full content. Concurrent edits from two devices are resolved last-write-wins at the playlist-version level for casual use cases — full operational-transform-style merging (see Day 17) is overkill for a playlist reorder and not worth the complexity here.

### Recommendations

Two layers, both offline from the playback path:
1. **Collaborative filtering** (matrix factorization over the user-track interaction matrix) to find "users like you also played X," computed as a nightly/hourly batch job.
2. **Content-based embeddings** (audio features + metadata) to recommend acoustically similar tracks, useful for cold-start tracks with little play history.

Serve precomputed recommendation lists from a fast key-value store (user_id → list of track_ids), refreshed periodically — never compute recommendations synchronously on the request path.

### Offline playback

Premium users can download a track: the client requests a download bundle, which is the audio file encrypted with a device-bound key plus a time-limited license. Playback of downloaded content still requires periodic license validation (the app must "phone home" within some window, e.g. every 30 days) to enforce that a lapsed subscription eventually blocks offline playback — this is a DRM/licensing requirement, not a caching detail, and interviewers listening for licensing awareness want to hear this distinction.

### Licensing / catalog takedowns

Track availability is region-scoped (`available_regions` on `Track`) and must be enforceable quickly — a rights holder can demand a track be pulled globally within hours. Implement this as a fast-path flag check in the Playback Service (checked on every stream request, cached with a short TTL so takedowns propagate in seconds, not by cache-busting the whole CDN).

## Scaling & trade-offs

| Concern | Choice | Trade-off |
|---|---|---|
| Audio delivery | CDN + object storage, signed URLs, adaptive bitrate | Scales to any read volume near-free after cache warm-up; adds encoding pipeline complexity |
| Search | Dedicated search index (Elasticsearch) synced via CDC | Fast fuzzy search; introduces eventual consistency between metadata DB and index |
| Recommendations | Fully offline/batch, served from precomputed KV store | Never impacts playback latency; recommendations can be up to a few hours stale |
| Playlist sync | Version-based conditional fetch, last-write-wins merge | Simple and sufficient for casual multi-device use; not real-time collaborative |
| Offline playback | Encrypted bundle + periodic license check | Enforces subscription without requiring constant connectivity |

## Likely follow-up questions — with answers

**Q: How do you avoid the "thundering herd" when a globally hyped new album drops and everyone streams it at once?**
A: Pre-warm CDN edge caches ahead of a scheduled release by pushing the audio to edge PoPs before the public release timestamp, and rate the origin fetch so a cache-miss stampede doesn't hit object storage simultaneously from every edge (request coalescing / cache-lock at the CDN layer).

**Q: How would you support real-time collaborative playlists (multiple people editing simultaneously, like a party playlist)?**
A: Swap the last-write-wins model for an operation-based approach — treat each add/remove/reorder as a discrete op broadcast over a WebSocket channel, and use a CRDT for a list (e.g., a sequence CRDT) so concurrent inserts converge without conflict, similar to Day 17's Google Docs discussion.

**Q: A track needs to be removed globally due to a rights dispute. Walk through what happens.**
A: Flip the track's status/region flags in the metadata DB, which invalidates the short-TTL cache in the Playback Service within seconds so no new stream URLs are issued; existing in-flight signed URLs are time-limited and expire naturally; for downloaded/offline copies, the next mandatory license check revokes playback.

## Key takeaways

- This system is CDN/object-storage bound, not database bound — never design the app servers to proxy audio bytes.
- Adaptive bitrate streaming (HLS/DASH, chunked, multiple quality tiers) is the standard answer for "handle poor networks."
- Recommendations must be fully decoupled and precomputed — never on the synchronous playback path.
- Popularity is Zipfian: a small hot set drives most traffic, which is exactly what makes CDN caching so effective here.
- Licensing/region restrictions need a fast, cache-friendly enforcement point (short-TTL flag check), separate from the slow catalog metadata pipeline.

## Today's checklist

- [ ] Define functional requirements: music streaming, playlists
- [ ] Define non-functional requirements: latency, audio quality
- [ ] Design music recommendation
- [ ] Design playlist management
- [ ] Handle offline playback
- [ ] Discuss licensing
