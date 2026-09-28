---
kind: lesson
id_key: interview-prep-45/day-13
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Dynamic Programming: Two Dimensions"
position: 17
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
---

Think of comparing two shopping lists to find the items they share, or figuring out the fewest edits to turn one sentence into another. Both need you to track a position in *two* things at once, not just one. The Dynamic Programming Basics lesson used a single moving index, `dp[i]`. Here the state grows to two dimensions: two strings, two positions in the same array, or one sequence plus an extra flag like "have I used my one free skip yet." This is where a lot of candidates' DP falls apart. Get comfortable with two-dimensional state and you've covered the pattern behind most "hard" DP interview questions.

## 2D DP state

When a problem compares or combines **two sequences**, or tracks one sequence plus something extra (like "how many items used so far" or "have I done X yet"), the state usually needs two indices: `dp[i][j]`.

```python
# Generic 2D DP table shape
dp = [[0] * (n + 1) for _ in range(m + 1)]
```

The extra row and column, the `+1` in each dimension, conventionally stands for the **empty prefix**: `dp[0][j]` and `dp[i][0]` are base cases meaning "zero characters or items considered from this side." This convention saves you from special-casing empty inputs everywhere inside the main loop.

**How to recognize 2D DP:** if comparing or combining two sequences means you need to know where you are in *both* of them, you need two indices. If it's really one sequence but you're also tracking an extra constraint, like a budget, a mode, or a used/unused flag, that constraint becomes the second dimension.

> **Remember:** two strings, two positions. One string plus an extra fact you must remember, one position plus one flag. Either way, that's your second dimension.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-intermediate-2d-state-q1", "type": "mcq",
      "prompt": "What usually signals that a DP problem needs a 2D table, dp[i][j], instead of a 1D one?",
      "options": [
        {"id": "a", "text": "The problem compares or combines two sequences, or tracks one sequence plus an extra condition like a used/unused flag"},
        {"id": "b", "text": "The input array has more than 100 elements"},
        {"id": "c", "text": "The problem asks for a yes/no answer instead of a number"},
        {"id": "d", "text": "The code uses recursion instead of a loop"}
      ],
      "correct": "a",
      "explanation": "A second index appears whenever the answer depends on positions in two separate sequences, or on one position plus one more piece of tracked information." }
] }
```

## String DP

String DP problems compare or transform two strings character by character. The state is `dp[i][j]` = "the answer considering the first `i` characters of string A and the first `j` characters of string B." The transition almost always branches on whether `A[i-1] == B[j-1]`.

```python
# Skeleton shared by LCS, Edit Distance, and most string-pair DP:
for i in range(1, m + 1):
    for j in range(1, n + 1):
        if A[i - 1] == B[j - 1]:
            dp[i][j] = ...  # characters match — extend some prior state
        else:
            dp[i][j] = ...  # characters differ — combine other subproblems
```

Space is often shrinkable from O(m×n) down to O(min(m,n)), because row `i` usually only depends on row `i-1`.

> **Remember:** string DP is a grid where row `i` and column `j` mean "first `i` characters of A, first `j` characters of B." The character comparison at that cell decides the transition.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-intermediate-string-dp-q1", "type": "mcq",
      "prompt": "In a two-string DP like Edit Distance or LCS, what does dp[i][j] usually represent?",
      "options": [
        {"id": "a", "text": "The answer for the first i characters of one string compared against the first j characters of the other"},
        {"id": "b", "text": "The total length of both strings combined"},
        {"id": "c", "text": "The number of times character i appears in string j"},
        {"id": "d", "text": "A boolean for whether the two full strings are identical"}
      ],
      "correct": "a",
      "explanation": "The two indices track a prefix length in each string independently, which is exactly why the table has two dimensions." }
] }
```

## State machines

Some DP problems, like stock trading or string parsing with modes, model the process as a **finite state machine**: `dp[i][state]` tracks the best value at step `i` while in a given state, and transitions move between states.

