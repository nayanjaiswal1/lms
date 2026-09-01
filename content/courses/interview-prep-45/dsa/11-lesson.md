---
kind: lesson
id_key: interview-prep-45/day-11
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Heaps / Priority Queues"
position: 11
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---

Heaps answer "give me the min or max efficiently, repeatedly, as the data changes." They're the backbone of top-K problems, merging sorted data, scheduling, and streaming statistics. Today you learn the structure, build one from scratch, and apply it to four problems interviewers reach for constantly.

## Heap properties (complete binary tree)

A heap is a **complete binary tree** stored in an array: every level is fully filled except possibly the last, which fills left to right with no gaps. Completeness is what makes array storage possible without wasting space or storing pointers.

For a node at index `i` (0-indexed array):

```python
def parent(i):  return (i - 1) // 2
def left(i):    return 2 * i + 1
def right(i):   return 2 * i + 2
```

```
Array: [1, 3, 2, 7, 5, 4, 8]
Tree:
              1(0)
            /      \
        3(1)         2(2)
       /    \        /    \
    7(3)   5(4)   4(5)   8(6)
```

Because the tree is always complete, height is always `O(log n)` for `n` elements. That bound is what gives heap operations their `O(log n)` cost.

## Max heap vs min heap

**Min heap:** every parent ≤ both children. The smallest element is always at the root (index 0). Python's `heapq` module implements a min heap.

**Max heap:** every parent ≥ both children. The largest element is always at the root.

```python
import heapq

min_heap = []
for x in [5, 1, 8, 3]:
    heapq.heappush(min_heap, x)
print(min_heap[0])  # 1 — smallest, always at index 0

# Python has no max-heap; negate values as the standard workaround
max_heap = []
for x in [5, 1, 8, 3]:
    heapq.heappush(max_heap, -x)
print(-max_heap[0])  # 8 — largest
```

**Pitfall with the negation trick:** when pushing tuples for a max heap, such as `(priority, item)`, negate only the priority field, and remember to negate it back on pop. When priorities tie, Python compares the second tuple element next. If that's an unorderable object, like a custom class, you'll get a `TypeError`, so add an index or unique tiebreaker as a third tuple element to avoid this.

| | Min heap | Max heap |
|---|---|---|
| Root | Smallest | Largest |
| `heapq` support | Native | Simulate via negation |
| Use for | Top-K largest (keep heap size K), Dijkstra, merge-K-lists | Top-K smallest, task scheduling by highest priority first |

## Heapify operation

`heapify` builds a valid heap from an arbitrary array in O(n) time, not the O(n log n) you might guess from "n inserts of O(log n) each." The trick: start from the last non-leaf node and sift each node down, working backward to the root. Most nodes sit near the bottom of the tree, where sift-down is cheap, so the total work sums to O(n).

```python
def sift_down(arr, i, n):
    while True:
        smallest = i
        l, r = 2 * i + 1, 2 * i + 2
        if l < n and arr[l] < arr[smallest]:
            smallest = l
        if r < n and arr[r] < arr[smallest]:
            smallest = r
        if smallest == i:
            break
        arr[i], arr[smallest] = arr[smallest], arr[i]
        i = smallest

def heapify(arr):
    n = len(arr)
    for i in range(n // 2 - 1, -1, -1):  # start at last non-leaf, go to root
        sift_down(arr, i, n)
```

```python
data = [9, 4, 7, 1, 3, 8]
heapify(data)
print(data)  # a valid min-heap array, e.g. [1, 3, 7, 9, 4, 8]
```

Python's `heapq.heapify(list)` does exactly this in place, in O(n).

## Kth Largest Element in Array

