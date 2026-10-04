---
kind: lesson
id_key: interview-prep-45/day-23
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Sliding Window: Harder Problems"
position: 4
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
The Sliding Window lesson covered a window tracked by one running number, a sum, a minimum, a single count. Picture that same train of connected cars, but now the conductor also has to track something more detailed about the 3 cars in view: how many different colors are among them, or whether at most 2 of them are red. This lesson covers exactly that: windows that need a whole frequency count instead of one number, and windows that must satisfy more than one rule at once. This is the pattern behind most "longest/shortest substring or subarray with property X" interview questions once they get past the beginner stage.

## Fixed window with data structures

Picture a security guard watching the last 4 people to badge through a door, keeping a running tally of how many different departments are among those 4. When a 5th person badges in, the guard does not recount all 4 people from scratch: they add the new person's department to the tally and remove the department of whoever just aged out the back of the window. A fixed-size window slides the same way, one element at a time. Instead of just a running sum, you often keep a frequency map or count that updates incrementally as elements enter and leave.

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

Every fixed-window problem does exactly two things per step: add the incoming element's effect, remove the outgoing element's effect. That "effect" can be a sum, a frequency count, a max-tracking deque, or anything else you can maintain incrementally. Never recompute the whole window from scratch each step, since that turns an O(n) sliding window into O(n·k).

> **Remember:** a fixed window does two things per step, add the new element's effect, remove the old element's effect. Never rescan the whole window.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-harder-fixed-window-q1", "type": "mcq",
      "prompt": "What mistake turns an O(n) fixed-size sliding window into O(n·k)?",
      "options": [
        {"id": "a", "text": "Recomputing the window's state from scratch on every step instead of updating incrementally"},
        {"id": "b", "text": "Using a Counter instead of a plain dictionary"},
        {"id": "c", "text": "Starting the window at index 0 instead of index k"},
        {"id": "d", "text": "Using k as the window size instead of n"}
      ],
      "correct": "a",
      "explanation": "The whole point of a fixed window is that each step does O(1) work: add the entering element, remove the leaving one. Rescanning all k elements every step multiplies the total cost by k." }
] }
```

## Variable window tracking multiple conditions

Picture that same guard, but now with two rules at once: "let at most 2 departments through together, and never let the group at the door grow past 15 people." The guard still does the same two things as before, let people in from the front, remove people from the back only when a rule breaks, just checking two rules instead of one. A variable-size window grows by advancing `right` and shrinks by advancing `left`, expanding while a condition holds and contracting when it is violated. The harder version tracks several conditions at once, for example "at most 2 distinct characters and window length under some bound."

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

The invariant to hold onto: `left` only ever moves forward. It never resets to 0 and rescans. That is what makes the whole algorithm O(n) instead of O(n²): each index enters and leaves the window at most once across the entire run.

> **Remember:** `is_valid` can check any number of conditions at once, the expand/contract skeleton around it never changes.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-harder-multi-condition-q1", "type": "mcq",
      "prompt": "What changes between a simple sliding-window problem and one with multiple conditions to satisfy?",
      "options": [
        {"id": "a", "text": "Only the validity check gets more complex; the expand/contract skeleton stays the same"},
        {"id": "b", "text": "The left pointer must move backward sometimes"},
        {"id": "c", "text": "You need two separate windows instead of one"},
        {"id": "d", "text": "The time complexity becomes O(n²)"}
      ],
      "correct": "a",
      "explanation": "The expand-contract-record skeleton is unchanged. Only `is_valid` grows to check more than one condition against the window's tracked state. The algorithm is still O(n)." }
] }
```

## Longest Repeating Character Replacement