```python
# Example shape: dp[i][0] = best value at step i in "state 0"
#                dp[i][1] = best value at step i in "state 1"
# Buy/sell stock is the canonical example:
def maxProfit_stateMachine(prices: list[int]) -> int:
    hold, not_hold = float('-inf'), 0  # state 0: holding a share, state 1: not
    for price in prices:
        hold, not_hold = max(hold, not_hold - price), max(not_hold, hold + price)
    return not_hold
```
```javascript +
function maxProfitStateMachine(prices) {
    let hold = -Infinity, notHold = 0;  // state 0: holding a share, state 1: not
    for (const price of prices) {
        [hold, notHold] = [Math.max(hold, notHold - price), Math.max(notHold, hold + price)];
    }
    return notHold;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] prices = {7, 1, 5, 3, 6, 4};
        System.out.println(maxProfitStateMachine(prices));
    }

    static int maxProfitStateMachine(int[] prices) {
        int hold = Integer.MIN_VALUE, notHold = 0;  // state 0: holding a share, state 1: not
        for (int price : prices) {
            int newHold = Math.max(hold, notHold - price);
            int newNotHold = Math.max(notHold, hold + price);
            hold = newHold;
            notHold = newNotHold;
        }
        return notHold;
    }
}
```

The key skill is drawing the state diagram first, on paper: what states exist, what moves between them are legal, what each move costs or earns, before writing any code. It's the same discipline as pinning down `dp[i]` correctly, just with an extra "which mode am I in" dimension.

> **Remember:** draw the states and the arrows between them on paper before coding. Code the diagram, don't invent it in the loop.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-intermediate-state-machine-q1", "type": "mcq",
      "prompt": "In the buy/sell stock state-machine DP, what do the two tracked states represent?",
      "options": [
        {"id": "a", "text": "Currently holding a share, and currently not holding a share"},
        {"id": "b", "text": "The stock price is rising, and the stock price is falling"},
        {"id": "c", "text": "The first half of the prices array, and the second half"},
        {"id": "d", "text": "Buying is allowed, and buying is forbidden"}
      ],
      "correct": "a",
      "explanation": "hold tracks the best profit if you currently own a share; notHold tracks the best profit if you don't. Each day's prices update both possibilities." }
] }
```

### Longest Common Subsequence

[LeetCode 1143](https://leetcode.com/problems/longest-common-subsequence/), DP, 2D

**Intuition:** A subsequence keeps the relative order of characters but can skip some. `dp[i][j]` = length of the longest common subsequence (LCS) of `text1[:i]` and `text2[:j]`. If the current characters match, they extend the LCS found without them; if not, take the better of skipping a character from either string.

**Approach:** `dp[i][j] = dp[i-1][j-1] + 1` if `text1[i-1] == text2[j-1]`, else `max(dp[i-1][j], dp[i][j-1])`.

```python
def longestCommonSubsequence(text1: str, text2: str) -> int:
    m, n = len(text1), len(text2)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if text1[i - 1] == text2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1] + 1
            else:
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])

    return dp[m][n]
