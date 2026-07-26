---
kind: lesson
id_key: interview-prep-45/day-23
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Sliding Window - Advanced"
position: 23
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
---

You've used basic sliding window before; today's problems push it further — windows that track auxiliary data structures (frequency counts) and windows that must satisfy multiple simultaneous conditions. This is the pattern behind most "longest/shortest substring/subarray with property X" interview questions.

## Fixed window with data structures

A **fixed-size window** slides one element at a time, and instead of just a running sum, you often maintain a frequency map or count that updates incrementally as elements enter and leave.

```python
from collections import Counter

def max_distinct_in_window(nums: list[int], k: int) -> int:
    counts = Counter(nums[:k])
    best = len(counts)
    for i in range(k, len(nums)):
        counts[nums[i]] += 1                 # element entering
        left = nums[i - k]
        counts[left] -= 1                    # element leaving
        if counts[left] == 0:
            del counts[left]                 # keep the map accurate for len() checks
        best = max(best, len(counts))
    return best
```

**The pattern:** every fixed-window problem does exactly two things per step — add the incoming element's effect, remove the outgoing element's effect. The "effect" can be a sum, a frequency count, a max-tracking deque, or any other incrementally-maintainable structure. Never recompute the whole window from scratch each step; that turns an O(n) sliding window into O(n·k).

## Variable window tracking multiple conditions

A **variable-size window** grows by advancing `right` and shrinks by advancing `left`, expanding while a condition holds and contracting when it's violated. The advanced version tracks *several* conditions at once (e.g., "at most 2 distinct characters AND window length ≤ some bound").

```python
def variable_window_skeleton(s: str, is_valid) -> int:
    left = 0
    best = 0
    window_state = {}  # whatever data the condition needs: counts, max-freq, etc.

    for right in range(len(s)):
        # 1. expand: absorb s[right] into window_state
        window_state[s[right]] = window_state.get(s[right], 0) + 1

        # 2. contract while the window violates the condition
        while not is_valid(window_state, right - left + 1):
            window_state[s[left]] -= 1
            if window_state[s[left]] == 0:
                del window_state[s[left]]
            left += 1

        # 3. record the best valid window at this right boundary
        best = max(best, right - left + 1)

    return best
```

**Critical invariant:** `left` only ever moves forward — it never resets to 0 and re-scans. This is what makes the whole algorithm O(n) instead of O(n²): each index enters and leaves the window at most once across the entire run, so total work across all iterations of the inner `while` is bounded by n, not n per outer step.

## Longest Repeating Character Replacement

