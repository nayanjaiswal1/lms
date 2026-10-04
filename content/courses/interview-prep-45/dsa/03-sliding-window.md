---
kind: lesson
id_key: interview-prep-45/day-03
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Sliding Window"
position: 3
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Picture a train with exactly 3 connected cars, rolling forward one station at a time along a track of 100 stations. At every station, the car at the back detaches and a new one joins at the front, so you always see exactly 3 cars, just a different 3. A sliding window works the same way over an array or a string: a contiguous stretch that grows and shrinks as you scan forward once, instead of checking every possible stretch from scratch (which for 100 elements means checking up to 5,000 different stretches). Sliding window is two pointers' sibling pattern for subarray and substring problems. Instead of pointers moving toward each other from both ends, both pointers move forward, marking out a contiguous window. Reach for it first on "longest, shortest, or best contiguous substring/subarray satisfying X" questions, which show up constantly in string-heavy interviews.

## Fixed vs variable window size

There are two flavors of sliding window, and the train picture above splits neatly into both.

- **Fixed-size window:** the window size `k` is given upfront (for example, "max sum of any subarray of size k"). Slide it by adding the new right element and removing the leftmost element every step: O(1) work per step, O(n) total.
- **Variable-size window:** the window grows and shrinks based on a condition (for example, "longest substring with no repeating characters"). The right pointer always moves forward; the left pointer moves forward only when the window becomes invalid, catching it back up to valid.

Recognizing which flavor a problem needs is the first decision to make. If the problem states a fixed length, it is fixed-size. If it says "longest," "shortest," or "minimum" without a fixed length, it is almost always variable-size.

> **Remember:** a fixed length in the problem means fixed-size window. "Longest" or "shortest" with no fixed length means variable-size.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-fixed-vs-variable-q1", "type": "mcq",
      "prompt": "A problem asks for the \"longest substring with no repeating characters.\" Which sliding-window flavor does it need?",
      "options": [
        {"id": "a", "text": "Variable-size window, since there's no fixed length given"},
        {"id": "b", "text": "Fixed-size window with k equal to the string length"},
        {"id": "c", "text": "Neither; this needs a hash map only, no window"},
        {"id": "d", "text": "Fixed-size window with k = 2"}
      ],
      "correct": "a",
      "explanation": "No specific window length is given, and the word \"longest\" signals the window should grow and shrink based on a condition, which is exactly what a variable-size window does." }
] }
```

## Expanding and contracting the window

Picture a rubber band stretched across a row of 100 seats, covering more seats as you pull it right. The moment it covers a seat that breaks a rule, say two people with the same ticket number both under the band, you let go of the left end until the rule holds again, then keep stretching right. The variable-window template captures that exact motion, and is worth knowing cold:

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
```javascript +
// Generic template — for this demo, "invalid" means a character appears
// more than once in the window, which is exactly the "longest substring
// without repeating characters" case walked through later in this lesson.
function windowIsInvalid(windowState) {
  return Object.values(windowState).some((count) => count > 1);
}