```
```javascript +
function longestCommonSubsequence(text1, text2) {
    const m = text1.length, n = text2.length;
    const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));

    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            if (text1[i - 1] === text2[j - 1]) {
                dp[i][j] = dp[i - 1][j - 1] + 1;
            } else {
                dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
            }
        }
    }

    return dp[m][n];
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(longestCommonSubsequence("abcde", "ace"));
    }

    static int longestCommonSubsequence(String text1, String text2) {
        int m = text1.length(), n = text2.length();
        int[][] dp = new int[m + 1][n + 1];

        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                if (text1.charAt(i - 1) == text2.charAt(j - 1)) {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                } else {
                    dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
                }
            }
        }

        return dp[m][n];
    }
}
```

**Worked example:** `"abcde"` and `"ace"` share the subsequence `"ace"` (skip `b` and `d`), so the answer is 3.

**Complexity:** Time O(m·n), space O(m·n), shrinkable to O(min(m,n)) since row `i` only needs row `i-1`.

**Common mistakes:** confusing "subsequence" with "substring." LCS allows gaps, so `dp[i][j]` isn't restricted to characters at `i-1, j-1` being part of one contiguous run. Also, off-by-one indexing between the 1-indexed `dp` table and 0-indexed strings: it's `text1[i-1]`, not `text1[i]`.

> **Remember:** LCS skips freely; substring problems don't. Mixing those two up is the most common LCS bug.

### Edit Distance

[LeetCode 72](https://leetcode.com/problems/edit-distance/), DP, 2D, Hard

**Intuition:** You want the fewest operations (insert, delete, replace) to turn `word1` into `word2`. `dp[i][j]` = edit distance between `word1[:i]` and `word2[:j]`. If characters match, no operation is needed at this position; if not, take the best of the three possible operations plus 1.

**Approach:** `dp[i][j] = dp[i-1][j-1]` if characters match, else `1 + min(dp[i-1][j-1], dp[i-1][j], dp[i][j-1])` (replace, delete, insert respectively).

```python
def minDistance(word1: str, word2: str) -> int:
    m, n = len(word1), len(word2)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    for i in range(m + 1):
        dp[i][0] = i  # delete all i characters of word1
    for j in range(n + 1):
        dp[0][j] = j  # insert all j characters of word2

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if word1[i - 1] == word2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(
                    dp[i - 1][j - 1],  # replace
                    dp[i - 1][j],      # delete from word1
                    dp[i][j - 1],      # insert into word1
                )

    return dp[m][n]
```
```javascript +
function minDistance(word1, word2) {
    const m = word1.length, n = word2.length;
    const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(0));

    for (let i = 0; i <= m; i++) dp[i][0] = i;  // delete all i characters of word1
    for (let j = 0; j <= n; j++) dp[0][j] = j;  // insert all j characters of word2

    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            if (word1[i - 1] === word2[j - 1]) {
                dp[i][j] = dp[i - 1][j - 1];
            } else {
                dp[i][j] = 1 + Math.min(
                    dp[i - 1][j - 1],  // replace
                    dp[i - 1][j],      // delete from word1
                    dp[i][j - 1]       // insert into word1
                );
            }
        }
    }

    return dp[m][n];
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(minDistance("horse", "ros"));
    }

    static int minDistance(String word1, String word2) {
        int m = word1.length(), n = word2.length();
        int[][] dp = new int[m + 1][n + 1];

        for (int i = 0; i <= m; i++) dp[i][0] = i;  // delete all i characters of word1
        for (int j = 0; j <= n; j++) dp[0][j] = j;  // insert all j characters of word2

        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                if (word1.charAt(i - 1) == word2.charAt(j - 1)) {
                    dp[i][j] = dp[i - 1][j - 1];
                } else {
                    dp[i][j] = 1 + Math.min(
                        dp[i - 1][j - 1],  // replace
                        Math.min(dp[i - 1][j], dp[i][j - 1])  // delete, insert
                    );
                }
            }
        }

        return dp[m][n];
    }
}
```

**Complexity:** Time O(m·n), space O(m·n), shrinkable to O(min(m,n)).

**Common mistakes:** forgetting the base-case row and column, `dp[i][0] = i` and `dp[0][j] = j`. Without these, comparing against an empty string gives wrong results. Also, mixing up which operation goes with which neighbor cell: delete is `dp[i-1][j]`, insert is `dp[i][j-1]`, replace is `dp[i-1][j-1]`. Draw a small table by hand once to lock this in.

> **Remember:** three neighbors, three operations. `dp[i-1][j]` deletes, `dp[i][j-1]` inserts, `dp[i-1][j-1]` replaces.

### Longest Increasing Subsequence

[LeetCode 300](https://leetcode.com/problems/longest-increasing-subsequence/), DP, Binary search optimization

**Intuition:** `dp[i]` = length of the longest increasing subsequence ending exactly at index `i`. The O(n²) version checks every earlier smaller element. The O(n log n) version instead keeps an array `tails`, where `tails[k]` is the smallest possible tail value of an increasing subsequence of length `k+1`, updated with binary search.

**Approach (O(n²), derive this one first):** `dp[i] = 1 + max(dp[j] for j < i if nums[j] < nums[i])`, defaulting to 1.

```python
def lengthOfLIS_On2(nums: list[int]) -> int:
    n = len(nums)
    dp = [1] * n
    for i in range(n):
        for j in range(i):
            if nums[j] < nums[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)
