---
kind: lesson
type: system_design
id_key: interview-prep-45/day-13-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design Netflix"
position: 13
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

Netflix streams video to hundreds of millions of people at once, and the interesting engineering problem isn't a database, it's bandwidth. This question forces you to design around planetary-scale data transfer: how do you encode one video into dozens of formats, deliver it without buffering, and place it physically close to whoever is watching. It's also the clearest example of choosing availability over consistency you'll see in this course.

## Requirements

**Functional requirements**
- Upload and encode video into multiple qualities and formats.
- Stream to clients with adaptive bitrate, so quality adjusts to network conditions automatically.
- Recommend content to each user.
- Resume playback where you left off, even after switching devices.

**Non-functional requirements**
- Minimize buffering. This is the single most important thing a streaming service can get right.
- Support massively parallel viewing, millions of concurrent streams during peak hours.
- Deliver with low latency worldwide.
- Favor availability over consistency: a slightly stale "continue watching" position beats a failed stream.

> **Remember:** for Netflix, a failed stream is a disaster and a stale resume point is a shrug. That priority order shapes almost every trade-off in this design.

```knowledge-check
{ "questions": [
    { "id": "system-design-netflix-requirements-q1", "type": "mcq", "prompt": "Why does Netflix favor availability over consistency for its watch-progress feature?", "options": [
        {"id": "a", "text": "Consistency is technically impossible for video streaming"},
        {"id": "b", "text": "A stream failing to play is a severe user experience failure, while a resume point being a few seconds stale is a minor, forgettable annoyance"},
        {"id": "c", "text": "Netflix doesn't track watch progress at all"},
        {"id": "d", "text": "Availability and consistency always mean the same thing in practice"}
    ], "correct": "b", "explanation": "The cost of the two failure modes is wildly different: blocking playback to guarantee a perfectly synced resume point would make the far more common, far more painful failure (a stream not starting) more likely." }
] }
```

## Estimates

Assume 250 million subscribers, with 30% watching concurrently at peak (a realistic evening prime-time fraction), so 75 million concurrent streams.

- **Peak bandwidth:** at an average 5 Mbps per stream across the SD/HD/4K mix, 75M × 5 Mbps = 375 Tbps of egress at peak. That single number is why "just serve from origin servers" isn't viable, a global CDN with edge caching is mandatory, not a nice-to-have.
- **Encoding workload:** assume 1,000 hours of new content processed a week, each hour encoded into around 10 quality and codec variants (240p through 4K, across H.264, HEVC, AV1), so 10,000 encode-hours a week of compute. This is a batch workload, not a real-time one, and it's easy to parallelize.
- **Storage:** the full catalog, roughly 15,000 titles averaging 1.5 hours each, across multiple encoded variants, lands in the multiple-petabyte range, replicated across regional storage and CDN edges.

## API

```
GET  /catalog/browse?genre=&cursor=            -> { titles[], next_cursor }
GET  /titles/{id}                                -> { metadata, available_qualities[] }
GET  /playback/{title_id}/manifest              -> { manifest_url }   -- HLS/DASH manifest listing available bitrates
POST /playback/{title_id}/progress { position_seconds }   -- resume point, fire periodically
GET  /recommendations?user_id=                  -> { titles[] }
```

The actual video bytes never touch this API. A client fetches the manifest, then pulls video segments directly from the nearest CDN edge, following the adaptive bitrate protocol.

## Data model

```
titles           id, name, metadata, genres[]
video_assets     id, title_id, codec, resolution, bitrate, cdn_path
watch_progress   user_id, title_id, position_seconds, updated_at, device_id
user_events      user_id, title_id, event_type (play/pause/complete), timestamp  -- feeds recommendations
```

Watch progress is the one piece of genuinely "live" state in this whole system, and it's deliberately simple. Almost all the engineering difficulty lives in the encoding pipeline and the delivery network, not the data model.

## High-level design

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

## Deep dives

### How does one video become dozens of streamable files?

Uploaded source video is split into chunks and transcoded in parallel, independent workers each encode a segment, and the segments are stitched together afterward, into a full matrix of quality variants: say 240p at 500kbps, 480p at 1.5Mbps, 720p at 3Mbps, 1080p at 6Mbps, and 4K at 25Mbps, each encoded in both H.264 (broad compatibility) and a more efficient codec like HEVC or AV1 (less bandwidth, needs a newer client). This is a batch pipeline, not something on the playback critical path. It's fine if it takes minutes to hours per title, since it happens once, long before anyone streams it. The output includes an HLS or DASH manifest: a playlist naming every available quality and where its segments live.

### How does the client decide what quality to play, moment to moment?

