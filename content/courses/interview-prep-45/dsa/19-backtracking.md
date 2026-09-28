---
kind: lesson
id_key: interview-prep-45/day-16
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Backtracking"
position: 19
estimated_minutes: 135
source:
    - 45-day-interview-roadmap.md
---

Picture trying on every combination of shirt and pants in your closet, but the moment you notice a shirt clashes with a color of pants, you skip trying it with any other pants and move straight to the next shirt. That's backtracking: explore a choice, and the moment it stops making sense, undo it and try the next one instead of blindly finishing a doomed combination. It's how you list every valid configuration of something (subsets, permutations, combinations) without brute-forcing every possibility blindly. It's one of the highest-frequency interview patterns, because the code shape stays nearly identical across problems, and interviewers use small twists, like duplicates, reusing an item, or a fixed length, to check whether you actually understand the recursion tree or just memorized one template.

## Choice, constraints, goal framework

Every backtracking problem breaks down into three questions:

1. **Choice**: at this point in the recursion, what options can I pick from next?
2. **Constraints**: which of those options are actually valid given what I've already picked?
3. **Goal**: when do I have a complete, valid answer worth recording?

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

The `path.pop()` right after the recursive call is the entire idea in one line: try a choice, explore everything downstream of it, then undo it so the next sibling choice starts from a clean slate. Forgetting that undo is the single most common backtracking bug, and it silently corrupts every branch that comes after it.

> **Remember:** every backtracking loop asks the same three questions: what can I pick, is it valid, am I done? And it always undoes a choice before trying the next one.

```knowledge-check
{ "questions": [
    { "id": "dsa-backtracking-framework-q1", "type": "mcq",
      "prompt": "What does the path.pop() line right after the recursive call actually do in a backtracking template?",
      "options": [
        {"id": "a", "text": "Undoes the current choice so the next sibling option starts from a clean slate, instead of carrying over a choice that's no longer active"},
        {"id": "b", "text": "Removes the goal check from the recursion"},
        {"id": "c", "text": "Sorts the path so far"},
        {"id": "d", "text": "Stops the recursion permanently"}
      ],
      "correct": "a",
      "explanation": "Without the undo, every sibling branch after the first would still see the earlier choice sitting in path, corrupting every result after it." }
] }
```

## Pruning optimization

Backtracking without pruning is just exhaustive search with extra bookkeeping. Pruning means noticing that a partial path can *never* lead to a valid goal, and abandoning it right away instead of recursing all the way down to find that out later.

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

Sorting the input first often makes pruning possible where it otherwise wouldn't be, like the `break` above: once one candidate is too large, every candidate after it is too, since the array is sorted. That turns a correctness check, skipping invalid branches, into a real performance win.

> **Remember:** don't wait until a leaf to discover a branch was hopeless. Check as early as possible and bail out before wasting more recursion on it.

```knowledge-check
{ "questions": [
    { "id": "dsa-backtracking-pruning-q1", "type": "mcq",
      "prompt": "Why does sorting the candidates array first help pruning in problems like Combination Sum?",
      "options": [
        {"id": "a", "text": "Once one candidate is too large for the remaining sum, every candidate after it (since they're sorted) is too large as well, so the loop can break early"},
        {"id": "b", "text": "Sorting makes the recursion depth shallower"},
        {"id": "c", "text": "Sorting removes the need for a goal check"},
        {"id": "d", "text": "Sorting is only needed for permutation problems, not for combinations"}
      ],
      "correct": "a",
      "explanation": "With a sorted array, the moment a candidate exceeds the remaining budget, every later candidate does too, so the loop can break instead of continuing to check each one." }
] }
```

## Combination vs permutation

This distinction decides where your loop starts each recursive call, and it's the detail interviewers watch closely.