```
```javascript +
function lengthOfLISOn2(nums) {
    const n = nums.length;
    const dp = new Array(n).fill(1);
    for (let i = 0; i < n; i++) {
        for (let j = 0; j < i; j++) {
            if (nums[j] < nums[i]) {
                dp[i] = Math.max(dp[i], dp[j] + 1);
            }
        }
    }
    return Math.max(...dp);
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {10, 9, 2, 5, 3, 7, 101, 18};
        System.out.println(lengthOfLISOn2(nums));
    }

    static int lengthOfLISOn2(int[] nums) {
        int n = nums.length;
        int[] dp = new int[n];
        java.util.Arrays.fill(dp, 1);
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < i; j++) {
                if (nums[j] < nums[i]) {
                    dp[i] = Math.max(dp[i], dp[j] + 1);
                }
            }
        }
        int best = 0;
        for (int v : dp) best = Math.max(best, v);
        return best;
    }
}
```

**Approach (O(n log n), the interview follow-up):**

```python
import bisect

def lengthOfLIS(nums: list[int]) -> int:
    tails = []
    for num in nums:
        pos = bisect.bisect_left(tails, num)
        if pos == len(tails):
            tails.append(num)
        else:
            tails[pos] = num
    return len(tails)
```
```javascript +
function lengthOfLIS(nums) {
    const tails = [];
    for (const num of nums) {
        let lo = 0, hi = tails.length;
        while (lo < hi) {  // binary search: first index where tails[idx] >= num
            const mid = (lo + hi) >> 1;
            if (tails[mid] < num) lo = mid + 1;
            else hi = mid;
        }
        if (lo === tails.length) tails.push(num);
        else tails[lo] = num;
    }
    return tails.length;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[] nums = {10, 9, 2, 5, 3, 7, 101, 18};
        System.out.println(lengthOfLIS(nums));
    }

    static int lengthOfLIS(int[] nums) {
        int[] tails = new int[nums.length];
        int size = 0;
        for (int num : nums) {
            int pos = Arrays.binarySearch(tails, 0, size, num);
            if (pos < 0) pos = -(pos + 1);  // insertion point, mirrors bisect_left
            tails[pos] = num;
            if (pos == size) size++;
        }
        return size;
    }
}
```

**Complexity:** O(n²) DP: time O(n²), space O(n). Binary-search version: time O(n log n), space O(n).

**Common mistakes:** thinking `tails` is an actual LIS at the end. It isn't: it only tracks the smallest possible tail for each length, so its length equals the LIS length, but its contents aren't a real subsequence. Also, using `bisect_right` instead of `bisect_left`, which would wrongly allow non-strict increases for the "strictly increasing" version of this problem.

> **Remember:** `tails` is a scoreboard of best-possible endings, not a real subsequence. Only its length matters for the answer.

### Word Break

[LeetCode 139](https://leetcode.com/problems/word-break/), DP, String

**Intuition:** `dp[i]` = can `s[:i]` be split into dictionary words? `dp[i]` is true if some earlier split point `j` has `dp[j]` true and `s[j:i]` is itself a dictionary word.

**Approach:** `dp[0] = True` (an empty prefix is trivially splittable). For each `i`, check every `j < i`: if `dp[j]` and `s[j:i]` is in the word set, set `dp[i] = True`.

```python
def wordBreak(s: str, wordDict: list[str]) -> bool:
    word_set = set(wordDict)
    n = len(s)
    dp = [False] * (n + 1)
    dp[0] = True

    for i in range(1, n + 1):
        for j in range(i):
            if dp[j] and s[j:i] in word_set:
                dp[i] = True
                break  # no need to check other j once found
    return dp[n]
