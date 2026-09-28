---
kind: lesson
id_key: interview-prep-45/day-24
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Interval Problems"
position: 22
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
---

Think of a shared calendar app trying to figure out how many meeting rooms a company needs, or a delivery app merging overlapping time slots for a driver. Interval problems, merging, inserting, scheduling, show up constantly because real systems deal in time ranges: calendar bookings, resource allocation, CPU scheduling. The whole category collapses to one insight: sort first, then a single linear pass. This lesson covers the sort-key decision and applies it across four problems.

## Sorting intervals by start or end

Almost every interval problem begins with a sort, and **which field you sort by is the single most important decision**. Get it wrong and no amount of clever logic afterward fixes it.

- **Sort by start time** when merging overlaps or inserting a new interval. You need to process intervals in the order they begin to correctly detect chains of overlap.
- **Sort by end time** when doing interval scheduling or selection (maximize non-overlapping intervals, minimum "arrows" to cover ranges). Greedily picking the interval that finishes earliest leaves the most room for future choices.

```python
intervals = [[1, 3], [2, 6], [8, 10], [15, 18]]

by_start = sorted(intervals, key=lambda x: x[0])
by_end = sorted(intervals, key=lambda x: x[1])
```
```javascript +
const intervals = [[1, 3], [2, 6], [8, 10], [15, 18]];

const byStart = [...intervals].sort((a, b) => a[0] - b[0]);
const byEnd = [...intervals].sort((a, b) => a[1] - b[1]);
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        List<int[]> intervals = new ArrayList<>(List.of(
            new int[]{1, 3}, new int[]{2, 6}, new int[]{8, 10}, new int[]{15, 18}
        ));

        List<int[]> byStart = new ArrayList<>(intervals);
        byStart.sort((a, b) -> Integer.compare(a[0], b[0]));

        List<int[]> byEnd = new ArrayList<>(intervals);
        byEnd.sort((a, b) -> Integer.compare(a[1], b[1]));

        for (int[] interval : byStart) {
            System.out.println(Arrays.toString(interval));
        }
        for (int[] interval : byEnd) {
            System.out.println(Arrays.toString(interval));
        }
    }
}
```

Why this matters so much: the correctness of the whole single-pass algorithm that follows depends on the sort setting up the right invariant. For example, once you've sorted by start and moved past an interval, you know nothing later can start before it did.

> **Remember:** merging and inserting sort by start. Scheduling and selection sort by end. Pick the wrong one and the bug hides in code that still looks reasonable.

```knowledge-check
{ "questions": [
    { "id": "dsa-intervals-sort-key-q1", "type": "mcq",
      "prompt": "When should you sort intervals by end time instead of start time?",
      "options": [
        {"id": "a", "text": "When solving a scheduling/selection problem, like maximizing non-overlapping intervals, where greedily picking the earliest-finishing option leaves the most room for future choices"},
        {"id": "b", "text": "Always; sorting by end time works for every interval problem"},
        {"id": "c", "text": "Only when the intervals are already sorted by start time"},
        {"id": "d", "text": "Never; merging and scheduling both require sorting by start time"}
      ],
      "correct": "a",
      "explanation": "Scheduling/selection problems want to fit as many non-overlapping intervals as possible, and picking the earliest-ending option first is what leaves maximum room for everything after it." }
] }
```

## Merging overlapping intervals

Once sorted by start, merging is a single linear pass: keep a "current merged interval," and for each next interval, either fold it in if it overlaps, or close out the current one and start a new one.

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
```javascript +
function mergeIntervals(intervals) {
    if (intervals.length === 0) return [];
    const sorted = [...intervals].sort((a, b) => a[0] - b[0]);
    const merged = [sorted[0]];

    for (let i = 1; i < sorted.length; i++) {
        const [start, end] = sorted[i];
        const lastEnd = merged[merged.length - 1][1];
        if (start <= lastEnd) {            // overlaps (or touches) the last merged interval
            merged[merged.length - 1][1] = Math.max(lastEnd, end);
        } else {
            merged.push([start, end]);
        }
    }

    return merged;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] intervals = {{1, 3}, {2, 6}, {8, 10}, {15, 18}};
        for (int[] interval : mergeIntervals(intervals)) {
            System.out.println(Arrays.toString(interval));
        }
    }

    static List<int[]> mergeIntervals(int[][] intervals) {
        if (intervals.length == 0) return new ArrayList<>();

        int[][] sorted = intervals.clone();
        Arrays.sort(sorted, (a, b) -> Integer.compare(a[0], b[0]));

        List<int[]> merged = new ArrayList<>();
        merged.add(sorted[0]);

        for (int i = 1; i < sorted.length; i++) {
            int start = sorted[i][0];
            int end = sorted[i][1];
            int[] last = merged.get(merged.size() - 1);
            if (start <= last[1]) {           // overlaps (or touches) the last merged interval
                last[1] = Math.max(last[1], end);
            } else {
                merged.add(new int[]{start, end});
            }
        }

        return merged;
    }
}
```

