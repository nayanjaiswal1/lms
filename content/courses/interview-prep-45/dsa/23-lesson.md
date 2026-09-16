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

You've used basic sliding window before. Today's problems push it further: windows that track auxiliary data structures like frequency counts, and windows that must satisfy multiple simultaneous conditions. This is the pattern behind most "longest/shortest substring/subarray with property X" interview questions.

## Fixed window with data structures

A **fixed-size window** slides one element at a time. Instead of just a running sum, you often maintain a frequency map or count that updates incrementally as elements enter and leave.

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

```javascript +
function maxDistinctInWindow(nums, k) {
    const counts = new Map();
    for (let i = 0; i < k; i++) {
        counts.set(nums[i], (counts.get(nums[i]) || 0) + 1);
    }
    let best = counts.size;

    for (let i = k; i < nums.length; i++) {
        counts.set(nums[i], (counts.get(nums[i]) || 0) + 1); // element entering
        const left = nums[i - k];
        counts.set(left, counts.get(left) - 1);              // element leaving
        if (counts.get(left) === 0) {
            counts.delete(left);                             // keep the map accurate for size checks
        }
        best = Math.max(best, counts.size);
    }

    return best;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[] nums = {1, 2, 1, 3, 4, 2, 3};
        System.out.println(maxDistinctInWindow(nums, 4));
    }

    static int maxDistinctInWindow(int[] nums, int k) {
        Map<Integer, Integer> counts = new HashMap<>();
        for (int i = 0; i < k; i++) {
            counts.merge(nums[i], 1, Integer::sum);
        }
        int best = counts.size();

        for (int i = k; i < nums.length; i++) {
            counts.merge(nums[i], 1, Integer::sum); // element entering
            int left = nums[i - k];
            counts.merge(left, -1, Integer::sum);   // element leaving
            if (counts.get(left) == 0) {
                counts.remove(left);                // keep the map accurate for size checks
            }
            best = Math.max(best, counts.size());
        }

        return best;
    }
}
```

The pattern: every fixed-window problem does exactly two things per step, add the incoming element's effect, remove the outgoing element's effect. The "effect" can be a sum, a frequency count, a max-tracking deque, or any other incrementally-maintainable structure. Never recompute the whole window from scratch each step, since that turns an O(n) sliding window into O(n·k).

## Variable window tracking multiple conditions

A **variable-size window** grows by advancing `right` and shrinks by advancing `left`, expanding while a condition holds and contracting when it's violated. The advanced version tracks *several* conditions at once, for example "at most 2 distinct characters AND window length ≤ some bound."

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

```javascript +
function variableWindowSkeleton(s, isValid) {
    let left = 0;
    let best = 0;
    const windowState = new Map(); // whatever data the condition needs: counts, max-freq, etc.

    for (let right = 0; right < s.length; right++) {
        // 1. expand: absorb s[right] into windowState
        windowState.set(s[right], (windowState.get(s[right]) || 0) + 1);

        // 2. contract while the window violates the condition
        while (!isValid(windowState, right - left + 1)) {
            const leftChar = s[left];
            windowState.set(leftChar, windowState.get(leftChar) - 1);
            if (windowState.get(leftChar) === 0) {
                windowState.delete(leftChar);
            }
            left++;
        }

        // 3. record the best valid window at this right boundary
        best = Math.max(best, right - left + 1);
    }

    return best;
}
```

```java +
import java.util.*;
import java.util.function.BiFunction;

public class Main {
    public static void main(String[] args) {
        // Example: window valid while it has at most 2 distinct characters
        BiFunction<Map<Character, Integer>, Integer, Boolean> atMostTwoDistinct =
            (state, length) -> state.size() <= 2;

        System.out.println(variableWindowSkeleton("eceba", atMostTwoDistinct));
    }

    static int variableWindowSkeleton(String s, BiFunction<Map<Character, Integer>, Integer, Boolean> isValid) {
        int left = 0;
        int best = 0;
        Map<Character, Integer> windowState = new HashMap<>(); // whatever data the condition needs

        for (int right = 0; right < s.length(); right++) {
            // 1. expand: absorb s[right] into windowState
            char rightChar = s.charAt(right);
            windowState.merge(rightChar, 1, Integer::sum);

            // 2. contract while the window violates the condition
            while (!isValid.apply(windowState, right - left + 1)) {
                char leftChar = s.charAt(left);
                windowState.merge(leftChar, -1, Integer::sum);
                if (windowState.get(leftChar) == 0) {
                    windowState.remove(leftChar);
                }
                left++;
            }

            // 3. record the best valid window at this right boundary
            best = Math.max(best, right - left + 1);
        }

        return best;
    }
}
```