The client never asks for "1080p" directly. It fetches the manifest, then continuously measures its own download throughput and how much video is already buffered ahead, and picks the next segment's quality itself, segment by segment, usually a few seconds at a time. If the network degrades mid-stream, the next segment simply comes from a lower-bitrate variant. That's the actual mechanism behind "the video adjusts to your connection": it's entirely client-side logic. The server's whole job is making sure every variant is sitting ready at the CDN edge.

### Why can't origin servers handle this traffic directly?

At roughly 375 Tbps of peak egress, no origin server fleet can serve that directly to end users. Content has to be cached physically close to viewers. Netflix's real approach, called Open Connect, places CDN appliances directly inside ISP networks, pre-loaded with whatever content is predicted to be popular in that region, refreshed overnight during off-peak hours rather than fetched on demand during the evening rush. That turns "deliver 4K to 75 million concurrent viewers" from a real-time origin-fetch problem into a mostly-precomputed cache-hit problem. A cache miss falls back through a regional origin, then a global one, in a tiered hierarchy.

> **Remember:** Netflix doesn't wait for people to request content before caching it. It predicts what will be popular and pushes it to the edge overnight, ahead of demand.

```knowledge-check
{ "questions": [
    { "id": "system-design-netflix-cdn-q1", "type": "mcq", "prompt": "Why does Netflix pre-position content at CDN edges overnight rather than caching it reactively as requests come in?", "options": [
        {"id": "a", "text": "Reactive caching is technically impossible for video"},
        {"id": "b", "text": "With a relatively small, predictable catalog, proactive placement avoids a real-time origin fetch during peak demand, which the required egress bandwidth simply can't support"},
        {"id": "c", "text": "Overnight bandwidth is free"},
        {"id": "d", "text": "It's purely a marketing decision, not a technical one"}
    ], "correct": "b", "explanation": "Netflix's catalog is small and predictable enough to forecast demand and push content out ahead of time, turning peak-hour serving into a cache-hit problem instead of a live-fetch problem at an unsustainable bandwidth level." }
] }
```

### How do recommendations work without recomputing everything live?

Recommendations are fundamentally an offline machine learning problem feeding a fast online serving layer, not a real-time computation. User events, plays, pauses, completions, ratings, stream into a pipeline that periodically retrains or updates a model, blending collaborative filtering ("users who watched X also watched Y") with content-based signals like genre and cast similarity. The serving path stays simple and fast: precomputed per-user lists, cached and served on request, refreshed periodically rather than computed live per page load. A lightweight real-time re-rank can layer on top for in-session signals, the same personalization-as-a-thin-layer pattern used in autocomplete design.

## Trade-offs and follow-up questions

| Layer | Approach | Trade-off |
|---|---|---|
| Encoding | Batch, parallelized, done once per title | Slow, but that's fine since it's off the playback critical path |
| Delivery | Global CDN, edge-cached, ISP-embedded appliances | High infrastructure investment, but the only way to hit the required egress bandwidth |
| Quality adaptation | Client-driven, over HLS/DASH | Server stays simple; all adaptive logic lives on the client |
| Recommendations | Offline batch ML, cached serving | Not instantly reactive to a single click, an acceptable trade for serving speed |
| Watch progress | Eventually consistent, async writes | Occasional minor resume-position drift, in exchange for never blocking playback |

**Q: How does the client decide when to switch video quality mid-stream?**
A: It continuously measures recent download throughput and current buffer health. If throughput comfortably exceeds the current bitrate and the buffer is healthy, it steps up on the next segment; if throughput drops, it steps down. This is a purely client-side algorithm; the server's only job is making every quality variant available.

**Q: How do you pre-position content on CDN edges before anyone has watched it (cold content)?**
A: Predictive placement based on regional popularity models and release schedules. A high-profile new title gets pushed to edge caches ahead of its release, informed by historical patterns rather than waiting for organic demand, using off-peak hours so it doesn't compete with live streaming traffic.

**Q: The recommendation model is a day old. How do you make it feel responsive to what someone just watched?**
A: Layer a lightweight real-time re-rank on top of the cached daily recommendation list, boosting titles similar to what was just watched, rather than recomputing the whole model live. Expensive computation stays batch and offline; cheap adjustments happen per request.

```knowledge-check
{ "questions": [
    { "id": "system-design-netflix-tradeoffs-q1", "type": "mcq", "prompt": "Why is the video encoding pipeline allowed to take minutes to hours per title without hurting the user experience?", "options": [
        {"id": "a", "text": "Users are willing to wait that long to start watching"},
        {"id": "b", "text": "Encoding is a batch process that happens once, well before any viewer requests the content, so it's entirely off the playback critical path"},
        {"id": "c", "text": "Encoding actually happens live, in real time, as someone streams"},
        {"id": "d", "text": "Slow encoding is an unavoidable limitation with no workaround"}
    ], "correct": "b", "explanation": "Because encoding happens once ahead of any viewing, its latency has zero effect on what a viewer experiences when they hit play, which is exactly why it's fine for it to be slow." }
] }
```
