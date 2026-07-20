---
kind: quiz
id_key: interview-prep-45/quiz-week-3
course: interview-prep-45
section: checkpoints
section_title: "Weekly Checkpoints"
section_position: 6
title: "Week 3 Checkpoint Quiz — Advanced Patterns"
position: 3
estimated_minutes: 20
source:
    - 45-day-interview-roadmap.md
pass_percentage: 70
duration_minutes: 15
questions:
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
    explanation: "There are 2ⁿ subsets and copying each one costs up to O(n) — exponential output means exponential time, which is why pruning matters so much in backtracking."
  - id_key: interview-prep-45/quiz-week-3/q2
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In the classic N-Queens backtracking solution, which three constraint sets are tracked?"
    options:
      - text: "Columns, positive diagonals (r+c), and negative diagonals (r−c)"
        correct: true
      - text: "Rows, columns, and knight-move squares"
      - text: "Rows, corners, and edges"
      - text: "Columns only — diagonals are checked by rescanning the board"
    explanation: "Placing row by row makes row conflicts impossible; O(1) membership checks on the column set and the two diagonal sets (keyed by r+c and r−c) prune invalid placements instantly."
  - id_key: interview-prep-45/quiz-week-3/q3
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "When is a greedy algorithm guaranteed to produce the optimal answer?"
    options:
      - text: "When the problem has the greedy-choice property — each local optimum extends to a global optimum"
        correct: true
      - text: "Whenever the input is sorted"
      - text: "For every optimization problem"
      - text: "Only when combined with memoization"
    explanation: "Greedy works only if a locally best choice can never need to be undone (e.g. Jump Game, interval scheduling). When choices interact — like 0/1 knapsack — you need DP instead."
  - id_key: interview-prep-45/quiz-week-3/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What amortized complexity does Union-Find achieve with path compression and union by rank?"
    options:
      - text: "Nearly O(1) per operation (inverse Ackermann)"
        correct: true
      - text: "O(log² n) per operation"
      - text: "O(n) per operation"
      - text: "O(√n) per operation"
    explanation: "With both optimizations, each find/union runs in O(α(n)) — the inverse Ackermann function, ≤ 4 for any realistic input — effectively constant time."
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
  - id_key: interview-prep-45/quiz-week-3/q6
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "What does the CAP theorem say a distributed system must choose between during a network partition?"
    options:
      - text: "Consistency or availability — you cannot have both while partitioned"
        correct: true
      - text: "Latency or throughput"
      - text: "Durability or atomicity"
      - text: "Nothing — modern databases avoid the trade-off entirely"
    explanation: "When nodes can't communicate, you either reject requests to stay consistent (CP) or serve possibly-stale data to stay available (AP). Partition tolerance itself is non-negotiable."
  - id_key: interview-prep-45/quiz-week-3/q7
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "What is the classic failure mode of a Redis distributed lock with a TTL?"
    options:
      - text: "A paused/slow client's lock expires, another client acquires it, and both run the critical section"
        correct: true
      - text: "The lock can never expire, causing deadlock"
      - text: "Redis rejects SET NX under load"
      - text: "TTL locks prevent all concurrency bugs"
    explanation: "If the holder stalls (GC pause, network) past the TTL, the lock is released while it still thinks it owns it. Mitigations: fencing tokens, lock renewal (watchdog), or accepting at-least-once semantics with idempotency."
  - id_key: interview-prep-45/quiz-week-3/q8
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a Ticketmaster-style booking system, what prevents two users from buying the same seat?"
    options:
      - text: "A short-lived reservation hold (row lock or expiring hold) taken before payment completes"
        correct: true
      - text: "Optimistically letting both pay and refunding one later, as the primary design"
      - text: "Caching seat availability in the browser"
      - text: "Processing all bookings on a single thread forever"
    explanation: "The standard design reserves the seat atomically (SELECT ... FOR UPDATE or an expiring hold in Redis) for a payment window; if payment doesn't complete, the hold lapses and the seat returns to inventory."
---

Checkpoint quiz for Week 3: backtracking, greedy, union-find, bit manipulation,
plus distributed systems, locks, and high-concurrency booking design.
Score 70% or higher before moving into breadth topics and mock interviews.