function variableWindowTemplate(s) {
  let left = 0;
  let best = 0;
  const windowState = {}; // whatever tracking the problem needs

  for (let right = 0; right < s.length; right++) {
    // 1. Expand: bring s[right] into the window
    windowState[s[right]] = (windowState[s[right]] || 0) + 1;

    // 2. Contract: while window is invalid, shrink from the left
    while (windowIsInvalid(windowState)) {
      windowState[s[left]] -= 1;
      if (windowState[s[left]] === 0) delete windowState[s[left]];
      left += 1;
    }

    // 3. Record: window [left, right] is now valid — update the answer
    best = Math.max(best, right - left + 1);
  }

  return best;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(variableWindowTemplate("abcabcbb"));
    }

    // Generic template — for this demo, "invalid" means a character appears
    // more than once in the window, which is exactly the "longest substring
    // without repeating characters" case walked through later in this lesson.
    static boolean windowIsInvalid(java.util.Map<Character, Integer> windowState) {
        for (int count : windowState.values()) {
            if (count > 1) return true;
        }
        return false;
    }

    static int variableWindowTemplate(String s) {
        int left = 0;
        int best = 0;
        java.util.Map<Character, Integer> windowState = new java.util.HashMap<>(); // whatever tracking the problem needs

        for (int right = 0; right < s.length(); right++) {
            // 1. Expand: bring s[right] into the window
            char rightCh = s.charAt(right);
            windowState.merge(rightCh, 1, Integer::sum);

            // 2. Contract: while window is invalid, shrink from the left
            while (windowIsInvalid(windowState)) {
                char leftCh = s.charAt(left);
                windowState.put(leftCh, windowState.get(leftCh) - 1);
                if (windowState.get(leftCh) == 0) windowState.remove(leftCh);
                left += 1;
            }

            // 3. Record: window [left, right] is now valid — update the answer
            best = Math.max(best, right - left + 1);
        }

        return best;
    }
}
```

The invariant that matters: the right pointer visits each index once, and the left pointer visits each index at most once, since it only moves forward. That is what makes the whole thing O(n) instead of O(n²): every index is added to the window once and removed at most once.

Harder sliding-window problems, like Minimum Window Substring below, need to track more than a simple count. The real question is whether the window currently satisfies every required character count, not just how many characters it holds. The standard trick is a `have`/`need` counter pair: `need` is fixed, the number of distinct characters that must be satisfied, and `have` increments only when a character's count in the window first reaches its required count. Comparing `have == need` in O(1) avoids rescanning the whole frequency map on every step.

> **Remember:** expand right always. Contract left only while the window is invalid. `have == need` checks validity in O(1) instead of rescanning.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-expand-contract-q1", "type": "mcq",
      "prompt": "In the variable-window template, why does the total work stay O(n) even though there's a while loop nested inside a for loop?",
      "options": [
        {"id": "a", "text": "The left pointer only ever moves forward, so across the whole run it advances at most n times total"},
        {"id": "b", "text": "The while loop only ever runs once per problem"},
        {"id": "c", "text": "The right pointer resets to 0 after each contraction"},
        {"id": "d", "text": "Hash map operations are always O(n)"}
      ],
      "correct": "a",
      "explanation": "Even though the while loop is nested, left never moves backward. Summed across every iteration of the outer loop, left advances at most n times in total, so the whole thing is O(n), not O(n²)." }
] }
```

## Best Time to Buy and Sell Stock

