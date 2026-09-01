---
kind: quiz
id_key: interview-prep-45/coding-drill-week-4
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Week 4 Coding Drill — Intervals, Search & Matrix"
position: 94
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
pass_percentage: 60
duration_minutes: 45
questions:
  - id_key: interview-prep-45/coding-drill-week-4/merge-intervals
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Merge Intervals** (LeetCode 56 — Day 24, Intervals)

      Merge all overlapping intervals and print the result. The week's core
      interval move: sort by start, then one linear pass — extend the last merged
      interval when `current.start <= prev.end`, otherwise start a new one.

      **Input:** one interval per line as `start end`.
      **Output:** the merged intervals, one per line as `start end`, sorted by start.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def merge(intervals):
            # Return the merged intervals sorted by start.
            raise NotImplementedError

        def main():
            intervals = [list(map(int, line.split()))
                         for line in sys.stdin.read().split("\n") if line.strip()]
            for start, end in merge(intervals):
                print(start, end)

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const intervals = lines.map((l) => l.split(/\s+/).map(Number));

        function merge(intervals) {
          // Return the merged intervals sorted by start.
        }

        console.log(merge(intervals).map(([s, e]) => `${s} ${e}`).join("\n"));
    test_cases:
      - stdin: "1 3\n2 6\n8 10\n15 18"
        expected: "1 6\n8 10\n15 18"
        weight: 1
      - stdin: "1 4\n4 5"
        expected: "1 5"
        weight: 1
      - stdin: "5 7\n1 3"
        expected: "1 3\n5 7"
        hidden: true
        weight: 1
      - stdin: "1 4\n2 3"
        expected: "1 4"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-4/rotated-search
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Search in Rotated Sorted Array** (LeetCode 33 — Day 25, Binary Search)

      A sorted array was rotated at an unknown pivot. Print the index of the
      target, or `-1`. Modified binary search: at each step one half is fully
      sorted — check whether the target lies in that half, otherwise recurse into
      the other. O(log n), and use the overflow-safe midpoint from the quiz.

      **Input:** line 1 — space-separated distinct integers; line 2 — the target.
      **Output:** the target's index, or `-1`.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def search(nums, target):
            # Return the index of target in the rotated sorted array, or -1.
            raise NotImplementedError

        def main():
            lines = sys.stdin.read().split("\n")
            nums = list(map(int, lines[0].split()))
            target = int(lines[1])
            print(search(nums, target))

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const nums = lines[0].split(/\s+/).map(Number);
        const target = Number(lines[1]);

        function search(nums, target) {
          // Return the index of target in the rotated sorted array, or -1.
        }

        console.log(search(nums, target));
    test_cases:
      - stdin: "4 5 6 7 0 1 2\n0"
        expected: "4"
        weight: 1
      - stdin: "4 5 6 7 0 1 2\n3"
        expected: "-1"
        weight: 1
      - stdin: "1\n1"
        expected: "0"
        hidden: true
        weight: 1
      - stdin: "5 1 3\n5"
        expected: "0"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-4/rotate-image
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Rotate Image** (LeetCode 48 — Day 26, Matrix)

      Rotate an n×n matrix 90° clockwise in place and print it. The trick from
      the checkpoint quiz, now in code: transpose (swap `m[i][j]` with `m[j][i]`
      for `j > i`), then reverse each row — O(1) extra space.

      **Input:** n lines of n space-separated integers.
      **Output:** the rotated matrix, one row per line, space-separated.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def rotate(matrix):
            # Rotate the n x n matrix 90 degrees clockwise in place.
            raise NotImplementedError

        def main():
            matrix = [list(map(int, line.split()))
                      for line in sys.stdin.read().split("\n") if line.strip()]
            rotate(matrix)
            for row in matrix:
                print(" ".join(map(str, row)))

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const matrix = lines.map((l) => l.split(/\s+/).map(Number));

        function rotate(matrix) {
          // Rotate the n x n matrix 90 degrees clockwise in place.
        }

        rotate(matrix);
        console.log(matrix.map((row) => row.join(" ")).join("\n"));
    test_cases:
      - stdin: "1 2 3\n4 5 6\n7 8 9"
        expected: "7 4 1\n8 5 2\n9 6 3"
        weight: 1
      - stdin: "1 2\n3 4"
        expected: "3 1\n4 2"
        weight: 1
      - stdin: "1"
        expected: "1"
        hidden: true
        weight: 1
      - stdin: "5 1 9 11\n2 4 8 10\n13 3 6 7\n15 14 12 16"
        expected: "15 13 2 5\n14 3 4 1\n12 6 8 9\n16 7 10 11"
        hidden: true
        weight: 1
---

Week 4 coding drill covers the breadth week's three sharpest tools: interval merging
(sort by start, then a linear pass), binary search on a rotated array (pick the
sorted half), and in-place matrix rotation (transpose, then reverse rows). Starter
code handles stdin/stdout, so just implement the marked function. Pass 60% to
continue.
