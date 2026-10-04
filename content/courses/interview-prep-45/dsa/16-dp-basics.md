---
kind: lesson
id_key: interview-prep-45/day-12
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Dynamic Programming Basics"
position: 16
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---

Picture splitting a big food bill among five friends who keep re-adding the same subtotals by hand, again and again, every time someone asks "wait, how much do I owe?" That's wasted work: the subtotal for the first three people never changes, so write it down once and reuse it. Dynamic programming (DP) is that idea turned into a technique: solve small pieces of a problem once, save the answers, and build the big answer out of the pieces you already solved. It trips up more candidates than any other topic, not because the code is hard, but because finding the right "piece" to save is hard. Get that right and the code almost writes itself.

## Recursion vs memoization vs tabulation

**Plain recursion** re-solves the same subproblem again and again whenever subproblems overlap. That repeated work is what makes a naive recursive solution slow, often exponentially slow.

```python
def fib_naive(n):
    if n <= 1:
        return n
    return fib_naive(n - 1) + fib_naive(n - 2)
# fib_naive(5) recomputes fib_naive(3) twice, fib_naive(2) three times, etc.
# Time: O(2^n)
```
```javascript +
function fibNaive(n) {
    if (n <= 1) return n;
    return fibNaive(n - 1) + fibNaive(n - 2);
}
// fibNaive(5) recomputes fibNaive(3) twice, fibNaive(2) three times, etc.
// Time: O(2^n)
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(fibNaive(10));
    }

    static int fibNaive(int n) {
        if (n <= 1) return n;
        return fibNaive(n - 1) + fibNaive(n - 2);
    }
    // fibNaive(5) recomputes fibNaive(3) twice, fibNaive(2) three times, etc.
    // Time: O(2^n)
}
```

**Memoization** (top-down DP) keeps the same recursive calls, but writes each answer down in a cache the first time it's computed. The next time the same question comes up, read the cache instead of recomputing.

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
```javascript +
const fibMemoCache = new Map();

function fibMemo(n) {
    if (n <= 1) return n;
    if (fibMemoCache.has(n)) return fibMemoCache.get(n);
    const result = fibMemo(n - 1) + fibMemo(n - 2);
    fibMemoCache.set(n, result);
    return result;
}
// Time: O(n), Space: O(n) for cache + O(n) recursion stack
```
```java +
import java.util.*;

public class Main {
    static final Map<Integer, Integer> cache = new HashMap<>();

    public static void main(String[] args) {
        System.out.println(fibMemo(30));
    }

    static int fibMemo(int n) {
        if (n <= 1) return n;
        if (cache.containsKey(n)) return cache.get(n);
        int result = fibMemo(n - 1) + fibMemo(n - 2);
        cache.put(n, result);
        return result;
    }
}
```

**Tabulation** (bottom-up DP) drops recursion entirely. Instead of starting at the top and working down, you start at the smallest answers and build up, filling a table step by step, the way you'd fill in a spreadsheet row by row.

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
```javascript +
function fibTab(n) {
    if (n <= 1) return n;
    const dp = new Array(n + 1).fill(0);
    dp[1] = 1;
    for (let i = 2; i <= n; i++) {
        dp[i] = dp[i - 1] + dp[i - 2];
    }
    return dp[n];
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(fibTab(10));
    }

    static int fibTab(int n) {
        if (n <= 1) return n;
        int[] dp = new int[n + 1];
        dp[1] = 1;
        for (int i = 2; i <= n; i++) {
            dp[i] = dp[i - 1] + dp[i - 2];
        }
        return dp[n];
    }
}
```

| | Recursion | Memoization | Tabulation |
|---|---|---|---|
| Structure | Top-down, natural to write | Top-down, with a cache | Bottom-up, a loop |
| Time when subproblems overlap | Exponential | Proportional to number of states | Proportional to number of states |
| Risk of crashing on deep input | High (deep recursion) | High | None |
| Best one to write first | Yes, to find the recurrence | Add a cache once recursion is correct | Convert once base cases and the rule are locked |
| Can you shrink the memory used? | Not really | Cache grows with the state space | Often shrinks to a couple of variables |

