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

String problems mix two skills you've already built, sliding window and frequency counting, with the specifics of efficient string construction and pattern matching. Today closes out the "strings" arc with harder sliding-window variants, an anagram-detection pattern you'll reuse constantly, and a classic string-matching algorithm.

## String building

Python strings are immutable. Every `s += char` creates a brand-new string, making naive concatenation in a loop **O(n²)** overall, since each of n appends copies the whole string so far.

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

```javascript +
// O(n^2) - avoid in a loop
let result = "";
for (const ch of "abcdef") {
    result += ch;
}

// O(n) - build an array, join once
const parts = [];
for (const ch of "abcdef") {
    parts.push(ch);
}
result = parts.join("");
```

```java +
public class Main {
    public static void main(String[] args) {
        // O(n^2) - avoid in a loop: String is immutable, += allocates a new String each time
        String result = "";
        for (char ch : "abcdef".toCharArray()) {
            result += ch;
        }

        // O(n) - build with StringBuilder, convert once
        StringBuilder parts = new StringBuilder();
        for (char ch : "abcdef".toCharArray()) {
            parts.append(ch);
        }
        result = parts.toString();

        System.out.println(result);
    }
}
```

`"".join(list_of_strings)` is the idiomatic O(n) pattern: it computes the final length once and allocates a single buffer, instead of reallocating on every append. This matters specifically when a problem asks you to build a result string inside a loop that could run thousands of times.

## Pattern matching

"Does string A appear inside string B" comes up disguised in many forms: substring search, anagram windows, repeated patterns. The naive approach checks every starting position in B against A character-by-character: **O(n·m)** where n = len(B), m = len(A). Two techniques improve on this:

1. **Sliding window with frequency counts.** When you're looking for anagrams/permutations of A within B rather than an exact substring match, maintain a frequency map of A and compare against a same-size window's frequency map as it slides. This avoids re-scanning m characters at every position.
2. **Rabin-Karp (rolling hash).** When you need exact substring matches, hash A once, then compute B's window hashes incrementally (O(1) update per shift) instead of rehashing the whole window each time. See below.

## Anagram detection

Two strings are anagrams if they contain exactly the same characters with the same multiplicities. The standard check: compare `Counter` (or a fixed-size frequency array) of both strings.

```python
from collections import Counter

def is_anagram(s: str, t: str) -> bool:
    return Counter(s) == Counter(t)
```