Critical invariant: `left` only ever moves forward. It never resets to 0 and re-scans. This is what makes the whole algorithm O(n) instead of O(n²): each index enters and leaves the window at most once across the entire run, so total work across all iterations of the inner `while` is bounded by n, not n per outer step.

## Longest Repeating Character Replacement

[LeetCode 424](https://leetcode.com/problems/longest-repeating-character-replacement/) — Sliding window

**Intuition:** You can change up to `k` characters in a window to make all characters the same. A window is valid if `window_length - count_of_most_frequent_char <= k`, which is exactly the number of characters you'd need to replace.

**Approach:** Expand `right`, tracking a frequency count and the running max frequency seen. `max_freq` never needs to decrease even as the window shrinks; it only ever underestimates slightly, but that's safe because the answer only grows when a *new* max_freq is achieved, so a stale-but-not-overestimating max_freq can't produce a wrong larger answer. Shrink `left` only when the window becomes invalid.

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

```javascript +
function characterReplacement(s, k) {
    const counts = new Map();
    let left = 0;
    let maxFreq = 0;
    let best = 0;

    for (let right = 0; right < s.length; right++) {
        const ch = s[right];
        counts.set(ch, (counts.get(ch) || 0) + 1);
        maxFreq = Math.max(maxFreq, counts.get(ch));

        const windowLen = right - left + 1;
        if (windowLen - maxFreq > k) {
            const leftChar = s[left];
            counts.set(leftChar, counts.get(leftChar) - 1);
            left++;
        }

        best = Math.max(best, right - left + 1);
    }

    return best;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        System.out.println(characterReplacement("AABABBA", 1));
    }

    static int characterReplacement(String s, int k) {
        int[] counts = new int[26];
        int left = 0;
        int maxFreq = 0;
        int best = 0;

        for (int right = 0; right < s.length(); right++) {
            int idx = s.charAt(right) - 'A';
            counts[idx]++;
            maxFreq = Math.max(maxFreq, counts[idx]);

            int windowLen = right - left + 1;
            if (windowLen - maxFreq > k) {
                counts[s.charAt(left) - 'A']--;
                left++;
            }

            best = Math.max(best, right - left + 1);
        }

        return best;
    }
}
```

**Complexity:** Time O(n), space O(1) (at most 26 letters in `counts`).

**Common mistakes:** Trying to decrement `max_freq` when the window shrinks is unnecessary and actually breaks the O(n) guarantee if done via a full rescan. Also, forgetting that `best` should be computed from the window length even mid-shrink, since the window size never needs to shrink below the best-so-far; it can only stay the same or grow.

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

```javascript +
function totalFruit(fruits) {
    const counts = new Map();
    let left = 0;
    let best = 0;

    for (let right = 0; right < fruits.length; right++) {
        const fruit = fruits[right];
        counts.set(fruit, (counts.get(fruit) || 0) + 1);

        while (counts.size > 2) {
            const leftFruit = fruits[left];
            counts.set(leftFruit, counts.get(leftFruit) - 1);
            if (counts.get(leftFruit) === 0) {
                counts.delete(leftFruit);
            }
            left++;
        }

        best = Math.max(best, right - left + 1);
    }

    return best;
}
```

```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[] fruits = {1, 2, 1, 2, 3, 3, 1};
        System.out.println(totalFruit(fruits));
    }

    static int totalFruit(int[] fruits) {
        Map<Integer, Integer> counts = new HashMap<>();
        int left = 0;
        int best = 0;

        for (int right = 0; right < fruits.length; right++) {
            int fruit = fruits[right];
            counts.merge(fruit, 1, Integer::sum);

            while (counts.size() > 2) {
                int leftFruit = fruits[left];
                counts.merge(leftFruit, -1, Integer::sum);
                if (counts.get(leftFruit) == 0) {
                    counts.remove(leftFruit);
                }
                left++;
            }

            best = Math.max(best, right - left + 1);
        }

        return best;
    }
}
```

**Complexity:** Time O(n), space O(1) (at most 3 keys in `counts` at any moment, since we shrink the instant it hits 3).

**Common mistakes:** Not recognizing the "2 baskets" framing as "at most 2 distinct values." Translating word problems into the underlying pattern is the actual skill being tested here. Also, forgetting to delete zero-count entries from the dict, which corrupts the `len(counts) > 2` check.

## Minimum Size Subarray Sum

[LeetCode 209](https://leetcode.com/problems/minimum-size-subarray-sum/) — Sliding window

**Intuition:** Find the *shortest* contiguous subarray with sum ≥ target. This flips the usual "maximize window" pattern to "minimize window while a condition holds," but the two-pointer mechanics are identical.

**Approach:** Expand `right`, adding to a running sum. While the sum meets or exceeds `target`, record the window length and shrink `left`, continuing to shrink while still valid since a smaller valid window is always better here.

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

```javascript +
function minSubArrayLen(target, nums) {
    let left = 0;
    let total = 0;
    let best = Infinity;

    for (let right = 0; right < nums.length; right++) {
        total += nums[right];

        while (total >= target) {
            best = Math.min(best, right - left + 1);
            total -= nums[left];
            left++;
        }
    }

    return best === Infinity ? 0 : best;
}
```

```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {2, 3, 1, 2, 4, 3};
        System.out.println(minSubArrayLen(7, nums));
    }

    static int minSubArrayLen(int target, int[] nums) {
        int left = 0;
        int total = 0;
        int best = Integer.MAX_VALUE;

        for (int right = 0; right < nums.length; right++) {
            total += nums[right];

            while (total >= target) {
                best = Math.min(best, right - left + 1);
                total -= nums[left];
                left++;
            }
        }

        return best == Integer.MAX_VALUE ? 0 : best;
    }
}
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** Using `if` instead of `while` when shrinking. A single conditional shrink misses shorter valid windows that remain valid after one shrink step. Also, forgetting the "no valid subarray exists" case, which requires returning 0, not `inf` or -1.

## Longest Subarray with Ones after Replacement

LeetCode 424 variant: the array analogue of Longest Repeating Character Replacement, sometimes phrased as "Max Consecutive Ones III" ([LeetCode 1004](https://leetcode.com/problems/max-consecutive-ones-iii/))

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

```javascript +
function longestOnes(nums, k) {
    let left = 0;
    let zeroCount = 0;
    let best = 0;

    for (let right = 0; right < nums.length; right++) {
        if (nums[right] === 0) {
            zeroCount++;
        }

        while (zeroCount > k) {
            if (nums[left] === 0) {
                zeroCount--;
            }
            left++;
        }

        best = Math.max(best, right - left + 1);
    }

    return best;
}
```

```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0};
        System.out.println(longestOnes(nums, 2));
    }

    static int longestOnes(int[] nums, int k) {
        int left = 0;
        int zeroCount = 0;
        int best = 0;

        for (int right = 0; right < nums.length; right++) {
            if (nums[right] == 0) {
                zeroCount++;
            }

            while (zeroCount > k) {
                if (nums[left] == 0) {
                    zeroCount--;
                }
                left++;
            }

            best = Math.max(best, right - left + 1);
        }

        return best;
    }
}
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** Rebuilding a full frequency count when a simple zero counter suffices. Only two values exist here, 0 and 1, so there's no need for a dict, unlike the character-replacement version with 26 possible letters. Also, off-by-one when computing window length after the shrink loop exits.

Step back and the six problems above split into just two templates: "at most K distinct" (Fruit Into Baskets) and "longest valid window after up to K changes" (Character Replacement, Max Consecutive Ones III). Minimum Size Subarray Sum is the mirror image of both, shrinking instead of growing. Once you can name which template a new problem matches, the two-pointer skeleton writes itself.
