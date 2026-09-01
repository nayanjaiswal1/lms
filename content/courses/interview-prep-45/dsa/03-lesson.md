---
kind: lesson
id_key: interview-prep-45/day-03
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Sliding Window"
position: 3
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Sliding window is two pointers' sibling pattern for subarray/substring problems: instead of pointers converging from both ends, they both move forward, defining a contiguous "window" that expands and contracts. It's the single highest-leverage pattern for "longest/shortest/best contiguous substring/subarray satisfying X" questions, which show up constantly in string-heavy interview sets.

## Fixed vs variable window size

There are two flavors:

- **Fixed-size window**: the window size `k` is given upfront (e.g., "max sum of any subarray of size k"). You slide it by adding the new right element and removing the leftmost element every step: O(1) work per step, O(n) total.
- **Variable-size window**: the window grows and shrinks based on a condition (e.g., "longest substring with no repeating characters"). The right pointer always advances; the left pointer advances only when the window becomes invalid, catching it back up to validity.

Recognizing which flavor a problem needs is the first decision point: if the problem states a fixed length, it's fixed-size; if it says "longest," "shortest," or "minimum" without a fixed length, it's almost always variable-size.

## When to expand vs contract window

The variable-window template is the one to internalize cold:

```python
def variable_window_template(s: str) -> int:
    left = 0
    best = 0
    window_state = {}  # whatever tracking the problem needs

    for right in range(len(s)):
        # 1. Expand: bring s[right] into the window
        window_state[s[right]] = window_state.get(s[right], 0) + 1

        # 2. Contract: while window is invalid, shrink from the left
        while window_is_invalid(window_state):
            window_state[s[left]] -= 1
            if window_state[s[left]] == 0:
                del window_state[s[left]]
            left += 1

        # 3. Record: window [left, right] is now valid — update the answer
        best = max(best, right - left + 1)

    return best
```

The invariant to hold onto: **the right pointer visits each index once, and the left pointer visits each index at most once** (it only moves forward). That's what makes the whole thing O(n) instead of O(n²): every index is added to the window once and removed at most once.

## Tracking multiple variables in window

Harder sliding-window problems (like Minimum Window Substring) require tracking more than a simple count. The real question is whether the window currently satisfies all the required character counts, not merely how many characters it holds. The standard trick is a `have`/`need` counter pair: `need` is fixed (how many distinct characters must be satisfied), and `have` increments only when a character's count in the window first *reaches* its required count. Comparing `have == need` in O(1) avoids re-scanning the whole frequency map on every step.

## Best Time to Buy and Sell Stock

