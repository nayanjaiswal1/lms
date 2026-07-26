---
kind: lesson
id_key: interview-prep-45/day-16
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Backtracking"
position: 16
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
---
Backtracking is how you enumerate every valid configuration of something — subsets, permutations, combinations — without brute-forcing all of them blindly. It's one of the highest-frequency interview patterns because the code shape is nearly identical across problems, and interviewers use small variations (duplicates, unbounded reuse, fixed length) to test whether you actually understand the recursion tree or just memorized one template.

## Choice, constraints, goal framework

Every backtracking problem decomposes into three questions:

1. **Choice** — at this point in the recursion, what are the options I can pick from next?
2. **Constraints** — which of those options are actually valid given what I've already picked?
3. **Goal** — when do I have a complete, valid answer worth recording?

```python
def backtrack(path, choices):
    if is_goal(path):           # goal check
        record(path)
        return
    for choice in choices:      # choice enumeration
        if not is_valid(choice, path):  # constraint check
            continue
        path.append(choice)
        backtrack(path, next_choices(choices, choice))
        path.pop()               # undo — this is the "back" in backtracking
```

The `path.pop()` after the recursive call is the entire idea in one line: you try a choice, explore everything downstream of it, then undo it so the next sibling choice starts from a clean slate. Forgetting the undo is the single most common backtracking bug — it silently corrupts every subsequent branch.

## Pruning optimization

Backtracking without pruning is just exhaustive search with extra bookkeeping. Pruning means detecting that a partial path can *never* lead to a valid goal and abandoning it immediately, instead of recursing all the way down to discover that later.

```python
# Without pruning: recurse fully, check validity only at leaves — wasteful
# With pruning: check validity at every step, bail out early

def backtrack(path, remaining_sum, candidates, start):
    if remaining_sum < 0:          # prune: overshot, no point continuing
        return
    if remaining_sum == 0:
        record(path)
        return
    for i in range(start, len(candidates)):
        if candidates[i] > remaining_sum:   # prune: sorted array, rest are bigger too
            break
        path.append(candidates[i])
        backtrack(path, remaining_sum - candidates[i], candidates, i)
        path.pop()
```

Sorting the input first often unlocks pruning that wouldn't otherwise be possible (as in the `break` above — once one candidate is too large, every candidate after it is too, since the array is sorted). This turns a correctness feature (skip invalid branches) into a real performance win.

## Combination vs permutation

This distinction decides your loop's starting index, and it's the detail interviewers watch for:

