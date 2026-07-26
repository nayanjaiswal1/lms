---
kind: quiz
id_key: interview-prep-45/quiz-week-4
course: interview-prep-45
section: checkpoints
section_title: "Checkpoint Quizzes"
section_position: 6
title: "Checkpoint Quiz 4 — Breadth & Design"
position: 4
estimated_minutes: 20
source:
    - 45-day-interview-roadmap.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: interview-prep-45/quiz-week-4/q1
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What makes a trie faster than a hash set for prefix queries like autocomplete?"
    options:
      - text: "Walking a prefix of length L visits at most L nodes, and every completion lives in that subtree"
        correct: true
      - text: "Tries hash each prefix once and cache the result"
      - text: "Tries store words sorted, enabling binary search"
      - text: "Tries use less memory than hash sets in all cases"
    explanation: "A hash set can only answer exact-match queries; a trie's structure IS the prefix index — descend L characters, then everything below is a valid completion. Memory is usually worse, not better."
  - id_key: interview-prep-45/quiz-week-4/q2
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In 'Minimum Window Substring', what drives the sliding-window expand/contract loop?"
    options:
      - text: "Expand right until the window covers all required characters, then contract left while it still does"
        correct: true
      - text: "Expand both ends until the strings are equal"
      - text: "Contract first, then expand — shortest windows come first"
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
    explanation: "After sorting by start, overlap detection becomes a single linear pass comparing each interval with the last merged one — current.start ≤ prev.end means overlap."
  - id_key: interview-prep-45/quiz-week-4/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In fixed-width integer languages, how do you compute a binary-search midpoint without overflow?"
    options:
      - text: "mid = low + (high − low) / 2"
        correct: true
      - text: "mid = (low + high) / 2 — it can never overflow"
      - text: "mid = high / 2 + low"
      - text: "Use floating point and round"
    explanation: "(low + high) can exceed the integer max when both are large; low + (high − low)/2 keeps every intermediate value in range. A classic math-and-edge-cases interview probe."
  - id_key: interview-prep-45/quiz-week-4/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Which design pattern lets you swap algorithms at runtime behind one interface — e.g. multiple payment providers?"
    options:
      - text: "Strategy"
        correct: true
      - text: "Singleton"
      - text: "Decorator"
      - text: "Observer"
    explanation: "Strategy encapsulates interchangeable behaviors behind a common interface chosen at runtime. Decorator adds responsibilities, Observer broadcasts events, Singleton restricts instantiation."
  - id_key: interview-prep-45/quiz-week-4/q6
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A table is in third normal form (3NF) when…"
    options:
      - text: "Every non-key column depends on the key, the whole key, and nothing but the key"
        correct: true
      - text: "It has no more than three foreign keys"
      - text: "All columns are indexed"
      - text: "Every query touches at most three tables"
    explanation: "3NF removes transitive dependencies: non-key attributes may not depend on other non-key attributes. The mnemonic 'the key, the whole key, and nothing but the key' covers 1NF→3NF."
  - id_key: interview-prep-45/quiz-week-4/q7
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "When would you deliberately denormalize a schema?"
    options:
      - text: "When read-heavy access patterns make join cost dominate and duplicated data can be kept consistent"
        correct: true
      - text: "Whenever a table exceeds one million rows"
      - text: "Never — normalization is always superior"
      - text: "When you need more foreign keys"
    explanation: "Denormalization trades write complexity (keeping copies in sync) for read speed (no joins). It's a measured response to real read patterns — feed timelines, counters, reporting tables — not a row-count rule."
  - id_key: interview-prep-45/quiz-week-4/q8
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "For 'Rotate Image' (rotate an n×n matrix 90° clockwise in place), the standard trick is:"
    options:
      - text: "Transpose the matrix, then reverse each row"
        correct: true
      - text: "Reverse each column, then transpose twice"
      - text: "Copy into a new matrix — in-place is impossible"
      - text: "Swap the diagonals only"
    explanation: "Transpose swaps rows with columns; reversing each row then completes the clockwise rotation — all in place with O(1) extra space. (Counter-clockwise: transpose then reverse columns.)"
---

Checkpoint for Week 4's breadth topics: tries, advanced sliding window, intervals,
math and geometry edge cases, design patterns, and database design. Score 70% or
higher to confirm you're ready for mock-interview week.
