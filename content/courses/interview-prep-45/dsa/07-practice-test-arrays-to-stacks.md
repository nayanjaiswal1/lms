---
kind: quiz
id_key: interview-prep-45/test-dsa-1
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Practice Test: Arrays, Pointers, Windows, Search and Stacks"
position: 7
estimated_minutes: 76
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
pass_percentage: 70
duration_minutes: 76
questions:
  - id_key: interview-prep-45/quiz-week-1/q1
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What is the average and worst-case time complexity of a hash map lookup?"
    options:
      - text: "O(1) average, O(n) worst case"
        correct: true
      - text: "O(log n) average, O(n) worst case"
      - text: "O(1) average and worst case"
      - text: "O(n) average, O(n²) worst case"
    explanation: "Hash map lookups are O(1) on average, but collisions can degrade a single bucket to O(n) in the worst case."
  - id_key: interview-prep-45/quiz-week-1/q2
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What is the time complexity of the standard two-pointer solution to 3Sum?"
    options:
      - text: "O(n²)"
        correct: true
      - text: "O(n log n)"
      - text: "O(n³)"
      - text: "O(n)"
    explanation: "3Sum sorts the array (O(n log n)) then runs a two-pointer scan for each element, giving O(n²) overall."
  - id_key: interview-prep-45/quiz-week-1/q3
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "The sliding window technique typically reduces which complexity to which?"
    options:
      - text: "O(n²) to O(n)"
        correct: true
      - text: "O(n) to O(log n)"
      - text: "O(n³) to O(n²)"
      - text: "O(2ⁿ) to O(n²)"
    explanation: "Instead of rescanning every subarray, a sliding window moves each pointer forward at most n times, turning O(n²) scans into O(n)."
  - id_key: interview-prep-45/quiz-week-1/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A monotonic stack is the go-to pattern for which class of problems?"
    options:
      - text: "Next greater / next smaller element problems"
        correct: true
      - text: "Shortest path problems"
      - text: "Prefix-sum range queries"
      - text: "Cycle detection"
    explanation: "Keeping a stack in sorted order lets you resolve, in one pass, the nearest greater or smaller element for every item (for example Daily Temperatures, Largest Rectangle in Histogram)."
  - id_key: interview-prep-45/test-dsa-1/hash-load-factor
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Why does a hash table resize itself once its load factor gets too high?"
    options:
      - text: "A high load factor means longer chains or probe sequences, which drags lookups toward O(n)"
        correct: true
      - text: "Resizing is required to make keys hashable"
      - text: "It has nothing to do with performance, only memory usage"
      - text: "It only matters for open addressing, never for chaining"
    explanation: "As the load factor (size / capacity) climbs, buckets hold more entries (chaining) or probe sequences get longer (open addressing), both of which push lookups away from O(1)."
  - id_key: interview-prep-45/test-dsa-1/two-pointer-space
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Compared to a hash-map solution, what does a two-pointer solution typically trade away to get O(1) extra space?"
    options:
      - text: "It usually needs the input sorted first, and loses the original indices"
        correct: true
      - text: "It always runs slower overall"
      - text: "It cannot handle duplicate values"
      - text: "It only works on strings, not arrays"
    explanation: "Two pointers exploits sortedness to avoid extra memory, but that usually means sorting the input first (if it wasn't already) and no longer knowing each value's original index."
  - id_key: interview-prep-45/test-dsa-1/binary-search-midpoint
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In fixed-width integer languages, how do you compute a binary-search midpoint without risking overflow?"
    options:
      - text: "mid = low + (high - low) / 2"
        correct: true
      - text: "mid = (low + high) / 2, since it can never overflow"
      - text: "mid = high / 2 + low"
      - text: "Use floating point and round"
    explanation: "low + high can exceed the integer maximum when both are large. low + (high - low) / 2 keeps every intermediate value in range."
  - id_key: interview-prep-45/test-dsa-1/binary-search-template-choice
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A problem asks for the first index where a sorted array's value is at least some target, not whether the target exists. Which binary search template fits?"
    options:
      - text: "Boundary search: lo < hi, hi = mid on the keep branch"
        correct: true
      - text: "Exact-match search: lo <= hi, mid ± 1"
      - text: "Linear scan, since binary search cannot find boundaries"
      - text: "Depth-first search over the array"
    explanation: "\"First index where a condition holds\" is a boundary search, which converges lo and hi together instead of returning early on an exact match."
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
  - id_key: interview-prep-45/coding-drill-week-4/rotated-search
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Search in Rotated Sorted Array** (LeetCode 33)

      A sorted array was rotated at an unknown pivot. Print the index of the
      target, or `-1`. Modified binary search: at each step one half is fully
      sorted — check whether the target lies in that half, otherwise recurse into
      the other. O(log n), and use the overflow-safe midpoint from the Binary
      Search lesson.

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
---
This test covers arrays and hashing, two pointers, sliding window, binary search, and stacks. Four problems ask you to write working code; the rest are multiple choice. Pass 70% to move on.
