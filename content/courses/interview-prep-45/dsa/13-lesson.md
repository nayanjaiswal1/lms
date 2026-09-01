---
kind: lesson
id_key: interview-prep-45/day-13
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Dynamic Programming - Intermediate"
position: 13
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
---

Yesterday's DP problems had a single moving index. Today the state grows to two dimensions: two strings, two pointers into the same array, or a value plus a decision flag. This is where most candidates' DP breaks down. Master 2D state and you've covered the pattern behind a huge share of "hard" DP interview questions.

## 2D DP state

When a problem involves **two sequences**, or one sequence plus an extra dimension (like "how many items used" or "have I done X yet"), the state usually needs two indices: `dp[i][j]`.

```python
# Generic 2D DP table shape
dp = [[0] * (n + 1) for _ in range(m + 1)]
```

The extra row and column (the `+1` in each dimension) conventionally represents the **empty prefix**: `dp[0][j]` and `dp[i][0]` are base cases meaning "zero characters or items considered from one side." This convention avoids constant off-by-one special-casing inside the main loop.

**Recognizing 2D DP:** if the recurrence for comparing or combining two sequences needs to know where you are in both, you need two indices. If it's one sequence but you're tracking an additional constraint, such as budget remaining, a state-machine phase, or a boolean flag, that constraint becomes the second dimension.

## String DP

String DP problems compare or transform two strings character by character, with the state `dp[i][j]` = "answer considering the first `i` characters of string A and first `j` characters of string B." The transition almost always branches on whether `A[i-1] == B[j-1]`.

```python
# Skeleton shared by LCS, Edit Distance, and most string-pair DP:
for i in range(1, m + 1):
    for j in range(1, n + 1):
        if A[i - 1] == B[j - 1]:
            dp[i][j] = ...  # characters match — extend some prior state
        else:
            dp[i][j] = ...  # characters differ — combine other subproblems
```

Space is often optimizable from O(m×n) to O(min(m,n)) because row `i` typically only depends on row `i-1`.

## State machines

Some DP problems (stock trading, string parsing with modes) model the underlying process as a **finite state machine**, where `dp[i][state]` tracks the best value at step `i` while in a given state, and transitions move between states.

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

The key skill is drawing the state diagram first, what states exist, what transitions are legal, what each transition costs or earns, before writing any code. It's the same discipline as defining `dp[i]` correctly, just with an extra "which mode am I in" dimension.

## Longest Common Subsequence

[LeetCode 1143](https://leetcode.com/problems/longest-common-subsequence/), DP, 2D

**Intuition:** A subsequence keeps relative order but can skip characters. `dp[i][j]` = length of the LCS of `text1[:i]` and `text2[:j]`. If the current characters match, they extend the LCS found without them; if not, take the best of skipping a character from either string.

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

**Complexity:** Time O(m·n), space O(m·n), reducible to O(min(m,n)) since row `i` only needs row `i-1`.

**Common mistakes:** Confusing "subsequence" with "substring." LCS allows gaps, so `dp[i][j]` isn't restricted to characters at `i-1, j-1` being part of a contiguous run. Off-by-one indexing between the 1-indexed `dp` table and 0-indexed strings; it's `text1[i-1]`, not `text1[i]`.

## Edit Distance

[LeetCode 72](https://leetcode.com/problems/edit-distance/), DP, 2D, Hard

**Intuition:** Minimum operations (insert, delete, replace) to turn `word1` into `word2`. `dp[i][j]` = edit distance between `word1[:i]` and `word2[:j]`. If characters match, no operation needed at this position; otherwise take the best of the three possible operations plus 1.

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

**Complexity:** Time O(m·n), space O(m·n), reducible to O(min(m,n)).

**Common mistakes:** Forgetting the base-case row and column initialization, `dp[i][0] = i` and `dp[0][j] = j`. Without these, comparing against an empty string produces wrong results. Mixing up which operation corresponds to which neighbor cell: delete is `dp[i-1][j]`, insert is `dp[i][j-1]`, replace is `dp[i-1][j-1]`. Draw the table by hand once to internalize this.

## Longest Increasing Subsequence

[LeetCode 300](https://leetcode.com/problems/longest-increasing-subsequence/), DP, Binary search optimization

**Intuition:** `dp[i]` = length of the longest increasing subsequence ending exactly at index `i`. The O(n²) version checks every earlier smaller element; the O(n log n) version instead maintains an array `tails` where `tails[k]` = the smallest possible tail value of an increasing subsequence of length `k+1`, updated via binary search.

**Approach (O(n²), the one to derive first):** `dp[i] = 1 + max(dp[j] for j < i if nums[j] < nums[i])`, defaulting to 1.

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

**Complexity:** O(n²) DP: time O(n²), space O(n). Binary search version: time O(n log n), space O(n).

**Common mistakes:** Believing `tails` is an actual LIS at the end. It isn't: it only tracks the smallest possible tail for each length, so its length equals the LIS length but its contents don't represent a real subsequence. Using `bisect_right` instead of `bisect_left`, which would incorrectly allow non-strict increases for the "strictly increasing" variant of this problem.

## Word Break

[LeetCode 139](https://leetcode.com/problems/word-break/), DP, String

**Intuition:** `dp[i]` = can `s[:i]` be segmented into dictionary words? `dp[i]` is true if there's some earlier split point `j` where `dp[j]` is true and `s[j:i]` is itself a dictionary word.

**Approach:** `dp[0] = True` (empty prefix trivially breakable). For each `i`, check all `j < i`: if `dp[j]` and `s[j:i] in wordDict`, set `dp[i] = True`.

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

**Complexity:** Time O(n²) for the double loop, plus O(k) per substring slice and lookup where k is average word length, so effectively O(n²·k) worst case; using a `set` keeps membership checks O(1) average. Space O(n) for `dp`, plus O(total dict chars) for `word_set`.

**Common mistakes:** Treating this as needing to enumerate all segmentations, which is Word Break II, a different and more expensive problem, when this variant only asks yes or no. Forgetting the `dp[0] = True` base case, which anchors every subsequent True value. Not breaking early once `dp[i]` is set; harmless for correctness, but it wastes time on large inputs.

## Recovering the answer, not just its value

LCS and Edit Distance above both compute a number: a length or a cost. Getting the actual subsequence, or the actual sequence of edits, takes one more step: walk backward from `dp[m][n]`, re-deriving at each cell which transition produced it. In LCS, if `text1[i-1] == text2[j-1]`, that character belongs to the LCS and you step diagonally to `dp[i-1][j-1]`; otherwise you step toward whichever neighbor, `dp[i-1][j]` or `dp[i][j-1]`, matches the current cell's value. The same backward walk applied to the Edit Distance table recovers the actual sequence of inserts, deletes, and replacements. Interviewers often ask for this as a follow-up once the length-or-cost version works, so it's worth tracing through by hand once rather than meeting it cold in an interview.
