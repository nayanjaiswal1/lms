---
kind: lesson
id_key: interview-prep-45/day-13
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 13 — Dynamic Programming - Intermediate"
position: 13
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---

Yesterday's DP problems had a single moving index. Today the state grows to two dimensions — two strings, two pointers into the same array, or a value plus a decision flag — which is where most candidates' DP breaks down. Master 2D state and you've covered the pattern behind a huge share of "hard" DP interview questions.

## 2D DP state

When a problem involves **two sequences**, or one sequence plus an extra dimension (like "how many items used" or "have I done X yet"), the state usually needs two indices: `dp[i][j]`.

```python
# Generic 2D DP table shape
dp = [[0] * (n + 1) for _ in range(m + 1)]
```

The extra row/column (`+1` in each dimension) conventionally represents the **empty prefix** — `dp[0][j]` and `dp[i][0]` are base cases meaning "zero characters/items considered from one side." This convention avoids constant off-by-one special-casing inside the main loop.

**Recognizing 2D DP:** if the recurrence for comparing/combining two sequences needs to know *where you are in both*, you need two indices. If it's one sequence but you're tracking an additional constraint (budget remaining, state machine phase, boolean flag), that constraint becomes the second dimension.

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

The key skill is drawing the state diagram first (what states exist, what transitions are legal, what each transition costs/earns) before writing any code — this is the same discipline as defining `dp[i]` correctly, just with an extra "which mode am I in" dimension.

## Longest Common Subsequence

[LeetCode 1143](https://leetcode.com/problems/longest-common-subsequence/) — DP — 2D

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

**Complexity:** Time O(m·n), space O(m·n) — reducible to O(min(m,n)) since row `i` only needs row `i-1`.

**Common mistakes:** Confusing "subsequence" with "substring" — LCS allows gaps, so `dp[i][j]` is not restricted to characters ending exactly at `i-1, j-1` being part of a contiguous run; off-by-one indexing between the 1-indexed `dp` table and 0-indexed strings (`text1[i-1]`, not `text1[i]`).

## Edit Distance

[LeetCode 72](https://leetcode.com/problems/edit-distance/) — DP — 2D — Hard

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

**Complexity:** Time O(m·n), space O(m·n) — reducible to O(min(m,n)).

**Common mistakes:** Forgetting the base-case row/column initialization (`dp[i][0] = i`, `dp[0][j] = j`) — without these, comparing against an empty string produces wrong results; mixing up which operation corresponds to which neighbor cell (delete = `dp[i-1][j]`, insert = `dp[i][j-1]`, replace = `dp[i-1][j-1]` — draw the table by hand once to internalize this).

## Longest Increasing Subsequence

[LeetCode 300](https://leetcode.com/problems/longest-increasing-subsequence/) — DP — Binary search optimization

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

**Common mistakes:** Believing `tails` is an actual LIS at the end — it isn't; it only tracks the *smallest possible tail for each length*, so its length equals the LIS length but its contents don't represent a real subsequence; using `bisect_right` instead of `bisect_left`, which would incorrectly allow non-strict increases for the "strictly increasing" variant of this problem.

## Word Break

[LeetCode 139](https://leetcode.com/problems/word-break/) — DP — String

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

**Complexity:** Time O(n² ) for the double loop plus O(k) per substring slice/lookup (k = average word length), so effectively O(n²·k) worst case; using a `set` keeps membership checks O(1) average. Space O(n) for `dp` plus O(total dict chars) for `word_set`.

**Common mistakes:** Treating this as needing to *enumerate* all segmentations (that's Word Break II, a different, more expensive problem) when this variant only asks yes/no; forgetting the `dp[0] = True` base case, which anchors every subsequent True value; not breaking early once `dp[i]` is set (harmless for correctness, but wastes time on large inputs).

## Key takeaways

- 2D DP state `dp[i][j]` appears whenever you're comparing two sequences, or tracking one sequence plus an extra constraint dimension.
- String DP transitions almost always branch on `A[i-1] == B[j-1]` — write that branch first, then figure out what each side of it should compute.
- Always initialize the base-case row and column explicitly (empty-prefix comparisons) before filling the main table — Edit Distance breaks immediately without this.
- LIS has two standard solutions: O(n²) DP (derive first, easy to explain) and O(n log n) via binary search on a `tails` array (the follow-up optimization interviewers look for).
- Reconstructing the actual solution (not just its length/cost) from a DP table means walking backward from `dp[m][n]`, re-deriving which transition was taken at each step.

## Today's checklist

- [ ] Explain when a problem needs 2D DP vs 1D
- [ ] Solve Longest Common Subsequence (LeetCode 1143)
- [ ] Solve Edit Distance (LeetCode 72)
- [ ] Solve Longest Increasing Subsequence (LeetCode 300), both O(n²) and O(n log n)
- [ ] Solve Word Break (LeetCode 139)
- [ ] Implement LCS with space optimized to O(min(m,n))
- [ ] Practice drawing a DP table by hand for Edit Distance before coding it
- [ ] Review: how to reconstruct the actual solution (not just the value) from a DP table
