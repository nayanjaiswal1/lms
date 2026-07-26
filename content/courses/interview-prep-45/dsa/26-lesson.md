---
kind: lesson
id_key: interview-prep-45/day-26
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "String Manipulation"
position: 26
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
---

String problems mix two skills you've already built — sliding window and frequency counting — with the specifics of efficient string construction and pattern matching. Today closes out the "strings" arc with harder sliding-window variants, an anagram-detection pattern you'll reuse constantly, and a classic string-matching algorithm.

## String building

Python strings are immutable — every `s += char` creates a brand-new string, making naive concatenation in a loop **O(n²)** overall (each of n appends copies the whole string so far).

```python
# O(n^2) - avoid in a loop
result = ""
for ch in "abcdef":
    result += ch

# O(n) - build a list, join once
parts = []
for ch in "abcdef":
    parts.append(ch)
result = "".join(parts)
```

`"".join(list_of_strings)` is the idiomatic O(n) pattern — it computes the final length once and allocates a single buffer, instead of reallocating on every append. This matters specifically when a problem asks you to build a result string inside a loop that could run thousands of times.

## Pattern matching

"Does string A appear inside string B" comes up disguised in many forms — substring search, anagram windows, repeated patterns. The naive approach checks every starting position in B against A character-by-character: **O(n·m)** where n = len(B), m = len(A). Two techniques improve on this:

1. **Sliding window with frequency counts** — when you're looking for anagrams/permutations of A within B rather than an exact substring match, maintain a frequency map of A and compare against a same-size window's frequency map as it slides. This avoids re-scanning m characters at every position.
2. **Rabin-Karp (rolling hash)** — when you need exact substring matches, hash A once, then compute B's window hashes incrementally (O(1) update per shift) instead of rehashing the whole window each time. See below.

## Anagram detection

Two strings are anagrams if they contain exactly the same characters with the same multiplicities. The standard check: compare `Counter` (or a fixed-size frequency array) of both strings.

```python
from collections import Counter

def is_anagram(s: str, t: str) -> bool:
    return Counter(s) == Counter(t)
```

For **sliding-window anagram search** (find all windows of B that are anagrams of A), maintain a running frequency count for the current window and compare to A's frequency count incrementally rather than rebuilding it every shift:

```python
def find_anagram_windows(s: str, p: str) -> list[int]:
    if len(p) > len(s):
        return []

    p_count = Counter(p)
    window_count = Counter(s[:len(p)])
    result = []

    if window_count == p_count:
        result.append(0)

    for i in range(len(p), len(s)):
        left_char = s[i - len(p)]
        window_count[s[i]] += 1
        window_count[left_char] -= 1
        if window_count[left_char] == 0:
            del window_count[left_char]

        if window_count == p_count:
            result.append(i - len(p) + 1)

    return result
```

**Complexity:** O(n) amortized if you avoid the O(26) `Counter == Counter` comparison per step (an optimization: track a running `matches` integer instead of comparing full Counters — see Find All Anagrams below for the fully optimized version). The version above is O(n · 26) worst case, which is still effectively linear since the alphabet is bounded.

## Longest Substring with At Least K Repeating Characters

