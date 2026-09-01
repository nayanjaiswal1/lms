---
kind: quiz
id_key: interview-prep-45/coding-drill-week-1
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Week 1 Coding Drill — Arrays & Hashing"
position: 91
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
pass_percentage: 60
duration_minutes: 45
questions:
  - id_key: interview-prep-45/coding-drill-week-1/two-sum
    type: coding
    difficulty: beginner
    points: 20
    prompt: |
      **Two Sum** (LeetCode 1)

      Given an array of integers `nums` and an integer `target`, return the indices of the
      two numbers that add up to `target`. Exactly one solution exists; you may not use the
      same element twice. Aim for O(n) time using a hash map of complements.

      **Input:** line 1 — space-separated integers; line 2 — the target.
      **Output:** the two indices in ascending order, space-separated (e.g. `0 1`).
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def two_sum(nums, target):
            # Return [i, j] with i < j such that nums[i] + nums[j] == target.
            raise NotImplementedError

        def main():
            lines = sys.stdin.read().split("\n")
            nums = list(map(int, lines[0].split()))
            target = int(lines[1])
            i, j = sorted(two_sum(nums, target))
            print(i, j)

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const nums = lines[0].split(/\s+/).map(Number);
        const target = Number(lines[1]);

        function twoSum(nums, target) {
          // Return [i, j] with i < j such that nums[i] + nums[j] === target.
        }

        const [i, j] = twoSum(nums, target).sort((a, b) => a - b);
        console.log(i + " " + j);
    test_cases:
      - stdin: "2 7 11 15\n9"
        expected: "0 1"
        weight: 1
      - stdin: "3 2 4\n6"
        expected: "1 2"
        weight: 1
      - stdin: "3 3\n6"
        expected: "0 1"
        hidden: true
        weight: 1
      - stdin: "-1 -2 -3 -4 -5\n-8"
        expected: "2 4"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-1/valid-anagram
    type: coding
    difficulty: beginner
    points: 20
    prompt: |
      **Valid Anagram** (LeetCode 242)

      Given two strings `s` and `t`, print `true` if `t` is an anagram of `s`, otherwise
      `false`. Use frequency counting — O(n) time, O(1) space for a fixed alphabet.

      **Input:** line 1 — string `s`; line 2 — string `t`.
      **Output:** `true` or `false`.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def is_anagram(s, t):
            # Return True when t is an anagram of s.
            raise NotImplementedError

        def main():
            lines = sys.stdin.read().split("\n")
            s, t = lines[0].strip(), lines[1].strip()
            print("true" if is_anagram(s, t) else "false")

        main()
      javascript: |
        const lines = require("fs").readFileSync(0, "utf8").trim().split("\n");
        const s = lines[0];
        const t = lines[1];

        function isAnagram(s, t) {
          // Return true when t is an anagram of s.
        }

        console.log(isAnagram(s, t) ? "true" : "false");
    test_cases:
      - stdin: "anagram\nnagaram"
        expected: "true"
        weight: 1
      - stdin: "rat\ncar"
        expected: "false"
        weight: 1
      - stdin: "aacc\nccac"
        expected: "false"
        hidden: true
        weight: 1
  - id_key: interview-prep-45/coding-drill-week-1/contains-duplicate
    type: coding
    difficulty: beginner
    points: 20
    prompt: |
      **Contains Duplicate** (LeetCode 217)

      Given an array of integers, print `true` if any value appears at least twice,
      otherwise `false`. A hash set gives O(n) time.

      **Input:** one line of space-separated integers.
      **Output:** `true` or `false`.
    languages:
      - python
      - javascript
    starter_code:
      python: |
        import sys

        def contains_duplicate(nums):
            # Return True when any value appears at least twice.
            raise NotImplementedError

        def main():
            nums = list(map(int, sys.stdin.read().split()))
            print("true" if contains_duplicate(nums) else "false")

        main()
      javascript: |
        const nums = require("fs").readFileSync(0, "utf8").trim().split(/\s+/).map(Number);

        function containsDuplicate(nums) {
          // Return true when any value appears at least twice.
        }

        console.log(containsDuplicate(nums) ? "true" : "false");
    test_cases:
      - stdin: "1 2 3 1"
        expected: "true"
        weight: 1
      - stdin: "1 2 3 4"
        expected: "false"
        weight: 1
      - stdin: "7"
        expected: "false"
        hidden: true
        weight: 1
---

Day 1 coding drill: solve the three Arrays & Hashing problems from the roadmap in the
in-browser editor. Each problem reads from stdin and prints to stdout; the starter code
already handles I/O, so implement only the marked function. Pass at least 60% to continue.
