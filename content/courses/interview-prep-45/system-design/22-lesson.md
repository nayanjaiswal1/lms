---
kind: lesson
type: system_design
id_key: interview-prep-45/day-22-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design YouTube"
position: 22
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
YouTube looks like Netflix on the surface but the interview intent is different: YouTube is user-generated (millions of independent uploaders, not a curated studio catalog), which changes the upload path, the recommendation cold-start problem, and the sheer scale of "millions of views" on unpredictable, spiky content. Today you reuse Day 13's streaming fundamentals and layer on upload-at-scale and recommendation-at-scale.

## Requirements

**Functional**
- Any user can upload a video; it gets processed and becomes streamable.
- Viewers stream video with adaptive quality.
- Per-video recommendations ("up next") and a personalized home feed.
- View counts, likes, comments on videos.

**Non-functional**
- Upload path must handle huge files (hours of raw 4K footage) reliably, with resume support.
- Transcoding must scale horizontally and elastically (upload volume is unpredictable and spiky).
- Viewing must handle "any video can go viral," not just a known catalog of popular titles.
- Read-heavy at massive scale, similar bandwidth pressure to Netflix, but with a far longer and more unpredictable tail of content.

## Capacity estimates

Assume 2B monthly active users, 500 hours of video uploaded per minute (YouTube's real published order of magnitude).
- Upload volume: 500 hours/min × 60 = 30,000 hours/day of raw source video ingested — each hour needs to be transcoded into ~10 quality variants, so ~300,000 encode-hours/day of compute, heavily parallelized batch work.
- Views: 1B+ hours watched per day (published figure) → at ~5 Mbps average bitrate, that's roughly 1B hours × 3600s × 5Mb / 8 ≈ hundreds of petabytes of daily egress — same order-of-magnitude CDN pressure as Netflix, but spread across a vastly larger and less predictable catalog (tens of millions of actively-watched videos vs. thousands of curated titles), which matters for cache pre-positioning strategy.
- Metadata: hundreds of millions of videos, each with title/description/tags/stats — a large but standard sharded-DB scale problem, not the bottleneck.

## API sketch

```
POST /videos/upload/init        { filename, size }            -> { upload_id, chunk_urls[] }
PUT  /videos/upload/{id}/chunk/{n}   (binary body)
POST /videos/upload/{id}/complete    -> { video_id, status: "processing" }
GET  /videos/{id}                     -> { metadata, status, manifest_url (once ready) }
GET  /videos/{id}/recommendations    -> { videos[] }           -- "up next" sidebar
GET  /feed/home?cursor=               -> { videos[], next_cursor }
POST /videos/{id}/view                -- fired by client to count a view (rate-limited/verified)
```

## Data model

```
videos            id, uploader_id, title, description, status (processing|ready|failed), duration, created_at
video_assets       video_id, resolution, bitrate, codec, cdn_path      -- one row per encoded variant
view_events        video_id, user_id, timestamp, watch_duration        -- feeds both counts and recommendations
video_stats        video_id, view_count, like_count, comment_count     -- denormalized, async-updated counters
```

## High-level architecture

```
Upload path:
Client --> chunked resumable upload (same pattern as Day 12's file storage) --> raw video in
           upload storage --> "upload_complete" event --> Transcoding pipeline
                                                                |
                                    elastic worker pool transcodes in parallel into variant matrix
                                    (same pattern as Day 13's Netflix encoding pipeline)
                                                                |
                                    on completion: video.status = "ready", manifest published
                                                                |
                                    pushed to CDN edge caches (reactively, on-demand for the long
                                    tail — NOT pre-positioned like Netflix's curated catalog, since
                                    YouTube's catalog is too large and unpredictable to pre-place)

Playback + recommendations: same ABR/CDN pattern as Day 13, plus:
view_events stream --> batch + near-real-time ML pipeline --> per-video "up next" candidates
                                                              --> per-user home feed candidates
                                                              --> cached, served with light real-time re-rank
```

## Component deep dives

**Upload at scale (resumable, elastic).** Reuse Day 12's chunked-upload pattern directly: large raw video files are split into chunks client-side, uploaded independently with resume-on-failure, and reassembled server-side once all chunks arrive. Unlike Dropbox's dedup-heavy design, video content is rarely bit-identical across uploads, so content-addressed deduplication matters far less here — the emphasis instead is on making the *transcoding* step elastic, since upload volume is bursty (30,000 hours/day but not evenly spread) and a fixed-size transcoding fleet would either be wildly over-provisioned most of the time or fall behind during upload spikes. Transcoding workers scale horizontally and automatically based on queue depth (a job-queue pattern from Day 8 sits underneath this: each video/chunk-to-transcode is a job, workers pull and process, failures retry).

**Why CDN pre-positioning works differently than Netflix.** Netflix's catalog is a few thousand titles with strong predictability (new releases, known popularity) — content can be proactively pushed to edge caches ahead of demand. YouTube's actively-watched catalog spans tens of millions of videos with a long, unpredictable tail (any video can go viral with no warning). Pre-positioning everything everywhere isn't feasible. The practical answer: reactive/on-demand edge caching (a video gets cached at an edge location the first time it's requested from that region, subsequent requests hit cache) with a much shorter or LRU-based eviction policy than Netflix's curated pre-placement, plus a smaller proactive-placement tier reserved for videos already trending or from very high-subscriber channels where a demand spike is more predictable.