[Best Time to Buy and Sell Stock (LeetCode 121)](https://leetcode.com/problems/best-time-to-buy-and-sell-stock/)

**Intuition:** This is a sliding window in disguise: the window is "buy day to sell day," and you want to maximize `price[sell] - price[buy]`. Instead of nested loops trying every pair, track the minimum price seen so far as you scan. That's an implicit left pointer that only ever moves forward when it finds a new minimum.

**Approach:** Walk the array once. Track `min_price` seen so far. At each day, compute the profit if you sold today (`price - min_price`) and update the best profit. Update `min_price` if today's price is lower.

```python
def max_profit(prices: list[int]) -> int:
    min_price = float("inf")
    best_profit = 0
    for price in prices:
        min_price = min(min_price, price)
        best_profit = max(best_profit, price - min_price)
    return best_profit
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:**
- Nested loops checking every buy/sell pair: O(n²), works but interviewers expect the O(n) version.
- Updating `best_profit` before updating `min_price` on the same day (order doesn't actually break this one, since you can't buy and sell same day at a profit from that exact price, but get the order right by habit for variants).
- Confusing this with the "multiple transactions allowed" variant (LeetCode 122), which needs a different, greedy approach.

## Longest Substring Without Repeating Characters

[Longest Substring Without Repeating Characters (LeetCode 3)](https://leetcode.com/problems/longest-substring-without-repeating-characters/)

**Intuition:** Classic variable-size window. Expand right, adding characters to a set/map. The moment you'd add a duplicate, the window is invalid, so shrink from the left until the duplicate is gone.

**Approach:** Use a hash map storing the *last seen index* of each character rather than a boolean set. That lets you jump the left pointer directly to just past the duplicate's previous position instead of incrementing one at a time.

```python
def length_of_longest_substring(s: str) -> int:
    last_seen = {}  # char -> most recent index
    left = 0
    best = 0
    for right, ch in enumerate(s):
        if ch in last_seen and last_seen[ch] >= left:
            left = last_seen[ch] + 1
        last_seen[ch] = right
        best = max(best, right - left + 1)
    return best
```

**Complexity:** Time O(n): each index visited once by `right`, and `left` jumps but never revisits. Space O(min(n, alphabet size)) for the map.

**Common mistakes:**
- Using a plain set and shrinking `left` one step at a time: correct but degrades toward O(n) *inside* an O(n) outer loop in pathological cases without the jump optimization (still O(n) amortized here, but the index-map version is cleaner and standard).
- Forgetting the `last_seen[ch] >= left` check. Without it, a stale index from before the current window incorrectly yanks `left` backward.
- Off-by-one on window length: it's `right - left + 1`, not `right - left`.

## Minimum Window Substring

[Minimum Window Substring (LeetCode 76)](https://leetcode.com/problems/minimum-window-substring/)

**Intuition:** Find the smallest window in `s` that contains every character of `t` (with multiplicity). This needs the `have`/`need` tracking described above: expand right until the window satisfies all of `t`'s requirements, then greedily contract left as far as possible while staying valid, recording the smallest valid window found.

**Approach:**
1. Build a frequency map of `t`. `need` = number of distinct characters in `t`.
2. Expand `right` across `s`, updating a window frequency map. When a character's window count first equals its required count, increment `have`.
3. While `have == need` (window is valid), record the window if it's the smallest so far, then contract `left`, decrementing `have` if shrinking breaks a satisfied requirement.

```python
from collections import Counter

def min_window(s: str, t: str) -> str:
    if not s or not t:
        return ""

    need_counts = Counter(t)
    need = len(need_counts)
    window_counts = {}
    have = 0

    left = 0
    best_len = float("inf")
    best_left = 0

    for right, ch in enumerate(s):
        window_counts[ch] = window_counts.get(ch, 0) + 1
        if ch in need_counts and window_counts[ch] == need_counts[ch]:
            have += 1

        while have == need:
            if (right - left + 1) < best_len:
                best_len = right - left + 1
                best_left = left

            left_ch = s[left]
            window_counts[left_ch] -= 1
            if left_ch in need_counts and window_counts[left_ch] < need_counts[left_ch]:
                have -= 1
            left += 1

    return "" if best_len == float("inf") else s[best_left:best_left + best_len]
```

**Complexity:** Time O(|s| + |t|): building the `t` counter is O(|t|), and both pointers over `s` move forward only, giving O(|s|). Space O(|t|) for the need map, O(alphabet) for the window map.

**Common mistakes:**
- Recomputing "is the window valid" by scanning the whole frequency map every step instead of tracking `have`/`need` incrementally: this turns O(n) into O(n·k).
- Off-by-one when decrementing `have`: it must trigger only when the count drops *below* the required amount, not merely when it changes.
- Not handling characters in `s` that aren't in `t` at all. They should still count in `window_counts` (harmless) but never affect `have`.

## When "longest" and "structural" collide

The five problems in this lesson split into two families that are easy to conflate under time pressure. Buy/Sell Stock and Longest Substring are single-condition windows: one running value (`min_price`, `last_seen`) is enough to decide when to move the left pointer. Minimum Window Substring is a multi-condition window: validity depends on satisfying several counts at once, which is why it needs `have`/`need` instead of a single tracked variable. Before coding, ask how many conditions define "valid" for this window. One condition, track a running value. Several conditions, reach for `have`/`need`.
