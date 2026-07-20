---
kind: quiz
id_key: interview-prep-45/coding-drill-week-2
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Week 2 Coding Drill — Graphs, Heaps & DP Basics"
position: 92
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
pass_percentage: 60
duration_minutes: 45
questions:
  - id_key: interview-prep-45/coding-drill-week-2/climbing-stairs
    type: coding
    difficulty: beginner
    points: 20
    prompt: |
      **Climbing Stairs** (LeetCode 70 — Day 12, DP Basics)

      You are climbing a staircase with `n` steps. Each move climbs 1 or 2 steps.
      Print the number of distinct ways to reach the top. This is Fibonacci in
      disguise — solve it bottom-up in O(n) time, O(1) space.

      **Input:** a single integer `n` (1 ≤ n ≤ 45).
      **Output:** the number of distinct ways.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def climb_stairs(n):
            # Return the number of distinct ways to climb n steps (1 or 2 at a time).
            raise NotImplementedError

        def main():
            n = int(sys.stdin.read().strip())
            print(climb_stairs(n))

        main()
      javascript: |
        const n = Number(require("fs").readFileSync(0, "utf8").trim());

        function climbStairs(n) {
          // Return the number of distinct ways to climb n steps (1 or 2 at a time).
        }

        console.log(climbStairs(n));
    test_cases:
      - stdin: "2"
        expected: "2"
        weight: 1
      - stdin: "3"
        expected: "3"
        weight: 1
      - stdin: "10"
        expected: "89"
        hidden: true
        weight: 1
      - stdin: "45"
        expected: "1836311903"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-2/kth-largest
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Kth Largest Element in an Array** (LeetCode 215 — Day 11, Heaps)

      Given an array of integers and an integer `k`, print the k-th largest element
      (in sorted order, not the k-th distinct element). The interview-grade answer
      keeps a min-heap of size k — O(n log k) time.

      **Input:** line 1 — space-separated integers; line 2 — `k`.
      **Output:** the k-th largest element.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys
        import heapq

        def kth_largest(nums, k):
            # Return the k-th largest element. heapq is a min-heap — keep it at size k.
            raise NotImplementedError

        def main():
            lines = sys.stdin.read().split("\n")
            nums = list(map(int, lines[0].split()))
            k = int(lines[1])
            print(kth_largest(nums, k))

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const nums = lines[0].split(/\s+/).map(Number);
        const k = Number(lines[1]);

        function kthLargest(nums, k) {
          // Return the k-th largest element. (JS has no built-in heap — sorting
          // is accepted here; mention the O(n log k) heap approach in interviews.)
        }

        console.log(kthLargest(nums, k));
    test_cases:
      - stdin: "3 2 1 5 6 4\n2"
        expected: "5"
        weight: 1
      - stdin: "3 2 3 1 2 4 5 5 6\n4"
        expected: "4"
        weight: 1
      - stdin: "7\n1"
        expected: "7"
        hidden: true
        weight: 1
      - stdin: "-1 -2 -3\n3"
        expected: "-3"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-2/number-of-islands
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Number of Islands** (LeetCode 200 — Day 9, Graph BFS/DFS)

      Given a grid of `1` (land) and `0` (water), print the number of islands.
      An island is a group of 1s connected horizontally or vertically. Flood-fill
      each unvisited land cell with DFS/BFS — O(rows × cols).

      **Input:** one line per grid row, each a string of 0s and 1s (e.g. `11000`).
      **Output:** the island count.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def num_islands(grid):
            # grid is a list of lists of "0"/"1" characters. Return the island count.
            raise NotImplementedError

        def main():
            rows = [line.strip() for line in sys.stdin.read().split("\n") if line.strip()]
            grid = [list(row) for row in rows]
            print(num_islands(grid))

        main()
      javascript: |
        const rows = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const grid = rows.map((r) => r.trim().split(""));

        function numIslands(grid) {
          // grid is an array of arrays of "0"/"1" characters. Return the island count.
        }

        console.log(numIslands(grid));
    test_cases:
      - stdin: "11110\n11010\n11000\n00000"
        expected: "1"
        weight: 1
      - stdin: "11000\n11000\n00100\n00011"
        expected: "3"
        weight: 1
      - stdin: "1"
        expected: "1"
        hidden: true
        weight: 1
      - stdin: "101\n010\n101"
        expected: "5"
        hidden: true
        weight: 1
---

Week 2 coding drill: one problem each from the week's pillars — DP basics (Climbing
Stairs), heaps (Kth Largest), and graph traversal (Number of Islands). The starter code
handles stdin/stdout; implement only the marked function. Pass at least 60% to continue.
