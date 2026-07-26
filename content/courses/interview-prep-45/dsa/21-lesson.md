---
kind: lesson
id_key: interview-prep-45/day-21
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Checkpoint 3"
position: 21
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Week 3 covered the hardest algorithmic material in this course: hard DP, backtracking, greedy, DSU, and bit manipulation. Today is consolidation, not new material — the goal is converting "I solved it once with hints" into "I can re-derive it cold," because only the second state survives interview pressure.

## What week 3 covered

| Day | Topic | Problems | Core pattern |
|-----|-------|----------|--------------|
| 15 | DP — Hard | 4 | 2D string-matching DP, rolling-array space optimization |
| 16 | Backtracking | 4 | Choice/constraints/goal, combinations vs. permutations |
| 17 | Backtracking — Advanced | 4 | Constraint satisfaction, three-set N-Queens trick |
| 18 | Greedy | 4 | Greedy choice property, exchange arguments |
| 19 | Union Find / DSU | 4 | Path compression + union by rank, cycle detection |
| 20 | Bit Manipulation | 4 | XOR cancellation, `n & (n-1)` |

Running total through Day 20: **66 LeetCode problems solved**.

## Self-test — can you re-derive these cold?

Work through each without notes. Stalling more than two minutes on any item puts that topic on today's re-solve list.

**DP Hard:**
- Write the wildcard-matching transition for `p[j-1] == '*'` in one line. (Answer: `dp[i][j] = dp[i][j-1] or dp[i-1][j]` — star matches zero chars, or consumes one more.)
- Why is O(n) space possible for a 2D string DP? (Each row only reads the row directly above it.)

**Backtracking:**
- What single line makes backtracking "backtrack"? (The undo after the recursive call: `path.pop()` / `used[i] = False`.)
- Same-level duplicate skip condition in Subsets II? (`i > start and nums[i] == nums[i-1]`, on a sorted array.)
- Which three sets does N-Queens maintain, and why do `row - col` / `row + col` work? (Columns plus both diagonals; each expression is constant along its diagonal.)

**Greedy:**
- State the greedy choice for Jump Game II. (Track the farthest reach within the current level; count a jump only when forced past the level boundary.)
- Give a counterexample where "largest coin first" fails. (Coins `[1,3,4]`, target 6: greedy gives 4+1+1 = 3 coins, optimal is 3+3 = 2.)

**DSU:**
- Write `find` with path compression from memory (three lines).
- Why is Graph Valid Tree not just a cycle check? (A forest is acyclic but disconnected — the `n - 1` edge-count check rules that out.)

**Bit manipulation:**
- What does `n & (n - 1)` do, and which two problems does it solve? (Clears the lowest set bit; popcount and power-of-2 check.)
- Why does XOR find the single unpaired number? (`a ^ a = 0`, `a ^ 0 = a`, order-independent.)

## Re-solve protocol

For each problem you re-solve today:

1. Read only the problem statement — no notes, no previous solution.
2. State the approach out loud (or write it in two sentences) *before* coding. If you can't, re-study that day's lesson first, then return.
3. Code it completely; run it against the examples plus one edge case you invent yourself.
4. Compare against the reference solution. Any *structural* difference (not style) means schedule another re-solve in 2 days.

Priority order (weak areas first, per the roadmap):

1. **DP Hard** — Wildcard Matching (LeetCode 44) with the O(n)-space rolling array; Regular Expression Matching (LeetCode 10) if time allows.
2. **Backtracking** — N-Queens (LeetCode 51) and Subsets II (LeetCode 90); together they cover the constraint-set trick and duplicate handling.
3. If both go cleanly: one quick confirmation each from Greedy (Task Scheduler), DSU (Graph Valid Tree), and Bits (Missing Number).

## Key takeaways

- Re-solving without notes is the only reliable retention test — recognition is not recall.
- The week's five topics share one meta-skill: identifying *which* tool a fresh problem calls for is worth more than depth in any single tool.
- DP Hard and Backtracking are the designated weak areas — they get today's first and largest time blocks.
- Structural differences from a reference solution signal a real gap; re-solve those problems again in 2 days.
- At 66 problems, most new mediums should map onto a pattern you already know — practice making that mapping explicit before coding.