[Best Time to Buy and Sell Stock (LeetCode 121)](https://leetcode.com/problems/best-time-to-buy-and-sell-stock/)

**Intuition:** This is a sliding window in disguise. The window is "buy day to sell day," and you want to maximize `price[sell] - price[buy]`. Instead of nested loops trying every pair, track the minimum price seen so far as you scan. That is an implicit left pointer that only ever moves forward when it finds a new minimum.

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
```javascript +
function maxProfit(prices) {
  let minPrice = Infinity;
  let bestProfit = 0;
  for (const price of prices) {
    minPrice = Math.min(minPrice, price);
    bestProfit = Math.max(bestProfit, price - minPrice);
  }
  return bestProfit;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] prices = {7, 1, 5, 3, 6, 4};
        System.out.println(maxProfit(prices));
    }

    static int maxProfit(int[] prices) {
        int minPrice = Integer.MAX_VALUE;
        int bestProfit = 0;
        for (int price : prices) {
            minPrice = Math.min(minPrice, price);
            bestProfit = Math.max(bestProfit, price - minPrice);
        }
        return bestProfit;
    }
}
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:**
- Nested loops checking every buy/sell pair: O(n²), works, but interviewers expect the O(n) version.
- Updating `best_profit` before updating `min_price` on the same day. The order does not actually break this problem, since you cannot buy and sell on the same day at a profit from the exact same price, but get the order right by habit for variants.
- Confusing this with the "multiple transactions allowed" variant (LeetCode 122), which needs a different, greedy approach.

> **Remember:** track the minimum price seen so far. The best profit at any day is today's price minus that running minimum.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-buy-sell-stock-q1", "type": "mcq",
      "prompt": "What single running value does the O(n) solution to Best Time to Buy and Sell Stock track?",
      "options": [
        {"id": "a", "text": "The minimum price seen so far"},
        {"id": "b", "text": "The maximum price seen so far"},
        {"id": "c", "text": "The average price so far"},
        {"id": "d", "text": "The index of the first price"}
      ],
      "correct": "a",
      "explanation": "Tracking the minimum price seen so far lets you compute, at every day, the best possible profit if you sold today: current price minus that running minimum." }
] }
```

## Longest Substring Without Repeating Characters

[Longest Substring Without Repeating Characters (LeetCode 3)](https://leetcode.com/problems/longest-substring-without-repeating-characters/)

**Intuition:** A classic variable-size window. Expand right, adding characters to a map. The moment you would add a duplicate, the window is invalid, so shrink from the left until the duplicate is gone.

**Approach:** Use a hash map storing the last seen index of each character, instead of a boolean set. That lets you jump the left pointer straight to just past the duplicate's previous position, instead of moving it one step at a time.

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
```javascript +
function lengthOfLongestSubstring(s) {
  const lastSeen = new Map(); // char -> most recent index
  let left = 0;
  let best = 0;
  for (let right = 0; right < s.length; right++) {
    const ch = s[right];
    if (lastSeen.has(ch) && lastSeen.get(ch) >= left) {
      left = lastSeen.get(ch) + 1;
    }
    lastSeen.set(ch, right);
    best = Math.max(best, right - left + 1);
  }
  return best;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(lengthOfLongestSubstring("abcabcbb"));
    }

    static int lengthOfLongestSubstring(String s) {
        java.util.Map<Character, Integer> lastSeen = new java.util.HashMap<>();
        int left = 0;
        int best = 0;
        for (int right = 0; right < s.length(); right++) {
            char ch = s.charAt(right);
            if (lastSeen.containsKey(ch) && lastSeen.get(ch) >= left) {
                left = lastSeen.get(ch) + 1;
            }
            lastSeen.put(ch, right);
            best = Math.max(best, right - left + 1);
        }
        return best;
    }
}
```

**Complexity:** Time O(n): each index visited once by `right`, and `left` jumps but never revisits. Space O(min(n, alphabet size)) for the map.

**Common mistakes:**
- Using a plain set and shrinking `left` one step at a time. Still O(n) amortized, but the last-seen-index version is cleaner and the standard answer.
- Forgetting the `last_seen[ch] >= left` check. Without it, a stale index from before the current window yanks `left` backward incorrectly.
- Off-by-one on window length: it is `right - left + 1`, not `right - left`.

> **Remember:** store the last seen index of each character, and jump `left` straight past a duplicate instead of stepping one at a time.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-longest-substring-q1", "type": "mcq",
      "prompt": "Why must the check be `last_seen[ch] >= left`, and not just `ch in last_seen`?",
      "options": [
        {"id": "a", "text": "A stale index from before the current window would otherwise pull `left` backward"},
        {"id": "b", "text": "It makes the algorithm run in O(1) instead of O(n)"},
        {"id": "c", "text": "It is only a style preference, not a correctness issue"},
        {"id": "d", "text": "Without it, the map would grow unbounded"}
      ],
      "correct": "a",
      "explanation": "A character might have been seen before, but outside the current window (its last-seen index is less than left). Moving left backward to that stale position would be wrong; the >= left check makes sure only in-window duplicates matter." }
] }
```

## Minimum Window Substring

[Minimum Window Substring (LeetCode 76)](https://leetcode.com/problems/minimum-window-substring/)

**Intuition:** Find the smallest window in `s` that contains every character of `t`, counting repeats. This needs the `have`/`need` tracking from earlier: expand right until the window satisfies every requirement in `t`, then greedily contract left as far as possible while staying valid, recording the smallest valid window found.

**Approach:**
1. Build a frequency map of `t`. `need` is the number of distinct characters in `t`.
2. Expand `right` across `s`, updating a window frequency map. When a character's window count first equals its required count, increment `have`.
3. While `have == need` (window is valid), record the window if it is the smallest so far, then contract `left`, decrementing `have` if shrinking breaks a satisfied requirement.

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
```javascript +
function minWindow(s, t) {
  if (!s || !t) return "";

  const needCounts = new Map();
  for (const ch of t) needCounts.set(ch, (needCounts.get(ch) || 0) + 1);
  const need = needCounts.size;
  const windowCounts = new Map();
  let have = 0;

  let left = 0;
  let bestLen = Infinity;
  let bestLeft = 0;

  for (let right = 0; right < s.length; right++) {
    const ch = s[right];
    windowCounts.set(ch, (windowCounts.get(ch) || 0) + 1);
    if (needCounts.has(ch) && windowCounts.get(ch) === needCounts.get(ch)) {
      have += 1;
    }

    while (have === need) {
      if (right - left + 1 < bestLen) {
        bestLen = right - left + 1;
        bestLeft = left;
      }

      const leftCh = s[left];
      windowCounts.set(leftCh, windowCounts.get(leftCh) - 1);
      if (needCounts.has(leftCh) && windowCounts.get(leftCh) < needCounts.get(leftCh)) {
        have -= 1;
      }
      left += 1;
    }
  }

  return bestLen === Infinity ? "" : s.slice(bestLeft, bestLeft + bestLen);
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(minWindow("ADOBECODEBANC", "ABC"));
    }

    static String minWindow(String s, String t) {
        if (s.isEmpty() || t.isEmpty()) return "";

        java.util.Map<Character, Integer> needCounts = new java.util.HashMap<>();
        for (char ch : t.toCharArray()) {
            needCounts.merge(ch, 1, Integer::sum);
        }
        int need = needCounts.size();
        java.util.Map<Character, Integer> windowCounts = new java.util.HashMap<>();
        int have = 0;

        int left = 0;
        int bestLen = Integer.MAX_VALUE;
        int bestLeft = 0;

        for (int right = 0; right < s.length(); right++) {
            char ch = s.charAt(right);
            windowCounts.merge(ch, 1, Integer::sum);
            if (needCounts.containsKey(ch) && windowCounts.get(ch).equals(needCounts.get(ch))) {
                have += 1;
            }

            while (have == need) {
                if (right - left + 1 < bestLen) {
                    bestLen = right - left + 1;
                    bestLeft = left;
                }

                char leftCh = s.charAt(left);
                windowCounts.put(leftCh, windowCounts.get(leftCh) - 1);
                if (needCounts.containsKey(leftCh) && windowCounts.get(leftCh) < needCounts.get(leftCh)) {
                    have -= 1;
                }
                left += 1;
            }
        }

        return bestLen == Integer.MAX_VALUE ? "" : s.substring(bestLeft, bestLeft + bestLen);
    }
}
```

**Complexity:** Time O(|s| + |t|): building the `t` counter is O(|t|), and both pointers over `s` move forward only, giving O(|s|). Space O(|t|) for the need map, O(alphabet) for the window map.

**Common mistakes:**
- Recomputing "is the window valid" by scanning the whole frequency map every step, instead of tracking `have`/`need` incrementally. That turns O(n) into O(n·k).
- Off-by-one when decrementing `have`: it must trigger only when the count drops below the required amount, not merely when it changes.
- Not handling characters in `s` that are not in `t` at all. They should still count in `window_counts` (harmless) but never affect `have`.

The five problems in this lesson split into two families it is easy to mix up under time pressure. Buy/Sell Stock and Longest Substring are single-condition windows: one running value (`min_price`, `last_seen`) is enough to decide when to move the left pointer. Minimum Window Substring is a multi-condition window: validity depends on satisfying several counts at once, which is why it needs `have`/`need` instead of a single tracked value. Before coding, ask how many conditions define "valid" for this window. One condition, track a running value. Several conditions, reach for `have`/`need`.

> **Remember:** one condition to satisfy, track a single running value. Several conditions at once, use `have`/`need`.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-min-window-substring-q1", "type": "mcq",
      "prompt": "Why does Minimum Window Substring need a `have`/`need` counter pair instead of a single running value?",
      "options": [
        {"id": "a", "text": "Validity depends on satisfying several distinct character counts at once, not one condition"},
        {"id": "b", "text": "Because the strings can contain digits"},
        {"id": "c", "text": "Because the window must be fixed size"},
        {"id": "d", "text": "Because Python dictionaries can't store single counters"}
      ],
      "correct": "a",
      "explanation": "The window is valid only when every distinct character in t has been matched to its required count. That is multiple simultaneous conditions, which is exactly what have (satisfied so far) versus need (total required) is built to track in O(1)." }
] }
```

