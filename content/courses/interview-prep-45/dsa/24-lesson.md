---
kind: lesson
id_key: interview-prep-45/day-24
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Interval Problems"
position: 24
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
---

Interval problems — merging, inserting, scheduling — show up constantly because real systems deal in time ranges: calendar bookings, resource allocation, CPU scheduling. The entire category collapses to one insight: sort first, then a single linear pass. Today you learn the sort-key decision and apply it across four problems.

## Sorting intervals by start/end

Almost every interval problem begins with a sort, and **which field you sort by is the single most important decision** — get it wrong and no amount of clever logic afterward fixes it.

- **Sort by start time** when you're merging overlaps or inserting a new interval — you need to process intervals in the order they begin to correctly detect chains of overlap.
- **Sort by end time** when you're doing interval scheduling / selection (maximize non-overlapping intervals, minimum "arrows" to cover ranges) — greedily picking the interval that finishes earliest leaves the most room for future choices.

```python
intervals = [[1, 3], [2, 6], [8, 10], [15, 18]]

by_start = sorted(intervals, key=lambda x: x[0])
by_end = sorted(intervals, key=lambda x: x[1])
```

**Why this matters so much:** the correctness of the entire single-pass algorithm that follows depends on the sort establishing the right invariant (e.g., "if intervals are sorted by start, then once I've moved past an interval, nothing later can start before it did").

## Merging overlapping intervals

Once sorted by start, merging is a single linear pass: keep a "current merged interval," and for each next interval, either fold it in (if it overlaps) or close out the current one and start a new one.

```python
def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    if not intervals:
        return []
    intervals.sort(key=lambda x: x[0])
    merged = [intervals[0]]

    for start, end in intervals[1:]:
        last_end = merged[-1][1]
        if start <= last_end:              # overlaps (or touches) the last merged interval
            merged[-1][1] = max(last_end, end)
        else:
            merged.append([start, end])

    return merged
```

**The overlap check that trips people up:** `start <= last_end`, not `start < last_end` — intervals `[1, 3]` and `[3, 5]` are considered overlapping (touching) in most problem statements, and merge into `[1, 5]`. Always check the problem statement for whether touching endpoints count as overlapping.

## Scheduling problems

Scheduling / selection problems ask "how many intervals can you fit without overlap" (or the complementary "how many do you need to remove"). The greedy strategy: **sort by end time, then greedily keep any interval whose start is ≥ the end of the last kept interval.**

```python
def max_non_overlapping(intervals: list[list[int]]) -> int:
    if not intervals:
        return 0
    intervals.sort(key=lambda x: x[1])  # sort by END time
    count = 1
    last_end = intervals[0][1]

    for start, end in intervals[1:]:
        if start >= last_end:
            count += 1
            last_end = end

    return count
```

**Why "sort by end, pick earliest-ending" is optimal:** the interval that finishes earliest leaves the most remaining room for future intervals — this is a classic exchange-argument greedy proof (any optimal solution can be transformed to include the earliest-ending interval without becoming worse), and it's worth being able to state that justification out loud in an interview.

## Merge Intervals

