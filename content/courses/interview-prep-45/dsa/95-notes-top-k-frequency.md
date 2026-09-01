---
kind: lesson
id_key: interview-prep-45/note-top-k-frequency
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Notes: Top-K Frequent Elements Pattern"
position: 95
estimated_minutes: 20
source:
    - interview-prep-notes.md
---
A recurring pattern: given a collection, find the K elements that occur most often. Three approaches, in order of when to reach for each.

## Step 1: always start with a frequency map

```python
from collections import Counter
freq = Counter(arr)  # O(n) — {element: count}
```

Every approach below builds on this. The difference is only in how you extract the top K *from* the map.

## Approach A: sort by count, O(n log n)

```python
top_k = sorted(freq.items(), key=lambda x: -x[1])[:k]
```

Simplest to write and correct, but it does more work than necessary: it fully sorts all n elements just to read off k of them.

## Approach B: min-heap of size K, O(n log k)

Better when `k` is small relative to `n`. Keep a heap of exactly `k` elements: push each new candidate, and when the heap grows past `k`, pop the smallest (least frequent) one. By the time you've scanned everything, the heap holds the current top k.

```python
import heapq

def top_k_frequent(arr, k):
    freq = Counter(arr)
    heap = []
    for num, count in freq.items():
        heapq.heappush(heap, (count, num))
        if len(heap) > k:
            heapq.heappop(heap)  # evict the current smallest
    return [num for count, num in heap]
```

`heapq` is a min-heap by default, so pushing `(count, num)` tuples puts the smallest count at the root. That's exactly the entry you want to evict when the heap overflows past `k`.

## Approach C: bucket sort by frequency, O(n) and optimal

The insight: frequency can never exceed `n` (the array length), so instead of comparing/sorting, index directly by frequency.

```python
def top_k_frequent(arr, k):
    freq = Counter(arr)
    buckets = [[] for _ in range(len(arr) + 1)]  # index = frequency
    for num, count in freq.items():
        buckets[count].append(num)

    result = []
    for count in range(len(buckets) - 1, 0, -1):  # walk from highest frequency down
        for num in buckets[count]:
            result.append(num)
            if len(result) == k:
                return result
    return result
```

This is the answer to give when an interviewer pushes for better than `O(n log n)`. Bucket sort trades the general-purpose comparison sort for an array indexed by the bounded range of possible frequencies (`0..n`), which gives true linear time.

## Which to reach for

- Default, safe answer: Approach A (sorted). Correct, easy to write under pressure, and honest about the complexity.
- If asked to optimize: Approach B (heap), the standard "top-k" interview answer at `O(n log k)`.
- If pushed further ("can you do better than log k?"): Approach C (bucket sort) at `O(n)`, since frequency is bounded by array length.
