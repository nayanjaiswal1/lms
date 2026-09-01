---
kind: lesson
id_key: interview-prep-45/note-sorting-algorithms-complexity
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Notes: Sorting Algorithms Complexity Cheatsheet"
position: 98
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

No lesson in this course dedicates itself to sorting alone. It shows up as a supporting tool instead: calling `nums.sort()` before running a two-pointer sweep on a sorted array, or reaching for a heap in the top-k frequency pattern. This note fills that gap for when an interviewer asks about sorting directly: complexity, stability, and why `Quick Sort` is O(n log n) average but O(n²) worst case.

## Comparison-based sorts

| Algorithm | Best | Average | Worst | Space | Stable? |
|---|---|---|---|---|---|
| Bubble Sort | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Selection Sort | O(n²) | O(n²) | O(n²) | O(1) | No |
| Insertion Sort | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Merge Sort | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes |
| Quick Sort | O(n log n) | O(n log n) | O(n²) | O(log n) | No |
| Heap Sort | O(n log n) | O(n log n) | O(n log n) | O(1) | No |

## Non-comparison sorts

| Algorithm | Best / Average / Worst | Space | Constraint |
|---|---|---|---|
| Counting Sort | O(n + k) | O(k) | Integers in a known, bounded range `k` |
| Radix Sort | O(nk) | O(n + k) | Fixed-width integers/strings; sorts digit-by-digit |
| Bucket Sort | O(n + k) best/avg, O(n²) worst | O(n + k) | Uniformly distributed input |

These beat the O(n log n) comparison-sort lower bound because they don't compare elements pairwise. They exploit structure in the values themselves, a bounded range or a fixed digit count, which is exactly why they don't generalize to arbitrary comparable objects.

## Why Quick Sort's worst case is O(n²)

Quick Sort partitions around a pivot. If the pivot is always the min or max of the current subarray (always picking the first element on already-sorted input, say), one side of the partition is empty and the other has everything else. Recursion depth becomes O(n) instead of O(log n), giving O(n²) total.

Trace it on the already-sorted array `[1, 2, 3, 4, 5]` with "always pick the first element" as the pivot rule: pivot `1` partitions into `[]` and `[2, 3, 4, 5]`, pivot `2` partitions into `[]` and `[3, 4, 5]`, and so on. Every partition peels off exactly one element instead of splitting the array roughly in half, so the recursion is 5 levels deep instead of the ~2-3 levels a balanced split would give. On an array of size n this becomes n levels deep, each doing O(n) partition work, hence O(n²) total. The fix is to randomize the pivot choice (or use median-of-three), which makes this worst case astronomically unlikely rather than triggered by a common input shape like "already sorted."

## Merge Sort vs. Quick Sort vs. Heap Sort: the interview framing

- **Merge Sort**: the only stable O(n log n) option here.
  - It needs O(n) auxiliary space for the merge step.
  - Preferred when stability matters, for example sorting by a secondary key after already sorting by a primary one.
  - Also preferred for linked lists, where merging costs O(1) extra space instead of the array shifting Quick Sort or Heap Sort would need.
- **Quick Sort**: in-place, meaning O(log n) space for the recursion stack rather than O(n).
  - Typically fastest in practice thanks to cache locality.
  - Not stable.
  - Carries the O(n²) worst case traced above.
- **Heap Sort**: O(1) space and no worst-case blowup.
  - Poor cache locality, since it jumps around the array via heap indices, makes it slower in practice than Quick Sort despite the same O(n log n) bound.
  - It's the classic "same Big-O, different real-world speed" example.

## Python's built-in sort: Timsort

```python
arr.sort()      # in-place, O(n log n) worst case, O(n) space
sorted(arr)     # returns a new list, same complexity
```

Timsort is a hybrid of Merge Sort and Insertion Sort: it finds already-sorted runs in the input, uses Insertion Sort to extend or create small runs efficiently, then merges those runs with Merge Sort's approach. It's stable and O(n log n) worst case. Insertion Sort's O(n) best case on nearly-sorted data is exactly why it handles the small-run part, not because it's a fallback for the whole sort.

## O(log n) vs O(n log n)

Binary search is O(log n) because it halves the search space each step, a mechanism covered in depth elsewhere in this course. The generalization worth stating explicitly:

- **O(log n)**: the algorithm itself halves the problem each step. Binary search, BST lookup, a single heap push/pop.
- **O(n log n)**: an O(log n)-per-element operation repeated for all n elements. Merge Sort does O(log n) merge levels, each processing all n elements, which is `n` × `log n`, not `log n` alone. Heap Sort has the same shape: n heap operations, each O(log n).

| n | log n | n log n |
|---|---|---|
| 8 | 3 | 24 |
| 1,000 | ~10 | ~10,000 |
| 1,000,000 | ~20 | ~20,000,000 |

One-line version: O(log n) = divide and ignore half; O(n log n) = divide and do O(log n) work for every one of the n elements.
