---
kind: lesson
type: system_design
id_key: interview-prep-45/day-22-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design YouTube"
position: 14
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

YouTube looks like Netflix on the surface, both stream video, both need adaptive bitrate and a CDN, but the interview is testing something different. YouTube's content comes from millions of independent uploaders, not a curated studio catalog, and that one difference changes the upload path, how recommendations handle a brand-new video, and just how unpredictable "this thing might suddenly get huge" really is. This lesson reuses the streaming fundamentals from the Netflix design and focuses on what changes when anyone can upload and any video can go viral.

## Requirements

**Functional requirements**
- Any user can upload a video, which gets processed and becomes streamable.
- Viewers stream with adaptive quality.
- Per-video recommendations ("up next") and a personalized home feed.
- View counts, likes, and comments on videos.

**Non-functional requirements**
- The upload path must handle huge files, hours of raw 4K footage, reliably, with resume support.
- Transcoding must scale horizontally and elastically, since upload volume is unpredictable and spiky.
- Viewing has to handle the fact that any video can go viral, not just a known catalog of popular titles.
- Read-heavy at massive scale, similar bandwidth pressure to Netflix, but spread across a far longer and less predictable tail of content.

> **Remember:** the difference that actually matters between YouTube and Netflix isn't raw traffic, it's catalog predictability. Netflix knows roughly what will be popular; YouTube genuinely doesn't.

```knowledge-check
{ "questions": [
    { "id": "system-design-youtube-requirements-q1", "type": "mcq", "prompt": "What is the key structural difference between YouTube and Netflix that reshapes YouTube's design?", "options": [
        {"id": "a", "text": "YouTube videos are always shorter than Netflix titles"},
        {"id": "b", "text": "YouTube's catalog comes from millions of independent uploaders and is far less predictable, so any video can go viral with no warning"},
        {"id": "c", "text": "YouTube does not use adaptive bitrate streaming"},
        {"id": "d", "text": "YouTube has fewer total viewers than Netflix"}
    ], "correct": "b", "explanation": "Netflix's small, curated catalog is predictable enough to plan around. YouTube's enormous, user-generated catalog isn't, which forces a different approach to caching and capacity." }
] }
```

## Estimates

Assume 2 billion monthly active users, with about 500 hours of video uploaded every minute, YouTube's real published order of magnitude.

- **Upload volume:** 500 hours/min × 60 = 30,000 hours/day of raw video. Each hour needs transcoding into roughly 10 quality variants, so about 300,000 encode-hours/day of heavily parallelized batch compute.
- **Views:** over a billion hours watched per day, at roughly 5 Mbps average, works out to hundreds of petabytes of daily egress. Similar order of magnitude to Netflix's CDN pressure, but spread across a vastly larger and less predictable catalog, tens of millions of actively watched videos instead of a few thousand curated titles, which is exactly what changes the caching strategy.
- **Metadata:** hundreds of millions of videos, each with title, description, tags, and stats. A large but standard sharded-database problem, not the bottleneck here.

## API

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

## High-level design

```
Upload path:
Client --> chunked resumable upload (same pattern as the Dropbox-style file storage design) --> raw video in
           upload storage --> "upload_complete" event --> Transcoding pipeline
                                                                |
                                    elastic worker pool transcodes in parallel into variant matrix
                                    (same pattern as Netflix's encoding pipeline)
                                                                |
                                    on completion: video.status = "ready", manifest published
                                                                |
                                    pushed to CDN edge caches (reactively, on-demand for the long
                                    tail — NOT pre-positioned like Netflix's curated catalog, since
                                    YouTube's catalog is too large and unpredictable to pre-place)

Playback + recommendations: same adaptive-bitrate/CDN pattern as Netflix, plus:
view_events stream --> batch + near-real-time ML pipeline --> per-video "up next" candidates
                                                              --> per-user home feed candidates
                                                              --> cached, served with light real-time re-rank
```

## Deep dives

### How does upload at this scale actually work?

Reuse the chunked, resumable upload pattern from the file storage design directly: large raw video files are split into chunks on the client, uploaded independently with resume on failure, and reassembled once every chunk arrives. Unlike Dropbox, though, content-addressed deduplication barely matters here, since video uploads are rarely bit-identical to each other. The real emphasis is making the transcoding step elastic: upload volume is bursty, 30,000 hours a day but not evenly spread, and a fixed-size transcoding fleet would either sit over-provisioned most of the time or fall behind during a spike. Transcoding workers scale automatically based on queue depth, the same job-queue pattern where each video is a job, workers pull and process it, and failures retry.

### Why does YouTube's CDN strategy have to work differently from Netflix's?

Netflix's catalog is a few thousand titles with strong predictability, so content can be proactively pushed to edge caches ahead of demand. YouTube's actively-watched catalog spans tens of millions of videos with a long, genuinely unpredictable tail, any video can go viral without warning, so pre-positioning everything everywhere simply isn't feasible. The practical answer is reactive, on-demand edge caching: a video gets cached at an edge location the first time someone in that region requests it, and later requests hit that cache. This uses a shorter, LRU-based eviction policy compared to Netflix's curated pre-placement, with a smaller proactive tier reserved for videos already trending or from very large channels, where a demand spike is at least somewhat predictable.

> **Remember:** Netflix pre-positions because it can predict demand. YouTube reacts because it can't. Same underlying CDN idea, opposite starting assumption.