## When sliding window doesn't apply

Picture the rubber band again, stretched over seats with only positive ticket numbers written on them. Adding a seat to the band only ever adds to the running total, it never subtracts, so once the total is too high, letting go of seats on the left is the only way to bring it back down: stretching further right never helps. That is the one assumption every sliding-window template leans on: once a window becomes invalid, it stays invalid until you contract it. Expanding never fixes an invalid window; only contracting does. This holds when the tracked property moves in one direction as the window grows: a sum only increases as you add non-negative numbers, a distinct-count only increases as you add elements.

It breaks the moment that stops being true. "Smallest subarray with sum at least target" works cleanly with non-negative numbers, because growing the window can only help reach the target, and shrinking can only hurt. Allow negative numbers, and adding an element can decrease the sum, so a window that looks invalid might become valid again by expanding further instead of contracting. At that point "contract while invalid" no longer proves anything.

The test to run before reaching for sliding window: can you prove that once the window is invalid, it stays invalid until contracted? If you cannot, sliding window will not crash. It will silently return a wrong answer, which is the dangerous failure mode: no exception, nothing obviously wrong to warn you.

For "subarray with sum exactly equal to k" where negatives are allowed, there is no one-directional property to exploit, so sliding window does not work. The standard tool instead is a prefix sum with a hash map of sums seen so far:

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

