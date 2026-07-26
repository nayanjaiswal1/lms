---
kind: lesson
id_key: interview-prep-45/day-12
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Dynamic Programming - Basics"
position: 12
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---

Dynamic programming trips up more candidates than any other topic, not because the code is hard but because *finding the state* is hard. Today you build the mental model — recursion → memoization → tabulation — on the simplest possible problems, so the pattern is automatic before you hit harder DP later in the course.

## Recursion vs memoization vs tabulation

**Plain recursion** re-solves the same subproblem repeatedly when subproblems overlap — this is what makes naive recursive solutions exponential.

```python
def fib_naive(n):
    if n <= 1:
        return n
    return fib_naive(n - 1) + fib_naive(n - 2)
# fib_naive(5) recomputes fib_naive(3) twice, fib_naive(2) three times, etc.
# Time: O(2^n)
```

**Memoization** (top-down DP) keeps the recursive structure but caches results, so each unique subproblem is computed once.

```python
def fib_memo(n, cache={}):
    if n <= 1:
        return n
    if n in cache:
        return cache[n]
    cache[n] = fib_memo(n - 1, cache) + fib_memo(n - 2, cache)
    return cache[n]
# Time: O(n), Space: O(n) for cache + O(n) recursion stack
```

**Tabulation** (bottom-up DP) removes recursion entirely — build the answer iteratively from the base cases upward, filling a table.

```python
def fib_tab(n):
    if n <= 1:
        return n
    dp = [0] * (n + 1)
    dp[1] = 1
    for i in range(2, n + 1):
        dp[i] = dp[i - 1] + dp[i - 2]
    return dp[n]
# Time: O(n), Space: O(n), no recursion stack risk
```

| | Recursion | Memoization | Tabulation |
|---|---|---|---|
| Structure | Top-down, natural | Top-down, cached | Bottom-up, iterative |
| Time (overlapping subproblems) | Exponential | O(states) | O(states) |
| Stack risk | High (deep recursion) | High | None |
| Easiest to write first | Yes — start here to find the recurrence | Add a cache once recursion is correct | Convert once the recurrence and base cases are locked |
| Space optimization | N/A | Cache proportional to state space | Often reducible to O(1) if only recent states matter |

**Workflow in an interview:** write the naive recursive solution first (even mentally) to nail the recurrence, add memoization to show you understand the overlap, then offer tabulation (and space optimization) as the polish — this progression itself demonstrates DP fluency to the interviewer.

## State definition

The "state" is the minimal set of parameters that uniquely determines a subproblem's answer. Getting this wrong is the most common way candidates get stuck on DP.

Ask: **what changes between recursive calls, and what do I need to know to answer "what's the best outcome from here"?**

- Climbing Stairs: state = current step `i`. `dp[i]` = number of ways to reach step `i`.
- House Robber: state = current house index `i`. `dp[i]` = max money robbable from houses `0..i`.
- Two-string problems (tomorrow): state = `(i, j)` — position in *each* string.

If two different state definitions give different answers to the same subproblem, the state is incomplete — you're missing a dimension (e.g., "have I used my one free skip yet" needs a boolean added to the state).

## Base cases and transitions

Every DP recurrence has two parts:

1. **Base case(s):** the smallest subproblems, answered directly without recursion (e.g., `dp[0] = 1`, `dp[1] = 1`).
2. **Transition:** how `dp[i]` is built from smaller already-solved states (e.g., `dp[i] = dp[i-1] + dp[i-2]`).

Get the base cases wrong and every downstream value is wrong even if the transition logic is perfect — always verify base cases against the smallest 1-2 concrete examples by hand before coding.

## Climbing Stairs

