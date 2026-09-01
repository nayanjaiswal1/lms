---
kind: quiz
id_key: interview-prep-45/coding-drill-week-3
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Week 3 Coding Drill — DP, Greedy & Bits"
position: 93
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
pass_percentage: 60
duration_minutes: 45
questions:
  - id_key: interview-prep-45/coding-drill-week-3/coin-change
    type: coding
    difficulty: advanced
    points: 20
    prompt: |
      **Coin Change** (LeetCode 322 — Day 15, Hard DP)

      Given coin denominations and a target amount, print the fewest coins needed
      to make the amount, or `-1` if impossible. Classic bottom-up DP:
      `dp[a] = 1 + min(dp[a - coin])` over all coins — O(amount × coins).

      **Input:** line 1 — space-separated coin values; line 2 — the amount.
      **Output:** the minimum coin count, or `-1`.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def coin_change(coins, amount):
            # Return the fewest coins to make amount, or -1 if impossible.
            raise NotImplementedError

        def main():
            lines = sys.stdin.read().split("\n")
            coins = list(map(int, lines[0].split()))
            amount = int(lines[1])
            print(coin_change(coins, amount))

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const coins = lines[0].split(/\s+/).map(Number);
        const amount = Number(lines[1]);

        function coinChange(coins, amount) {
          // Return the fewest coins to make amount, or -1 if impossible.
        }

        console.log(coinChange(coins, amount));
    test_cases:
      - stdin: "1 2 5\n11"
        expected: "3"
        weight: 1
      - stdin: "2\n3"
        expected: "-1"
        weight: 1
      - stdin: "1\n0"
        expected: "0"
        hidden: true
        weight: 1
      - stdin: "186 419 83 408\n6249"
        expected: "20"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-3/jump-game
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Jump Game** (LeetCode 55 — Day 18, Greedy)

      Each array element is your maximum jump length from that index, starting at
      index 0. Print `true` if the last index is reachable, else `false`. The
      greedy insight: track the furthest reachable index in one O(n) pass — no DP
      needed.

      **Input:** one line of space-separated non-negative integers.
      **Output:** `true` or `false`.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def can_jump(nums):
            # Return True when the last index is reachable from index 0.
            raise NotImplementedError

        def main():
            nums = list(map(int, sys.stdin.read().split()))
            print("true" if can_jump(nums) else "false")

        main()
      javascript: |
        const nums = require("fs").readFileSync(0, "utf8").trim().split(/\s+/).map(Number);

        function canJump(nums) {
          // Return true when the last index is reachable from index 0.
        }

        console.log(canJump(nums) ? "true" : "false");
    test_cases:
      - stdin: "2 3 1 1 4"
        expected: "true"
        weight: 1
      - stdin: "3 2 1 0 4"
        expected: "false"
        weight: 1
      - stdin: "0"
        expected: "true"
        hidden: true
        weight: 1
      - stdin: "1 0 1"
        expected: "false"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-3/single-number
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Single Number** (LeetCode 136 — Day 20, Bit Manipulation)

      Every element appears exactly twice except one — print the one that appears
      once. The bit trick: `a ^ a = 0` and XOR is commutative, so XOR-ing the whole
      array leaves only the single number. O(n) time, O(1) space — no hash map.

      **Input:** one line of space-separated integers.
      **Output:** the element that appears once.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def single_number(nums):
            # Return the element that appears exactly once (use XOR, not a dict).
            raise NotImplementedError

        def main():
            nums = list(map(int, sys.stdin.read().split()))
            print(single_number(nums))

        main()
      javascript: |
        const nums = require("fs").readFileSync(0, "utf8").trim().split(/\s+/).map(Number);

        function singleNumber(nums) {
          // Return the element that appears exactly once (use XOR, not a Map).
        }

        console.log(singleNumber(nums));
    test_cases:
      - stdin: "2 2 1"
        expected: "1"
        weight: 1
      - stdin: "4 1 2 1 2"
        expected: "4"
        weight: 1
      - stdin: "1"
        expected: "1"
        hidden: true
        weight: 1
      - stdin: "-3 5 -3"
        expected: "5"
        hidden: true
        weight: 1
---

Week 3 coding drill covers the three hardest muscles from this stretch: bottom-up DP
(Coin Change), the greedy-choice property (Jump Game), and XOR bit tricks (Single
Number). Starter code handles stdin/stdout, so just implement the marked function.
Pass 60% to continue.