The overlap check that trips people up: `start <= last_end`, not `start < last_end`. Intervals `[1, 3]` and `[3, 5]` count as overlapping (touching) in most problem statements, and merge into `[1, 5]`. Always check the problem statement for whether touching endpoints count as overlapping.

> **Remember:** once sorted by start, one pass is enough. The only question at each step is whether the new interval touches or overlaps the one you're currently building.

```knowledge-check
{ "questions": [
    { "id": "dsa-intervals-merging-q1", "type": "mcq",
      "prompt": "In the merge-overlapping-intervals sweep, what does `start <= last_end` (rather than strict `<`) usually mean for the problem's convention?",
      "options": [
        {"id": "a", "text": "Touching intervals, like [1,3] and [3,5], count as overlapping and should be merged into one interval"},
        {"id": "b", "text": "The intervals must never touch, or the algorithm is broken"},
        {"id": "c", "text": "It only matters when intervals contain negative numbers"},
        {"id": "d", "text": "It has no effect on the result either way"}
      ],
      "correct": "a",
      "explanation": "Using <= instead of < treats an interval that starts exactly where the previous one ends as overlapping, which is the usual convention for 'merge intervals' style problems." }
] }
```

## Scheduling problems

Scheduling and selection problems ask "how many intervals can you fit without overlap," or the flip side, "how many do you need to remove." The greedy strategy: **sort by end time, then greedily keep any interval whose start is at least the end of the last kept interval.**

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
```javascript +
function maxNonOverlapping(intervals) {
    if (intervals.length === 0) return 0;
    const sorted = [...intervals].sort((a, b) => a[1] - b[1]); // sort by END time
    let count = 1;
    let lastEnd = sorted[0][1];

    for (let i = 1; i < sorted.length; i++) {
        const [start, end] = sorted[i];
        if (start >= lastEnd) {
            count++;
            lastEnd = end;
        }
    }

    return count;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] intervals = {{1, 2}, {2, 3}, {3, 4}, {1, 3}};
        System.out.println(maxNonOverlapping(intervals));
    }

    static int maxNonOverlapping(int[][] intervals) {
        if (intervals.length == 0) return 0;

        int[][] sorted = intervals.clone();
        Arrays.sort(sorted, (a, b) -> Integer.compare(a[1], b[1])); // sort by END time

        int count = 1;
        int lastEnd = sorted[0][1];

        for (int i = 1; i < sorted.length; i++) {
            int start = sorted[i][0];
            int end = sorted[i][1];
            if (start >= lastEnd) {
                count++;
                lastEnd = end;
            }
        }

        return count;
    }
}
```

Why "sort by end, pick the earliest-ending" is optimal: the interval that finishes earliest leaves the most remaining room for future intervals. This is a classic exchange-argument greedy proof: any optimal solution can be rearranged to include the earliest-ending interval without becoming worse, and it's worth stating that justification out loud in an interview.

> **Remember:** the interval that ends soonest leaves the most room behind it. That's why scheduling problems sort by end, not by start.

```knowledge-check
{ "questions": [
    { "id": "dsa-intervals-scheduling-q1", "type": "mcq",
      "prompt": "Why does greedily picking the earliest-ending interval work for maximizing the count of non-overlapping intervals?",
      "options": [
        {"id": "a", "text": "The earliest-ending interval leaves the most remaining room for future intervals, so any optimal solution can be rearranged to include it without getting worse"},
        {"id": "b", "text": "It works because intervals are always the same length"},
        {"id": "c", "text": "It works only when there are fewer than 10 intervals"},
        {"id": "d", "text": "It's actually incorrect; the correct approach requires dynamic programming"}
      ],
      "correct": "a",
      "explanation": "This is the exchange-argument proof: swapping in the earliest-ending interval for whatever an optimal solution chose instead never makes the solution worse, so greedy is safe here." }
] }
```

## Merge Intervals