```
```javascript +
function wordBreak(s, wordDict) {
    const wordSet = new Set(wordDict);
    const n = s.length;
    const dp = new Array(n + 1).fill(false);
    dp[0] = true;

    for (let i = 1; i <= n; i++) {
        for (let j = 0; j < i; j++) {
            if (dp[j] && wordSet.has(s.slice(j, i))) {
                dp[i] = true;
                break;  // no need to check other j once found
            }
        }
    }
    return dp[n];
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        List<String> wordDict = Arrays.asList("leet", "code");
        System.out.println(wordBreak("leetcode", wordDict));
    }

    static boolean wordBreak(String s, List<String> wordDict) {
        Set<String> wordSet = new HashSet<>(wordDict);
        int n = s.length();
        boolean[] dp = new boolean[n + 1];
        dp[0] = true;

        for (int i = 1; i <= n; i++) {
            for (int j = 0; j < i; j++) {
                if (dp[j] && wordSet.contains(s.substring(j, i))) {
                    dp[i] = true;
                    break;  // no need to check other j once found
                }
            }
        }
        return dp[n];
    }
}
```

**Complexity:** Time O(n²) for the double loop, plus O(k) per substring slice and lookup where k is the average word length, so effectively O(n²·k) worst case; a `set` keeps membership checks O(1) on average. Space O(n) for `dp`, plus O(total dictionary characters) for `word_set`.

**Common mistakes:** treating this as needing to list every possible split, which is a different, more expensive problem (Word Break II); this variant only needs a yes/no answer. Also, forgetting the `dp[0] = True` base case, which anchors every later true value. Not breaking early once `dp[i]` is set is harmless for correctness but wastes time on large inputs.

> **Remember:** `dp[i]` asks one question: is there ANY earlier valid split point `j` where the rest of the string is a dictionary word? One yes is enough.

## Recovering the answer, not just its value

LCS and Edit Distance above both compute a number: a length or a cost. Getting the actual subsequence, or the actual sequence of edits, takes one more step: walk backward from `dp[m][n]`, and at each cell figure out which transition produced it. In LCS, if `text1[i-1] == text2[j-1]`, that character belongs to the answer and you step diagonally to `dp[i-1][j-1]`. Otherwise you step toward whichever neighbor, `dp[i-1][j]` or `dp[i][j-1]`, matches the current cell's value. The same backward walk applied to the Edit Distance table recovers the actual sequence of inserts, deletes, and replacements. Interviewers often ask for this as a follow-up once the length-or-cost version works, so trace it through by hand once rather than meeting it cold in an interview.

> **Remember:** the table gives you a number. Walking it backward, cell by cell, gives you the actual sequence of choices behind that number.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-intermediate-recover-answer-q1", "type": "mcq",
      "prompt": "After computing dp[m][n] for LCS, how do you recover the actual common subsequence, not just its length?",
      "options": [
        {"id": "a", "text": "Walk backward from dp[m][n], stepping diagonally when characters match and toward whichever neighbor matches the current value otherwise"},
        {"id": "b", "text": "Re-run the algorithm forward with a different starting cell"},
        {"id": "c", "text": "The table already stores the subsequence directly in dp[0][0]"},
        {"id": "d", "text": "It's impossible to recover the subsequence, only its length is computable"}
      ],
      "correct": "a",
      "explanation": "Backtracking through the table by re-deriving which transition produced each cell's value reconstructs the actual sequence of matches and skips." }
] }
```
