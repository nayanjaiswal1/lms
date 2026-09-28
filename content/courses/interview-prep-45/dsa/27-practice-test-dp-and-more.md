---
kind: quiz
id_key: interview-prep-45/test-dsa-3
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Practice Test: DP, Backtracking, Greedy and More"
position: 27
estimated_minutes: 130
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
    - final-prep/42-lesson.md
    - dsa/21-lesson.md
pass_percentage: 70
duration_minutes: 130
questions:
  - id_key: interview-prep-45/quiz-week-2/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the difference between top-down (memoization) and bottom-up (tabulation) dynamic programming?"
    options:
      - text: "Top-down recurses from the goal, caching results; bottom-up iterates from base cases, filling a table"
        correct: true
      - text: "Top-down is always faster than bottom-up"
      - text: "Bottom-up uses recursion; top-down uses loops"
      - text: "They differ only in space complexity, never in structure"
    explanation: "Both compute the same states. Memoization starts at the target and recurses down with a cache; tabulation starts at base cases and iterates up: same asymptotic complexity, different mechanics."
  - id_key: interview-prep-45/quiz-week-3/q1
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the worst-case time complexity of generating all subsets via backtracking?"
    options:
      - text: "O(n · 2ⁿ)"
        correct: true
      - text: "O(n²)"
      - text: "O(n log n)"
      - text: "O(2ⁿ / n)"
    explanation: "There are 2ⁿ subsets, and copying each one costs up to O(n): exponential output means exponential time, which is why pruning matters so much in backtracking."
  - id_key: interview-prep-45/quiz-week-3/q2
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In the classic N-Queens backtracking solution, which three constraint sets are tracked?"
    options:
      - text: "Columns, positive diagonals (r+c), and negative diagonals (r-c)"
        correct: true
      - text: "Rows, columns, and knight-move squares"
      - text: "Rows, corners, and edges"
      - text: "Columns only; diagonals are checked by rescanning the board"
    explanation: "Placing row by row makes row conflicts impossible; O(1) membership checks on the column set and the two diagonal sets (keyed by r+c and r-c) prune invalid placements instantly."
  - id_key: interview-prep-45/quiz-week-3/q3
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "When is a greedy algorithm guaranteed to produce the optimal answer?"
    options:
      - text: "When the problem has the greedy-choice property: each local optimum extends to a global optimum"
        correct: true
      - text: "Whenever the input is sorted"
      - text: "For every optimization problem"
      - text: "Only when combined with memoization"
    explanation: "Greedy works only if a locally best choice never needs to be undone later (for example Jump Game, interval scheduling). When choices interact, like 0/1 knapsack, you need DP instead."
  - id_key: interview-prep-45/quiz-week-3/q5
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Which XOR properties make Single Number solvable in O(n) time and O(1) space?"
    options:
      - text: "a ⊕ a = 0 and a ⊕ 0 = a"
        correct: true
      - text: "a ⊕ b = a + b"
      - text: "XOR is not commutative, which isolates the answer"
      - text: "a ⊕ a = a"
    explanation: "XOR-ing everything cancels each paired value to 0, and 0 ⊕ x = x leaves exactly the unpaired element."
  - id_key: interview-prep-45/quiz-week-4/q2
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In 'Minimum Window Substring', what drives the sliding-window expand and contract loop?"
    options:
      - text: "Expand right until the window covers all required characters, then contract left while it still does"
        correct: true
      - text: "Expand both ends until the strings are equal"
      - text: "Contract first, then expand; shortest windows come first"
      - text: "Restart the window at every index of the source string"
    explanation: "The invariant is 'window satisfies the requirement': grow to satisfy it, then shrink to minimality before recording the answer. A have/need counter pair makes both checks O(1)."
  - id_key: interview-prep-45/quiz-week-4/q3
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the first step in almost every interval problem (merge, insert, non-overlapping)?"
    options:
      - text: "Sort the intervals by start time"
        correct: true
      - text: "Build an interval tree"
      - text: "Convert intervals to a bitmap of covered points"
      - text: "Sort by interval length, shortest first"
    explanation: "After sorting by start, overlap detection becomes a single linear pass comparing each interval with the last merged one: current.start <= prev.end means overlap."
  - id_key: interview-prep-45/quiz-week-4/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In fixed-width integer languages, how do you compute a binary-search midpoint without overflow?"
    options:
      - text: "mid = low + (high - low) / 2"
        correct: true
      - text: "mid = (low + high) / 2, since it can never overflow"
      - text: "mid = high / 2 + low"
      - text: "Use floating point and round"
    explanation: "(low + high) can exceed the integer maximum when both are large; low + (high - low) / 2 keeps every intermediate value in range. A classic math-and-edge-cases interview probe."
  - id_key: interview-prep-45/quiz-week-4/q8
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "For 'Rotate Image' (rotate an n×n matrix 90° clockwise in place), the standard trick is:"
    options:
      - text: "Transpose the matrix, then reverse each row"
        correct: true
      - text: "Reverse each column, then transpose twice"
      - text: "Copy into a new matrix; in-place is impossible"
      - text: "Swap the diagonals only"
    explanation: "Transpose swaps rows with columns; reversing each row then completes the clockwise rotation, all in place with O(1) extra space."
  - id_key: interview-prep-45/quiz-week-5/q1
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What should you do FIRST when given a coding problem in an interview?"
    options:
      - text: "Restate the problem, ask clarifying questions, and confirm constraints and edge cases"
        correct: true
      - text: "Start typing the brute-force solution immediately"
      - text: "Ask for a hint to save time"
      - text: "Write all the test cases before discussing the approach"
    explanation: "Interviewers grade the process: restating catches misunderstandings when they're free to fix, and constraints (input size, value ranges, duplicates) determine which complexity class is acceptable."
  - id_key: interview-prep-45/quiz-week-5/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "You're stuck on a mock-interview problem for several minutes. Best move?"
    options:
      - text: "Talk through what you know, name the pattern you suspect, and solve a simpler version out loud"
        correct: true
      - text: "Go silent until you find the optimal solution"
      - text: "Give up and ask for the answer"
      - text: "Write code randomly hoping it compiles into insight"
    explanation: "Silence is the worst signal in an interview. Verbalizing partial progress shows your debugging process and invites the interviewer's calibrated hints, which they want to give."
  - id_key: interview-prep-45/quiz-week-5/q7
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "After a mock interview, the single most useful habit is:"
    options:
      - text: "Log every stumble, pattern gaps and communication misses, and drill those specific weaknesses next"
        correct: true
      - text: "Immediately schedule another mock to stay warm"
      - text: "Re-solve only the problems you already got right"
      - text: "Memorize the exact solution to that one problem"
    explanation: "Mocks are diagnostic instruments. Repeating what you're good at feels productive but moves nothing; targeted drilling on logged weaknesses does."
  - id_key: interview-prep-45/quiz-week-6/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "You blank on the optimal solution during the real interview. Best recovery?"
    options:
      - text: "State the brute force, code it if needed, then optimize out loud; a working O(n²) beats an imaginary O(n)"
        correct: true
      - text: "Sit silently until the optimal approach appears"
      - text: "Claim you've seen the problem and ask for another"
      - text: "Write the optimal solution's signature and bluff the body"
    explanation: "Interviewers reward trajectory: brute force, correctness, then optimization is a legitimate, hireable path. It keeps you talking, produces working code, and often the optimization emerges while explaining the bottleneck."
  - id_key: interview-prep-45/quiz-week-6/q6
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Which signal says a pattern is genuinely interview-ready, rather than just familiar?"
    options:
      - text: "You can identify the pattern from a fresh problem statement and code it without reference in about 20 minutes"
        correct: true
      - text: "You recognize the solution when you read it"
      - text: "You've watched three videos about it"
      - text: "You solved it once, three weeks ago"
    explanation: "Recognition is not recall. The interview demands generation under time pressure: if you can't produce the code cold on a new instance of the pattern, it goes back on the weakness list."
  - id_key: interview-prep-45/test-dsa-3/wildcard-star-transition
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "In wildcard matching, what is the transition for dp[i][j] when p[j-1] == '*'?"
    options:
      - text: "dp[i][j] = dp[i][j-1] or dp[i-1][j]: the star matches zero characters, or it consumes one more character of s"
        correct: true
      - text: "dp[i][j] = dp[i-1][j-1], the same rule as a plain character match"
      - text: "dp[i][j] = dp[i-1][j-2], looking back two rows and two columns"
      - text: "A star can never appear in a valid pattern, so no transition is needed"
    explanation: "The star has two valid outcomes that must be OR'd together: matching zero characters of s (dp[i][j-1]) or consuming one more character while the star stays active (dp[i-1][j])."
  - id_key: interview-prep-45/test-dsa-3/2d-dp-space-shrink
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why can a 2D string-comparison DP often be shrunk from O(m*n) space down to O(n)?"
    options:
      - text: "Each row of the table only ever reads values from the row directly above it, so only the previous row needs to be kept"
        correct: true
      - text: "Because strings are always shorter than 100 characters"
      - text: "Because Python automatically compresses 2D arrays"
      - text: "It can't be shrunk; O(m*n) space is always required"
    explanation: "If dp[i][j] only depends on row i-1 (and possibly the current row), a rolling pair of 1D arrays is enough, since older rows are never read again."
  - id_key: interview-prep-45/test-dsa-3/backtrack-undo-line
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Which single line is responsible for the \"back\" in backtracking?"
    options:
      - text: "The undo right after the recursive call, like path.pop() or used[i] = False"
        correct: true
      - text: "The base case check at the top of the function"
      - text: "The for loop that enumerates choices"
      - text: "The initial call that starts the recursion"
    explanation: "Trying a choice, recursing, then undoing it is what lets the next sibling choice start from a clean slate. Skip the undo and every later branch is corrupted."
  - id_key: interview-prep-45/test-dsa-3/subsets-ii-same-level-skip
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In Subsets II, what condition correctly skips a duplicate value while still allowing that value to appear in subsets built from a different branch?"
    options:
      - text: "i > start and nums[i] == nums[i-1], checked only within the current recursion level, on a sorted array"
        correct: true
      - text: "A single global 'seen' set of values already used anywhere in the recursion"
      - text: "Skip any value that appears more than once anywhere in the array"
      - text: "Sort descending instead of ascending before recursing"
    explanation: "A global seen-set would wrongly block a value from being reused in a different branch of the tree. The i > start same-level check only skips a repeat sibling choice, which is exactly the duplicate subsets those repeats would produce."
  - id_key: interview-prep-45/test-dsa-3/coin-greedy-counterexample
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "With coins [1, 3, 4] and a target of 6, why does 'always take the largest coin that fits' fail to find the optimal answer?"
    options:
      - text: "It gives 4 + 1 + 1 = 3 coins, while the optimal answer is 3 + 3 = 2 coins"
        correct: true
      - text: "It fails because 4 is larger than the target divided by 2"
      - text: "It doesn't fail; greedy always finds the optimal coin count"
      - text: "It fails only when the coin list isn't sorted first"
    explanation: "This is the standard counterexample for why general coin change needs dynamic programming, not greedy: the locally biggest coin blocks a globally better combination."
  - id_key: interview-prep-45/test-dsa-3/clear-lowest-set-bit
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What does the expression n & (n - 1) do, and which two classic problems does it solve?"
    options:
      - text: "It clears the lowest set bit; it's used for counting set bits (popcount) and for checking whether a number is a power of two"
        correct: true
      - text: "It sets the lowest unset bit; used for generating subsets"
      - text: "It reverses all the bits of n"
      - text: "It has no standard use beyond arithmetic simplification"
    explanation: "Subtracting 1 flips every bit below and including the lowest set bit; ANDing with the original clears exactly that lowest set bit, which is the basis of both a fast popcount loop and an O(1) power-of-2 check."
  - id_key: interview-prep-45/coding-drill-week-2/climbing-stairs
    type: coding
    difficulty: beginner
    points: 20
    prompt: |
      **Climbing Stairs** (LeetCode 70 · Dynamic Programming Basics)

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
  - id_key: interview-prep-45/coding-drill-week-3/coin-change
    type: coding
    difficulty: advanced
    points: 20
    prompt: |
      **Coin Change** (LeetCode 322 · Dynamic Programming: Hard String Matching)

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
      **Jump Game** (LeetCode 55 · Greedy Algorithms)

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
      **Single Number** (LeetCode 136 · Bit Manipulation)

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
  - id_key: interview-prep-45/coding-drill-week-4/merge-intervals
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Merge Intervals** (LeetCode 56 · Interval Problems)

      Merge all overlapping intervals and print the result. The core interval
      move: sort by start, then one linear pass — extend the last merged
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
  - id_key: interview-prep-45/coding-drill-week-4/rotate-image
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Rotate Image** (LeetCode 48 · Math and Geometry)

      Rotate an n×n matrix 90° clockwise in place and print it. The trick:
      transpose (swap `m[i][j]` with `m[j][i]` for `j > i`), then reverse each
      row — O(1) extra space.

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

Covers dynamic programming, backtracking, greedy, bit manipulation, intervals, and math from this
part of the course. Six coding problems (implement the marked function; starter code handles
stdin/stdout) plus MCQs on complexity, correctness, and interview process. Pass 70% to continue.
