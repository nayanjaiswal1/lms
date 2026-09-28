---
kind: lesson
type: system_design
id_key: interview-prep-45/day-16-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design Spotify"
position: 15
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

A music streaming service tests a different muscle than a ride-hailing app. It's dominated by large, unchanging audio files served to a huge number of listeners, plus a recommendation pipeline that runs entirely in the background and never gets in the way of playback. The interesting decisions here are about CDN strategy, adaptive delivery, and syncing state across a user's devices, not about coordinating people racing for the same resource.

## Requirements

**Functional requirements**
- Search for and stream tracks, albums, and podcasts.
- Create, edit, and share playlists.
- Recommend tracks and playlists based on listening history.
- Download tracks for offline playback, a paid feature.
- Artists and labels upload and manage catalog metadata and audio.

**Non-functional requirements**
- Low startup latency: audio should start within about 200ms of pressing play.
- High availability: streaming should degrade to a lower bitrate on a bad connection rather than fail outright.
- Massive read fan-out: a handful of popular tracks account for a hugely disproportionate share of daily plays.
- Licensing constraints: some tracks are restricted to certain regions, or must be pulled from the catalog quickly.
- Playlist state stays reasonably in sync across a user's phone, desktop, and web app; a few seconds of lag is fine.

> **Remember:** this system is bound by bandwidth and CDN reach, not by database throughput. The core engineering problem is getting audio bytes to listeners cheaply and fast.

```knowledge-check
{ "questions": [
    { "id": "system-design-spotify-requirements-q1", "type": "mcq", "prompt": "What is the dominant engineering constraint in a music streaming service like Spotify?", "options": [
        {"id": "a", "text": "Database transaction throughput"},
        {"id": "b", "text": "Getting large audio files to a huge number of listeners cheaply and fast, which makes it a CDN and bandwidth problem"},
        {"id": "c", "text": "Coordinating concurrent writers to the same row"},
        {"id": "d", "text": "Real-time geospatial matching"}
    ], "correct": "b", "explanation": "Unlike a system with heavy concurrent writes, music streaming is almost entirely about serving large, unchanging files to enormous numbers of readers, which is fundamentally a delivery and caching problem." }
] }
```

## Estimates

Assume 500 million monthly active users, 200 million daily active, averaging an hour of listening a day.

- **Track starts:** an average track runs about 3.5 minutes, so roughly 17 track plays per user per day. 200M × 17 ≈ 3.4 billion track starts/day, about 40,000/sec average, several times higher during the evening peak.
- **Audio file size:** a 3.5-minute track at 128kbps is about 3.4 MB per quality tier. Storing three tiers (say 96/160/320 kbps) is roughly 10 MB per track across all of them.
- **Catalog size:** 100 million tracks × 10 MB across tiers = 1 petabyte of audio. This is exactly why virtually all of it sits in object storage behind a CDN, never served directly from app servers.
- **Metadata** (track, album, artist, playlist rows) is comparatively tiny, tens of millions of rows, fitting comfortably in a normal database with caching.

## API

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

Playback events are fire-and-forget, sent to an asynchronous pipeline rather than blocking the request path. They feed both recommendations and royalty accounting.

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

`AudioAsset` is separate from `Track` because one track has several encoded variants, and the actual bytes live in object storage. The database row only holds a pointer, never the audio itself.

## High-level design

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

The **Playback Service** never proxies audio through app servers. It authenticates the request, checks licensing and subscription status, and hands back a signed, time-limited CDN URL, or a manifest for adaptive bitrate. The client then talks directly to the CDN. The **Recommendation Pipeline** is fully decoupled from serving, so a slow or broken recommender never touches playback.

## Deep dives

### How does adaptive streaming keep audio playing smoothly?

Encode each track into multiple bitrate tiers, chunked into short segments, so a client can switch quality mid-stream based on measured bandwidth without restarting playback. Because popularity follows a power-law curve, a small set of hot tracks stays cache-warm at nearly every CDN edge, pushing the cache hit rate for top content close to 100%, which is what keeps origin bandwidth costs under control at this scale. For fast startup, prefetch the first few seconds of the most likely next track, the next item in a queue, while the current one is still playing.

> **Remember:** the reason "top" content streams instantly everywhere is that a small share of the catalog accounts for most plays, so the CDN keeps it warm at nearly every edge by default.

