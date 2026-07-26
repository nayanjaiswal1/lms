---
kind: lesson
id_key: interview-prep-45/day-18
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Greedy Algorithms"
position: 18
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Greedy algorithms make the locally best choice at every step and never look back — no recursion tree, no backtracking, no undo. That makes them fast (usually O(n log n) or better) but the entire interview is about *proving* the greedy choice is actually safe, because for every problem where greedy works there's a near-identical variant where it silently produces a wrong answer.

## Greedy choice property

A problem has the greedy choice property if a locally optimal choice at each step leads to a globally optimal solution, and — critically — making that choice never rules out reaching the true optimum. This needs to be true, not assumed. The standard way to convince yourself (and an interviewer) is an exchange argument: take an optimal solution that didn't make the greedy choice, show you can swap it in without making the solution worse, therefore the greedy choice is at least as good.

Example: Jump Game II (minimum jumps to reach the end). The greedy choice — at each step, jump to whichever reachable position extends your *reach* the furthest, not necessarily the position closest to the end — works because reach is transitive: whatever the furthest-reaching position can eventually access, every other reachable position can access too (or less). You lose nothing by maximizing reach at every step.

```python
# Greedy choice property check, informally:
# 1. State the greedy rule in one sentence.
# 2. Ask: does an optimal solution exist that makes a DIFFERENT choice here
#    and still does at least as well? If yes, greedy is wrong.
# 3. If no such solution exists, the greedy choice is safe.
```

## Local vs global optimum

The failure mode of greedy is a locally attractive choice that closes off a better global path. Classic counterexample: coin change with denominations `[1, 3, 4]` and target `6`. Greedy picks the largest coin `<=` remaining each time: `4 + 1 + 1 = 3` coins. Optimal is `3 + 3 = 2` coins. Greedy's "take the biggest coin now" was locally sensible but globally wrong — this is why coin change in general needs DP, not greedy (it only works greedily for specific denomination sets, like US currency).

The interview skill is recognizing *which* category a new problem falls into before you commit to an approach. If you can't construct a proof or a clean exchange argument in under a minute, that's a signal to fall back to DP or search instead of forcing greedy.

## When greedy fails

Signs a problem is not greedy-safe:

- The "obviously best" local choice depends on information you don't have yet (later constraints change what "best" means).
- A counterexample is easy to construct by hand (always try 2-3 small cases before committing).
- The problem asks for a count of *all* ways, or requires backtracking over choices — greedy produces one answer, not an exploration of alternatives.

If you can't rule these out quickly, say so out loud in the interview and default to DP — proposing greedy and getting the counterexample thrown back at you mid-interview is a worse outcome than never proposing it.

### Jump Game