**How to use this in an interview:** write the plain recursive version first, even just in your head, to nail down the rule connecting a value to smaller ones. Add a cache to show you understand why the naive version was slow. Then offer the loop version, and shrinking the memory, as the polish. Walking through that progression out loud is itself what shows an interviewer you understand DP, not just that you memorized a template.

> **Remember:** recursion re-solves, memoization remembers while going down, tabulation builds while going up. Same answer, three different amounts of wasted work.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-basics-recursion-memo-tab-q1", "type": "mcq",
      "prompt": "Why is plain recursive Fibonacci exponential time, while the memoized version is linear time?",
      "options": [
        {"id": "a", "text": "Plain recursion recomputes the same subproblem many times; memoization caches each subproblem's answer so it's computed only once"},
        {"id": "b", "text": "Memoization uses a different, faster addition operator"},
        {"id": "c", "text": "Plain recursion is only slow in Python, not in other languages"},
        {"id": "d", "text": "Tabulation and memoization always produce different answers"}
      ],
      "correct": "a",
      "explanation": "Without a cache, fib(5) re-derives fib(3) and fib(2) from scratch every time they're needed. A cache means each distinct subproblem is solved exactly once." }
] }
```

## State definition

The "state" is the smallest set of facts that fully answers "what's the best outcome from here?" Getting this wrong is the single most common way candidates get stuck on DP.

Ask yourself: **what changes between one recursive call and the next, and what do I actually need to know to answer the question at this point?**

- Climbing Stairs: the state is the current step `i`. `dp[i]` means "number of ways to reach step `i`."
- House Robber: the state is the current house index `i`. `dp[i]` means "max money you can rob from houses `0` through `i`."
- Problems comparing two strings (later in this course): the state is a pair `(i, j)`, your position in *each* string.

A useful test: if two different state definitions give different answers for what should be the same subproblem, the state is incomplete. You're missing a piece of information, often a yes/no flag like "have I already used my one free skip?"

> **Remember:** the state is the exact question you'd have to text a friend to get back the right number. If the question is incomplete, the answer will be too.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-basics-state-q1", "type": "mcq",
      "prompt": "What's the sign that a DP state definition is missing information?",
      "options": [
        {"id": "a", "text": "Two different paths that should reach the same subproblem give different answers under that state"},
        {"id": "b", "text": "The code runs slower than expected"},
        {"id": "c", "text": "The base case is set to zero"},
        {"id": "d", "text": "The array has more than one dimension"}
      ],
      "correct": "a",
      "explanation": "If a state definition were complete, every path that lands on the 'same' state should get the same answer. A mismatch means an extra fact (like a used/unused flag) needs to be part of the state." }
] }
```

## Base cases and transitions

Every DP recurrence has exactly two parts:

1. **Base case(s):** the smallest subproblems, answered directly with no recursion needed (for example, `dp[0] = 1`, `dp[1] = 1`).
2. **Transition:** the rule for building `dp[i]` out of smaller, already-solved states (for example, `dp[i] = dp[i-1] + dp[i-2]`).

Get the base case wrong, and every value built on top of it is wrong too, even if the transition rule is perfect. Always check your base cases against the smallest one or two real examples by hand before you write any code.

> **Remember:** a wrong base case poisons the whole table. Check it by hand first, on paper, before typing anything.

```knowledge-check
{ "questions": [
    { "id": "dsa-dp-basics-base-transition-q1", "type": "mcq",
      "prompt": "Why does a wrong base case matter more in DP than a small bug elsewhere in the recurrence?",
      "options": [
        {"id": "a", "text": "Every later value in the table is built on top of the base case, so an error there propagates through the whole table"},
        {"id": "b", "text": "Base cases are checked separately by the compiler"},
        {"id": "c", "text": "It only matters for problems with two-dimensional tables"},
        {"id": "d", "text": "A wrong base case only affects the final answer, not any intermediate ones"}
      ],
      "correct": "a",
      "explanation": "dp[i] depends on dp[i-1] and dp[i-2], which depend on the base cases. A wrong dp[0] or dp[1] corrupts every downstream value." }
] }
```