- **Combinations / subsets** (order doesn't matter): each recursive call starts its loop from `start` (or `start + 1`), never revisiting earlier indices. `[1,2]` and `[2,1]` count as the same combination, so you never generate both.
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

Mixing these up is the classic bug. A `start` index used for a permutation problem silently produces only results in sorted order; a full scan used for a combination problem produces duplicates.

> **Remember:** combinations move the starting point forward and never look back. Permutations scan everything every time and just skip what's already used.

```knowledge-check
{ "questions": [
    { "id": "dsa-backtracking-combo-vs-perm-q1", "type": "mcq",
      "prompt": "What bug happens if you use a `start` index (the combination pattern) inside a permutation problem?",
      "options": [
        {"id": "a", "text": "It silently produces only one ordering per set of elements instead of all n! orderings"},
        {"id": "b", "text": "It crashes with an index out of range error"},
        {"id": "c", "text": "It produces every permutation, just in a different order than expected"},
        {"id": "d", "text": "Nothing changes; start-based and used-based loops are interchangeable"}
      ],
      "correct": "a",
      "explanation": "A start index only ever moves forward, so it can never revisit an earlier index to place it in a different position, which is exactly what generating distinct orderings requires." }
] }
```

### Subsets

[LeetCode 78 · Subsets](https://leetcode.com/problems/subsets/) · Backtracking · Generate all subsets

**Intuition:** Every element is either "in" or "out" of a given subset. Backtracking naturally lists all of them by recording the current path at every recursive call, not just at the leaves, since every prefix is itself a valid subset.

**Approach:** Standard combination-style loop starting at `start`, recording `path` at every node of the recursion tree, not only at the base case.

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
```javascript +
function subsets(nums) {
    const result = [];
    const path = [];

    function backtrack(start) {
        result.push([...path]);          // every node is a valid subset
        for (let i = start; i < nums.length; i++) {
            path.push(nums[i]);
            backtrack(i + 1);
            path.pop();
        }
    }

    backtrack(0);
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<List<Integer>> subsets(int[] nums) {
        List<List<Integer>> result = new ArrayList<>();
        Deque<Integer> path = new ArrayDeque<>();
        backtrack(nums, 0, path, result);
        return result;
    }

    private static void backtrack(int[] nums, int start, Deque<Integer> path, List<List<Integer>> result) {
        result.add(new ArrayList<>(path)); // every node is a valid subset
        for (int i = start; i < nums.length; i++) {
            path.addLast(nums[i]);
            backtrack(nums, i + 1, path, result);
            path.removeLast();
        }
    }

    public static void main(String[] args) {
        System.out.println(subsets(new int[] {1, 2, 3}));
    }
}
```

**Complexity:** O(n * 2^n) time (2^n subsets, O(n) to copy each), O(n) recursion depth excluding the output.

**Common mistakes:** appending `path` directly instead of `path[:]`, which stores a reference that later gets mutated and corrupts every subset already recorded; forgetting that every recursive call, not only the leaves, produces a valid answer here.

> **Remember:** Subsets records an answer at every single node, not just at the leaves, because every prefix is already a valid subset.

### Subsets II

[LeetCode 90 · Subsets II](https://leetcode.com/problems/subsets-ii/) · Backtracking · Handle duplicates

**Intuition:** The input may have duplicate values. Sort first, then at each recursion level, skip a candidate if it's equal to the previous candidate *at that same level*, not globally. That previous one already covered every subset this one would produce.

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
```javascript +
function subsetsWithDup(nums) {
    nums = [...nums].sort((a, b) => a - b);
    const result = [];
    const path = [];

    function backtrack(start) {
        result.push([...path]);
        for (let i = start; i < nums.length; i++) {
            if (i > start && nums[i] === nums[i - 1]) continue; // skip duplicate at this level
            path.push(nums[i]);
            backtrack(i + 1);
            path.pop();
        }
    }

    backtrack(0);
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<List<Integer>> subsetsWithDup(int[] nums) {
        Arrays.sort(nums);
        List<List<Integer>> result = new ArrayList<>();
        Deque<Integer> path = new ArrayDeque<>();
        backtrack(nums, 0, path, result);
        return result;
    }

    private static void backtrack(int[] nums, int start, Deque<Integer> path, List<List<Integer>> result) {
        result.add(new ArrayList<>(path));
        for (int i = start; i < nums.length; i++) {
            if (i > start && nums[i] == nums[i - 1]) continue; // skip duplicate at this level
            path.addLast(nums[i]);
            backtrack(nums, i + 1, path, result);
            path.removeLast();
        }
    }

    public static void main(String[] args) {
        System.out.println(subsetsWithDup(new int[] {1, 2, 2}));
    }
}
```

**Complexity:** O(n * 2^n) time worst case, O(n) recursion depth.

**Common mistakes:** skipping duplicates with a global `seen` set instead of the `i > start` same-level check. A global set wrongly blocks valid subsets that reuse a value at a *different* branch of the tree. Also, forgetting to sort first, which the same-level dedup depends on completely.

> **Remember:** skip a duplicate only if it's a repeat at the SAME level as the one right before it, not a repeat anywhere in the whole array.

### Combination Sum

[LeetCode 39 · Combination Sum](https://leetcode.com/problems/combination-sum/) · Backtracking · Unbounded knapsack

**Intuition:** The same number can be reused as many times as needed, so the recursive call passes `i` (not `i + 1`), to allow re-picking the current candidate.

**Approach:** Sort candidates for pruning. Track the `remaining` target, subtract as you go, prune when `remaining < 0`, record when `remaining == 0`.

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
```javascript +
function combinationSum(candidates, target) {
    candidates = [...candidates].sort((a, b) => a - b);
    const result = [];
    const path = [];

    function backtrack(start, remaining) {
        if (remaining === 0) {
            result.push([...path]);
            return;
        }
        for (let i = start; i < candidates.length; i++) {
            if (candidates[i] > remaining) break; // sorted, so nothing further can work either
            path.push(candidates[i]);
            backtrack(i, remaining - candidates[i]); // i, not i+1: reuse allowed
            path.pop();
        }
    }

    backtrack(0, target);
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<List<Integer>> combinationSum(int[] candidates, int target) {
        Arrays.sort(candidates);
        List<List<Integer>> result = new ArrayList<>();
        Deque<Integer> path = new ArrayDeque<>();
        backtrack(candidates, target, 0, path, result);
        return result;
    }

    private static void backtrack(int[] candidates, int remaining, int start, Deque<Integer> path, List<List<Integer>> result) {
        if (remaining == 0) {
            result.add(new ArrayList<>(path));
            return;
        }
        for (int i = start; i < candidates.length; i++) {
            if (candidates[i] > remaining) break; // sorted, so nothing further can work either
            path.addLast(candidates[i]);
            backtrack(candidates, remaining - candidates[i], i, path, result); // i, not i+1: reuse allowed
            path.removeLast();
        }
    }

    public static void main(String[] args) {
        System.out.println(combinationSum(new int[] {2, 3, 6, 7}, 7));
    }
}
```

**Complexity:** O(n^(target/min_candidate)) time worst case (exponential, bounded by the target), O(target / min_candidate) recursion depth.

**Common mistakes:** passing `i + 1` instead of `i`, the classic bug that silently turns "unbounded reuse" into "each number used at most once," which is actually a different problem (Combination Sum II). Also, forgetting to sort before relying on `break` as a pruning strategy.

> **Remember:** passing `i` instead of `i + 1` into the recursive call is what allows reusing the same number. That single character is the whole difference from "use once."

### Permutations

[LeetCode 46 · Permutations](https://leetcode.com/problems/permutations/) · Backtracking · Generate permutations

**Intuition:** Unlike combinations, order matters here, and every index can appear in every position, so the loop scans the full array each time, skipping only what's already placed in the current path.

**Approach:** Track a `used` boolean array (or set) instead of a `start` index, since permutations don't have an "already passed this index" idea; they have "already placed this value."

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
```javascript +
function permute(nums) {
    const result = [];
    const path = [];
    const used = new Array(nums.length).fill(false);

    function backtrack() {
        if (path.length === nums.length) {
            result.push([...path]);
            return;
        }
        for (let i = 0; i < nums.length; i++) {
            if (used[i]) continue;
            used[i] = true;
            path.push(nums[i]);
            backtrack();
            path.pop();
            used[i] = false;
        }
    }

    backtrack();
    return result;
}
```
```java +
import java.util.*;

public class Main {
    public static List<List<Integer>> permute(int[] nums) {
        List<List<Integer>> result = new ArrayList<>();
        Deque<Integer> path = new ArrayDeque<>();
        boolean[] used = new boolean[nums.length];
        backtrack(nums, used, path, result);
        return result;
    }

    private static void backtrack(int[] nums, boolean[] used, Deque<Integer> path, List<List<Integer>> result) {
        if (path.size() == nums.length) {
            result.add(new ArrayList<>(path));
            return;
        }
        for (int i = 0; i < nums.length; i++) {
            if (used[i]) continue;
            used[i] = true;
            path.addLast(nums[i]);
            backtrack(nums, used, path, result);
            path.removeLast();
            used[i] = false;
        }
    }

    public static void main(String[] args) {
        System.out.println(permute(new int[] {1, 2, 3}));
    }
}
```

**Complexity:** O(n * n!) time (n! permutations, O(n) to copy each), O(n) space for `used` plus recursion depth.

**Common mistakes:** using a `start` index like a combination problem, which produces only 1 ordering instead of n!. Also, forgetting to reset `used[i] = False` on backtrack, which corrupts sibling branches.

> **Remember:** permutations need a `used` set, not a `start` index, because any leftover value can go in any leftover position.

Notice where each problem records its answer follows directly from its own goal condition: Subsets records at every node because every prefix is valid, Combination Sum records only when `remaining == 0`, and Permutations records only once `path` reaches full length. Get the goal condition right, and the recording point falls out for free.