[LeetCode 55 — Jump Game](https://leetcode.com/problems/jump-game/) — Greedy — Forward traversal

**Intuition:** Track the furthest index reachable so far. If you ever reach an index beyond that furthest-reachable point before updating it, you're stuck — otherwise, by the time you reach the last index, it was always within reach.

**Approach:** Single forward pass; maintain `max_reach`; at each index `i`, if `i > max_reach` the current index is unreachable, so fail immediately. Otherwise update `max_reach = max(max_reach, i + nums[i])`.

```python
def can_jump(nums: list[int]) -> bool:
    max_reach = 0
    for i, num in enumerate(nums):
        if i > max_reach:
            return False   # can't even reach this index
        max_reach = max(max_reach, i + num)
        if max_reach >= len(nums) - 1:
            return True
    return True
```

**Complexity:** O(n) time, O(1) space.

**Common mistakes:** checking `max_reach >= len(nums) - 1` only at the very end instead of updating and checking inside the loop (still correct but misses the early-exit optimization); using DP with O(n^2) reachability checks when the greedy one-pass solution is strictly better and simpler.

### Jump Game II

[LeetCode 45 — Jump Game II](https://leetcode.com/problems/jump-game-ii/) — Greedy — Minimum jumps

**Intuition:** Think in "levels," like BFS on an implicit graph. `current_end` marks the boundary of the current jump's reach; `farthest` tracks the best reach achievable from any position within the current level. When you hit `current_end`, you're forced to take another jump — increment the counter and advance the boundary to `farthest`.

**Approach:** This is the "maximize reach at every step" greedy choice discussed above, formalized into a BFS-level counter.

```python
def jump(nums: list[int]) -> int:
    jumps = 0
    current_end = 0
    farthest = 0

    for i in range(len(nums) - 1):   # don't need to jump from the last index
        farthest = max(farthest, i + nums[i])
        if i == current_end:
            jumps += 1
            current_end = farthest

    return jumps
```

**Complexity:** O(n) time, O(1) space.

**Common mistakes:** confusing this with Jump Game I — this problem counts *minimum jumps*, not reachability, and the greedy rule (maximize reach, advance boundary only when forced) is different from a simple reachability scan; looping through the entire array including the last index (off-by-one — you never need to jump *from* the destination).

### Meeting Rooms II

[LeetCode 253 — Meeting Rooms II](https://leetcode.com/problems/meeting-rooms-ii/) — Greedy — Min heap

**Intuition:** The number of rooms needed at any instant equals the number of meetings currently overlapping. Sort meetings by start time, then use a min-heap of end times to track which room frees up soonest — if the earliest-ending meeting has already ended by the time the next meeting starts, reuse that room instead of allocating a new one.

**Approach:** Sort by start. Maintain a min-heap of currently occupied rooms' end times. For each meeting, pop-and-reuse if the heap's minimum end time is `<=` the new meeting's start; otherwise push a new end time (a new room). The heap's final size is the answer.

```python
import heapq

def min_meeting_rooms(intervals: list[list[int]]) -> int:
    if not intervals:
        return 0

    intervals.sort(key=lambda pair: pair[0])
    heap = []   # min-heap of end times of currently occupied rooms

    for start, end in intervals:
        if heap and heap[0] <= start:
            heapq.heappop(heap)   # reuse the room that just freed up
        heapq.heappush(heap, end)

    return len(heap)
```

**Complexity:** O(n log n) time (sort plus n heap operations), O(n) space for the heap.

**Common mistakes:** forgetting to sort by start time first — the greedy reuse logic assumes meetings are processed in chronological order; using `<` instead of `<=` when comparing end time to start time (a meeting ending exactly when another starts can share a room, assuming the problem's convention allows it — confirm this with the interviewer).

### Task Scheduler

[LeetCode 621 — Task Scheduler](https://leetcode.com/problems/task-scheduler/) — Greedy — Formula

**Intuition:** The bottleneck is the most frequent task — it needs `n` idle slots between each repetition. Build a schedule around the max-frequency task(s): `(max_freq - 1)` full cooldown blocks of size `(n + 1)`, plus however many tasks tie for max frequency in the last block. Anything beyond that fills idle slots for free.

**Approach:** Compute frequency counts, find `max_freq` and the count of tasks tied at `max_freq`. The formula: `max(len(tasks), (max_freq - 1) * (n + 1) + count_of_max_freq_tasks)`.

```python
from collections import Counter

def least_interval(tasks: list[str], n: int) -> int:
    counts = Counter(tasks)
    max_freq = max(counts.values())
    num_max = sum(1 for count in counts.values() if count == max_freq)

    # (max_freq - 1) full blocks of size (n + 1), plus the final partial block
    formula = (max_freq - 1) * (n + 1) + num_max
    return max(len(tasks), formula)
```

**Complexity:** O(k) time where `k` is the number of tasks (counting) plus O(26) for the frequency scan — effectively O(k), O(1) space (bounded by 26 uppercase letters).

**Common mistakes:** forgetting `max(len(tasks), formula)` — when there are enough distinct tasks to fill every idle slot, the formula alone can undercount and give a value smaller than the task count itself; miscounting `num_max` (must count *all* tasks tied at the max frequency, not just the max task itself).

## Key takeaways

- Greedy is fast but unforgiving — always be ready to justify the greedy choice with an exchange argument, not just intuition.
- "Maximize reach" (Jump Game I & II) is a recurring greedy pattern: track the furthest achievable state and only commit to a new "level" when forced.
- Meeting Rooms II is greedy-plus-heap: sort by start, use a min-heap of end times to detect reusable resources in O(log n) per meeting.
- Task Scheduler reduces to a formula because the max-frequency task structurally determines the minimum schedule length — recognize when a problem has a closed-form answer instead of needing simulation.
- Always sanity-check greedy against 2-3 small counterexamples before committing in an interview — coin change with `[1,3,4]` is the canonical "greedy looks right but isn't."
- If you can't prove the greedy choice safe quickly, say so and fall back to DP rather than guessing.
