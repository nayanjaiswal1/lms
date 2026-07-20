---
kind: lesson
id_key: interview-prep-45/day-30
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Day 30 — Mock Interviews 1–3: DSA, System Design, Behavioral"
position: 30
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Three back-to-back mocks today, same as a real onsite loop. Run each on its own timer with zero pausing, speak every thought out loud (record yourself if you can, you will hate listening back and that's the point), and don't touch a reference solution or model answer until your own attempt is over.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:33 | Mock 1: DSA — Merge Intervals (30 min solve + 3 min self-note) |
| 0:33–0:43 | Break |
| 0:43–1:28 | Mock 2: System Design — Chat Application (40 min + 5 min self-note) |
| 1:28–1:38 | Break |
| 1:38–2:03 | Mock 3: Behavioral — 3 questions (20 min + 5 min self-note) |
| 2:03–2:30 | Score against rubric, write debrief |
| 2:30–4:00 | Buffer — re-run your weakest segment cold |

## Mock Interview 1: DSA — Merge Intervals (30 minutes)

**Problem:** [Merge Intervals (LeetCode 56)](https://leetcode.com/problems/merge-intervals/). Given an array of intervals where `intervals[i] = [start_i, end_i]`, merge all overlapping intervals and return an array of the non-overlapping intervals that cover all the intervals in the input.

```
Input: [[1,3],[2,6],[8,10],[15,18]]
Output: [[1,6],[8,10],[15,18]]
```

**Time allocation:** Clarification 3 min, algorithm 10 min, code 15 min, test 5 min. (Note: this totals 33 — that's intentional slack; a real interviewer lets you run slightly over on a clean solve.)

**Clarifying hints an interviewer expects you to surface:**
- "Is the input already sorted?" — No, assume unsorted; you must sort first.
- "Do touching intervals count as overlapping?" e.g. `[1,3]` and `[3,5]` — Yes, treat `end_i >= start_{i+1}` as overlapping (touching merges).
- "Can intervals be empty or have `start > end`?" — Assume valid, `start <= end`.

#### Reference solution

```python
def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    if not intervals:
        return []
    intervals.sort(key=lambda iv: iv[0])
    merged = [intervals[0]]
    for start, end in intervals[1:]:
        last = merged[-1]
        if start <= last[1]:
            last[1] = max(last[1], end)
        else:
            merged.append([start, end])
    return merged


if __name__ == "__main__":
    assert merge_intervals([[1, 3], [2, 6], [8, 10], [15, 18]]) == [[1, 6], [8, 10], [15, 18]]
    assert merge_intervals([[1, 4], [4, 5]]) == [[1, 5]]
    assert merge_intervals([]) == []
    print("ok")
```

Time: O(n log n) for the sort, then O(n) to sweep. Space: O(n) for the sort/output (O(log n) to O(n) depending on sort implementation, mention this if asked). The key insight to say out loud: once sorted, overlap can only happen with the *most recently merged* interval, so a single linear pass after sorting suffices — no nested loop needed.

## Mock Interview 2: System Design — Chat Application (40 minutes)

**Prompt:** "Design a real-time chat application like WhatsApp or Slack — one-on-one and group messaging, online/offline delivery."

**Framework and time allocation:**
1. Clarify requirements — 5 min
2. High-level design — 10 min
3. Deep dive — 15 min
4. Wrap up — 5 min (state weaknesses, mention what you'd do with more time)

Speak continuously — dead air in a real interview reads as being stuck even when you're thinking.

**Clarifying questions to ask:**
- One-on-one only, or group chats too?
- Message delivery guarantees — at-least-once acceptable, or exactly-once required?
- Do we need read receipts / typing indicators / online presence?
- Message history retention — forever, or time-bounded?
- Scale — how many DAU, messages/day?

### Reference solution

**Functional requirements:** send/receive messages 1:1 and in groups, persist history, deliver to offline users when they reconnect, show delivery/read status.
**Non-functional requirements:** low latency delivery (<200ms for online recipients), durability (never lose a sent message), horizontal scalability, eventual consistency acceptable for presence/read receipts.

**High-level architecture:**
```
Client (WebSocket) -> Gateway/Connection servers -> Message service -> Message store (per-conversation log)
                                                   -> Presence service (Redis, ephemeral)
                                                   -> Push notification service (for offline delivery)
```

**Connection layer:** clients hold a persistent WebSocket to a connection server. Connection servers are stateless regarding message content but maintain an in-memory map of `user_id -> connection`. Because a user can be connected to any one of many connection servers, you need a routing layer: a pub/sub system (Redis Pub/Sub or Kafka) where each connection server subscribes to the users currently connected to it, and the message service publishes to `user_id`'s channel — whichever server holds that connection delivers it.

**Message flow (send):**
1. Client A sends message to server via WebSocket.
2. Message service assigns a message ID (monotonic per conversation, e.g. Snowflake ID or `(conversation_id, sequence_number)`), writes it durably to the message store, then publishes to the recipient's channel.
3. If recipient is online, their connection server pushes it over the open WebSocket immediately.
4. If offline, message sits in the store; on reconnect, client fetches messages since its last-seen sequence number. Also trigger a push notification (APNs/FCM) for mobile.

**Data model (message store):** partition by `conversation_id` so a conversation's messages are colocated and can be read as an ordered log.
```sql
CREATE TABLE messages (
    conversation_id BIGINT NOT NULL,
    sequence_number BIGINT NOT NULL,
    sender_id BIGINT NOT NULL,
    body TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (conversation_id, sequence_number)
);
```
A wide-column store (Cassandra/DynamoDB) is a common real-world pick here because writes are append-only and reads are always "give me the last N messages of conversation X" — exactly the access pattern those stores are built for. Say this out loud even if you design with Postgres for simplicity; it shows you know the trade-off.

**Delivery guarantee:** at-least-once is achievable simply (retry until ack); exactly-once requires idempotency keys (client generates a UUID per message, server dedupes on that key) since network retries can double-send. State which one you're building and why — most chat products ship at-least-once + client-side dedupe, not true exactly-once.

**Group chats:** fan-out on write (push to every member's channel at send time) works fine up to a few hundred members. For very large groups/channels (Slack-style broadcast channels), fan-out on read is safer: readers pull recent messages rather than the server pushing to thousands of connections at once. Mention both and pick based on the group-size assumption you clarified.

**Presence (online/offline):** ephemeral, stored in Redis with a TTL, refreshed by heartbeat. This is explicitly *not* durable — losing presence data on a Redis restart is acceptable, unlike losing a message.

**Wrap-up / weaknesses to name:** message ordering across multiple sender devices, handling connection-server failover (client reconnects and resumes from last sequence number), and end-to-end encryption if required — say you'd need more time to design the key exchange properly rather than hand-waving it.

## Mock Interview 3: Behavioral (20 minutes)

Set a timer for 20 minutes total across three questions. Answer as if talking to a real interviewer — out loud, structured, no re-reading a script.

**Question 1: Tell me about yourself (2 minutes)**
Budget: 30 seconds current role, 45 seconds relevant background/trajectory, 30 seconds why you're looking now, 15 seconds transition into what you're excited about. This is not your life story — it's a 90-second pitch that sets up the rest of the interview.

**Question 2: Why do you want to join? (3 minutes)**
Budget: name something specific about the company (product, engineering culture, a problem they're solving) that you actually researched — not "I love your mission" generically. Connect it to what you want next in your career. End with a concrete thing you'd want to work on there.

**Question 3: Project deep dive (10 minutes)**
Pick your most technically interesting project. Use STAR:
- Situation (1 min): what was the context/problem.
- Task (1 min): what specifically was your responsibility.
- Action (5–6 min): the actual technical decisions — this is where most of the time goes. Be ready to go two levels deep on any technical claim ("you said you optimized the query" → what was slow, what did you change, what was the before/after number).
- Result (2 min): quantified outcome if at all possible (latency, cost, user impact), plus what you'd do differently now.

**Reference approach (what a strong answer sounds like, structurally):**

> "At [company], our checkout API had a p99 latency of 1.8s (Situation). I was asked to bring it under 500ms before a launch (Task). I profiled the request and found we were making three sequential calls to the inventory service that could run in parallel, and a database query without an index on a frequently-filtered column (Action — name the specific tools: a profiler, an EXPLAIN ANALYZE, whatever you actually used). After parallelizing the calls and adding the index, p99 dropped to 340ms, and we shipped on time (Result). In hindsight I'd have added the index a sprint earlier — I found it reactively during load testing instead of catching it in design review."

Notice: specific numbers, specific technical actions, an honest "what I'd do differently." Vague answers ("we improved performance a lot") are the single most common behavioral failure — fix this by rehearsing with real numbers pulled from your own projects before the interview, not during it.

Record yourself if possible and review immediately after: listen for filler words ("um", "like", "basically"), rambling without a clear STAR structure, and claims you couldn't defend if pushed on technical detail.

## Scoring rubric

**Mock 1 — DSA (Merge Intervals)**
- Clarified overlap semantics and sort assumption before coding: /5
- Handled edge cases (empty input, touching intervals, single interval): /5
- Stated time/space complexity (O(n log n) sort + O(n) sweep) unprompted: /5
- Code was clean and would need no rewrite: /5

**Mock 2 — System Design (Chat App)**
- Clarifying questions drove the requirements, not the other way around: /5
- Covered functional (send/receive/history) and non-functional (latency/durability/scale) requirements explicitly: /5
- Named real trade-offs (fan-out on write vs read, at-least-once vs exactly-once, SQL vs wide-column store): /5
- Handled the wrap-up honestly — named weaknesses instead of pretending the design was complete: /5

**Mock 3 — Behavioral**
- "Tell me about yourself" stayed under 2 minutes and was structured, not a ramble: /5
- "Why join" was specific to the company, not generic: /5
- Project deep dive followed STAR with quantified results and survived a hypothetical "go deeper" follow-up: /5

## Debrief

Right after each mock, write three things while it's fresh: the single biggest mistake, its root cause (gap in knowledge, nerves, or poor time management), and the fix (a problem to redo, a story to rewrite with real numbers, a concept to re-read). If you recorded yourself, watch back only the segments scored 3/5 or below — don't waste time re-watching what already went well. Anything under 3/5 goes on tomorrow's warm-up list.

## Today's checklist

- [ ] Mock 1: Merge Intervals solved within 30 minutes, thinking out loud
- [ ] Mock 1: logged what went well and what to improve
- [ ] Mock 2: followed the 4-step system design framework with correct time splits
- [ ] Mock 2: spoke continuously, no long silences
- [ ] Mock 3: answered all 3 behavioral questions within 20 minutes
- [ ] Mock 3: recorded and reviewed the answers
- [ ] Scored every mock against the rubric and logged debrief notes