[LeetCode 56](https://leetcode.com/problems/merge-intervals/) — Intervals

**Intuition:** Direct application of the merging pattern above — sort by start, sweep once, fold overlapping intervals together.

**Approach:** Sort by start time. Maintain a result list; compare each interval's start against the last merged interval's end.

```python
def merge(intervals: list[list[int]]) -> list[list[int]]:
    intervals.sort(key=lambda x: x[0])
    merged = []

    for interval in intervals:
        if not merged or interval[0] > merged[-1][1]:
            merged.append(interval)
        else:
            merged[-1][1] = max(merged[-1][1], interval[1])

    return merged
```

**Complexity:** Time O(n log n) for the sort (the pass itself is O(n)), space O(n) for the output.

**Common mistakes:** Using `>=` instead of `>` for the "no overlap" branch (off-by-one on the touching-endpoints rule — verify against the problem's stated examples); mutating the input list's inner lists when the interviewer expects the original untouched (build fresh `[start, end]` pairs if that matters).

## Insert Interval

[LeetCode 57](https://leetcode.com/problems/insert-interval/) — Intervals

**Intuition:** The input is already sorted and non-overlapping — you're inserting one new interval and merging only where it collides. Three phases: intervals entirely before the new one (copy as-is), intervals overlapping the new one (merge into it), intervals entirely after (copy as-is).

**Approach:** Walk the list once. Append intervals ending before the new interval starts. Merge all intervals that overlap the new interval (expanding its bounds). Append the merged interval, then append everything remaining.

```python
def insert(intervals: list[list[int]], newInterval: list[int]) -> list[list[int]]:
    result = []
    i, n = 0, len(intervals)
    new_start, new_end = newInterval

    while i < n and intervals[i][1] < new_start:
        result.append(intervals[i])
        i += 1

    while i < n and intervals[i][0] <= new_end:
        new_start = min(new_start, intervals[i][0])
        new_end = max(new_end, intervals[i][1])
        i += 1

    result.append([new_start, new_end])

    while i < n:
        result.append(intervals[i])
        i += 1

    return result
```

**Complexity:** Time O(n) — no sort needed since the input is already sorted. Space O(n) for the output.

**Common mistakes:** Sorting the input unnecessarily (it's guaranteed pre-sorted — sorting is wasted O(n log n) work and can mask a bug in the merge logic); using `<` instead of `<=` in the overlap-detection loop, which misses touching intervals that should merge.

## Meeting Rooms

[LeetCode 252](https://leetcode.com/problems/meeting-rooms/) — Intervals

**Intuition:** Can one person attend all meetings? Equivalent to: do any two intervals overlap? Sort by start time; if any interval starts before the previous one ends, there's a conflict.

**Approach:** Sort by start. Single pass comparing each interval's start against the previous interval's end.

```python
def canAttendMeetings(intervals: list[list[int]]) -> bool:
    intervals.sort(key=lambda x: x[0])
    for i in range(1, len(intervals)):
        if intervals[i][0] < intervals[i - 1][1]:
            return False
    return True
```

**Complexity:** Time O(n log n), space O(1) extra (ignoring sort space).

**Common mistakes:** Confusing this with Meeting Rooms II (below) and building a heap when a simple sorted pass suffices — this variant only asks a yes/no question, not "how many rooms."

**Note on Meeting Rooms II (the natural follow-up, LeetCode 253 — often paywalled but referenced constantly in interviews):** it asks for the *minimum number of rooms* needed, which requires tracking how many meetings are simultaneously active. The standard approach sorts start times and end times **separately**, then sweeps both with two pointers: advance the start pointer, and every time a meeting starts before the earliest active meeting ends, you need another room; otherwise a room frees up. This is the natural extension of the "sort by end, greedy" scheduling idea to a counting problem instead of a selection problem.

## Minimum Number of Arrows to Burst Balloons

[LeetCode 452](https://leetcode.com/problems/minimum-number-of-arrows-to-burst-balloons/) — Intervals

**Intuition:** An arrow shot at position x bursts every balloon whose interval contains x. Minimize arrows = maximize how many balloons one arrow can burst at once = the classic "sort by end time, greedily group overlapping intervals" scheduling pattern, just phrased as balloons instead of meetings.

**Approach:** Sort by end coordinate. Shoot an arrow at the end of the first (earliest-ending) balloon's range; any subsequent balloon whose start is ≤ that arrow position is burst by the same arrow. When a balloon starts after the current arrow position, you need a new arrow.

```python
def findMinArrowShots(points: list[list[int]]) -> int:
    if not points:
        return 0
    points.sort(key=lambda x: x[1])
    arrows = 1
    arrow_pos = points[0][1]

    for start, end in points[1:]:
        if start > arrow_pos:
            arrows += 1
            arrow_pos = end

    return arrows
```

**Complexity:** Time O(n log n) for the sort, space O(1) extra.

**Common mistakes:** Sorting by start instead of end — this is the exact "wrong sort key" trap the concept section warns about, and it produces an incorrect greedy result here; using `>=` instead of `>` in the new-arrow check (touching balloons, e.g. `[1,2]` and `[2,3]`, can share one arrow at position 2 — verify against the problem's boundary convention).

## Key takeaways

- Every interval problem starts with a sort — the choice between sort-by-start (merging, inserting) and sort-by-end (scheduling, minimizing arrows/resources) determines whether the rest of your algorithm is even correct.
- Merging is a single linear pass after sorting by start: fold in overlaps, close out and start fresh otherwise.
- Greedy interval scheduling (sort by end, keep the earliest-finishing non-conflicting interval) is provably optimal via an exchange argument — be ready to explain why, not just recite the algorithm.
- Meeting Rooms I asks yes/no (any overlap); Meeting Rooms II asks a count (min rooms needed) — recognizing which one you're solving prevents over- or under-engineering the solution.
- Watch the boundary convention (`<` vs `<=`) at every overlap check — touching endpoints are a frequent off-by-one trap across every problem in this category.
