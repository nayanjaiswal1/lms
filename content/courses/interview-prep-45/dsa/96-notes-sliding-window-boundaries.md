---
kind: lesson
id_key: interview-prep-45/note-sliding-window-boundaries
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Notes: Sliding Window — When It Doesn't Apply, and a Correctness Checklist"
position: 96
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The core sliding window templates, fixed-size windows, variable-size windows, the have/need counter for matching subsequences, and the stale-max trick for windowed maximums, are covered in depth elsewhere in this course, worked through against real problems. This note adds two things a template walkthrough usually skips: how to prove sliding window even applies before reaching for it, and a checklist for the bugs that show up when it doesn't quite work.

## The precondition sliding window depends on: monotonicity

Every sliding-window template relies on one assumption: **once a window becomes invalid, it stays invalid until you contract it**. Expanding never fixes an invalid window; only contracting does. This holds when the tracked property moves in one direction as the window grows: sum only increases as you add non-negative numbers, distinct-count only increases as you add elements.

It breaks the moment that's not true. "Smallest subarray with sum ≥ target" works cleanly with non-negative numbers because growing the window can only help reach the target, and shrinking can only hurt: sum is monotonic in window size. Allow negative numbers and adding an element can *decrease* the sum, so a window that looks invalid might become valid again by expanding further rather than contracting. At that point the "contract while invalid" loop no longer proves anything.

**The test before reaching for sliding window:** can you prove that once the window is invalid, it stays invalid until contracted? If you can't, sliding window won't crash. It will silently return a wrong answer, which is the dangerous failure mode: no exception, no obviously-wrong output to tip you off.

## When sliding window isn't the tool: prefix sum + hashmap

For "subarray with sum exactly equal to k" where negatives are allowed, there's no monotonicity to exploit, so sliding window doesn't work. The standard tool instead is prefix sums with a hashmap of sums seen so far:

```python
def subarray_sum(nums: list[int], k: int) -> int:
    count = 0
    running_sum = 0
    seen = {0: 1}  # prefix sum 0 occurs once, before any elements

    for num in nums:
        running_sum += num
        # if (running_sum - k) was seen before, the subarray between
        # that point and here sums to exactly k
        count += seen.get(running_sum - k, 0)
        seen[running_sum] = seen.get(running_sum, 0) + 1

    return count
```

This runs in O(n) time and space, the same complexity class as sliding window, but it's a fundamentally different technique: no left/right pointers, no expand/contract. It applies precisely where sliding window's monotonicity requirement fails.

## Distinguishing the three related patterns

| Signal | Technique |
|---|---|
| Fixed size `k` given | Sliding window (fixed) |
| "Longest/shortest subarray such that..." + monotonic property | Sliding window (variable) |
| Negative numbers + exact sum target | Prefix sum + hashmap |
| Pointers start at both ends, move inward (e.g. container with most water) | Two pointers (opposite ends): a different technique despite the superficial "two pointers" similarity to sliding window, since both pointers move independently inward rather than a single window expanding and contracting |

## Correctness checklist

Each of these shows up individually inside specific sliding-window problems elsewhere in this course; collected here as a pre-submission check:

- Monotonicity precondition holds (or you've switched to prefix sum instead).
- Window size formula is `right - left + 1`, not `right - left`.
- Contract order: remove using the current `left`, *then* `left += 1`.
- `if` vs `while` matches whether multi-step contraction is possible: fixed-size windows contract by exactly one (`if`), variable-size windows can need zero-to-many contractions per step (`while`). Using `if` where `while` is needed leaves the window invalid after only one contraction, which is the most common sliding-window bug.
- Answer recorded at the right point. For a longest-valid-subarray problem, record the answer *after* the contraction loop exits, once the window is guaranteed valid again. For a shortest-valid-subarray problem, record the answer *inside* the contraction loop, on every contraction, since that's the smallest the window gets before it goes invalid again.
- `left` never moves backward anywhere in the code. That's what makes the amortized-O(n) argument hold: `right` advances n times, and `left` advances at most n times total across the whole run, not per iteration.