[LeetCode 215](https://leetcode.com/problems/kth-largest-element-in-an-array/), Heap, QuickSelect alternative

**Intuition:** Maintain a min heap of size `k`. After processing all elements, the heap's root is the k-th largest: everything smaller than it has been evicted, and the heap holds exactly the top `k` values.

**Approach:** Push each number; if heap size exceeds `k`, pop the smallest. At the end, the root is the answer.

```python
def findKthLargest(nums: list[int], k: int) -> int:
    heap = []
    for num in nums:
        heapq.heappush(heap, num)
        if len(heap) > k:
            heapq.heappop(heap)
    return heap[0]
```

**Complexity:** Time O(n log k), space O(k), much better than sorting's O(n log n) when k is small. QuickSelect achieves average O(n) but worst-case O(n²) and mutates the input, so the heap approach is the safer default to mention first, with QuickSelect as the follow-up optimization.

**Common mistakes:** Using a max heap of all n elements and popping k times. That's O(n + k log n), but it needlessly builds a heap of the whole array when a size-k min heap is smaller and simpler to reason about. Forgetting the size check lets the heap grow unbounded.

## Top K Frequent Elements

[LeetCode 347](https://leetcode.com/problems/top-k-frequent-elements/), Heap, Frequency counting

**Intuition:** Count frequencies first; then you need the k elements with the highest counts. Same "maintain a size-k heap" pattern as Kth Largest, just ordered by frequency instead of value.

**Approach:** `Counter` for frequencies, then a min heap of size k keyed by frequency (evict the lowest-frequency entry when the heap exceeds k).

```python
from collections import Counter

def topKFrequent(nums: list[int], k: int) -> list[int]:
    counts = Counter(nums)
    heap = []
    for num, freq in counts.items():
        heapq.heappush(heap, (freq, num))
        if len(heap) > k:
            heapq.heappop(heap)
    return [num for freq, num in heap]
```

**Complexity:** Time O(n log k), space O(n) for the counter. `heapq.nlargest(k, counts.keys(), key=counts.get)` is the idiomatic one-liner if the interviewer allows library shortcuts, but be ready to implement it manually, since that's usually the actual ask.

**Common mistakes:** Sorting the full frequency map, O(n log n), when k is small and a heap does better. Forgetting the answer only needs the numbers, not the frequencies, when building the return list.

## Merge K Sorted Lists

[LeetCode 23](https://leetcode.com/problems/merge-k-sorted-lists/), Heap, Merge technique

**Intuition:** At any point, the next smallest overall value is the smallest among the current heads of all k lists. A min heap holding one candidate per list gives you that smallest value in O(log k) instead of scanning all k heads in O(k) each step.

**Approach:** Push the head of each list into a min heap keyed by value (with a tiebreaker index to avoid comparing `ListNode` objects). Pop the minimum, append it to the result, and push its `.next` if one exists.

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

def mergeKLists(lists: list[ListNode]) -> ListNode:
    heap = []
    for i, node in enumerate(lists):
        if node:
            heapq.heappush(heap, (node.val, i, node))  # i breaks value ties

    dummy = ListNode()
    tail = dummy

    while heap:
        val, i, node = heapq.heappop(heap)
        tail.next = node
        tail = tail.next
        if node.next:
            heapq.heappush(heap, (node.next.val, i, node.next))

    return dummy.next
```

**Complexity:** Time O(N log k) where N is total node count across all lists, space O(k) for the heap.

**Common mistakes:** Pushing `(val, node)` without a tiebreaker; comparing `ListNode` objects when values tie raises `TypeError`. Forgetting the dummy-head pattern makes assembling the result list awkward.

## Find Median from Data Stream

[LeetCode 295](https://leetcode.com/problems/find-median-from-data-stream/), Heap, Two heaps pattern

**Intuition:** Split the stream into two halves: a max heap holding the smaller half, a min heap holding the larger half. Keep them balanced in size, within 1 of each other. The median is then either the max heap's root, the min heap's root, or their average, with no full sort needed on every insert.

**Approach:** Add each new number to the appropriate heap, then rebalance so sizes never differ by more than 1.

```python
class MedianFinder:
    def __init__(self):
        self.small = []  # max heap (negated), holds the smaller half
        self.large = []  # min heap, holds the larger half

    def addNum(self, num: int) -> None:
        heapq.heappush(self.small, -num)
        # ensure every element in small <= every element in large
        heapq.heappush(self.large, -heapq.heappop(self.small))
        if len(self.large) > len(self.small):
            heapq.heappush(self.small, -heapq.heappop(self.large))

    def findMedian(self) -> float:
        if len(self.small) > len(self.large):
            return -self.small[0]
        return (-self.small[0] + self.large[0]) / 2.0
```

**Complexity:** Time O(log n) per `addNum`, O(1) per `findMedian`. Space O(n) to hold the stream.

**Common mistakes:** Forgetting to route every insert through `small` first. The push-then-pop-then-rebalance sequence above guarantees correctness even when the new number belongs in `large`. Allowing size imbalance greater than 1, which breaks the median formula. Using a plain sorted list with `bisect.insort` also works, with O(n) insert, but it doesn't scale as well as the two-heap approach for large streams; mention it as the naive baseline.