[LeetCode 395](https://leetcode.com/problems/longest-substring-with-at-least-k-repeating-characters/) — String

**Intuition:** Any character appearing fewer than `k` times anywhere in the current substring can never be part of a valid answer — it disqualifies every substring containing it. So: find such a "bad" character, split the string at every occurrence of it, and recurse on each piece. This is divide-and-conquer, not sliding window (the number of distinct characters and their positions don't slide cleanly here).

**Approach:** Count character frequencies in the current substring. If all frequencies are ≥ k, the whole substring is valid — return its length. Otherwise, split on the first character with frequency < k and recurse on each side, taking the max.

```python
def longestSubstring(s: str, k: int) -> int:
    if len(s) < k:
        return 0

    counts = Counter(s)
    for ch, freq in counts.items():
        if freq < k:
            return max(longestSubstring(part, k) for part in s.split(ch))

    return len(s)  # every character meets the threshold
```

**Complexity:** Time O(n × 26) in the typical case (each recursion level does O(n) work, and the recursion depth is bounded by the 26-letter alphabet since each split removes at least one distinct character entirely), space O(n) for recursion and split copies.

**Common mistakes:** Trying to force this into a sliding-window shape — the "at least K repeats" condition isn't monotonic in a way that supports a simple expand/contract two-pointer approach, which is why divide-and-conquer is the right tool here, not the wrong one; forgetting the base case `len(s) < k`, which would otherwise recurse forever on tiny fragments.

## Find All Anagrams in a String

[LeetCode 438](https://leetcode.com/problems/find-all-anagrams-in-a-string/) — String

**Intuition:** Exactly the "sliding-window anagram search" pattern from the concept section — find every starting index in `s` where a fixed-size window is an anagram of `p`.

**Approach:** Fixed-size window of length `len(p)`. Maintain frequency counts and a `matches` counter (how many of the 26 letters currently have equal counts in both windows) to avoid comparing full frequency maps every shift — O(1) per-step check instead of O(26).

```python
def findAnagrams(s: str, p: str) -> list[int]:
    if len(p) > len(s):
        return []

    p_count = [0] * 26
    s_count = [0] * 26
    for ch in p:
        p_count[ord(ch) - ord('a')] += 1

    result = []
    window_len = len(p)

    for i in range(len(s)):
        s_count[ord(s[i]) - ord('a')] += 1
        if i >= window_len:
            left_char = s[i - window_len]
            s_count[ord(left_char) - ord('a')] -= 1
        if i >= window_len - 1 and s_count == p_count:
            result.append(i - window_len + 1)

    return result
```

**Complexity:** Time O(n × 26) — the array comparison `s_count == p_count` is O(26), effectively O(1) since the alphabet is bounded, giving overall O(n). Space O(26) = O(1).

**Common mistakes:** Comparing `Counter` objects every iteration without bounding the alphabet size mentally (still fine here since 26 is a constant, but worth explicitly noting to the interviewer that this is O(1) per check, not O(n)); off-by-one on when the window becomes "full" (`i >= window_len - 1` is the first index at which a complete window exists).

## Minimum Window Substring

[LeetCode 76](https://leetcode.com/problems/minimum-window-substring/) — String — Review

**Intuition:** Find the smallest window in `s` containing all characters of `t` (with at least their required multiplicities). Classic variable-size sliding window: expand `right` until the window is valid (contains everything needed), then contract `left` as far as possible while it stays valid, recording the best window found.

**Approach:** Track required character counts from `t`. Expand `right`, decrementing a "still needed" counter whenever an added character helps satisfy a requirement. Once the counter hits 0 (window is valid), shrink `left` while validity holds, updating the best window at each fully-valid state.

```python
def minWindow(s: str, t: str) -> str:
    if not s or not t:
        return ""

    need = Counter(t)
    missing = len(t)  # total characters still needed (with multiplicity)
    left = 0
    best_left, best_len = 0, float('inf')

    for right, ch in enumerate(s):
        if need[ch] > 0:
            missing -= 1
        need[ch] -= 1

        while missing == 0:
            if right - left + 1 < best_len:
                best_left, best_len = left, right - left + 1

            need[s[left]] += 1
            if need[s[left]] > 0:
                missing += 1
            left += 1

    return s[best_left:best_left + best_len] if best_len != float('inf') else ""
```

**Complexity:** Time O(n + m) where n = len(s), m = len(t) — each index enters and leaves the window at most once. Space O(m) for the `need` counter (bounded by the distinct characters in `t`).

**Common mistakes:** Using `need[ch] > 0` as the sole gate for decrementing `missing` — this correctly ignores characters not in `t` or already over-satisfied, but it's easy to instead decrement `missing` unconditionally, which breaks when duplicate/extra characters appear in the window; forgetting this is a *review* problem because it's genuinely one of the hardest sliding-window problems on LeetCode — if it doesn't come back quickly, revisit yesterday's variable-window material.

## Rabin-Karp Algorithm

LeetCode implement — String

**Intuition:** To find a pattern `p` inside text `s`, naive matching re-compares up to `m` characters at every one of `n` positions (O(n·m)). Rabin-Karp instead hashes the pattern once, then slides a window across `s`, updating the window's hash in **O(1) per shift** using a rolling hash formula — only falling back to a full character comparison when hashes match (to rule out hash collisions).

**Approach:** Compute the pattern's hash and the first window's hash using a polynomial rolling hash (base `B`, modulus `M` to bound value size). At each shift, remove the leaving character's contribution and add the entering character's contribution in O(1). Compare hashes; on a match, verify with a direct substring comparison (handles the rare hash collision).

```python
def rabin_karp(text: str, pattern: str) -> list[int]:
    n, m = len(text), len(pattern)
    if m > n or m == 0:
        return []

    BASE = 256
    MOD = 10 ** 9 + 7

    high_order = pow(BASE, m - 1, MOD)  # BASE^(m-1) mod MOD, for removing the leading digit

    pattern_hash = 0
    window_hash = 0
    for i in range(m):
        pattern_hash = (pattern_hash * BASE + ord(pattern[i])) % MOD
        window_hash = (window_hash * BASE + ord(text[i])) % MOD

    matches = []

    for i in range(n - m + 1):
        if pattern_hash == window_hash:
            if text[i:i + m] == pattern:   # verify to rule out a hash collision
                matches.append(i)

        if i + m < n:
            window_hash = (window_hash - ord(text[i]) * high_order) % MOD
            window_hash = (window_hash * BASE + ord(text[i + m])) % MOD
            window_hash %= MOD

    return matches
```

**Complexity:** Average time O(n + m) — O(1) rolling update per shift, with occasional O(m) verification on hash matches (rare if MOD is large relative to collision risk). Worst case O(n·m) if many spurious hash collisions occur (mitigated by a large prime modulus). Space O(1) extra beyond the output.

**Common mistakes:** Forgetting the modulus, letting the hash grow unbounded (fine in Python's arbitrary-precision integers, but defeats the purpose of a fixed-size rolling hash and is wrong in most other languages — mention this if discussing portability); skipping the verification step after a hash match, which risks a false positive on a genuine collision; getting the rolling-hash update formula's sign wrong when removing the leaving character (must subtract `leaving_char * BASE^(m-1)` **before** re-multiplying by `BASE`, not after).

## Key takeaways

- Build strings with `"".join(list)`, never `+=` in a loop — the latter is O(n²) due to string immutability.
- Anagram detection is frequency-count comparison; sliding-window anagram search upgrades this to an incrementally-maintained frequency array with an O(1)-per-step match counter instead of comparing full counters every shift.
- Not every "substring" problem is sliding window — "at least K repeating characters" needs divide-and-conquer because the validity condition isn't monotonic in window size.
- Minimum Window Substring is the hardest standard sliding-window problem — the `missing` counter trick (only decrement when a character actually helps satisfy a requirement) is the key insight worth re-deriving until automatic.
- Rabin-Karp's rolling hash turns substring search from O(n·m) to average O(n+m) by updating the window hash in O(1) per shift instead of rehashing from scratch — always verify hash matches with a direct comparison to rule out collisions.
