---
kind: lesson
type: system_design
id_key: interview-prep-45/day-13-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Netflix"
position: 13
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Netflix is asked because video streaming forces you to design around bandwidth and latency at planetary scale. The video encoding pipeline, adaptive bitrate delivery, and CDN placement are problems with no equivalent in typical CRUD systems. It's also the canonical "explicitly pick availability over consistency" system, which makes it a good CAP-theorem discussion vehicle.

## Requirements

**Functional**
- Upload and encode video content into multiple qualities/formats.
- Stream video to clients with adaptive bitrate (quality adjusts to network conditions).
- Recommend content per user.
- Resume playback where the user left off, across devices.

**Non-functional**
- Minimize buffering/rebuffering, the single most important UX metric for streaming.
- Support massively parallel viewership (millions of concurrent streams during peak hours).
- Global low-latency delivery.
- Availability strongly favored over consistency (a slightly stale "continue watching" position beats a failed stream).

## Capacity estimates

Assume 250M subscribers, 30% watching concurrently at peak (a large but real peak fraction for evening prime time), so 75M concurrent streams.
- Average bitrate per stream (mixed quality mix, SD/HD/4K): ~5 Mbps average.
- Peak bandwidth: 75M × 5 Mbps = 375 Tbps of egress at peak. This number alone is why "just serve from origin servers" is not viable, and a global CDN with edge caching is mandatory, not optional.
- New content encoding: assume 1000 hours of new/catalog content processed per week; each hour of source video encoded into ~10 quality/codec variants (240p through 4K, H.264/HEVC/AV1), so 10,000 encode-hours/week of compute. This is a batch, not real-time, workload and is heavily parallelizable.
- Storage: full catalog (~15,000 titles × ~1.5 hours average × multiple encoded variants) is on the order of multiple petabytes, replicated across regional storage and CDN edge caches.

## API sketch

```
GET  /catalog/browse?genre=&cursor=            -> { titles[], next_cursor }
GET  /titles/{id}                                -> { metadata, available_qualities[] }
GET  /playback/{title_id}/manifest              -> { manifest_url }   -- HLS/DASH manifest listing available bitrates
POST /playback/{title_id}/progress { position_seconds }   -- resume point, fire periodically
GET  /recommendations?user_id=                  -> { titles[] }
```

Actual video bytes never flow through this API. Clients fetch the manifest, then pull video segments directly from the nearest CDN edge per the adaptive bitrate protocol (HLS/DASH).

## Data model

```
titles           id, name, metadata, genres[]
video_assets     id, title_id, codec, resolution, bitrate, cdn_path
watch_progress   user_id, title_id, position_seconds, updated_at, device_id
user_events      user_id, title_id, event_type (play/pause/complete), timestamp  -- feeds recommendations
```

Watch progress is the one piece of "real" state in this system and is intentionally simple. The bulk of the engineering complexity is in the encoding pipeline and delivery network, not the data model.

## High-level architecture

```
Upload path:
Studio/content team --> raw video upload --> Encoding pipeline (parallelized, chunked transcode)
                                                    |
                                     produces multiple resolution/bitrate/codec variants
                                     + generates HLS/DASH manifest (segment list per quality)
                                                    |
                                     pushed to origin storage --> replicated to CDN edge caches globally

Playback path:
Client --> Playback API --> manifest_url --> Client's adaptive bitrate player fetches
           segments directly from nearest CDN edge, switching quality per segment
           based on measured throughput/buffer health
                                                    |
           client periodically POSTs watch_progress --> Progress service (async, eventually consistent)

Recommendation path (offline/batch, mostly):
user_events stream --> batch/streaming ML pipeline --> per-user recommendation scores
                                                    --> cached, served by Recommendations API
```

## Component deep dives

**Video encoding pipeline.** Uploaded source video is split into chunks and transcoded in parallel (independent workers each encode a segment, then segments are stitched/indexed) into a matrix of resolution × bitrate × codec variants, e.g., 240p/500kbps, 480p/1.5Mbps, 720p/3Mbps, 1080p/6Mbps, 4K/25Mbps, each in H.264 (broad compatibility) and more efficient codecs like HEVC/AV1 (lower bandwidth, needs newer client support). This is a batch pipeline, not a live-request path. It can be slow (minutes to hours per title) since it happens once, long before any viewer streams the content. The output includes an HLS or DASH manifest: a playlist describing available quality variants and their segment URLs.

