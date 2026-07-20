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

No day in this course dedicates a lesson to sorting itself — it shows up as a tool (`nums.sort()` before two pointers, day 2; a heap for the top-k pattern, day 11) rather than something explained on its own. This note is the reference for when an interviewer asks about sorting directly: complexity, stability, and why `Quick Sort` is O(n log n) average but O(n²) worst case.

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
| Radix Sort | O(nk) | O(n + k) | Fixed-width integers/strings — sorts digit-by-digit |
| Bucket Sort | O(n + k) best/avg, O(n²) worst | O(n + k) | Uniformly distributed input |

These beat the O(n log n) comparison-sort lower bound because they don't compare elements pairwise — they exploit structure in the values themselves (a bounded range, fixed digit count), which is exactly why they don't generalize to arbitrary comparable objects.

## Why Quick Sort's worst case is O(n²)

Quick Sort partitions around a pivot; if the pivot is always the min or max of the current subarray (e.g. always picking the first element on already-sorted input), one side of the partition is empty and the other has everything else — recursion depth becomes O(n) instead of O(log n), giving O(n²) total. Fix: randomize the pivot choice (or use median-of-three), which makes the worst case astronomically unlikely rather than triggered by a common input shape like "already sorted."

## Merge Sort vs Quick Sort vs Heap Sort — the interview framing

- **Merge Sort** — the only stable O(n log n) option here; needs O(n) auxiliary space for the merge step. Preferred when stability matters (e.g., sorting by a secondary key after already sorting by a primary one) or for linked lists (merging is O(1) extra space there, no array shifting).
- **Quick Sort** — in-place (O(log n) space for the recursion stack, not O(n)), typically fastest in practice due to cache locality, but not stable and has the O(n²) worst case above.
- **Heap Sort** — O(1) space, no worst-case blowup, but poor cache locality (jumps around the array via heap indices) makes it slower in practice than Quick Sort despite the same O(n log n) bound — the classic "same Big-O, different real-world speed" example.

## Python's built-in sort: Timsort

```python
arr.sort()      # in-place, O(n log n) worst case, O(n) space
sorted(arr)     # returns a new list, same complexity
```

Timsort is a hybrid of Merge Sort and Insertion Sort: it finds already-sorted runs in the input, uses Insertion Sort to extend/create small runs efficiently, then merges runs with Merge Sort's approach. It's stable and O(n log n) worst case — Insertion Sort's O(n) best case on nearly-sorted data is exactly why it's used for the small-run part, not as a fallback for the whole sort.

## O(log n) vs O(n log n)

Day 4 covers *why* binary search is O(log n) (halving the search space each step) in depth. The generalization worth stating explicitly:

- **O(log n)** — the algorithm itself halves the problem each step. Binary search, BST lookup, a single heap push/pop.
- **O(n log n)** — an O(log n)-per-element operation repeated for all n elements. Merge Sort does O(log n) merge levels, each processing all n elements — that's `n` × `log n`, not `log n` alone. Same shape in Heap Sort: n heap operations, each O(log n).

| n | log n | n log n |
|---|---|---|
| 8 | 3 | 24 |
| 1,000 | ~10 | ~10,000 |
| 1,000,000 | ~20 | ~20,000,000 |

One-line version: O(log n) = divide and ignore half; O(n log n) = divide and do O(log n) work for every one of the n elements.

## Key takeaways

- No comparison-based sort beats O(n log n) worst case — Counting/Radix/Bucket sort beat that bound only because they exploit a constraint on the input values (bounded range, fixed digit width), not because they're smarter comparisons.
- Merge Sort is the only stable O(n log n) sort here; Quick Sort and Heap Sort both trade stability for better space or practical speed.
- Quick Sort's O(n²) worst case comes from consistently unbalanced partitions (e.g. always-first-element pivot on sorted input) — randomized pivot selection is the standard fix.
- Python's `sort()`/`sorted()` is Timsort — Merge Sort's structure with Insertion Sort handling small/already-sorted runs, stable, O(n log n) worst case.
- O(n log n) is not a distinct kind of growth from O(log n) — it's O(log n) work multiplied across n elements.
