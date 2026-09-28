---
kind: lesson
id_key: interview-prep-45/day-15
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Dynamic Programming: Hard String Matching"
position: 18
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
    - final-prep/36-lesson.md
---

Think about a search box that supports `*` for "anything" and `?` for "any one character," the way old file explorers let you type `report*.pdf` to find every report. Making that actually work under the hood is dynamic programming (DP), and it's one of the places senior interviews specifically probe, because a wrong transition often *looks* right and only fails on tricky inputs. This lesson pushes DP past the "fill a 1D table" problems from earlier lessons into 2D string-matching DP, where the transition itself is the hard part. Interviewers use these problems to check whether you actually understand the state you're building, rather than having memorized a template.

## Recognizing a 2-string matching DP

Regex matching, wildcard matching, and edit distance all share one shape: two strings (or a string and a pattern) being compared position by position. Once you can spot that shape, the setup is always the same three steps.

1. Define `dp[i][j]` as the answer for the first `i` characters of string `s` and the first `j` characters of the other string `t`.
2. Build a table sized `(len(s)+1) x (len(t)+1)`. Row 0 and column 0 stand for the empty prefix, which kills most off-by-one bugs before they start.
3. Fill row by row, and each cell's answer depends only on `(i-1, j)`, `(i, j-1)`, and `(i-1, j-1)`, the cells directly above, to the left, and diagonally above-left.

Reach for this shape whenever you see: two sequences being compared, transformed, or aligned (edit distance, longest common subsequence, interleaving strings); or `*` / `?` wildcard-style matching against a pattern.

> **Remember:** two strings being compared, one table with an extra empty-prefix row and column. That setup is the same for edit distance, wildcard matching, and regex matching.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-hard-recognize-q1", "type": "mcq",
      "prompt": "What's the shared setup across edit distance, wildcard matching, and regex matching?",
      "options": [
        {"id": "a", "text": "A dp[i][j] table sized (len(s)+1) x (len(t)+1), where row 0 and column 0 represent empty prefixes"},
        {"id": "b", "text": "All three use a min-heap to track the best partial match"},
        {"id": "c", "text": "All three can be solved without ever comparing individual characters"},
        {"id": "d", "text": "None of them need a base case"}
      ],
      "correct": "a",
      "explanation": "Every 2-string comparison DP uses the same table shape: two indices, and an extra row/column so the empty prefix has a defined answer." }
] }
```

## State reduction

State reduction means shrinking `dp[i][j][k]...` down to the smallest set of indices that fully describes a subproblem. Every DP problem starts with too much information in your head: position in the string, position in the pattern, whether you're mid-star, how many stars used so far. The real skill is proving most of that is unnecessary.

For string matching problems, the state is almost always `(i, j)`: "does `s[:i]` match `p[:j]`?" You don't need to track *how* it matched, only *whether* it did, because what happens next only depends on that yes/no plus the remaining suffixes. That's the reduction: from "the full matching history" down to "one bit per `(i, j)` pair."

```python
# Bad instinct: track the whole match path
# dp[i][j] = list of ways s[:i] matched p[:j]   -> exponential blowup

# Correct: track only whether a match is possible
# dp[i][j] = bool                                -> O(m*n) states
```

Rule of thumb: if two different "histories" lead to the same future behavior, they belong in the same state. If your DP table has an extra dimension, ask whether that dimension actually changes what happens next.

> **Remember:** don't track how you got here, only whether you're in a valid state now. If the future doesn't care about the history, the state shouldn't either.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-hard-state-reduction-q1", "type": "mcq",
      "prompt": "Why is dp[i][j] = boolean enough for string matching, instead of tracking the full history of how the match happened?",
      "options": [
        {"id": "a", "text": "Because what happens next from (i, j) only depends on whether a match is possible there, not on how it became possible"},
        {"id": "b", "text": "Because booleans use less memory than integers"},
        {"id": "c", "text": "Because Python doesn't support storing lists inside a DP table"},
        {"id": "d", "text": "Tracking history is required; boolean-only DP is a common bug"}
      ],
      "correct": "a",
      "explanation": "If two different match histories lead to the same future behavior, they belong in the same state. The future from (i, j) is identical regardless of the specific path taken to reach it." }
] }
```

