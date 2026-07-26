---
kind: lesson
id_key: interview-prep-45/day-15
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Dynamic Programming - Hard"
position: 15
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
---
Today pushes DP past the easy "fill a 1D table" problems into 2D string-matching DP, where the transition itself is the hard part. Regex and wildcard matching show up in senior interviews specifically because a wrong transition looks plausible but fails on edge cases — interviewers use them to see if you actually understand the state, not just pattern-matched a template.

## State reduction

State reduction means shrinking `dp[i][j][k]...` down to the smallest set of indices that fully describes a subproblem. Every DP problem starts with too much information in your head ("position in string, position in pattern, whether we're mid-star, how many stars used so far") — the skill is proving most of that is redundant.

For string matching problems, the state is almost always `(i, j)` = "does `s[:i]` match `p[:j]`?" You don't need to track *how* it matched, only *whether* it did, because the sub-problem going forward only depends on that boolean plus the remaining suffixes. That's the reduction: from "the full matching history" down to "one bit per `(i, j)` pair."

```python
# Bad instinct: track the whole match path
# dp[i][j] = list of ways s[:i] matched p[:j]   -> exponential blowup

# Correct: track only whether a match is possible
# dp[i][j] = bool                                -> O(m*n) states
```

Rule of thumb: if two different "histories" lead to the same future behavior, they belong in the same state. If your DP table has an extra dimension, ask whether that dimension actually changes what happens next.

## Space optimization

Once you have a correct `dp[i][j]` table, look at the transition. If `dp[i][j]` only ever reads from row `i-1` (and maybe row `i`), you don't need the full 2D table — two 1D rows (`prev`, `curr`) suffice, or even one row updated carefully in place.

```python
# 2D table: O(m*n) space
dp = [[False] * (n + 1) for _ in range(m + 1)]

# Rolling array: O(n) space — only keep the previous row
prev = [False] * (n + 1)
curr = [False] * (n + 1)
for i in range(1, m + 1):
    curr[0] = False  # reset base case for this row
    for j in range(1, n + 1):
        curr[j] = ...  # transition using prev[j], prev[j-1], curr[j-1]
    prev, curr = curr, prev
```

This matters in interviews for two reasons: it shows you understand the *dependency structure* of your own recurrence (not just that you wrote one), and it's a real production concern — a 10,000 x 10,000 DP table is 100M cells; a rolling array is 10,000 cells.

Pitfall: when you roll the array, any base-case reset (`dp[i][0]`) has to happen explicitly inside the loop, since you're reusing the same memory. Forgetting this is the #1 bug in rolling-array code.

## Complex transitions

The wildcard/regex family has "look-behind" transitions — `p[j-1] == '*'` doesn't just compare one pair of characters, it branches into "match zero of the preceding element" vs. "match one more of the current string." Both branches must be OR'd together. This is the part candidates get wrong under pressure: they handle the straightforward character-match case fine, then panic on `*` and either miss a branch or transpose `i`/`j`.

The reliable process: write the recurrence in English first ("if the pattern char is `*`, either the string char is unused entirely — the `*` matched zero times — or the string char is consumed and we stay on the same pattern position because `*` can match more"), then transcribe directly. Do not try to code the branch logic without saying it out loud first.

### Regular Expression Matching

