---
kind: quiz
id_key: interview-prep-45/quiz-week-2
course: interview-prep-45
section: checkpoints
section_title: "Checkpoint Quizzes"
section_position: 6
title: "Checkpoint Quiz 2 — Core Patterns & Systems"
position: 2
estimated_minutes: 20
source:
    - 45-day-interview-roadmap.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: interview-prep-45/quiz-week-2/q1
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Topological sort is only defined for which kind of graph?"
    options:
      - text: "Directed acyclic graphs (DAGs)"
        correct: true
      - text: "Undirected connected graphs"
      - text: "Weighted graphs"
      - text: "Complete graphs"
    explanation: "A topological order requires directed edges and no cycles — a cycle makes any linear ordering impossible, which is why Course Schedule reduces to cycle detection."
  - id_key: interview-prep-45/quiz-week-2/q2
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What are the time complexities of heap push/pop and peek?"
    options:
      - text: "Push/pop O(log n), peek O(1)"
        correct: true
      - text: "Push/pop O(1), peek O(log n)"
      - text: "All operations O(log n)"
      - text: "Push O(n), pop O(1), peek O(1)"
    explanation: "Insert and extract sift an element up or down the tree height (O(log n)); the min/max is always at the root, so peek is O(1)."
  - id_key: interview-prep-45/quiz-week-2/q3
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why can you reconstruct a binary tree from preorder + inorder traversals, but not from preorder alone?"
    options:
      - text: "Preorder gives the root order, but inorder is needed to split left and right subtrees"
        correct: true
      - text: "Preorder alone loses the values of leaf nodes"
      - text: "Inorder is needed to know the tree's height"
      - text: "You actually can reconstruct it from preorder alone"
    explanation: "Preorder tells you each subtree's root, but without inorder you can't tell which following nodes belong to the left vs right subtree — multiple trees share the same preorder."
  - id_key: interview-prep-45/quiz-week-2/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the difference between top-down (memoization) and bottom-up (tabulation) dynamic programming?"
    options:
      - text: "Top-down recurses from the goal caching results; bottom-up iterates from base cases filling a table"
        correct: true
      - text: "Top-down is always faster than bottom-up"
      - text: "Bottom-up uses recursion; top-down uses loops"
      - text: "They differ only in space complexity, never in structure"
    explanation: "Both compute the same states. Memoization starts at the target and recurses down with a cache; tabulation starts at base cases and iterates up — same asymptotic complexity, different mechanics."
  - id_key: interview-prep-45/quiz-week-2/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a Twitter-style feed design, what is the main trade-off between fan-out-on-write and fan-out-on-read?"
    options:
      - text: "Fan-out-on-write precomputes timelines for fast reads but is expensive for accounts with millions of followers"
        correct: true
      - text: "Fan-out-on-read is always cheaper in every dimension"
      - text: "Fan-out-on-write reduces storage usage"
      - text: "There is no difference for celebrity accounts"
    explanation: "Pushing each tweet into every follower's timeline makes reads O(1) but writes explode for celebrities — real systems use a hybrid: fan-out-on-write for normal users, fan-out-on-read for high-follower accounts."
  - id_key: interview-prep-45/quiz-week-2/q6
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In Django ORM, what is the difference between select_related and prefetch_related?"
    options:
      - text: "select_related uses a SQL JOIN for foreign keys; prefetch_related runs a second query for many-to-many/reverse relations"
        correct: true
      - text: "They are aliases for the same operation"
      - text: "prefetch_related joins tables; select_related runs extra queries"
      - text: "select_related only works on many-to-many fields"
    explanation: "select_related follows single-valued relations in one JOINed query; prefetch_related fetches related sets in a separate query and stitches them in Python — both kill N+1 query problems."
  - id_key: interview-prep-45/quiz-week-2/q7
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Which HTTP method semantics are correct for a REST API?"
    options:
      - text: "PUT replaces a resource idempotently; PATCH applies a partial update; POST creates without idempotency"
        correct: true
      - text: "POST is idempotent; PUT is not"
      - text: "PATCH fully replaces the resource"
      - text: "PUT and POST are interchangeable by spec"
    explanation: "PUT sends the full replacement representation and repeated calls give the same result; PATCH sends only changed fields; POST creates a new resource each call, so retries need idempotency keys."
  - id_key: interview-prep-45/quiz-week-2/q8
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "In a job queue system, how do you safely handle a worker that dies mid-task?"
    options:
      - text: "Use visibility timeouts / heartbeats so the job returns to the queue, and make task handlers idempotent"
        correct: true
      - text: "Mark the job completed as soon as a worker picks it up"
      - text: "Delete the job when the worker crashes"
      - text: "Rely on the worker to always finish"
    explanation: "Acknowledge only after completion; if the worker's lease or heartbeat lapses, the broker redelivers. Because redelivery means possible re-execution, handlers must be idempotent — the core Celery interview answer."
---

Checkpoint quiz for Week 2: BSTs, graphs, topological sort, heaps, DP basics,
plus feed design, REST semantics, Django ORM, and task queues.
Score 70% or higher to confirm you're ready for Week 3.