### Climbing Stairs

[LeetCode 70](https://leetcode.com/problems/climbing-stairs/), DP, Basic

**Intuition:** To reach step `n`, your last move was either a 1-step from `n-1` or a 2-step from `n-2`. So the number of ways to reach `n` is the sum of the ways to reach those two prior steps. This is the Fibonacci recurrence in disguise.

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
```javascript +
function climbStairs(n) {
    if (n <= 1) return 1;
    let prev2 = 1, prev1 = 1;  // dp[0], dp[1]
    for (let i = 2; i <= n; i++) {
        [prev2, prev1] = [prev1, prev2 + prev1];
    }
    return prev1;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(climbStairs(5));
    }

    static int climbStairs(int n) {
        if (n <= 1) return 1;
        int prev2 = 1, prev1 = 1;  // dp[0], dp[1]
        for (int i = 2; i <= n; i++) {
            int next = prev2 + prev1;
            prev2 = prev1;
            prev1 = next;
        }
        return prev1;
    }
}
```

**Worked example:** for `n = 5`, the ways build up as `1, 1, 2, 3, 5, 8`, so `dp[5] = 8`.

**Complexity:** Time O(n), space O(1). This is a memory shrink in action: since `dp[i]` only needs the two previous values, there's no need to keep the whole array.

**Common mistakes:** getting the base case off by one; `dp[0]` should be 1, not 0, since there's exactly one way to be at the ground with zero steps taken (do nothing). Using plain unmemoized recursion here gives O(2^n) for no reason.

> **Remember:** Climbing Stairs is Fibonacci with a costume on. Spot the "last move was one of two options" shape and the recurrence follows.

### Min Cost Climbing Stairs

[LeetCode 746](https://leetcode.com/problems/min-cost-climbing-stairs/), DP, Basic

**Intuition:** You can start from step 0 or step 1 for free, and every step you land on costs `cost[i]` to leave. Minimize the total cost of getting past the top. `dp[i]` = minimum cost to reach step `i`.

**Approach:** `dp[i] = min(dp[i-1] + cost[i-1], dp[i-2] + cost[i-2])`. Reaching step `i` means paying to leave whichever of the two prior steps you came from.

```python
def minCostClimbingStairs(cost: list[int]) -> int:
    n = len(cost)
    prev2, prev1 = 0, 0  # dp[0] = 0, dp[1] = 0 (both are free starting points)
    for i in range(2, n + 1):
        prev2, prev1 = prev1, min(prev1 + cost[i - 1], prev2 + cost[i - 2])
    return prev1
```
```javascript +
function minCostClimbingStairs(cost) {
    const n = cost.length;
    let prev2 = 0, prev1 = 0;  // dp[0] = 0, dp[1] = 0 (both free starting points)
    for (let i = 2; i <= n; i++) {
        [prev2, prev1] = [prev1, Math.min(prev1 + cost[i - 1], prev2 + cost[i - 2])];
    }
    return prev1;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] cost = {10, 15, 20};
        System.out.println(minCostClimbingStairs(cost));
    }

    static int minCostClimbingStairs(int[] cost) {
        int n = cost.length;
        int prev2 = 0, prev1 = 0;  // dp[0] = 0, dp[1] = 0 (both free starting points)
        for (int i = 2; i <= n; i++) {
            int next = Math.min(prev1 + cost[i - 1], prev2 + cost[i - 2]);
            prev2 = prev1;
            prev1 = next;
        }
        return prev1;
    }
}
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** mixing up "cost to reach step i" with "cost of step i." The cost is paid when you leave a step, not when you land on it, and that shifts the indices in the transition. Also, forgetting the top is one step past the last index, `n`, not `len(cost) - 1`.

> **Remember:** the cost is a toll you pay leaving a step, not an entry fee. That one detail decides which index goes where in the formula.

### House Robber

[LeetCode 198](https://leetcode.com/problems/house-robber/), DP, State selection

**Intuition:** At each house, you either rob it (and skip the previous one, since two adjacent houses can't both be robbed) or skip it. `dp[i]` = the most money you can rob from the first `i` houses.

**Approach:** `dp[i] = max(dp[i-1], dp[i-2] + nums[i])`. Either skip house `i` and carry forward `dp[i-1]`, or rob it: `nums[i]` plus the best result from two houses back, since the one right before it is now off-limits.

```python
def rob(nums: list[int]) -> int:
    prev2, prev1 = 0, 0  # dp[-1] = 0 (no houses), dp[0] before loop starts
    for num in nums:
        prev2, prev1 = prev1, max(prev1, prev2 + num)
    return prev1
```
```javascript +
function rob(nums) {
    let prev2 = 0, prev1 = 0;  // dp[-1] = 0 (no houses), dp[0] before loop starts
    for (const num of nums) {
        [prev2, prev1] = [prev1, Math.max(prev1, prev2 + num)];
    }
    return prev1;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {2, 7, 9, 3, 1};
        System.out.println(rob(nums));
    }

    static int rob(int[] nums) {
        int prev2 = 0, prev1 = 0;  // dp[-1] = 0 (no houses), dp[0] before loop starts
        for (int num : nums) {
            int next = Math.max(prev1, prev2 + num);
            prev2 = prev1;
            prev1 = next;
        }
        return prev1;
    }
}
```

**Complexity:** Time O(n), space O(1).

**Common mistakes:** trying to track *which* houses were robbed instead of just the best total. The problem only asks for the amount, so the state is simpler than it looks at first. Also, confusing this with a greedy "always take the bigger neighbor" rule, which is wrong: DP correctly looks ahead through the recurrence, greedy doesn't.

> **Remember:** at every house you make one binary choice, rob it or skip it, and `dp[i]` remembers the best answer so far either way.

### House Robber II

[LeetCode 213](https://leetcode.com/problems/house-robber-ii/), DP, Circular array

**Intuition:** The houses sit in a circle, so house 0 and house `n-1` are now neighbors too, and you can't rob both. Split into two cases: rob from every house except the last, or rob from every house except the first. The answer is the better of the two, each solved with plain House Robber.

**Approach:** Run the House Robber I logic twice, once on `nums[0:n-1]` and once on `nums[1:n]`, and take the max. Handle `n == 1` as its own case, since a single house has no circle conflict at all.

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
```javascript +
function robII(nums) {
    if (nums.length === 1) return nums[0];

    function robLinear(houses) {
        let prev2 = 0, prev1 = 0;
        for (const num of houses) {
            [prev2, prev1] = [prev1, Math.max(prev1, prev2 + num)];
        }
        return prev1;
    }

    return Math.max(robLinear(nums.slice(0, -1)), robLinear(nums.slice(1)));
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int[] nums = {2, 3, 2};
        System.out.println(robII(nums));
    }

    static int robII(int[] nums) {
        if (nums.length == 1) return nums[0];
        return Math.max(
            robLinear(Arrays.copyOfRange(nums, 0, nums.length - 1)),
            robLinear(Arrays.copyOfRange(nums, 1, nums.length))
        );
    }

    static int robLinear(int[] houses) {
        int prev2 = 0, prev1 = 0;
        for (int num : houses) {
            int next = Math.max(prev1, prev2 + num);
            prev2 = prev1;
            prev1 = next;
        }
        return prev1;
    }
}
```

**Complexity:** Time O(n) across two linear passes, space O(n) for the slices, or O(1) extra if you pass index ranges instead of slicing.

**Common mistakes:** forgetting the `n == 1` case. Slicing `nums[:-1]` and `nums[1:]` both produce empty lists when `n == 1`, which silently returns 0 instead of `nums[0]`. Also, trying to solve the circular case directly in one pass instead of breaking it into two linear subproblems; that reduction to plain House Robber is the entire trick.

> **Remember:** a circle is just two lines in disguise. Solve "exclude the last house" and "exclude the first house" separately and take the better one.