[LeetCode 424](https://leetcode.com/problems/longest-repeating-character-replacement/) — Sliding window

**Intuition:** You can change up to `k` characters in a window to make all characters the same. A window is valid if `window_length - count_of_most_frequent_char <= k` — that's exactly the number of characters you'd need to replace.

**Approach:** Expand `right`, tracking a frequency count and the running max frequency seen (`max_freq` never needs to decrease even as the window shrinks — it only ever underestimates slightly, but that's safe because the answer only grows when a *new* max_freq is achieved, so a stale-but-not-overestimating max_freq can't produce a wrong larger answer). Shrink `left` only when the window becomes invalid.

```python
def characterReplacement(s: str, k: int) -> int:
    counts = {}
    left = 0
    max_freq = 0
    best = 0

    for right in range(len(s)):
        counts[s[right]] = counts.get(s[right], 0) + 1
        max_freq = max(max_freq, counts[s[right]])

        window_len = right - left + 1
        if window_len - max_freq > k:
            counts[s[left]] -= 1
            left += 1

        best = max(best, right - left + 1)

    return best
```

**Complexity:** Time O(n), space O(1) (at most 26 letters in `counts`).

**Common mistakes:** Trying to decrement `max_freq` when the window shrinks — unnecessary and actually breaks the O(n) guarantee if done via a full rescan; forgetting that `best` should be computed from the (possibly still invalid-shrinking) window length, since the window size never needs to shrink below the best-so-far — it can only stay the same or grow.

## Fruit Into Baskets

[LeetCode 904](https://leetcode.com/problems/fruit-into-baskets/) — Sliding window

**Intuition:** This is "longest subarray with at most 2 distinct values" wearing a word problem's clothes. Two baskets = at most 2 distinct fruit types in the window.

**Approach:** Expand `right`, tracking fruit-type counts in a dict. While the dict has more than 2 keys, shrink `left`.

```python
def totalFruit(fruits: list[int]) -> int:
    counts = {}
    left = 0
    best = 0

    for right, fruit in enumerate(fruits):
        counts[fruit] = counts.get(fruit, 0) + 1

        while len(counts) > 2:
            left_fruit = fruits[left]
            counts[left_fruit] -= 1
            if counts[left_fruit] == 0:
                del counts[left_fruit]
            left += 1

        best = max(best, right - left + 1)

    return best
```

**Complexity:** Time O(n), space O(1) (at most 3 keys in `counts` at any moment, since we shrink the instant it hits 3).

**Common mistakes:** Not recognizing the "2 baskets" framing as "at most 2 distinct values" — translating word problems into the underlying pattern is the actual skill being tested; forgetting to delete zero-count entries from the dict, which corrupts the `len(counts) > 2` check.

## Minimum Size Subarray Sum

[LeetCode 209](https://leetcode.com/problems/minimum-size-subarray-sum/) — Sliding window

**Intuition:** Find the *shortest* contiguous subarray with sum ≥ target — this flips the usual "maximize window" pattern to "minimize window while a condition holds," but the two-pointer mechanics are identical.

**Approach:** Expand `right`, adding to a running sum. While the sum meets or exceeds `target`, record the window length and shrink `left` (trying to shrink further while still valid, since a smaller valid window is always better here).

```python
def minSubArrayLen(target: int, nums: list[int]) -> int:
    left = 0
    total = 0
    best = float('inf')

    for right, num in enumerate(nums):
        total += num

        while total >= target:
            best = min(best, right - left + 1)
            total -= nums[left]
            left += 1

    return best if best != float('inf') else 0
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** Using `if` instead of `while` when shrinking — a single conditional shrink misses shorter valid windows that remain valid after one shrink step; forgetting the "no valid subarray exists" case, which requires returning 0, not `inf` or -1.

## Longest Subarray with Ones after Replacement

LeetCode 424 variant — the array analogue of Longest Repeating Character Replacement, sometimes phrased as "Max Consecutive Ones III" ([LeetCode 1004](https://leetcode.com/problems/max-consecutive-ones-iii/))

**Intuition:** You can flip up to `k` zeros to ones. Find the longest subarray achievable. This is structurally identical to Longest Repeating Character Replacement: a window is valid if `zero_count_in_window <= k`.

**Approach:** Expand `right`, tracking the count of zeros in the window. Shrink `left` while zero count exceeds `k`.

```python
def longestOnes(nums: list[int], k: int) -> int:
    left = 0
    zero_count = 0
    best = 0

    for right, num in enumerate(nums):
        if num == 0:
            zero_count += 1

        while zero_count > k:
            if nums[left] == 0:
                zero_count -= 1
            left += 1

        best = max(best, right - left + 1)

    return best
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** Rebuilding a full frequency count when a simple zero counter suffices (only two values exist, 0 and 1 — no need for a dict here, unlike the character-replacement version with 26 possible letters); off-by-one when computing window length after the shrink loop exits.

## Key takeaways

- Fixed windows do exactly two incremental updates per step (element entering, element leaving) — never recompute the window from scratch.
- Variable windows expand `right` every iteration and contract `left` only while a condition is violated; `left` never resets, which is what guarantees O(n) total work.
- "At most K distinct" and "longest with condition X after up to K changes" are the two dominant advanced sliding-window templates — most problems are one of these two wearing different words.
- A frequency map that's only *approximately* accurate in one direction (like `max_freq` in Character Replacement, which is allowed to be stale-low but never stale-high) is a common and valid optimization — understand why it's still correct before using it.
- Minimizing a window (shortest subarray satisfying a condition) uses the identical two-pointer skeleton as maximizing one — only the direction of "is this window good, should I shrink or expand" flips.
