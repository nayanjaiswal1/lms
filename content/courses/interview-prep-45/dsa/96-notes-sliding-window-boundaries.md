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

Day 3 and Day 23 already cover the sliding window templates (fixed vs variable, the have/need counter, the stale-max trick) in depth with real problems. This note adds the two things those lessons don't: how to prove sliding window even applies before reaching for it, and a checklist for the bugs that show up when it doesn't quite work.

## The precondition sliding window depends on: monotonicity

Every sliding-window template relies on one assumption: **once a window becomes invalid, it stays invalid until you contract it** — expanding never fixes an invalid window, only contracting does. This holds when the tracked property moves in one direction as the window grows (sum only increases as you add non-negative numbers; distinct-count only increases as you add elements).

It breaks the moment that's not true. "Smallest subarray with sum ≥ target" works cleanly with non-negative numbers because growing the window can only help reach the target, and shrinking can only hurt — sum is monotonic in window size. Allow negative numbers, and adding an element to the window can *decrease* the sum, so a window that looks invalid might become valid again by expanding further, not contracting — the whole "contract while invalid" loop no longer proves anything.

**The test before reaching for sliding window:** can you prove that once the window is invalid, it stays invalid until contracted? If you can't, sliding window doesn't crash — it silently returns a wrong answer. That's the dangerous failure mode, not an exception or a wrong-answer-on-obvious-input.

## When sliding window isn't the tool: prefix sum + hashmap

For "subarray with sum exactly equal to k" where negatives are allowed (no monotonicity to exploit), sliding window doesn't work — the standard tool is prefix sums with a hashmap of sums seen so far:

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

This is O(n) time and space — same complexity class as sliding window, but it's a fundamentally different technique (no left/right pointers, no expand/contract), applicable precisely where sliding window's monotonicity requirement fails.

## Distinguishing the three related patterns

| Signal | Technique |
|---|---|
| Fixed size `k` given | Sliding window — fixed |
| "Longest/shortest subarray such that..." + monotonic property | Sliding window — variable |
| Negative numbers + exact sum target | Prefix sum + hashmap |
| Pointers start at both ends, move inward (e.g. container with most water) | Two pointers (opposite ends) — Day 2, a different technique despite the superficial "two pointers" similarity to sliding window |

## Correctness checklist

Day 3/23 cover each of these individually inside specific problems; collected here as a pre-submission check:

- Monotonicity precondition holds (or you've switched to prefix sum instead).
- Window size formula is `right - left + 1`, not `right - left`.
- Contract order: remove using the current `left`, *then* `left += 1`.
- `if` vs `while` matches whether multi-step contraction is possible — fixed-size windows contract by exactly one (`if`); variable-size windows can need zero-to-many contractions per step (`while`). Using `if` where `while` is needed leaves the window invalid after only one contraction — the most common sliding-window bug.
- Answer recorded at the right point: longest-valid-subarray records *after* the contraction loop exits (window guaranteed valid); shortest-valid-subarray records *inside* the contraction loop, on every contraction (smallest window before it goes invalid again).
- `left` never moves backward anywhere in the code — that's what makes the amortized-O(n) argument (`right` advances n times, `left` advances at most n times total across the whole run, not per iteration) actually hold.

## Key takeaways

- Sliding window requires monotonicity — prove "once invalid, stays invalid until contracted" before applying it; if you can't, it gives silently wrong answers, not a crash.
- Negative numbers + exact-sum-target breaks that precondition — use prefix sum + hashmap instead (different technique, not a sliding-window variant).
- `if` (fixed window, exactly one contraction) vs `while` (variable window, zero-to-many contractions) is a structural choice, not a stylistic one.
- Longest-subarray answers record after the contraction loop; shortest-subarray answers record inside it, on every contraction.