- **Combinations / subsets** (order doesn't matter): each recursive call starts its loop from `start` (or `start + 1`), never revisiting earlier indices. `[1,2]` and `[2,1]` are the same combination, so you never generate both.
- **Permutations** (order matters): each recursive call loops over *all* indices not yet used, tracked with a `used` set or by swapping. `[1,2]` and `[2,1]` are different permutations, so both must be generated.

```python
# Combinations: loop starts at `start`, moves forward only
for i in range(start, len(nums)):
    ...
    backtrack(i + 1)   # next call starts after i

# Permutations: loop scans everything, skip what's used
for i in range(len(nums)):
    if used[i]:
        continue
    ...
    backtrack()   # next call scans from 0 again
```

Mixing these up is the classic bug: using a `start` index for a permutation problem silently produces only sorted-order results, or using a full scan for a combination problem produces duplicates.

### Subsets

[LeetCode 78 — Subsets](https://leetcode.com/problems/subsets/) — Backtracking — Generate all subsets

**Intuition:** Every element is either "in" or "out" of a given subset. Backtracking naturally enumerates this by recording the current path at every recursive call (not just at leaves), since every prefix is itself a valid subset.

**Approach:** Standard combination-style loop starting at `start`, recording `path` at every node of the recursion tree (not only at the base case).

```python
def subsets(nums: list[int]) -> list[list[int]]:
    result = []
    path = []

    def backtrack(start: int) -> None:
        result.append(path[:])          # every node is a valid subset
        for i in range(start, len(nums)):
            path.append(nums[i])
            backtrack(i + 1)
            path.pop()

    backtrack(0)
    return result
```

**Complexity:** O(n * 2^n) time (2^n subsets, O(n) to copy each), O(n) recursion depth excluding output.

**Common mistakes:** appending `path` directly instead of `path[:]` — this stores a reference that gets mutated later, corrupting every previously recorded subset; forgetting that every recursive call (not just leaves) produces a valid answer.

### Subsets II

[LeetCode 90 — Subsets II](https://leetcode.com/problems/subsets-ii/) — Backtracking — Handle duplicates

**Intuition:** Input may contain duplicate values. Sort first, then at each recursion level, skip a candidate if it's equal to the previous candidate *at the same level* (not globally) — that previous one already explored every subset this one would produce.

**Approach:** Sort `nums`. In the loop, skip `nums[i]` when `i > start and nums[i] == nums[i-1]`.

```python
def subsets_with_dup(nums: list[int]) -> list[list[int]]:
    nums.sort()
    result = []
    path = []

    def backtrack(start: int) -> None:
        result.append(path[:])
        for i in range(start, len(nums)):
            if i > start and nums[i] == nums[i - 1]:
                continue  # skip duplicate at this recursion level
            path.append(nums[i])
            backtrack(i + 1)
            path.pop()

    backtrack(0)
    return result
```

**Complexity:** O(n * 2^n) time worst case, O(n) recursion depth.

**Common mistakes:** skipping duplicates with a global `seen` set instead of the `i > start` same-level check — a global set incorrectly blocks valid subsets that reuse a value at a *different* branch of the tree; forgetting to sort first, which the same-level dedup depends on.

### Combination Sum

[LeetCode 39 — Combination Sum](https://leetcode.com/problems/combination-sum/) — Backtracking — Unbounded knapsack

**Intuition:** Same number can be reused unlimited times, so the recursive call passes `i` (not `i + 1`) to allow re-picking the current candidate.

**Approach:** Sort candidates for pruning. Track `remaining` target; subtract as you go; prune when `remaining < 0`; record when `remaining == 0`.

```python
def combination_sum(candidates: list[int], target: int) -> list[list[int]]:
    candidates.sort()
    result = []
    path = []

    def backtrack(start: int, remaining: int) -> None:
        if remaining == 0:
            result.append(path[:])
            return
        for i in range(start, len(candidates)):
            if candidates[i] > remaining:
                break  # sorted, so nothing further can work either
            path.append(candidates[i])
            backtrack(i, remaining - candidates[i])  # i, not i+1: reuse allowed
            path.pop()

    backtrack(0, target)
    return result
```

**Complexity:** O(n^(target/min_candidate)) time worst case (exponential, bounded by target), O(target / min_candidate) recursion depth.

**Common mistakes:** passing `i + 1` instead of `i` (this is the classic bug — it silently turns "unbounded" into "each number used at most once," which is actually [Combination Sum II](https://leetcode.com/problems/combination-sum-ii/)); forgetting to sort before using `break` as a pruning strategy.

### Permutations

[LeetCode 46 — Permutations](https://leetcode.com/problems/permutations/) — Backtracking — Generate permutations

**Intuition:** Unlike combinations, order matters and every index can appear in every position — so the loop scans the full array each time, skipping only what's already placed in the current path.

**Approach:** Track a `used` boolean array (or set) instead of a `start` index, since permutations don't have a "already passed this index" notion — they have "already placed this value."

```python
def permute(nums: list[int]) -> list[list[int]]:
    result = []
    path = []
    used = [False] * len(nums)

    def backtrack() -> None:
        if len(path) == len(nums):
            result.append(path[:])
            return
        for i in range(len(nums)):
            if used[i]:
                continue
            used[i] = True
            path.append(nums[i])
            backtrack()
            path.pop()
            used[i] = False

    backtrack()
    return result
```

**Complexity:** O(n * n!) time (n! permutations, O(n) to copy each), O(n) space for `used` plus recursion depth.

**Common mistakes:** using a `start` index like a combination problem — this produces only 1 ordering instead of n!; forgetting to reset `used[i] = False` on backtrack, which corrupts sibling branches.

## Key takeaways

- Every backtracking problem is choice, constraints, goal — write those three down before coding.
- The undo step (`path.pop()`, `used[i] = False`) after the recursive call is not optional — it's what makes backtracking correct across sibling branches.
- Sort the input first when you need pruning via `break` or same-level duplicate skipping.
- Combinations use a `start` index that only moves forward; permutations use a `used` set and re-scan from 0 every call — mixing these up is the #1 conceptual bug.
- Unbounded reuse (Combination Sum) passes `i` to the recursive call instead of `i + 1`.
- Record results at the right point: every node for subsets, only complete-length paths for permutations, only zero-remaining paths for combination-sum style problems.