```knowledge-check
{ "questions": [
    { "id": "system-design-spotify-cdn-q1", "type": "mcq", "prompt": "Why does a small set of popular tracks achieve near-100% cache hit rates at CDN edges without special handling?", "options": [
        {"id": "a", "text": "Popular tracks are given priority storage by policy"},
        {"id": "b", "text": "Play counts follow a power-law distribution, so the same small set of tracks gets requested constantly at every edge, naturally keeping them cache-warm"},
        {"id": "c", "text": "All tracks are cached everywhere regardless of popularity"},
        {"id": "d", "text": "Popular tracks are smaller in file size"}
    ], "correct": "b", "explanation": "Because a small fraction of the catalog accounts for a disproportionate share of plays, ordinary LRU-style caching naturally keeps those tracks resident everywhere without needing explicit pre-positioning logic." }
] }
```

### How do playlists stay in sync across devices without a merge algorithm?

Model a playlist as a small ordered list carrying a monotonically increasing version number. Each client caches the playlist locally and does a conditional fetch, checking the version, rather than polling the full content every time. Concurrent edits from two devices resolve with last-write-wins at the playlist-version level, which is fine for casual use. The operational-transform-style merging that Google Docs needs would be overkill here for something as simple as reordering a list.

### How do recommendations run without slowing down playback?

Two layers, both entirely offline from the playback path. **Collaborative filtering** finds "users like you also played X" through a batch job over the user-track interaction matrix, run nightly or hourly. **Content-based embeddings**, built from audio features and metadata, recommend acoustically similar tracks, useful for a brand-new track with little play history yet. Both feed a fast key-value store mapping user ID to a precomputed track list, refreshed periodically. Recommendations are never computed synchronously on the request path.

### How does offline playback and licensing enforcement work?

A premium user's download request returns an encrypted bundle, the audio file locked with a device-bound key, plus a time-limited license. Playback of a downloaded track still requires periodic license validation, the app has to "phone home" within some window, say every 30 days, so a lapsed subscription eventually blocks offline playback too. This is a licensing requirement, not just a caching detail, worth naming explicitly.

Track availability is scoped by region, and a rights holder can demand a track be pulled globally within hours. Implement this as a fast, cached flag check in the Playback Service on every stream request, with a short TTL, so a takedown propagates in seconds rather than needing to bust the entire CDN.

## Trade-offs and follow-up questions

| Concern | Choice | Trade-off |
|---|---|---|
| Audio delivery | CDN plus object storage, signed URLs, adaptive bitrate | Scales to almost any read volume once caches warm up, at the cost of encoding pipeline complexity |
| Search | A dedicated search index synced via change-data-capture | Fast fuzzy search, but eventually consistent with the metadata database |
| Recommendations | Fully offline, served from a precomputed key-value store | Never touches playback latency, at the cost of being up to a few hours stale |
| Playlist sync | Version-based conditional fetch, last-write-wins | Simple and sufficient for casual multi-device use, not real-time collaborative |
| Offline playback | Encrypted bundle plus periodic license check | Enforces subscription status without needing constant connectivity |

**Q: How do you avoid a "thundering herd" when a hyped new album drops and everyone streams it at once?**
A: Pre-warm CDN edge caches ahead of a scheduled release by pushing the audio out before the public release time, and rate-limit the origin fetch so a cache-miss stampede doesn't hit object storage from every edge simultaneously.

**Q: How would you support a real-time collaborative playlist, like a party playlist multiple people edit live?**
A: Swap last-write-wins for an operation-based approach: treat each add, remove, or reorder as a discrete event broadcast over a WebSocket, and use a sequence CRDT so concurrent inserts converge without conflict, the same idea as Google Docs' collaborative editing.

**Q: A track needs to be pulled globally due to a rights dispute. Walk through what happens.**
A: Flip the track's status flag in the metadata database, which invalidates the short-TTL cache in the Playback Service within seconds, so no new stream URLs are issued. Existing signed URLs are already time-limited and expire naturally. For offline copies, the next mandatory license check revokes playback.

```knowledge-check
{ "questions": [
    { "id": "system-design-spotify-tradeoffs-q1", "type": "mcq", "prompt": "Why is a track takedown implemented as a fast, short-TTL cached flag check rather than by purging the entire CDN?", "options": [
        {"id": "a", "text": "Purging a CDN globally is technically impossible"},
        {"id": "b", "text": "A short-TTL flag check propagates the takedown within seconds without the cost and complexity of busting cached content across every edge"},
        {"id": "c", "text": "Takedowns are rare enough that speed doesn't matter"},
        {"id": "d", "text": "The flag check only works for free-tier users"}
    ], "correct": "b", "explanation": "Checking a cheap, frequently-refreshed flag on every stream request achieves near-instant enforcement without needing to actively invalidate content already cached at every CDN edge worldwide." }
] }
```
