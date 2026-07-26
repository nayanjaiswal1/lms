---
kind: quiz
id_key: interview-prep-45/quiz-week-1
course: interview-prep-45
section: checkpoints
section_title: "Checkpoint Quizzes"
section_position: 6
title: "Checkpoint Quiz 1 — Fundamentals"
position: 1
estimated_minutes: 20
source:
    - 45-day-interview-roadmap.md
pass_percentage: 70
duration_minutes: 15
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
    explanation: "Instead of re-scanning every subarray, a sliding window moves each pointer forward at most n times, turning O(n²) scans into O(n)."
  - id_key: interview-prep-45/quiz-week-1/q4
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Which data structures back BFS and DFS traversals respectively?"
    options:
      - text: "BFS uses a queue; DFS uses a stack (or recursion)"
        correct: true
      - text: "BFS uses a stack; DFS uses a queue"
      - text: "Both use queues"
      - text: "Both use heaps"
    explanation: "BFS explores level by level via a FIFO queue; DFS goes deep first via a LIFO stack or the call stack."
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
    explanation: "Maintaining a stack in sorted order lets you resolve, in one pass, the nearest greater or smaller element for every item (e.g. Daily Temperatures, Largest Rectangle in Histogram)."
  - id_key: interview-prep-45/quiz-week-1/q6
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a rate limiter design, which algorithm allows short bursts while enforcing a long-term average rate?"
    options:
      - text: "Token bucket"
        correct: true
      - text: "Fixed window counter"
      - text: "Leaky bucket"
      - text: "Round robin"
    explanation: "Token bucket accumulates tokens up to a burst capacity, so clients can burst briefly while the refill rate caps the sustained average. Leaky bucket smooths output to a constant rate instead."
  - id_key: interview-prep-45/quiz-week-1/q7
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "When would adding a B-tree index to a PostgreSQL column likely NOT help?"
    options:
      - text: "When the column has very low selectivity (few distinct values)"
        correct: true
      - text: "When the table has millions of rows"
      - text: "When queries filter on that column with equality"
      - text: "When queries sort by that column"
    explanation: "If a filter matches a large fraction of rows (low selectivity), the planner prefers a sequential scan — the index adds write cost without read benefit."
  - id_key: interview-prep-45/quiz-week-1/q8
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What does an inorder traversal of a valid binary search tree produce?"
    options:
      - text: "The values in sorted ascending order"
        correct: true
      - text: "The values level by level"
      - text: "The values in reverse insertion order"
      - text: "An unpredictable order"
    explanation: "Inorder visits left subtree, node, right subtree — for a BST that is exactly ascending sorted order, which is also how you validate one."
---

Checkpoint quiz for Week 1: arrays and hashing, two pointers, sliding window,
binary search, stacks, trees, plus the week's system design and backend topics.
Score 70% or higher to confirm you're ready for Week 2.