[LeetCode 10 — Regular Expression Matching](https://leetcode.com/problems/regular-expression-matching/) — DP — Hard

**Intuition:** `.` matches any single character; `*` matches zero or more of the *preceding* element (not the character before `*` literally being repeated, but as a pattern unit). Because `*` looks back one pattern character, `dp[i][j]` must consider `p[j-2]` whenever `p[j-1] == '*'`.

**Approach:** Build `dp[i][j]` = "does `s[:i]` match `p[:j]`". Base case: empty pattern only matches empty string, but `a*`, `a*b*`, etc. can match empty string too, so `dp[0][j]` needs its own recurrence. For each cell, branch on whether the current pattern character is `*`.

```python
def is_match(s: str, p: str) -> bool:
    m, n = len(s), len(p)
    dp = [[False] * (n + 1) for _ in range(m + 1)]
    dp[0][0] = True

    # empty string vs patterns like a*, a*b*c* etc.
    for j in range(1, n + 1):
        if p[j - 1] == '*':
            dp[0][j] = dp[0][j - 2]

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if p[j - 1] == '.' or p[j - 1] == s[i - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            elif p[j - 1] == '*':
                # zero occurrences of p[j-2]
                dp[i][j] = dp[i][j - 2]
                # one more occurrence of p[j-2], if it can match s[i-1]
                prev_char = p[j - 2]
                if prev_char == '.' or prev_char == s[i - 1]:
                    dp[i][j] = dp[i][j] or dp[i - 1][j]
            else:
                dp[i][j] = False

    return dp[m][n]
```

**Complexity:** O(m*n) time, O(m*n) space (can be rolled to O(n), see Space optimization above).

**Common mistakes:** forgetting the `dp[0][j]` base case for patterns that can match empty string; indexing `p[j-2]` when `j < 2` (guaranteed safe here because `*` can never be the first pattern character in a valid regex, but double-check input assumptions in an interview); confusing "zero occurrences" (`dp[i][j-2]`) with "one occurrence" (`dp[i-1][j]`) — both must be considered, not just one.

### Wildcard Matching

[LeetCode 44 — Wildcard Matching](https://leetcode.com/problems/wildcard-matching/) — DP — Hard

**Intuition:** `?` matches exactly one character, `*` matches any sequence (including empty) of characters. This is simpler than regex because `*` doesn't look back at a preceding element — it's a free-standing wildcard.

**Approach:** `dp[i][j]` = "does `s[:i]` match `p[:j]`". When `p[j-1] == '*'`, it can either match zero characters of `s` (`dp[i][j-1]`) or consume one more character of `s` and stay matched against the same `*` (`dp[i-1][j]`). This is the required O(m*n) time, O(n) space version.

```python
def is_match(s: str, p: str) -> bool:
    m, n = len(s), len(p)

    # prev = dp[i-1][*], curr = dp[i][*]
    prev = [False] * (n + 1)
    prev[0] = True
    for j in range(1, n + 1):
        prev[j] = prev[j - 1] and p[j - 1] == '*'

    for i in range(1, m + 1):
        curr = [False] * (n + 1)
        curr[0] = False  # non-empty s can't match empty p
        for j in range(1, n + 1):
            if p[j - 1] == '*':
                curr[j] = curr[j - 1] or prev[j]
            elif p[j - 1] == '?' or p[j - 1] == s[i - 1]:
                curr[j] = prev[j - 1]
            else:
                curr[j] = False
        prev = curr

    return prev[n]
```

**Complexity:** O(m*n) time, O(n) space — this is the target profile called out in today's implementation task.

**Common mistakes:** conflating `*`'s "zero or more characters" semantics here with regex's "zero or more of preceding element" from Problem 1 above — they look similar but the transition is different (no look-back); forgetting to reset `curr[0] = False` each row when rolling the array; off-by-one errors when consecutive `*` characters appear in the pattern (they should collapse to the same matching power as one `*`, and the DP handles this correctly without needing to pre-collapse the pattern, but it's worth knowing the DP already handles it).

### Minimum Path Sum

[LeetCode 64 — Minimum Path Sum](https://leetcode.com/problems/minimum-path-sum/) — DP — 2D

**Intuition:** Only two moves are allowed — right or down — so the minimum cost to reach `(i, j)` is the cell's own cost plus the cheaper of "coming from above" or "coming from the left."

**Approach:** In-place DP directly on the input grid avoids extra space entirely — this is the "state reduction" idea applied aggressively: you don't even need a separate table, because each cell's dependency (`up`, `left`) is already computed and won't be needed again.

```python
def min_path_sum(grid: list[list[int]]) -> int:
    m, n = len(grid), len(grid[0])
    for i in range(m):
        for j in range(n):
            if i == 0 and j == 0:
                continue
            elif i == 0:
                grid[i][j] += grid[i][j - 1]
            elif j == 0:
                grid[i][j] += grid[i - 1][j]
            else:
                grid[i][j] += min(grid[i - 1][j], grid[i][j - 1])
    return grid[m - 1][n - 1]
```

**Complexity:** O(m*n) time, O(1) extra space (mutates input in place — mention this trade-off out loud in an interview, since mutating input isn't always acceptable).

**Common mistakes:** forgetting the first row/column special cases (they only have one possible direction of approach, not two); mutating the grid when the interviewer expects the input preserved (ask, or allocate a copy if unsure).

### Longest Palindromic Substring

[LeetCode 5 — Longest Palindromic Substring](https://leetcode.com/problems/longest-palindromic-substring/) — DP

**Intuition:** A substring `s[i:j]` is a palindrome if `s[i] == s[j-1]` and the inner substring `s[i+1:j-1]` is also a palindrome. That's a valid DP, but the expand-around-center technique gets the same O(n^2) time with O(1) space, which is the version to lead with in an interview.

**Approach (expand around center):** Every palindrome has a center — either a single character (odd length) or a gap between two characters (even length). Try all `2n - 1` centers and expand outward while characters match.

```python
def longest_palindrome(s: str) -> str:
    if not s:
        return ""

    def expand(left: int, right: int) -> tuple[int, int]:
        while left >= 0 and right < len(s) and s[left] == s[right]:
            left -= 1
            right += 1
        # left/right have overstepped by one on the last failed check
        return left + 1, right - 1

    start, end = 0, 0
    for center in range(len(s)):
        l1, r1 = expand(center, center)        # odd length
        l2, r2 = expand(center, center + 1)     # even length
        if r1 - l1 > end - start:
            start, end = l1, r1
        if r2 - l2 > end - start:
            start, end = l2, r2

    return s[start:end + 1]
```

**Complexity:** O(n^2) time, O(1) space. The classic DP table version is O(n^2) time and O(n^2) space — worth knowing both so you can explain the trade-off if asked.

**Common mistakes:** forgetting the even-length center case (a gap, not a character) — this silently misses palindromes like `"abba"`; off-by-one in the return of `expand` (the loop exits one step past the actual palindrome boundary, so you must correct by ±1).

## Key takeaways

- State reduction: keep only the information the *future* recurrence needs, not the full history.
- Space optimization from O(m*n) to O(n) is safe whenever a row only depends on the row directly above it — reset base cells explicitly when rolling.
- `*` means different things in regex (look-back at the preceding pattern element) vs. wildcard matching (free-standing, no look-back) — don't let the two transitions blur together.
- In-place DP on the input (Minimum Path Sum) is the ultimate space optimization, but confirm mutating input is acceptable.
- Expand-around-center beats table-based DP for palindrome problems when O(1) space matters.
- Say the recurrence in English before writing code — this is what prevents dropped branches under interview pressure.
