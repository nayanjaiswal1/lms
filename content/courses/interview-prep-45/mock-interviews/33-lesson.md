---
kind: lesson
id_key: interview-prep-45/day-33
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Mock Interviews 10–12: Hard DSA, YouTube, Full Stack"
position: 33
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Three mocks today, each harder than anything in week 4 so far: a hard heap problem, a video-streaming system design, and a timed full-stack build where you own both ends of the wire. Run every segment on a hard timer, talk out loud the whole time, and don't open a reference solution until your own attempt is over or the clock hits zero.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:40 | Mock 10: DSA (Hard) — Merge K Sorted Lists, heap approach (40 min) |
| 0:40–0:50 | Break — write down what went wrong while it's fresh |
| 0:50–1:30 | Mock 11: System Design — Design YouTube (40 min) |
| 1:30–1:40 | Break |
| 1:40–2:25 | Mock 12: Full Stack — REST API + frontend, error handling (45 min) |
| 2:25–2:50 | Score against rubric, write debrief |
| 2:50–4:00 | Buffer — Median of Data Stream, Sliding Window Maximum, or Top K Frequent Elements (pick one or two, cold) |

## Mock Interview 10: DSA (Hard) — Merge K Sorted Lists (40 minutes)

**Problem:** [Merge K Sorted Lists (LeetCode 23)](https://leetcode.com/problems/merge-k-sorted-lists/). You are given an array of `k` linked lists, each sorted in ascending order. Merge all the lists into one sorted linked list and return it.

```
Input: lists = [[1,4,5],[1,3,4],[2,6]]
Output: [1,1,2,3,4,4,5,6]
```

**Instructions:** solve with a min-heap first, and get it to O(N log k) where N is the total number of nodes and k is the number of lists. If time remains, implement the divide-and-conquer merge as a second approach and compare.

**Clarifying hints an interviewer would give if you don't ask:**
- "Can `lists` be empty, or contain empty lists?" — Yes to both; handle `lists = []` and `lists = [[], [1]]`.
- "Are values unique across lists?" — No, duplicates are allowed and must all appear in the output.
- "In-place or new list?" — Either is fine; reusing existing nodes (not copying values) is the expected style for a linked-list problem.

Budget: 3 min clarify, 7 min discuss naive vs heap vs divide-and-conquer, 22 min code the heap solution, 8 min test + discuss the alternative.

### Reference solution

```python
import heapq
from typing import Optional


class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next


def merge_k_lists_heap(lists: list[Optional[ListNode]]) -> Optional[ListNode]:
    """Push the head of every list into a min-heap. Pop the smallest, attach it
    to the output, and push its successor. The heap never holds more than k
    nodes, so each of the N pops/pushes costs O(log k)."""
    heap: list[tuple[int, int, ListNode]] = []
    for i, node in enumerate(lists):
        if node:
            # tie-break on i (list index) since ListNode isn't orderable and
            # heapq needs a total order when values are equal.
            heapq.heappush(heap, (node.val, i, node))

    dummy = ListNode()
    tail = dummy
    while heap:
        val, i, node = heapq.heappop(heap)
        tail.next = node
        tail = tail.next
        if node.next:
            heapq.heappush(heap, (node.next.val, i, node.next))
    return dummy.next


def merge_two_lists(a: Optional[ListNode], b: Optional[ListNode]) -> Optional[ListNode]:
    dummy = ListNode()
    tail = dummy
    while a and b:
        if a.val <= b.val:
            tail.next, a = a, a.next
        else:
            tail.next, b = b, b.next
        tail = tail.next
    tail.next = a or b
    return dummy.next


def merge_k_lists_divide_and_conquer(lists: list[Optional[ListNode]]) -> Optional[ListNode]:
    """Pair up lists and merge two at a time, halving the count each round —
    same O(N log k) bound as the heap, without needing a heap at all."""
    if not lists:
        return None
    lists = list(lists)
    while len(lists) > 1:
        merged = []
        for i in range(0, len(lists), 2):
            l1 = lists[i]
            l2 = lists[i + 1] if i + 1 < len(lists) else None
            merged.append(merge_two_lists(l1, l2))
        lists = merged
    return lists[0]


def build(values: list[int]) -> Optional[ListNode]:
    dummy = ListNode()
    tail = dummy
    for v in values:
        tail.next = ListNode(v)
        tail = tail.next
    return dummy.next


def to_list(node: Optional[ListNode]) -> list[int]:
    out = []
    while node:
        out.append(node.val)
        node = node.next
    return out


if __name__ == "__main__":
    lists = [build([1, 4, 5]), build([1, 3, 4]), build([2, 6])]
    assert to_list(merge_k_lists_heap(lists)) == [1, 1, 2, 3, 4, 4, 5, 6]

    lists2 = [build([1, 4, 5]), build([1, 3, 4]), build([2, 6])]
    assert to_list(merge_k_lists_divide_and_conquer(lists2)) == [1, 1, 2, 3, 4, 4, 5, 6]

    assert merge_k_lists_heap([]) is None
    assert to_list(merge_k_lists_heap([None, build([1])])) == [1]
    print("ok")
```

**What to explain out loud:** the naive approach — collect all N values, sort, rebuild — is O(N log N) and throws away the fact that each individual list is already sorted. Merging lists one at a time (`merge(merge(merge(l1, l2), l3), l4)...`) is O(N*k) because the accumulated list gets scanned against every remaining list. The heap keeps only the k current heads in memory at once; every pop/push is O(log k), and there are N total nodes processed, giving O(N log k) — strictly better than O(N*k) whenever k is more than a small constant, which is exactly the case this problem is built to test. Divide-and-conquer gets the same bound differently: `log k` rounds, each round doing O(N) work total across all pairwise merges, so O(N log k) again — mention this is often preferred in practice because it avoids heap overhead and is easier to parallelize (each pairwise merge in a round is independent).

**Extra practice for the buffer block** — three problems in the same "keep a running structure over a stream/window" family as today's heap problem:
- **Median of Data Stream** — two heaps (a max-heap for the lower half, a min-heap for the upper half), rebalanced after every insert so their sizes differ by at most 1; median is the top of the larger heap or the average of both tops.
- **Sliding Window Maximum** — a monotonic deque of indices, popping from the back while the incoming value is larger (they can never be the answer while a bigger, newer value exists) and from the front when the index falls out of the window.
- **Top K Frequent Elements** — count with a hash map, then either a min-heap of size k (O(n log k)) or bucket sort by frequency (O(n), since frequency is bounded by array length).

## Mock Interview 11: System Design — Design YouTube (40 minutes)

**Prompt as the interviewer would give it:** "Design a video platform like YouTube. Users upload videos, other users watch them. Focus on the streaming path, not recommendations or comments."

Time budget: 5 min requirements, 10 min high-level architecture, 15 min deep dive (upload/transcode/playback), 10 min scaling and trade-offs.

**Clarifying questions to ask out loud:**
- Upload size/duration limits?
- Does playback need adaptive quality (auto-switch resolution based on bandwidth), or is a fixed set of quality options enough?
- Live streaming in scope, or upload-then-watch only?
- Global audience, or single region?
- Rough scale — uploads/day, concurrent viewers at peak?

### Reference solution

**Functional requirements:** upload a video, process it into streamable form, browse/search (assume a separate search service, out of scope for the deep dive), play a video with selectable/adaptive quality.
**Non-functional requirements:** playback start latency low (<1–2s to first frame), high read availability (watching must basically never be down), durability of uploaded originals, must scale to enormous read:write skew (uploads are rare relative to views).

**Capacity estimate:** say a mid-size platform gets 500 hours of video uploaded per minute — roughly 720,000 hours/day. At ~1GB/hour of raw video, that's ~720TB/day of raw ingest before transcoding, which multiplies by however many renditions you store (240p through 4K, several codecs). This is squarely "needs a blob store + CDN," not "needs a database that holds video bytes" — say that decision out loud, storing video data in a relational DB is the single fastest way to fail this design.

**High-level architecture:**
```
Upload: Client -> Upload service -> Blob store (raw, e.g. S3) -> Transcoding queue -> Transcode workers
                                                                                    -> Rendition storage (S3) -> CDN

Playback: Client -> CDN (edge) -> [cache miss] -> Origin (rendition storage)
          Client -> Metadata service -> Metadata DB (title, owner, duration, available renditions)
```

**Upload path:** client does a chunked, resumable upload (so a dropped connection on a 2-hour 4K file doesn't restart from zero) directly to blob storage, often via a pre-signed URL so the raw bytes never round-trip through your app servers. Once the upload completes, an event (S3 event notification, or an explicit "upload complete" API call) enqueues a transcoding job. A pool of transcode workers pulls jobs, produces multiple renditions — several resolutions (240p/480p/720p/1080p/4K) and, for adaptive streaming, splits each into short segments (2–10s) with a manifest (HLS `.m3u8` or DASH `.mpd`) listing the available bitrates and their segment URLs. Renditions and manifests land back in blob storage, then get pushed/pulled into the CDN.

**Playback path — the hot path:** client requests the manifest, the video player (HLS.js, native HLS on iOS, ExoPlayer/DASH on Android) picks a starting bitrate, then continuously measures actual download throughput and switches renditions segment-to-segment — this is adaptive bitrate streaming (ABR), and it's the reason video is delivered as many small segments instead of one file: switching quality mid-stream just means requesting the next segment from a different rendition, no re-buffering from zero. Segments are served from CDN edge nodes; a cache miss falls through to origin (your rendition storage), and the edge caches it for the next viewer in that region.

**Data model (metadata service):**
```sql
CREATE TABLE videos (
    id BIGSERIAL PRIMARY KEY,
    owner_id BIGINT NOT NULL,
    title TEXT NOT NULL,
    duration_seconds INT,
    status VARCHAR(20) NOT NULL, -- uploading | transcoding | ready | failed
    manifest_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE renditions (
    video_id BIGINT REFERENCES videos(id),
    resolution VARCHAR(10) NOT NULL,
    codec VARCHAR(20) NOT NULL,
    storage_url TEXT NOT NULL,
    PRIMARY KEY (video_id, resolution, codec)
);
```

**Scaling and trade-offs:**
- **CDN caching is the whole game for reads.** View popularity is heavily Zipfian — a small number of videos take most of the traffic. Popular videos stay warm at edge nodes; long-tail videos fall back to origin more often. This is fine, and worth stating explicitly rather than trying to make every video equally cache-friendly.
- **Storage tiering:** recently uploaded/actively watched renditions stay on fast storage; rarely watched old videos can move to cheaper cold storage (with a higher retrieval latency accepted as a trade-off) once access patterns show they've gone cold.
- **Transcoding is the expensive, parallelizable part.** Each rendition of a video can transcode independently — scale the worker pool horizontally, use a priority queue so a short viral clip doesn't sit behind someone's 4-hour 4K upload.
- **View counts** should not be a synchronous write to the metadata DB on every play — batch/aggregate view events asynchronously (a stream processor or periodic aggregation job) and eventually-consistently update the count; exact real-time accuracy isn't worth the write amplification on a hot path.

**Failure modes to name:** a transcode job that fails partway (retry with a dead-letter queue after N attempts, don't silently mark the video "ready" with missing renditions), a CDN cache stampede when a video suddenly goes viral (mitigate with request coalescing at the origin, or pre-warming edges from trending signals), and inconsistent metadata if the "mark ready" step fails after renditions are already written (idempotent status updates, or an outbox-style pattern so the DB write and the "notify CDN" step don't drift out of sync).

## Mock Interview 12: Full Stack — REST API + Frontend (45 minutes)

**Prompt:** "Build a small task list app: a REST API to create, list, toggle, and delete tasks, and a frontend that talks to it. Handle errors gracefully on both ends — don't let a failed request leave the UI in a broken or silently-stale state."

Time budget: 5 min plan the API contract and component state, 20 min backend, 15 min frontend, 5 min wire up + discuss error handling.

**Clarifying hints an interviewer would give:**
- "Persistence — real database or in-memory is fine?" — In-memory is fine for a 45-minute round; say out loud what you'd change for production (a real DB, migrations).
- "What should the UI do while a request is in flight, and if it fails?" — Show loading state; on failure, surface the error and don't leave optimistic changes applied if the server rejected them.
- "Validation — client-side, server-side, or both?" — Both. Client-side for immediate feedback, server-side because the client can never be trusted to enforce it.

### Reference solution

**Backend — FastAPI, in-memory store:**

```python
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI()


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class Task(BaseModel):
    id: str
    title: str
    done: bool = False


tasks: dict[str, Task] = {}


@app.get("/tasks", response_model=list[Task])
def list_tasks() -> list[Task]:
    return list(tasks.values())


@app.post("/tasks", response_model=Task, status_code=201)
def create_task(payload: TaskCreate) -> Task:
    task = Task(id=str(uuid4()), title=payload.title)
    tasks[task.id] = task
    return task


@app.patch("/tasks/{task_id}", response_model=Task)
def toggle_task(task_id: str) -> Task:
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="task not found")
    task.done = not task.done
    return task


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: str) -> None:
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="task not found")
    del tasks[task_id]
```

Note what's doing the error handling here: Pydantic rejects an empty or 201-character title before the handler body even runs (422, automatic); the 404s are explicit because "delete something that doesn't exist" is a real case, not an edge case to ignore.

**Frontend — React/TSX, optimistic updates with rollback on failure:**

```tsx
import { useState, useEffect, useCallback, FormEvent } from "react";

interface Task {
  id: string;
  title: string;
  done: boolean;
}

async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail ?? `request failed: ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export function TaskList() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setTasks(await apiFetch<Task[]>("/tasks"));
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed to load tasks");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      const created = await apiFetch<Task>("/tasks", {
        method: "POST",
        body: JSON.stringify({ title }),
      });
      setTasks((prev) => [...prev, created]);
      setTitle("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed to create task");
    } finally {
      setSubmitting(false);
    }
  };

  const toggleTask = async (id: string) => {
    const snapshot = tasks;
    setTasks((cur) => cur.map((t) => (t.id === id ? { ...t, done: !t.done } : t)));
    try {
      await apiFetch<Task>(`/tasks/${id}`, { method: "PATCH" });
    } catch (err) {
      setTasks(snapshot); // roll back the optimistic flip
      setError(err instanceof Error ? err.message : "failed to update task");
    }
  };

  const deleteTask = async (id: string) => {
    const snapshot = tasks;
    setTasks((cur) => cur.filter((t) => t.id !== id));
    try {
      await apiFetch<void>(`/tasks/${id}`, { method: "DELETE" });
    } catch (err) {
      setTasks(snapshot); // roll back the optimistic removal
      setError(err instanceof Error ? err.message : "failed to delete task");
    }
  };

  if (loading) return <p>Loading tasks…</p>;

  return (
    <div>
      {error && (
        <p role="alert" style={{ color: "red" }}>
          {error}
        </p>
      )}
      <form onSubmit={handleSubmit}>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="New task" />
        <button type="submit" disabled={submitting}>
          Add
        </button>
      </form>
      <ul>
        {tasks.map((t) => (
          <li key={t.id}>
            <label>
              <input type="checkbox" checked={t.done} onChange={() => toggleTask(t.id)} />
              <span style={{ textDecoration: t.done ? "line-through" : undefined }}>{t.title}</span>
            </label>
            <button onClick={() => deleteTask(t.id)}>Delete</button>
          </li>
        ))}
      </ul>
      {tasks.length === 0 && <p>No tasks yet.</p>}
    </div>
  );
}
```

**Why these choices, explain out loud:** toggle and delete update local state immediately (optimistic UI — feels instant) but keep a snapshot of the prior state so a server rejection rolls the UI back exactly, rather than leaving it in a state the server never confirmed. `load` and `handleSubmit` are not optimistic — there's nothing to optimistically show before the first fetch, and a create's real ID only exists once the server assigns it. Every network call goes through one `apiFetch` helper that normalizes error extraction, so error handling isn't reimplemented five times with five different bugs. `disabled={submitting}` on the add button prevents duplicate submits from double-clicking, a real bug interviewers watch for.

## Scoring rubric

**Mock 10 — DSA (Merge K Sorted Lists)**
- Reached the heap approach and correctly bounded it at O(N log k): 5 = derived it from first principles, explained why the heap never exceeds size k; 1 = only reached the O(N*k) sequential-merge approach even after a hint.
- Implemented divide-and-conquer as the comparison approach: 5 = coded it correctly and explained why it hits the same bound differently; 1 = didn't attempt it or couldn't explain the complexity.
- Handled edge cases (empty `lists`, lists containing `None`, duplicate values): 5 = handled all three unprompted; 1 = crashed on an empty list.
- Code cleanliness (heap tie-breaking, dummy-node pattern): 5 = used a tie-breaker for equal values without being told why it's needed; 1 = crashed or needed a hint on the `TypeError` from comparing `ListNode` objects directly.

**Mock 11 — System Design (YouTube)**
- Recognized this needs blob storage + CDN, not a database holding video bytes: 5 = stated this unprompted in the first five minutes; 1 = proposed storing video files in a SQL table.
- Explained adaptive bitrate streaming and why video is segmented: 5 = correctly described manifest + segment switching and why it avoids re-buffering; 1 = described it as "just pick a resolution and stream the whole file."
- Separated the upload/transcode pipeline from the playback/CDN path: 5 = drew both flows distinctly with correct data flow; 1 = conflated them into one undifferentiated pipeline.
- Named concrete scaling trade-offs (cache tiering, transcode parallelism, async view counts): 5 = named at least two with reasoning; 1 = no trade-offs mentioned unless asked directly.

**Mock 12 — Full Stack (Task API + Frontend)**
- API contract was sane before code started (routes, status codes, request/response shapes): 5 = sketched the contract in under 5 minutes and stuck to it; 1 = designed the API ad hoc while writing frontend code and had to backtrack.
- Server-side validation, not just client-side: 5 = used a schema/validation layer server-side unprompted; 1 = only validated in the browser, trusting the client.
- Frontend handled loading and error states, not just the happy path: 5 = explicit loading/error UI plus rollback on failed mutation; 1 = only the success path renders correctly, errors are silently swallowed or crash the UI.
- Explained the optimistic-update/rollback pattern and when it's appropriate: 5 = articulated the trade-off (feels fast, but must roll back cleanly on failure) unprompted; 1 = didn't attempt optimistic updates or implemented them with no rollback path.

## Debrief

Log every stumble immediately after each mock, not at the end of the day. For Mock 10, note specifically whether the heap approach was slow to arrive at (a knowledge gap — review "top-k / stream" pattern recognition) or slow to *code* (a mechanics gap — drill `heapq` syntax cold). For Mock 11, note whether you reached for CDN + blob storage unprompted or needed a nudge — this is one of the most-repeated patterns in video/media system design and should become reflexive. For Mock 12, note the exact moment error handling was skipped (did you write the happy path first and never circle back? that's a habit to break, not a one-off). Anything scored 3/5 or below goes on tomorrow's warm-up so it gets revisited inside 48 hours.