This runs in O(n) time and space, the same complexity class as sliding window, but it is a different technique: no left/right pointers, no expand/contract. It applies exactly where sliding window's one-directional requirement fails.

| Signal | Technique |
|---|---|
| Fixed size `k` given | Sliding window (fixed) |
| "Longest/shortest subarray such that..." with a one-directional property | Sliding window (variable) |
| Negative numbers and an exact sum target | Prefix sum + hash map |
| Pointers start at both ends, move inward (like Container With Most Water) | Two pointers (a different technique despite the name) |

Before submitting a sliding-window solution, check:
- The one-directional assumption holds, or you have switched to prefix sum instead.
- Window size is `right - left + 1`, not `right - left`.
- Contract order: remove using the current `left`, then `left += 1`.
- `if` vs `while` matches whether more than one contraction step is possible: fixed-size windows contract by exactly one (`if`), variable-size windows can need zero to many contractions per step (`while`). Using `if` where `while` is needed leaves the window invalid after only one contraction, the most common sliding-window bug.
- The answer is recorded at the right point. For a longest-valid-subarray problem, record it after the contraction loop exits, once the window is valid again. For a shortest-valid-subarray problem, record it inside the contraction loop, on every contraction, since that is the smallest the window gets before it goes invalid again.
- `left` never moves backward anywhere in the code. That is what makes the amortized O(n) argument hold.

> **Remember:** sliding window needs "once invalid, stays invalid until contracted." Negative numbers usually break that; reach for prefix sum + hash map instead.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-when-it-fails-q1", "type": "mcq",
      "prompt": "Why doesn't sliding window work for \"subarray with sum exactly equal to k\" when the array can contain negative numbers?",
      "options": [
        {"id": "a", "text": "Adding an element can decrease the sum, so an invalid window might become valid again by expanding, not just by contracting"},
        {"id": "b", "text": "Sliding window only works on strings, never on numeric arrays"},
        {"id": "c", "text": "The window size would need to be negative"},
        {"id": "d", "text": "Hash maps can't store negative numbers as values"}
      ],
      "correct": "a",
      "explanation": "Sliding window depends on the window staying invalid once it becomes invalid, until you shrink it. With negative numbers, the running sum isn't one-directional as the window grows, so that assumption breaks and the technique gives wrong answers silently." }
] }
```