[LeetCode 424](https://leetcode.com/problems/longest-repeating-character-replacement/)

**Intuition:** You can change up to `k` characters in a window to make every character the same. A window is valid if `window_length - count_of_most_frequent_char <= k`, which is exactly the number of characters you would need to replace.

**Approach:** Expand `right`, tracking a frequency count and the running max frequency seen. `max_freq` never needs to decrease even as the window shrinks. It only ever underestimates slightly, but that is safe, since the answer only grows when a new max_freq is achieved, so a stale max_freq cannot produce a wrong, too-large answer. Shrink `left` only when the window becomes invalid.

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

**Common mistakes:** Trying to decrement `max_freq` when the window shrinks is unnecessary, and actually breaks the O(n) guarantee if done with a full rescan. Also, forgetting that `best` can be computed from the window length even mid-shrink, since the window never needs to shrink below the best length found so far; it can only stay the same or grow.

> **Remember:** `max_freq` never needs to shrink, even when the window does. The answer can only grow.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-harder-char-replacement-q1", "type": "mcq",
      "prompt": "In Longest Repeating Character Replacement, what condition makes the current window invalid?",
      "options": [
        {"id": "a", "text": "window_length minus the count of the most frequent character exceeds k"},
        {"id": "b", "text": "The window contains more than 26 distinct characters"},
        {"id": "c", "text": "The window length exceeds k"},
        {"id": "d", "text": "The most frequent character's count exceeds k"}
      ],
      "correct": "a",
      "explanation": "window_length - max_freq is exactly the number of characters you'd need to change to make the whole window one repeated character. If that exceeds k, you can't afford it and must shrink." }
] }
```

## Fruit Into Baskets

[LeetCode 904](https://leetcode.com/problems/fruit-into-baskets/)

**Intuition:** This is "longest subarray with at most 2 distinct values" wearing a word problem's clothes. Two baskets means at most 2 distinct fruit types in the window.

**Approach:** Expand `right`, tracking fruit-type counts in a map. While the map has more than 2 keys, shrink `left`.

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

**Complexity:** Time O(n), space O(1) (at most 3 keys in `counts` at any moment, since you shrink the instant it hits 3).

**Common mistakes:** Not recognizing the "2 baskets" framing as "at most 2 distinct values." Translating a word problem into the underlying pattern is the real skill being tested. Also, forgetting to delete zero-count entries from the map, which corrupts the `len(counts) > 2` check.

> **Remember:** "2 baskets" is just "at most 2 distinct values" in a costume. Learn to spot the pattern under the wording.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-harder-fruit-baskets-q1", "type": "mcq",
      "prompt": "What underlying pattern does \"Fruit Into Baskets\" (2 baskets) map to?",
      "options": [
        {"id": "a", "text": "Longest subarray with at most 2 distinct values"},
        {"id": "b", "text": "Longest subarray with exactly 2 equal values"},
        {"id": "c", "text": "Shortest subarray containing 2 distinct values"},
        {"id": "d", "text": "Fixed-size window of length 2"}
      ],
      "correct": "a",
      "explanation": "Two baskets can each hold one fruit type, so the problem is really: find the longest contiguous run with at most 2 distinct values, the same variable-window-with-a-distinct-count-cap pattern used elsewhere." }
] }
```

## Minimum Size Subarray Sum

[LeetCode 209](https://leetcode.com/problems/minimum-size-subarray-sum/)

**Intuition:** Find the shortest contiguous subarray with sum at least `target`. This flips the usual "maximize the window" pattern into "minimize the window while a condition holds," but the two-pointer mechanics are identical.

**Approach:** Expand `right`, adding to a running sum. While the sum meets or exceeds `target`, record the window length and shrink `left`, continuing to shrink while it is still valid, since a smaller valid window is always better here.

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

**Common mistakes:** Using `if` instead of `while` when shrinking. A single conditional shrink misses shorter valid windows that stay valid after one shrink step. Also, forgetting the "no valid subarray exists" case, which needs to return 0, not `inf` or -1.

> **Remember:** when minimizing, shrink with a `while`, not an `if`, and record the answer on every shrink, not just once.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-harder-min-subarray-sum-q1", "type": "mcq",
      "prompt": "Why must the shrink step in Minimum Size Subarray Sum use `while total >= target` instead of `if`?",
      "options": [
        {"id": "a", "text": "A single `if` could miss shorter valid windows that remain valid after more than one shrink"},
        {"id": "b", "text": "`if` would cause an infinite loop"},
        {"id": "c", "text": "`while` is required for Python syntax reasons"},
        {"id": "d", "text": "`if` only works for negative numbers"}
      ],
      "correct": "a",
      "explanation": "After adding one element, the running sum might exceed target by a lot, meaning several elements could be removed from the left while staying valid. `if` only removes one; `while` finds the true minimum window at this right boundary." }
] }
```

## Longest Subarray with Ones after Replacement

Also known as Max Consecutive Ones III ([LeetCode 1004](https://leetcode.com/problems/max-consecutive-ones-iii/)), the array version of Longest Repeating Character Replacement.

**Intuition:** You can flip up to `k` zeros to ones. Find the longest subarray you can make this way. This is structurally identical to Longest Repeating Character Replacement: a window is valid if `zero_count_in_window <= k`.

**Approach:** Expand `right`, tracking the count of zeros in the window. Shrink `left` while the zero count exceeds `k`.

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

**Common mistakes:** Building a full frequency map when a simple zero counter is enough. Only two values exist here, 0 and 1, so there is no need for a map, unlike the character-replacement version with 26 possible letters. Also, off-by-one when computing window length after the shrink loop exits.

Step back, and the four problems above split into just two templates: "at most K distinct" (Fruit Into Baskets) and "longest valid window after up to K changes" (Character Replacement, Max Consecutive Ones III). Minimum Size Subarray Sum is the mirror image of both, shrinking instead of growing. Once you can name which template a new problem matches, the two-pointer skeleton writes itself.

> **Remember:** four problems, two templates. Name the template first, then the code is mechanical.

```knowledge-check
{ "questions": [
    { "id": "dsa-sliding-window-harder-ones-replacement-q1", "type": "mcq",
      "prompt": "Why doesn't Longest Subarray with Ones after Replacement need a full frequency map like Character Replacement does?",
      "options": [
        {"id": "a", "text": "There are only two possible values (0 and 1), so a single zero counter is enough"},
        {"id": "b", "text": "The array is always sorted"},
        {"id": "c", "text": "It uses a fixed-size window instead of a variable one"},
        {"id": "d", "text": "Frequency maps don't work on integer arrays"}
      ],
      "correct": "a",
      "explanation": "Character Replacement needs to track up to 26 letter counts, so a map earns its keep. Here there are only two possible values, so one integer counter for zeros captures everything the window needs to know." }
] }
```