[LeetCode 70](https://leetcode.com/problems/climbing-stairs/) — DP — Basic

**Intuition:** To reach step `n`, your last move was either a 1-step from `n-1` or a 2-step from `n-2`. So the number of ways to reach `n` is the sum of ways to reach those two prior steps — this is literally the Fibonacci recurrence.

**Approach:** `dp[i] = dp[i-1] + dp[i-2]`, with `dp[0] = 1` (one way to stand at the start: do nothing) and `dp[1] = 1`.

```python
def climbStairs(n: int) -> int:
    if n <= 1:
        return 1
    prev2, prev1 = 1, 1  # dp[0], dp[1]
    for i in range(2, n + 1):
        prev2, prev1 = prev1, prev2 + prev1
    return prev1
```

**Complexity:** Time O(n), space O(1) — this is the "space optimization" mentioned above: since `dp[i]` only depends on the two previous values, we don't need the full array.

**Common mistakes:** Off-by-one on base cases (`dp[0]` should be 1, not 0 — there's exactly one way to be at the ground with zero steps taken: do nothing); recomputing with unmemoized recursion, giving O(2^n).

## Min Cost Climbing Stairs

[LeetCode 746](https://leetcode.com/problems/min-cost-climbing-stairs/) — DP — Basic

**Intuition:** You can start from step 0 or step 1 for free, and each step you land on costs `cost[i]` to leave. Minimize total cost to get past the top. `dp[i]` = minimum cost to reach step `i`.

**Approach:** `dp[i] = min(dp[i-1] + cost[i-1], dp[i-2] + cost[i-2])` — reaching step `i` means paying to leave whichever of the two prior steps you came from.

```python
def minCostClimbingStairs(cost: list[int]) -> int:
    n = len(cost)
    prev2, prev1 = 0, 0  # dp[0] = 0, dp[1] = 0 (both are free starting points)
    for i in range(2, n + 1):
        prev2, prev1 = prev1, min(prev1 + cost[i - 1], prev2 + cost[i - 2])
    return prev1
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** Confusing "cost to reach step i" with "cost of step i" — the cost is paid when you *leave* a step, not when you land on it, which shifts the indices in the transition; forgetting the top is *past* the last index (`n`, one beyond `len(cost) - 1`).

## House Robber

[LeetCode 198](https://leetcode.com/problems/house-robber/) — DP — State selection

**Intuition:** At each house, you either rob it (and skip the previous one, since adjacent houses can't both be robbed) or skip it. `dp[i]` = max money robbable from the first `i` houses.

**Approach:** `dp[i] = max(dp[i-1], dp[i-2] + nums[i])` — either skip house `i` (carry forward `dp[i-1]`) or rob it (`nums[i]` plus the best from two houses back, since the adjacent one is now off-limits).

```python
def rob(nums: list[int]) -> int:
    prev2, prev1 = 0, 0  # dp[-1] = 0 (no houses), dp[0] before loop starts
    for num in nums:
        prev2, prev1 = prev1, max(prev1, prev2 + num)
    return prev1
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** Trying to track "which houses were robbed" instead of just the max value — the problem only asks for the amount, so state is simpler than it first appears; confusing this with a greedy "always take the bigger neighbor" approach, which is wrong (DP correctly looks ahead via the recurrence, greedy doesn't).

## House Robber II

[LeetCode 213](https://leetcode.com/problems/house-robber-ii/) — DP — Circular array

**Intuition:** Houses are arranged in a circle, so house 0 and house `n-1` are now adjacent too — you can't rob both. Split into two cases: rob from the range excluding the last house, or rob from the range excluding the first house. The answer is the max of the two, each solved with plain House Robber.

**Approach:** Run the House Robber I logic twice — once on `nums[0:n-1]`, once on `nums[1:n]` — and take the max. Handle `n == 1` as a special case (a single house has no "circle" conflict).

```python
def rob_ii(nums: list[int]) -> int:
    if len(nums) == 1:
        return nums[0]

    def rob_linear(houses):
        prev2, prev1 = 0, 0
        for num in houses:
            prev2, prev1 = prev1, max(prev1, prev2 + num)
        return prev1

    return max(rob_linear(nums[:-1]), rob_linear(nums[1:]))
```

**Complexity:** Time O(n) (two linear passes), space O(n) for the slices (O(1) extra if you pass index ranges instead of slicing).

**Common mistakes:** Forgetting the `n == 1` edge case — slicing `nums[:-1]` and `nums[1:]` both produce empty lists when `n == 1`, silently returning 0 instead of `nums[0]`; trying to solve the circular case directly with one pass instead of decomposing into two linear subproblems (the reduction to House Robber I is the whole trick here).

## Key takeaways

- Always find the recurrence via naive recursion first, then add memoization, then convert to tabulation — this progression is also how you should narrate it in an interview.
- The state is the minimal set of variables that fully determines a subproblem; an incomplete state gives inconsistent answers for what looks like "the same" subproblem.
- Base cases anchor the whole table — verify them by hand on the smallest 1-2 inputs before trusting the transition.
- When `dp[i]` only depends on a fixed number of previous states (not the whole history), you can collapse the array to O(1) space — this is the single most common DP follow-up question.
- "Circular" variants (House Robber II) often reduce to two runs of the linear version rather than needing new logic.