**Handling "millions of views" and viral spikes.** A previously obscure video can jump from 100 views/hour to 1M views/hour within minutes. This stresses the same layers as Twitter's viral-tweet problem (Day 10): cache hot-key contention on that one video's metadata/manifest (mitigate with local/edge in-process caching layered on top of the CDN), and counters (view_count, like_count) under write contention (mitigate with async batched increments via a counting service rather than a synchronous DB write per view — same pattern as Twitter's like counters). Additionally, the CDN edge cache for that specific video needs to scale its replica count dynamically as request volume to that one asset spikes, which is why reactive caching systems monitor per-object request rate and promote hot objects to wider replication automatically.

**Recommendation engine basics.** Same core pattern as Day 13's Netflix recommendations — an offline/batch ML pipeline (collaborative filtering blended with content signals: title/tag/category similarity, channel affinity) consuming the `view_events` stream, producing cached candidate lists refreshed periodically, topped with a lightweight real-time re-rank layer for in-session signals (what you just watched). The two YouTube-specific twists: "up next" (per-video recommendations, driven heavily by co-watch patterns — "people who watched this also watched") is architecturally separate from the personalized home feed (per-user recommendations, driven by watch history) even though both are served from the same underlying ML pipeline and event stream — they're different candidate-generation queries against the same data. Cold start for a brand-new video with zero view history falls back to content-based signals (title/tag/category/channel similarity) until enough view_events accumulate to activate collaborative signals.

**View count verification.** Naively trusting every client-fired `/videos/{id}/view` call invites trivial view-count fraud (bots, refresh scripts). Real systems apply server-side heuristics before crediting a view toward the public count: minimum watch duration, deduplication per user/session within a time window, and anomaly detection on view velocity from a single IP/account cluster — this is a fraud-detection layer sitting between the raw `view_events` stream and the publicly displayed `view_count`, not something enforced at write time.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Elastic transcoding worker pool (job-queue backed) | Absorbs bursty upload volume without over-provisioning | Transcoding backlog grows during extreme spikes; publish latency increases under load |
| Reactive/LRU CDN caching (vs. Netflix's proactive placement) | Feasible for a catalog too large/unpredictable to pre-place | First-ever request for a given region incurs a cache miss / origin fetch |
| Async batched view/like counters | Survives viral write contention on a single hot row | Counts are eventually consistent, briefly stale under extreme load |
| Separate "up next" vs. home feed recommendation queries | Each optimized for its own signal (co-watch vs. personal history) | Two candidate-generation paths to maintain against the same underlying data |

## Likely follow-up questions — with answers

**Q: A video uploaded 10 minutes ago suddenly gets 1M views in the next 10 minutes. What breaks first, and how do you fix it?**
A: First the CDN edge cache for that specific video's manifest/segments, since a newly reactive-cached object may only be replicated to a small number of edges — fix by promoting hot objects to wider replication dynamically based on per-object request-rate monitoring. Second, the view/like counters on that video's row — fix with async batched increments (an in-memory counter flushed periodically to the DB) instead of a synchronous write per view. Neither the transcoding pipeline nor the upload path is affected, since the video was already fully processed before the spike.

**Q: How is YouTube's CDN strategy fundamentally different from Netflix's, given they're both video streaming platforms?**
A: Netflix has a small (~15,000 title), highly predictable catalog and can proactively pre-position content at CDN edges ahead of demand, largely during off-peak hours. YouTube's actively-watched catalog is orders of magnitude larger and its demand pattern is far less predictable (any upload can go viral) — pre-placing everything everywhere isn't economical. YouTube's CDN strategy is predominantly reactive/on-demand caching with dynamic replication for objects that prove to be hot, reserving a smaller proactive tier for content with more predictable demand (trending, high-subscriber channels).

**Q: How would you prevent view-count fraud without slowing down the upload-to-visible-view pipeline?**
A: Keep the raw event ingestion path fast and unfiltered (every `/videos/{id}/view` call is accepted and logged to `view_events` immediately), and run fraud detection as an asynchronous downstream stage — minimum watch duration checks, per-user/session dedup within a time window, and IP/account velocity anomaly detection — before those events are aggregated into the publicly displayed `view_count`. This decouples ingestion latency from fraud-detection complexity, at the cost of the public count lagging the raw event stream by the detection pipeline's processing delay (typically seconds to low minutes).

## Key takeaways

- Upload-at-scale reuses the resumable chunked-upload pattern from file storage, feeding an elastic, job-queue-backed transcoding pipeline that reuses the Netflix encoding pattern.
- CDN strategy diverges from Netflix specifically because of catalog size and unpredictability: reactive/on-demand caching with dynamic hot-object replication, not proactive pre-positioning.
- Viral spikes stress the same two layers every time (cache hot-keys, counter contention) — the fix is always local/edge caching plus async batched counters, a pattern that repeats from Twitter through YouTube.
- "Up next" and home-feed recommendations are two separate candidate-generation queries (co-watch vs. personal history) against the same offline ML pipeline and event stream, not two separate systems.
- View counts need an asynchronous fraud-detection layer between raw ingestion and the publicly displayed number — never trust and display a client-fired event directly.
- When a follow-up says "how is this different from a similar system you already designed," the strongest answer names the specific scale/predictability difference driving the divergence, not just "it's bigger."