```javascript +
function isAnagram(s, t) {
    const count = (str) => {
        const map = new Map();
        for (const ch of str) {
            map.set(ch, (map.get(ch) || 0) + 1);
        }
        return map;
    };

    const sCount = count(s);
    const tCount = count(t);
    if (sCount.size !== tCount.size) return false;

    for (const [ch, freq] of sCount) {
        if (tCount.get(ch) !== freq) return false;
    }
    return true;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(isAnagram("listen", "silent"));
    }

    static boolean isAnagram(String s, String t) {
        if (s.length() != t.length()) return false;

        Map<Character, Integer> counts = new HashMap<>();
        for (char ch : s.toCharArray()) {
            counts.merge(ch, 1, Integer::sum);
        }
        for (char ch : t.toCharArray()) {
            counts.merge(ch, -1, Integer::sum);
        }

        for (int freq : counts.values()) {
            if (freq != 0) return false;
        }
        return true;
    }
}
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

```javascript +
function findAnagramWindows(s, p) {
    if (p.length > s.length) return [];

    const countOf = (str) => {
        const map = new Map();
        for (const ch of str) {
            map.set(ch, (map.get(ch) || 0) + 1);
        }
        return map;
    };

    const mapsEqual = (a, b) => {
        if (a.size !== b.size) return false;
        for (const [key, val] of a) {
            if (b.get(key) !== val) return false;
        }
        return true;
    };

    const pCount = countOf(p);
    const windowCount = countOf(s.slice(0, p.length));
    const result = [];

    if (mapsEqual(windowCount, pCount)) {
        result.push(0);
    }

    for (let i = p.length; i < s.length; i++) {
        const leftChar = s[i - p.length];
        windowCount.set(s[i], (windowCount.get(s[i]) || 0) + 1);
        windowCount.set(leftChar, windowCount.get(leftChar) - 1);
        if (windowCount.get(leftChar) === 0) {
            windowCount.delete(leftChar);
        }

        if (mapsEqual(windowCount, pCount)) {
            result.push(i - p.length + 1);
        }
    }

    return result;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(findAnagramWindows("cbaebabacd", "abc"));
    }

    static List<Integer> findAnagramWindows(String s, String p) {
        List<Integer> result = new ArrayList<>();
        if (p.length() > s.length()) return result;

        Map<Character, Integer> pCount = new HashMap<>();
        for (char ch : p.toCharArray()) {
            pCount.merge(ch, 1, Integer::sum);
        }

        Map<Character, Integer> windowCount = new HashMap<>();
        for (int i = 0; i < p.length(); i++) {
            windowCount.merge(s.charAt(i), 1, Integer::sum);
        }

        if (windowCount.equals(pCount)) {
            result.add(0);
        }

        for (int i = p.length(); i < s.length(); i++) {
            char leftChar = s.charAt(i - p.length());
            windowCount.merge(s.charAt(i), 1, Integer::sum);
            windowCount.merge(leftChar, -1, Integer::sum);
            if (windowCount.get(leftChar) == 0) {
                windowCount.remove(leftChar);
            }

            if (windowCount.equals(pCount)) {
                result.add(i - p.length() + 1);
            }
        }

        return result;
    }
}
```

**Complexity:** O(n) amortized if you avoid the O(26) `Counter == Counter` comparison per step. One optimization: track a running `matches` integer instead of comparing full Counters (see Find All Anagrams below for the fully optimized version). The version above is O(n · 26) worst case, which is still effectively linear since the alphabet is bounded.

## Longest Substring with At Least K Repeating Characters

[LeetCode 395](https://leetcode.com/problems/longest-substring-with-at-least-k-repeating-characters/) — String

**Intuition:** Any character appearing fewer than `k` times anywhere in the current substring can never be part of a valid answer: it disqualifies every substring containing it. So find such a "bad" character, split the string at every occurrence of it, and recurse on each piece. This is divide-and-conquer, not sliding window, since the number of distinct characters and their positions don't slide cleanly here.

**Approach:** Count character frequencies in the current substring. If all frequencies are ≥ k, the whole substring is valid, so return its length. Otherwise, split on the first character with frequency < k and recurse on each side, taking the max.

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

```javascript +
function longestSubstring(s, k) {
    if (s.length < k) return 0;

    const counts = new Map();
    for (const ch of s) {
        counts.set(ch, (counts.get(ch) || 0) + 1);
    }

    for (const [ch, freq] of counts) {
        if (freq < k) {
            return Math.max(...s.split(ch).map((part) => longestSubstring(part, k)));
        }
    }

    return s.length; // every character meets the threshold
}
```

```java +
import java.util.*;
import java.util.regex.Pattern;

public class Main {
    public static void main(String[] args) {
        System.out.println(longestSubstring("aaabb", 3));
    }