## Space optimization

Once you have a correct `dp[i][j]` table, look at the transition. If `dp[i][j]` only ever reads from row `i-1` (and maybe row `i`), you don't need the full 2D table: two 1D rows (`prev`, `curr`) are enough, or even one row updated carefully in place.

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

This matters in interviews for two reasons. It shows you understand the *dependency structure* of your own recurrence, not just that you wrote one down. And it's a real production concern: a 10,000 x 10,000 DP table is 100 million cells; a rolling array is 10,000 cells.

**Pitfall:** when you roll the array, any base-case reset (`dp[i][0]`) has to happen explicitly inside the loop, since you're reusing the same memory. Forgetting this is the number one bug in rolling-array code.

> **Remember:** if a cell only ever reads the row above it, you don't need the whole table, just that one row. Mention the shrink out loud even if you don't have time to code it.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-hard-space-opt-q1", "type": "mcq",
      "prompt": "What's the most common bug when converting a 2D DP table into a rolling two-row version?",
      "options": [
        {"id": "a", "text": "Forgetting to explicitly reset the base-case cell (like curr[0]) inside the loop, since the memory is now reused instead of being fresh each row"},
        {"id": "b", "text": "Rolling arrays always change the final answer"},
        {"id": "c", "text": "Rolling arrays can only be used with strings, not with numbers"},
        {"id": "d", "text": "The time complexity increases when you roll the array"}
      ],
      "correct": "a",
      "explanation": "In the full 2D table, dp[i][0] starts as its own fresh cell every row. In a rolling array, that memory is reused, so the base case has to be reset by hand each iteration." }
] }
```

## Complex transitions

The wildcard and regex family have "look-behind" transitions. `p[j-1] == '*'` involves more than comparing one pair of characters: it branches into "match zero of the preceding element" versus "match one more of the current string," and both branches have to be OR'd together. This is the part candidates get wrong under pressure: they handle the plain character-match case fine, then panic on `*` and either miss a branch or mix up `i` and `j`.

The reliable process: say the recurrence out loud in plain English first ("if the pattern character is `*`, either the string character is unused entirely, since `*` matched zero times, or the string character is consumed and we stay on the same pattern position, since `*` can match more"), then transcribe it directly into code. Don't try to write the branch logic without saying it out loud first.

> **Remember:** never code a `*` transition cold. Say the two branches in plain English first, then translate the sentence into code.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-hard-transitions-q1", "type": "mcq",
      "prompt": "Why do candidates most often get the `*` transition wrong under interview pressure?",
      "options": [
        {"id": "a", "text": "They handle the simple character-match case fine but skip stating the two `*` branches in plain English first, so they miss one branch or swap i and j"},
        {"id": "b", "text": "The `*` character isn't allowed in regular expressions"},
        {"id": "c", "text": "Python doesn't support the `*` operator in string matching"},
        {"id": "d", "text": "The `*` transition never actually needs two branches"}
      ],
      "correct": "a",
      "explanation": "The `*` case has two valid outcomes (match zero, or consume one more) that must be OR'd together. Skipping the plain-English statement of both branches is what causes the slip." }
] }
```

### Regular Expression Matching