**Adaptive bitrate streaming (ABR).** The client doesn't request "1080p." It fetches the manifest, then continuously measures its own download throughput and local buffer health, and picks which quality segment to fetch next, segment by segment (segments are typically a few seconds each). If the network degrades mid-stream, the next segment request drops to a lower bitrate variant. That's what "buffering adapts to your connection" actually means mechanically. This logic lives entirely client-side; the server's job is just to have every variant available at the CDN edge.

**CDN strategy.** With ~375 Tbps of peak egress, origin servers cannot serve traffic directly to end users. Content must be cached at edge locations close to viewers. Netflix's actual approach (Open Connect) is instructive: place CDN appliances directly inside ISP networks, pre-populated with the most-likely-to-be-watched content for that region (predicted from regional viewing patterns), refreshed during off-peak hours (overnight) rather than fetched on-demand during peak viewing. This turns "deliver 4K video to 75M concurrent viewers" from a real-time origin-fetch problem into a mostly-precomputed cache-hit problem. Cache misses fall back to a regional origin, then a global origin, in a tiered hierarchy.

**Recommendation system basics.** This is fundamentally an offline ML problem feeding an online serving layer, not a real-time computation. User events (plays, pauses, completions, ratings, browse behavior) stream into a data pipeline that periodically (batch, e.g., daily/hourly) retrains or updates a recommendation model (collaborative filtering, "users who watched X also watched Y," blended with content-based signals like genre/cast similarity). The serving path is simple and fast: precomputed per-user recommendation lists cached and served on request, refreshed periodically rather than computed live per page load. Real-time signals (what you just clicked in this session) can be layered on top as a lightweight re-rank, similar to the personalization pattern from Day 11's autocomplete design.

**Availability vs consistency, explicitly.** This system is a textbook case for choosing availability over consistency (the AP side of CAP). If the watch-progress service is briefly partitioned or lagging, the right behavior is to let playback continue regardless, never blocking streaming on progress-sync succeeding, and to let the resume position be eventually consistent. It might occasionally resume a few seconds off after switching devices, a minor annoyance, not a failure. Contrast with, say, a payment system (Day 25) where the opposite trade-off applies.

## Scaling & trade-offs

| Layer | Approach | Trade-off |
|---|---|---|
| Encoding | Batch, parallelized, done once per title | Slow (not real-time) but that's fine, it's not on the playback critical path |
| Delivery | Global CDN, edge-cached, ISP-embedded appliances | High infra investment, but the only way to hit required egress bandwidth |
| Quality adaptation | Client-driven ABR over HLS/DASH | Server stays simple (just serve segments); all adaptive logic is client-side |
| Recommendations | Offline batch ML, cached serving | Not instantly reactive to a single click, but that's an acceptable trade for serving speed and compute cost |
| Watch progress | Eventually consistent, async writes | Occasional minor resume-position drift, in exchange for never blocking playback |

## Likely follow-up questions — with answers

**Q: How does the client decide when to switch video quality mid-stream?**
A: The player continuously measures recent segment download throughput and current buffer occupancy (how many seconds of video are already buffered ahead). If throughput comfortably exceeds the current bitrate and buffer is healthy, it steps up quality on the next segment request; if throughput drops or buffer is draining, it steps down. This is a purely client-side algorithm (e.g., buffer-based ABR). The server's only job is making every bitrate variant available so any segment request can be satisfied at any quality level.

**Q: How do you pre-position content on CDN edges before anyone has watched it yet (cold content)?**
A: Predictive placement based on regional popularity models and release schedules. A new high-profile title is pushed to edge caches proactively ahead of its release, informed by historical patterns (genre popularity by region, marketing reach) rather than waiting for organic cache-fill from first requests. Off-peak hours (overnight) are used for this bulk pre-positioning so it doesn't compete with live streaming traffic.

**Q: The recommendation model is a day old. How do you make it feel responsive to what a user just watched?**
A: Layer real-time signal on top of the batch-computed base recommendations rather than recomputing the whole model live: a lightweight online re-ranking step boosts titles similar to what was just watched/clicked in the current session, applied at serving time on top of the cached daily recommendation list. This mirrors the personalization-as-a-thin-layer pattern used in the autocomplete design: expensive computation stays batch/offline, cheap adjustments happen per-request.
