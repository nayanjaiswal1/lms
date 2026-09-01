---
kind: lesson
id_key: interview-prep-45/day-38
course: interview-prep-45
section: final-prep
section_title: "Weakness Focus & Final Prep"
section_position: 8
title: "Final Practice — DSA and System Design"
position: 38
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

From here to Day 45 the goal shifts from *learning* patterns to *executing* them fast and clean under pressure. Today is a speed drill: four core DSA patterns at 15 minutes each, three big system designs at 40 minutes each, then a wind-down. Treat every problem like it's the real interview: talk through your approach before you type.

## Block 1 (60 min): Easy/Medium Pattern Speed Round

15 minutes per problem, one from each pattern. If you go over 15 minutes, stop, look at the approach (not the code), and re-time a fresh attempt. Speed here comes from recognizing the pattern instantly, not from typing faster.

### Two Pointers

```python
def two_sum_sorted(nums: list[int], target: int) -> list[int]:
    lo, hi = 0, len(nums) - 1
    while lo < hi:
        s = nums[lo] + nums[hi]
        if s == target:
            return [lo, hi]
        elif s < target:
            lo += 1   # need a bigger sum
        else:
            hi -= 1   # need a smaller sum
    return []
```
**Use when:** sorted array/string, need a pair/triple satisfying a sum or comparison condition, or in-place partitioning (Dutch flag).

### Sliding Window

```python
def longest_substring_no_repeat(s: str) -> int:
    seen = {}
    left = 0
    best = 0
    for right, ch in enumerate(s):
        if ch in seen and seen[ch] >= left:
            left = seen[ch] + 1   # shrink window past the duplicate
        seen[ch] = right
        best = max(best, right - left + 1)
    return best
```
**Use when:** contiguous subarray/substring optimizing a size, sum, or count of distinct elements. The window only ever expands right and shrinks left, never resets.

### Binary Search

```python
def search_rotated(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if nums[mid] == target:
            return mid
        if nums[lo] <= nums[mid]:            # left half is sorted
            if nums[lo] <= target < nums[mid]:
                hi = mid - 1
            else:
                lo = mid + 1
        else:                                 # right half is sorted
            if nums[mid] < target <= nums[hi]:
                lo = mid + 1
            else:
                hi = mid - 1
    return -1
```
**Use when:** sorted (or "sorted with a twist") search space, or the classic tell: "minimize the maximum" / "maximize the minimum" over a monotonic predicate (binary search on the answer, not the array).

### BFS/DFS

```python
from collections import deque

def num_islands(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])
    visited = set()
    count = 0

    def bfs(r, c):
        q = deque([(r, c)])
        visited.add((r, c))
        while q:
            cr, cc = q.popleft()
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nr, nc = cr + dr, cc + dc
                if (0 <= nr < rows and 0 <= nc < cols
                        and (nr, nc) not in visited
                        and grid[nr][nc] == "1"):
                    visited.add((nr, nc))
                    q.append((nr, nc))

    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == "1" and (r, c) not in visited:
                bfs(r, c)
                count += 1
    return count
```
**Use when:** graph/grid traversal. BFS for shortest path in unweighted graphs or level-order processing; DFS for connectivity, cycle detection, backtracking, or when recursion naturally fits (trees).

**Goal check:** could you write each of these four without looking, in under 15 minutes, with correct edge cases (empty input, single element, no match)? If any pattern took longer than 15, that's your remaining gap. The fix isn't "more LeetCode," it's re-drilling that one specific pattern tomorrow morning before it fades.

## Block 2 (120 min): Final System Design, Speed and Confidence

Three designs, 40 minutes each, full run through requirements, capacity, API, high-level, deep dive, bottlenecks. The focus today isn't new material. It's talking continuously and confidently without long silences.

- **Design Uber.** Dispatch matching (geospatial indexing: geohash or quadtree), real-time location updates (write-heavy, short-TTL data, don't over-persist it), surge pricing as a rate-limited pub/sub signal, ETA calculation as a separate read-optimized service.
- **Design Netflix.** Video encoding pipeline (async, multiple bitrates/resolutions), CDN-first delivery (most requests never hit origin), a recommendation system as a batch-computed read path rather than synchronous per-request ML, metadata service separate from the video-serving path.
- **Design Ticketmaster.** The hard part is preventing overselling under high concurrent demand for the same seat: short-TTL reservation holds (e.g., 10 min in Redis) before payment, queue-based access control during high-demand on-sales (virtual waiting room), and idempotent purchase confirmation.

For each, force yourself to narrate the tradeoff and not just the choice. "I'm using a geohash here instead of a quadtree because it's simpler to shard by prefix across services, at the cost of uneven cell sizes near the poles" is a much stronger answer than silently drawing a box labeled "geo index."

## Block 3 (60 min): Mock Interview Routine + Wind-Down

Light touch today: you have real mocks coming on Day 39, so don't burn out tonight.

- One light practice problem or design walkthrough, whichever you're least confident on right now, just to end the day on a win, not a struggle.
- Prepare tomorrow's materials: charged devices, quiet room booked/blocked, IDE and whiteboard tool (excalidraw/tldraw) open and tested, water nearby.
- Get good rest. Sleep is part of the prep plan, not a break from it: tired brains lose pattern recognition first.

Notice that speed, in both the DSA round and the design round, comes from the same place: recognizing a shape you've seen before instead of reasoning it out fresh. That recognition is a practiced skill, not a personality trait, which is why today was built around repetition rather than new material. Tonight stays light on purpose. Tomorrow's mocks need a rested brain more than a maximally drilled one.