[LeetCode 10 · Regular Expression Matching](https://leetcode.com/problems/regular-expression-matching/) · DP · Hard

**Intuition:** `.` matches any single character; `*` matches zero or more of the *preceding* element (not the literal character before `*`, but that pattern unit). Because `*` looks back one pattern character, `dp[i][j]` has to consider `p[j-2]` whenever `p[j-1] == '*'`.

**Approach:** Build `dp[i][j]` = "does `s[:i]` match `p[:j]`?" Base case: an empty pattern only matches an empty string, but patterns like `a*`, `a*b*` can also match an empty string, so `dp[0][j]` needs its own rule. For each cell, branch on whether the current pattern character is `*`.

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
```javascript +
function isMatch(s, p) {
    const m = s.length, n = p.length;
    const dp = Array.from({ length: m + 1 }, () => new Array(n + 1).fill(false));
    dp[0][0] = true;

    // empty string vs patterns like a*, a*b*c* etc.
    for (let j = 1; j <= n; j++) {
        if (p[j - 1] === '*') {
            dp[0][j] = dp[0][j - 2];
        }
    }

    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            if (p[j - 1] === '.' || p[j - 1] === s[i - 1]) {
                dp[i][j] = dp[i - 1][j - 1];
            } else if (p[j - 1] === '*') {
                // zero occurrences of p[j-2]
                dp[i][j] = dp[i][j - 2];
                // one more occurrence of p[j-2], if it can match s[i-1]
                const prevChar = p[j - 2];
                if (prevChar === '.' || prevChar === s[i - 1]) {
                    dp[i][j] = dp[i][j] || dp[i - 1][j];
                }
            } else {
                dp[i][j] = false;
            }
        }
    }

    return dp[m][n];
}
```
```java +
public class Main {
    public static boolean isMatch(String s, String p) {
        int m = s.length(), n = p.length();
        boolean[][] dp = new boolean[m + 1][n + 1];
        dp[0][0] = true;

        // empty string vs patterns like a*, a*b*c* etc.
        for (int j = 1; j <= n; j++) {
            if (p.charAt(j - 1) == '*') {
                dp[0][j] = dp[0][j - 2];
            }
        }

        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                char pc = p.charAt(j - 1);
                if (pc == '.' || pc == s.charAt(i - 1)) {
                    dp[i][j] = dp[i - 1][j - 1];
                } else if (pc == '*') {
                    // zero occurrences of p[j-2]
                    dp[i][j] = dp[i][j - 2];
                    // one more occurrence of p[j-2], if it can match s[i-1]
                    char prevChar = p.charAt(j - 2);
                    if (prevChar == '.' || prevChar == s.charAt(i - 1)) {
                        dp[i][j] = dp[i][j] || dp[i - 1][j];
                    }
                } else {
                    dp[i][j] = false;
                }
            }
        }

        return dp[m][n];
    }

    public static void main(String[] args) {
        System.out.println(isMatch("aa", "a*"));
        System.out.println(isMatch("mississippi", "mis*is*p*."));
    }
}
```

**Complexity:** O(m*n) time, O(m*n) space (rollable to O(n), see Space optimization above).

**Common mistakes:** forgetting the `dp[0][j]` base case for patterns that can match an empty string; indexing `p[j-2]` when `j < 2` (safe here because a valid regex never starts with `*`, but always double-check input assumptions in an interview); confusing "zero occurrences" (`dp[i][j-2]`) with "one occurrence" (`dp[i-1][j]`), when both actually need to be considered together.

> **Remember:** `*` in regex looks backward at the pattern character before it. Both "use it zero times" and "use it one more time" have to be checked.

### Wildcard Matching

[LeetCode 44 · Wildcard Matching](https://leetcode.com/problems/wildcard-matching/) · DP · Hard

**Intuition:** `?` matches exactly one character, `*` matches any sequence, including empty, of characters. This is simpler than regex, because `*` doesn't look back at a preceding element here: it's a free-standing wildcard.

**Approach:** `dp[i][j]` = "does `s[:i]` match `p[:j]`?" When `p[j-1] == '*'`, it can either match zero characters of `s` (`dp[i][j-1]`) or consume one more character of `s` and stay matched against the same `*` (`dp[i-1][j]`). This is the O(m*n) time, O(n) space version.

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
```javascript +
function isMatch(s, p) {
    const m = s.length, n = p.length;

    // prev = dp[i-1][*], curr = dp[i][*]
    let prev = new Array(n + 1).fill(false);
    prev[0] = true;
    for (let j = 1; j <= n; j++) {
        prev[j] = prev[j - 1] && p[j - 1] === '*';
    }

    for (let i = 1; i <= m; i++) {
        const curr = new Array(n + 1).fill(false);
        curr[0] = false; // non-empty s can't match empty p
        for (let j = 1; j <= n; j++) {
            if (p[j - 1] === '*') {
                curr[j] = curr[j - 1] || prev[j];
            } else if (p[j - 1] === '?' || p[j - 1] === s[i - 1]) {
                curr[j] = prev[j - 1];
            } else {
                curr[j] = false;
            }
        }
        prev = curr;
    }

    return prev[n];
}
```
```java +
public class Main {
    public static boolean isMatch(String s, String p) {
        int m = s.length(), n = p.length();

        // prev = dp[i-1][*], curr = dp[i][*]
        boolean[] prev = new boolean[n + 1];
        prev[0] = true;
        for (int j = 1; j <= n; j++) {
            prev[j] = prev[j - 1] && p.charAt(j - 1) == '*';
        }

        for (int i = 1; i <= m; i++) {
            boolean[] curr = new boolean[n + 1];
            curr[0] = false; // non-empty s can't match empty p
            for (int j = 1; j <= n; j++) {
                char pc = p.charAt(j - 1);
                if (pc == '*') {
                    curr[j] = curr[j - 1] || prev[j];
                } else if (pc == '?' || pc == s.charAt(i - 1)) {
                    curr[j] = prev[j - 1];
                } else {
                    curr[j] = false;
                }
            }
            prev = curr;
        }

        return prev[n];
    }

    public static void main(String[] args) {
        System.out.println(isMatch("adceb", "*a*b"));
        System.out.println(isMatch("acdcb", "a*c?b"));
    }
}
```

**Complexity:** O(m*n) time, O(n) space.

**Common mistakes:** mixing up this `*`'s "zero or more characters" meaning with regex's "zero or more of the preceding element" from the problem above. They look similar, but the transition differs, since wildcard's `*` never looks back. Also, forgetting to reset `curr[0] = False` each row when rolling the array; and assuming consecutive `*` characters need special handling, when the DP already collapses them to the same matching power as one `*`, with no pre-processing needed.

> **Remember:** wildcard's `*` never looks back at a specific character, it's just "any sequence." That's the one difference from regex's `*` to keep straight.

### Minimum Path Sum

[LeetCode 64 · Minimum Path Sum](https://leetcode.com/problems/minimum-path-sum/) · DP · 2D

**Intuition:** Only two moves are allowed, right or down, so the minimum cost to reach `(i, j)` is that cell's own cost plus the cheaper of "coming from above" or "coming from the left."

**Approach:** In-place DP directly on the input grid skips extra space entirely. It's the state-reduction idea applied aggressively: you don't even need a separate table, because each cell's dependency (`up`, `left`) is already computed and won't be needed again.

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
```javascript +
function minPathSum(grid) {
    const m = grid.length, n = grid[0].length;
    for (let i = 0; i < m; i++) {
        for (let j = 0; j < n; j++) {
            if (i === 0 && j === 0) {
                continue;
            } else if (i === 0) {
                grid[i][j] += grid[i][j - 1];
            } else if (j === 0) {
                grid[i][j] += grid[i - 1][j];
            } else {
                grid[i][j] += Math.min(grid[i - 1][j], grid[i][j - 1]);
            }
        }
    }
    return grid[m - 1][n - 1];
}
```
```java +
public class Main {
    public static int minPathSum(int[][] grid) {
        int m = grid.length, n = grid[0].length;
        for (int i = 0; i < m; i++) {
            for (int j = 0; j < n; j++) {
                if (i == 0 && j == 0) {
                    continue;
                } else if (i == 0) {
                    grid[i][j] += grid[i][j - 1];
                } else if (j == 0) {
                    grid[i][j] += grid[i - 1][j];
                } else {
                    grid[i][j] += Math.min(grid[i - 1][j], grid[i][j - 1]);
                }
            }
        }
        return grid[m - 1][n - 1];
    }

    public static void main(String[] args) {
        int[][] grid = { {1, 3, 1}, {1, 5, 1}, {4, 2, 1} };
        System.out.println(minPathSum(grid));
    }
}
```

**Complexity:** O(m*n) time, O(1) extra space (mutates the input in place, so mention that trade-off out loud in an interview, since it isn't always acceptable).

**Common mistakes:** forgetting the first row/column special cases; they only have one possible direction of approach, not two. Also, mutating the grid when the interviewer expects the input preserved: ask first, or copy the grid if unsure.

> **Remember:** the first row and column only have one way in. Everywhere else, take the cheaper of "from above" or "from the left."

### Longest Palindromic Substring

[LeetCode 5 · Longest Palindromic Substring](https://leetcode.com/problems/longest-palindromic-substring/) · DP

**Intuition:** A substring `s[i:j]` is a palindrome if `s[i] == s[j-1]` and the inner substring `s[i+1:j-1]` is also a palindrome. That's a valid DP, but the expand-around-center technique gets the same O(n²) time with O(1) space, and it's the version to lead with in an interview.

**Approach (expand around center):** Every palindrome has a center, either a single character (odd length) or a gap between two characters (even length). Try all `2n - 1` centers and expand outward while characters keep matching.

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
```javascript +
function longestPalindrome(s) {
    if (!s) return "";

    const expand = (left, right) => {
        while (left >= 0 && right < s.length && s[left] === s[right]) {
            left -= 1;
            right += 1;
        }
        // left/right have overstepped by one on the last failed check
        return [left + 1, right - 1];
    };

    let [start, end] = [0, 0];
    for (let center = 0; center < s.length; center++) {
        const [l1, r1] = expand(center, center);        // odd length
        const [l2, r2] = expand(center, center + 1);     // even length
        if (r1 - l1 > end - start) [start, end] = [l1, r1];
        if (r2 - l2 > end - start) [start, end] = [l2, r2];
    }

    return s.slice(start, end + 1);
}
```
```java +
public class Main {
    public static String longestPalindrome(String s) {
        if (s == null || s.isEmpty()) return "";

        int[] best = {0, 0};
        for (int center = 0; center < s.length(); center++) {
            int[] odd = expand(s, center, center);          // odd length
            int[] even = expand(s, center, center + 1);      // even length
            if (odd[1] - odd[0] > best[1] - best[0]) best = odd;
            if (even[1] - even[0] > best[1] - best[0]) best = even;
        }

        return s.substring(best[0], best[1] + 1);
    }

    private static int[] expand(String s, int left, int right) {
        while (left >= 0 && right < s.length() && s.charAt(left) == s.charAt(right)) {
            left -= 1;
            right += 1;
        }
        // left/right have overstepped by one on the last failed check
        return new int[] { left + 1, right - 1 };
    }

    public static void main(String[] args) {
        System.out.println(longestPalindrome("babad"));
    }
}
```

**Complexity:** O(n²) time, O(1) space. The classic DP table version is O(n²) time and O(n²) space, worth knowing both so you can explain the trade-off if asked.

**Common mistakes:** forgetting the even-length center case (a gap, not a character), which silently misses palindromes like `"abba"`. Also, an off-by-one in the return of `expand`: the loop exits one step past the actual palindrome boundary, so you must correct by 1 in each direction.

> **Remember:** every palindrome has a center, either on a character or in the gap between two. Check both kinds of center at every position.

The two `*` semantics in this lesson are easy to blur together once you've seen both: regex's `*` looks back at the preceding pattern element, wildcard's `*` is free-standing and never looks back. If you catch yourself writing the same transition for both problems, stop and re-derive it from the plain-English description first.