[LeetCode 56](https://leetcode.com/problems/merge-intervals/) — Intervals

**Intuition:** Direct application of the merging pattern above: sort by start, sweep once, fold overlapping intervals together.

**Approach:** Sort by start time. Keep a result list; compare each interval's start against the last merged interval's end.

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
```javascript +
function merge(intervals) {
    const sorted = [...intervals].sort((a, b) => a[0] - b[0]);
    const merged = [];

    for (const interval of sorted) {
        if (merged.length === 0 || interval[0] > merged[merged.length - 1][1]) {
            merged.push(interval);
        } else {
            merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], interval[1]);
        }
    }

    return merged;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] intervals = {{1, 3}, {2, 6}, {8, 10}, {15, 18}};
        int[][] result = merge(intervals);
        for (int[] interval : result) {
            System.out.println(Arrays.toString(interval));
        }
    }

    static int[][] merge(int[][] intervals) {
        int[][] sorted = intervals.clone();
        Arrays.sort(sorted, (a, b) -> Integer.compare(a[0], b[0]));

        List<int[]> merged = new ArrayList<>();
        for (int[] interval : sorted) {
            if (merged.isEmpty() || interval[0] > merged.get(merged.size() - 1)[1]) {
                merged.add(interval);
            } else {
                int[] last = merged.get(merged.size() - 1);
                last[1] = Math.max(last[1], interval[1]);
            }
        }

        return merged.toArray(new int[0][]);
    }
}
```

**Complexity:** Time O(n log n) for the sort (the pass itself is O(n)), space O(n) for the output.

**Common mistakes:** using `>=` instead of `>` for the "no overlap" branch, an off-by-one on the touching-endpoints rule; verify against the problem's stated examples. Also, mutating the input list's inner lists when the interviewer expects the original untouched: build fresh `[start, end]` pairs if that matters.

> **Remember:** Merge Intervals is the concept section's algorithm applied directly, with no extra wrinkle.

## Insert Interval

[LeetCode 57](https://leetcode.com/problems/insert-interval/) — Intervals

**Intuition:** The input is already sorted and non-overlapping; you're inserting one new interval and merging only where it collides. Three phases: intervals entirely before the new one (copy as-is), intervals overlapping the new one (merge into it), intervals entirely after (copy as-is).

**Approach:** Walk the list once. Append intervals that end before the new interval starts. Merge all intervals that overlap the new interval, expanding its bounds. Append the merged interval, then append everything remaining.

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
```javascript +
function insert(intervals, newInterval) {
    const result = [];
    let i = 0;
    const n = intervals.length;
    let [newStart, newEnd] = newInterval;

    while (i < n && intervals[i][1] < newStart) {
        result.push(intervals[i]);
        i++;
    }

    while (i < n && intervals[i][0] <= newEnd) {
        newStart = Math.min(newStart, intervals[i][0]);
        newEnd = Math.max(newEnd, intervals[i][1]);
        i++;
    }

    result.push([newStart, newEnd]);

    while (i < n) {
        result.push(intervals[i]);
        i++;
    }

    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] intervals = {{1, 3}, {6, 9}};
        int[] newInterval = {2, 5};
        for (int[] interval : insert(intervals, newInterval)) {
            System.out.println(Arrays.toString(interval));
        }
    }

    static int[][] insert(int[][] intervals, int[] newInterval) {
        List<int[]> result = new ArrayList<>();
        int i = 0;
        int n = intervals.length;
        int newStart = newInterval[0];
        int newEnd = newInterval[1];

        while (i < n && intervals[i][1] < newStart) {
            result.add(intervals[i]);
            i++;
        }

        while (i < n && intervals[i][0] <= newEnd) {
            newStart = Math.min(newStart, intervals[i][0]);
            newEnd = Math.max(newEnd, intervals[i][1]);
            i++;
        }

        result.add(new int[]{newStart, newEnd});

        while (i < n) {
            result.add(intervals[i]);
            i++;
        }

        return result.toArray(new int[0][]);
    }
}
```

**Complexity:** Time O(n): no sort needed since the input is already sorted. Space O(n) for the output.

**Common mistakes:** sorting the input unnecessarily. It's guaranteed pre-sorted, so sorting wastes O(n log n) work and can hide a bug in the merge logic. Also, using `<` instead of `<=` in the overlap-detection loop, which misses touching intervals that should merge.

> **Remember:** the input is already sorted, so don't sort it again. Just walk it once: before, overlapping, after.

## Meeting Rooms

[LeetCode 252](https://leetcode.com/problems/meeting-rooms/) — Intervals

**Intuition:** Can one person attend all meetings? That's the same question as: do any two intervals overlap? Sort by start time; if any interval starts before the previous one ends, there's a conflict.

**Approach:** Sort by start. Single pass comparing each interval's start against the previous interval's end.

```python
def canAttendMeetings(intervals: list[list[int]]) -> bool:
    intervals.sort(key=lambda x: x[0])
    for i in range(1, len(intervals)):
        if intervals[i][0] < intervals[i - 1][1]:
            return False
    return True
```
```javascript +
function canAttendMeetings(intervals) {
    const sorted = [...intervals].sort((a, b) => a[0] - b[0]);
    for (let i = 1; i < sorted.length; i++) {
        if (sorted[i][0] < sorted[i - 1][1]) {
            return false;
        }
    }
    return true;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] intervals = {{0, 30}, {5, 10}, {15, 20}};
        System.out.println(canAttendMeetings(intervals));
    }

    static boolean canAttendMeetings(int[][] intervals) {
        int[][] sorted = intervals.clone();
        Arrays.sort(sorted, (a, b) -> Integer.compare(a[0], b[0]));

        for (int i = 1; i < sorted.length; i++) {
            if (sorted[i][0] < sorted[i - 1][1]) {
                return false;
            }
        }
        return true;
    }
}
```

**Complexity:** Time O(n log n), space O(1) extra (ignoring sort space).

**Common mistakes:** confusing this with Meeting Rooms II below, and building a heap when a simple sorted pass is enough. This variant only asks a yes/no question, not "how many rooms."

Meeting Rooms II (the natural follow-up, LeetCode 253, referenced constantly in interviews even where it's paywalled) asks for the *minimum number of rooms* needed, which requires tracking how many meetings are active at once. The Greedy Algorithms lesson's Meeting Rooms II walkthrough covers this in full: sort by start, track occupied rooms' end times in a min-heap, and reuse a room the moment its meeting has ended.

> **Remember:** "can one person attend everything" is just "do any two intervals overlap." Sort by start and check neighbors.

## Minimum Number of Arrows to Burst Balloons

[LeetCode 452](https://leetcode.com/problems/minimum-number-of-arrows-to-burst-balloons/) — Intervals

**Intuition:** An arrow shot at position x bursts every balloon whose interval contains x. Minimizing arrows means maximizing how many balloons one arrow can burst at once, which is the same "sort by end time, greedily group overlapping intervals" scheduling pattern from earlier in this lesson, just phrased as balloons instead of meetings.

**Approach:** Sort by end coordinate. Shoot an arrow at the end of the first, earliest-ending, balloon's range; any later balloon whose start is `<=` that arrow position is burst by the same arrow. When a balloon starts after the current arrow position, you need a new arrow.

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
```javascript +
function findMinArrowShots(points) {
    if (points.length === 0) return 0;
    const sorted = [...points].sort((a, b) => a[1] - b[1]);
    let arrows = 1;
    let arrowPos = sorted[0][1];

    for (let i = 1; i < sorted.length; i++) {
        const [start, end] = sorted[i];
        if (start > arrowPos) {
            arrows++;
            arrowPos = end;
        }
    }

    return arrows;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[][] points = {{10, 16}, {2, 8}, {1, 6}, {7, 12}};
        System.out.println(findMinArrowShots(points));
    }

    static int findMinArrowShots(int[][] points) {
        if (points.length == 0) return 0;

        int[][] sorted = points.clone();
        Arrays.sort(sorted, (a, b) -> Integer.compare(a[1], b[1]));

        int arrows = 1;
        int arrowPos = sorted[0][1];

        for (int i = 1; i < sorted.length; i++) {
            int start = sorted[i][0];
            int end = sorted[i][1];
            if (start > arrowPos) {
                arrows++;
                arrowPos = end;
            }
        }

        return arrows;
    }
}
```

**Complexity:** Time O(n log n) for the sort, space O(1) extra.

**Common mistakes:** sorting by start instead of end, exactly the "wrong sort key" trap the concept section warns about, which produces a wrong greedy result here. Also, using `>=` instead of `>` in the new-arrow check: touching balloons, like `[1,2]` and `[2,3]`, can share one arrow at position 2, so verify against the problem's boundary convention.

> **Remember:** minimizing arrows and maximizing non-overlapping meetings are the same problem wearing different names, sort by end and greedily group.

Four problems, one recurring choice: sort by start or sort by end. Get that call right and each algorithm above becomes a few lines of linear-pass bookkeeping. Get it wrong and the bug hides in code that passes small examples and fails on edge cases, so when a new interval problem shows up, decide the sort key before writing anything else.