```knowledge-check
{ "questions": [
    { "id": "system-design-youtube-cdn-q1", "type": "mcq", "prompt": "Why does YouTube rely mostly on reactive, on-demand CDN caching instead of Netflix's proactive pre-positioning?", "options": [
        {"id": "a", "text": "YouTube's CDN technology is less advanced than Netflix's"},
        {"id": "b", "text": "YouTube's catalog is orders of magnitude larger and far less predictable, since any upload can go viral, making proactive placement of everything infeasible"},
        {"id": "c", "text": "YouTube videos are smaller in file size than Netflix titles"},
        {"id": "d", "text": "Reactive caching is always superior to proactive caching"}
    ], "correct": "b", "explanation": "The choice follows directly from catalog size and predictability, not raw traffic volume. A catalog too large and unpredictable to forecast can't be pre-placed economically, so caching has to react to real demand instead." }
] }
```

### What happens when an obscure video suddenly goes viral?

A previously obscure video can jump from 100 views/hour to a million views/hour within minutes. This stresses the same layers as a viral social media post: cache hot-key contention on that one video's metadata and manifest, fixed with local, in-process caching layered on top of the CDN, and its view/like counters under write contention, fixed with async batched increments through a counting service rather than a synchronous write per view. The CDN edge cache for that specific video also needs to scale its replica count dynamically as request volume spikes, which is why reactive caching systems monitor per-object request rate and automatically promote hot objects to wider replication.

### How do "up next" and the home feed differ, and how do you stop view-count fraud?

Recommendations follow the same core pattern as Netflix: an offline batch pipeline blending collaborative filtering with content signals, consuming the `view_events` stream, producing cached candidate lists topped with a lightweight real-time re-rank. Two things are specific to YouTube. "Up next" is driven heavily by co-watch patterns ("people who watched this also watched"), while the home feed is driven by personal watch history, different candidate-generation queries against the same underlying data. And cold start for a brand-new video with zero view history falls back to content-based signals, title, tags, category, channel, until enough view events accumulate to activate the collaborative signal.

Naively trusting every client-fired view call invites obvious fraud (bots, refresh scripts). Keep ingestion fast and unfiltered, every view call is logged immediately, and run fraud detection as an asynchronous downstream stage: minimum watch duration, per-user dedup within a time window, and anomaly detection on view velocity from one IP or account cluster, before those events roll up into the publicly displayed count.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Elastic transcoding worker pool | Absorbs bursty upload volume without over-provisioning | A backlog grows during extreme spikes, increasing publish latency |
| Reactive/LRU CDN caching | Feasible for a catalog too large to pre-place | The first-ever request from a region pays a cache miss |
| Async batched view/like counters | Survives viral write contention on a single hot row | Counts are eventually consistent, briefly stale under extreme load |
| Separate "up next" vs. home feed queries | Each is optimized for its own signal | Two candidate-generation paths to maintain against the same data |

**Q: A video uploaded 10 minutes ago suddenly gets a million views in the next 10 minutes. What breaks first, and how do you fix it?**
A: First, the CDN edge cache for that video's manifest and segments, since a newly-cached object may only be replicated to a small number of edges, fixed by dynamically promoting hot objects to wider replication based on per-object request-rate monitoring. Second, the view and like counters, fixed with async batched increments instead of a synchronous write per view. Neither the transcoding pipeline nor the upload path is affected, since the video was already fully processed before the spike hit.

**Q: How is YouTube's CDN strategy fundamentally different from Netflix's, given both stream video?**
A: Netflix has a small, highly predictable catalog it can pre-position ahead of demand, mostly during off-peak hours. YouTube's catalog is orders of magnitude larger and far less predictable, so its strategy is predominantly reactive, on-demand caching with dynamic replication for objects that prove hot, reserving a smaller proactive tier for content with more predictable demand.

**Q: How would you prevent view-count fraud without slowing down the pipeline from upload to visible view?**
A: Keep raw ingestion fast and unfiltered, and run fraud detection as an asynchronous downstream stage, minimum watch duration, per-session dedup, and velocity anomaly detection, before events roll up into the public count. This decouples ingestion latency from fraud-detection complexity, at the cost of the public count lagging the raw stream by the detection pipeline's processing delay, typically seconds to a few minutes.

```knowledge-check
{ "questions": [
    { "id": "system-design-youtube-tradeoffs-q1", "type": "mcq", "prompt": "Why is view-count fraud detection run as an asynchronous downstream stage rather than checked before a view event is even accepted?", "options": [
        {"id": "a", "text": "Fraud detection is too unimportant to prioritize"},
        {"id": "b", "text": "It keeps raw ingestion fast and simple, decoupling the fast write path from the slower, more complex fraud-detection logic"},
        {"id": "c", "text": "It's technically impossible to detect fraud before accepting an event"},
        {"id": "d", "text": "Fraud only matters for uploads, not for views"}
    ], "correct": "b", "explanation": "Blocking every view event on a complex fraud check would slow down the entire ingestion path. Accepting quickly and reconciling asynchronously keeps the hot path fast while still catching fraud before it reaches the public count." }
] }
```

When an interviewer asks "how is this different from a similar system you already designed," the strongest answer names the specific difference that's actually driving the divergence, catalog size and predictability here, not a vague "it's bigger."