    static int longestSubstring(String s, int k) {
        if (s.length() < k) return 0;

        Map<Character, Integer> counts = new HashMap<>();
        for (char ch : s.toCharArray()) {
            counts.merge(ch, 1, Integer::sum);
        }

        for (Map.Entry<Character, Integer> entry : counts.entrySet()) {
            if (entry.getValue() < k) {
                int best = 0;
                String splitPattern = Pattern.quote(String.valueOf(entry.getKey()));
                for (String part : s.split(splitPattern)) {
                    best = Math.max(best, longestSubstring(part, k));
                }
                return best;
            }
        }

        return s.length(); // every character meets the threshold
    }
}
```

**Complexity:** Time O(n × 26) in the typical case: each recursion level does O(n) work, and the recursion depth is bounded by the 26-letter alphabet since each split removes at least one distinct character entirely. Space O(n) for recursion and split copies.

**Common mistakes:** Trying to force this into a sliding-window shape. The "at least K repeats" condition isn't monotonic in a way that supports a simple expand/contract two-pointer approach, which is why divide-and-conquer is the right tool here. Also, forgetting the base case `len(s) < k`, which would otherwise recurse forever on tiny fragments.

## Find All Anagrams in a String

[LeetCode 438](https://leetcode.com/problems/find-all-anagrams-in-a-string/) — String

**Intuition:** Exactly the "sliding-window anagram search" pattern from the concept section: find every starting index in `s` where a fixed-size window is an anagram of `p`.

**Approach:** Fixed-size window of length `len(p)`. Maintain frequency counts and a `matches` counter (how many of the 26 letters currently have equal counts in both windows) to avoid comparing full frequency maps every shift: an O(1) per-step check instead of O(26).

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

```javascript +
function findAnagrams(s, p) {
    if (p.length > s.length) return [];

    const pCount = new Array(26).fill(0);
    const sCount = new Array(26).fill(0);
    const aCode = 'a'.charCodeAt(0);

    for (const ch of p) {
        pCount[ch.charCodeAt(0) - aCode]++;
    }

    const result = [];
    const windowLen = p.length;

    for (let i = 0; i < s.length; i++) {
        sCount[s.charCodeAt(i) - aCode]++;
        if (i >= windowLen) {
            const leftChar = s[i - windowLen];
            sCount[leftChar.charCodeAt(0) - aCode]--;
        }
        if (i >= windowLen - 1 && sCount.every((count, idx) => count === pCount[idx])) {
            result.push(i - windowLen + 1);
        }
    }

    return result;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(findAnagrams("cbaebabacd", "abc"));
    }

    static List<Integer> findAnagrams(String s, String p) {
        List<Integer> result = new ArrayList<>();
        if (p.length() > s.length()) return result;

        int[] pCount = new int[26];
        int[] sCount = new int[26];
        for (char ch : p.toCharArray()) {
            pCount[ch - 'a']++;
        }

        int windowLen = p.length();

        for (int i = 0; i < s.length(); i++) {
            sCount[s.charAt(i) - 'a']++;
            if (i >= windowLen) {
                char leftChar = s.charAt(i - windowLen);
                sCount[leftChar - 'a']--;
            }
            if (i >= windowLen - 1 && Arrays.equals(sCount, pCount)) {
                result.add(i - windowLen + 1);
            }
        }

        return result;
    }
}
```

**Complexity:** Time O(n × 26): the array comparison `s_count == p_count` is O(26), effectively O(1) since the alphabet is bounded, giving overall O(n). Space O(26) = O(1).

**Common mistakes:** Comparing `Counter` objects every iteration without bounding the alphabet size mentally. Still fine here since 26 is a constant, but worth explicitly noting to the interviewer that this is O(1) per check, not O(n). Also, off-by-one on when the window becomes "full": `i >= window_len - 1` is the first index at which a complete window exists.

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

```javascript +
function minWindow(s, t) {
    if (!s || !t) return "";

    const need = new Map();
    for (const ch of t) {
        need.set(ch, (need.get(ch) || 0) + 1);
    }

    let missing = t.length; // total characters still needed (with multiplicity)
    let left = 0;
    let bestLeft = 0;
    let bestLen = Infinity;

    for (let right = 0; right < s.length; right++) {
        const ch = s[right];
        if ((need.get(ch) || 0) > 0) {
            missing--;
        }
        need.set(ch, (need.get(ch) || 0) - 1);

        while (missing === 0) {
            if (right - left + 1 < bestLen) {
                bestLeft = left;
                bestLen = right - left + 1;
            }

            const leftChar = s[left];
            need.set(leftChar, (need.get(leftChar) || 0) + 1);
            if (need.get(leftChar) > 0) {
                missing++;
            }
            left++;
        }
    }

    return bestLen === Infinity ? "" : s.slice(bestLeft, bestLeft + bestLen);
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(minWindow("ADOBECODEBANC", "ABC"));
    }

    static String minWindow(String s, String t) {
        if (s.isEmpty() || t.isEmpty()) return "";

        Map<Character, Integer> need = new HashMap<>();
        for (char ch : t.toCharArray()) {
            need.merge(ch, 1, Integer::sum);
        }

        int missing = t.length(); // total characters still needed (with multiplicity)
        int left = 0;
        int bestLeft = 0;
        int bestLen = Integer.MAX_VALUE;

        for (int right = 0; right < s.length(); right++) {
            char ch = s.charAt(right);
            if (need.getOrDefault(ch, 0) > 0) {
                missing--;
            }
            need.merge(ch, -1, Integer::sum);

            while (missing == 0) {
                if (right - left + 1 < bestLen) {
                    bestLeft = left;
                    bestLen = right - left + 1;
                }

                char leftChar = s.charAt(left);
                need.merge(leftChar, 1, Integer::sum);
                if (need.get(leftChar) > 0) {
                    missing++;
                }
                left++;
            }
        }

        return bestLen == Integer.MAX_VALUE ? "" : s.substring(bestLeft, bestLeft + bestLen);
    }
}
```

**Complexity:** Time O(n + m) where n = len(s), m = len(t): each index enters and leaves the window at most once. Space O(m) for the `need` counter (bounded by the distinct characters in `t`).

**Common mistakes:** Using `need[ch] > 0` as the sole gate for decrementing `missing` correctly ignores characters not in `t` or already over-satisfied, but it's easy to instead decrement `missing` unconditionally, which breaks when duplicate/extra characters appear in the window. Also worth remembering: this is a *review* problem because it's genuinely one of the hardest sliding-window problems on LeetCode. If it doesn't come back quickly, revisit yesterday's variable-window material.

## Rabin-Karp Algorithm

LeetCode implement: String

**Intuition:** To find a pattern `p` inside text `s`, naive matching re-compares up to `m` characters at every one of `n` positions (O(n·m)). Rabin-Karp instead hashes the pattern once, then slides a window across `s`, updating the window's hash in **O(1) per shift** using a rolling hash formula, falling back to a full character comparison only when hashes match, to rule out hash collisions.

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

```javascript +
function rabinKarp(text, pattern) {
    const n = text.length;
    const m = pattern.length;
    if (m > n || m === 0) return [];

    const BASE = 256n;
    const MOD = 1000000007n;

    let highOrder = 1n;
    for (let i = 0; i < m - 1; i++) {
        highOrder = (highOrder * BASE) % MOD; // BASE^(m-1) mod MOD, for removing the leading digit
    }

    let patternHash = 0n;
    let windowHash = 0n;
    for (let i = 0; i < m; i++) {
        patternHash = (patternHash * BASE + BigInt(pattern.charCodeAt(i))) % MOD;
        windowHash = (windowHash * BASE + BigInt(text.charCodeAt(i))) % MOD;
    }

    const matches = [];

    for (let i = 0; i <= n - m; i++) {
        if (patternHash === windowHash) {
            if (text.slice(i, i + m) === pattern) { // verify to rule out a hash collision
                matches.push(i);
            }
        }

        if (i + m < n) {
            windowHash = (windowHash - BigInt(text.charCodeAt(i)) * highOrder) % MOD;
            windowHash = (windowHash * BASE + BigInt(text.charCodeAt(i + m))) % MOD;
            windowHash = ((windowHash % MOD) + MOD) % MOD;
        }
    }

    return matches;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(rabinKarp("ababcababcabc", "abc"));
    }

    static List<Integer> rabinKarp(String text, String pattern) {
        int n = text.length();
        int m = pattern.length();
        List<Integer> matches = new ArrayList<>();
        if (m > n || m == 0) return matches;

        final long BASE = 256;
        final long MOD = 1_000_000_007L;

        long highOrder = 1;
        for (int i = 0; i < m - 1; i++) {
            highOrder = (highOrder * BASE) % MOD; // BASE^(m-1) mod MOD, for removing the leading digit
        }

        long patternHash = 0;
        long windowHash = 0;
        for (int i = 0; i < m; i++) {
            patternHash = (patternHash * BASE + pattern.charAt(i)) % MOD;
            windowHash = (windowHash * BASE + text.charAt(i)) % MOD;
        }

        for (int i = 0; i <= n - m; i++) {
            if (patternHash == windowHash) {
                if (text.substring(i, i + m).equals(pattern)) { // verify to rule out a hash collision
                    matches.add(i);
                }
            }

            if (i + m < n) {
                windowHash = (windowHash - text.charAt(i) * highOrder % MOD + MOD) % MOD;
                windowHash = (windowHash * BASE + text.charAt(i + m)) % MOD;
            }
        }

        return matches;
    }
}
```

**Complexity:** Average time O(n + m): O(1) rolling update per shift, with occasional O(m) verification on hash matches, which is rare if MOD is large relative to collision risk. Worst case O(n·m) if many spurious hash collisions occur, mitigated by a large prime modulus. Space O(1) extra beyond the output.

**Common mistakes:** Forgetting the modulus and letting the hash grow unbounded is fine in Python's arbitrary-precision integers, but it defeats the purpose of a fixed-size rolling hash and is wrong in most other languages, worth mentioning if discussing portability. Skipping the verification step after a hash match risks a false positive on a genuine collision. And getting the rolling-hash update formula's sign wrong when removing the leaving character is a classic slip: you must subtract `leaving_char * BASE^(m-1)` **before** re-multiplying by `BASE`, not after.

Notice the shape common to Find All Anagrams, Minimum Window Substring, and Rabin-Karp: each replaces a per-position O(alphabet) or O(pattern-length) recheck with an O(1) incremental update, whether that's a match counter, a "missing" tally, or a rolling hash. That trade, recomputing nothing you can update instead, is the real skill this lesson is teaching.
