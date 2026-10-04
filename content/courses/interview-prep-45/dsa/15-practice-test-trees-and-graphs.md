---
kind: quiz
id_key: interview-prep-45/test-dsa-2
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Practice Test: Trees, Heaps and Graphs"
position: 15
estimated_minutes: 52
source:
    - 45-day-interview-roadmap.md
pass_percentage: 70
duration_minutes: 52
questions:
  - id_key: interview-prep-45/quiz-week-1/q4
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Which data structures back BFS and DFS traversals?"
    options:
      - text: "BFS uses a queue; DFS uses a stack (or recursion)"
        correct: true
      - text: "BFS uses a stack; DFS uses a queue"
      - text: "Both use queues"
      - text: "Both use heaps"
    explanation: "BFS explores level by level with a FIFO queue. DFS goes deep first with a LIFO stack, or the call stack when written recursively."
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
    explanation: "Inorder visits left subtree, node, right subtree. For a BST that always comes out as ascending sorted order, which is also how you validate one."
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
    explanation: "A topological order needs directed edges and no cycles. A cycle makes any linear ordering impossible, which is why Course Schedule reduces to cycle detection."
  - id_key: interview-prep-45/quiz-week-2/q2
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What are the time complexities of heap push, pop, and peek?"
    options:
      - text: "Push/pop O(log n), peek O(1)"
        correct: true
      - text: "Push/pop O(1), peek O(log n)"
      - text: "All operations O(log n)"
      - text: "Push O(n), pop O(1), peek O(1)"
    explanation: "Insert and extract sift an element up or down the tree's height, O(log n). The min or max always sits at the root, so peek is O(1)."
  - id_key: interview-prep-45/quiz-week-2/q3
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why can you rebuild a binary tree from preorder plus inorder traversals, but not from preorder alone?"
    options:
      - text: "Preorder gives the root order, but inorder is needed to split left and right subtrees"
        correct: true
      - text: "Preorder alone loses the values of leaf nodes"
      - text: "Inorder is needed to know the tree's height"
      - text: "You can actually rebuild it from preorder alone"
    explanation: "Preorder tells you each subtree's root, but without inorder you can't tell which following values belong to the left subtree versus the right. Multiple different trees can share the same preorder."
  - id_key: interview-prep-45/quiz-week-3/q4
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What amortized time does union-find achieve with path compression and union by rank?"
    options:
      - text: "Nearly O(1) per operation (inverse Ackermann)"
        correct: true
      - text: "O(log² n) per operation"
      - text: "O(n) per operation"
      - text: "O(√n) per operation"
    explanation: "With both optimizations, every find/union runs in O(α(n)), the inverse Ackermann function, which is 4 or less for any realistic input, effectively constant time."
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
      - text: "Tries always use less memory than hash sets"
    explanation: "A hash set can only answer exact-match queries. A trie's structure IS the prefix index: descend L characters, and everything below is a valid completion. Memory is usually worse, not better."
  - id_key: interview-prep-45/test-dsa-2/bfs-vs-dfs-choice
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "A problem asks for the fewest steps between two nodes in an unweighted graph. Which traversal should you reach for, and why?"
    options:
      - text: "BFS, because it explores level by level, so the first time it reaches the target is guaranteed to be the shortest path"
        correct: true
      - text: "DFS, because it's usually shorter to code"
      - text: "Either one gives the same guarantee on any graph"
      - text: "Neither; shortest path always needs a priority queue"
    explanation: "BFS visits nodes in order of distance from the source. DFS can reach the target through a long, winding path first, so it gives no shortest-path guarantee on its own."
  - id_key: interview-prep-45/test-dsa-2/heapify-complexity
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What is the time complexity of turning an arbitrary array into a valid heap with heapify, and why does it beat n separate inserts?"
    options:
      - text: "O(n), because most nodes sit near the bottom of the tree, where a sift-down is cheap"
        correct: true
      - text: "O(n log n), the same as n separate inserts"
      - text: "O(n²), since every node must be compared against every other node"
      - text: "O(log n), regardless of array size"
    explanation: "Sifting down from the bottom means most nodes only travel a short distance. Summed across the whole tree, that totals O(n), beating the O(n log n) you'd get from inserting one element at a time."
  - id_key: interview-prep-45/test-dsa-2/kahn-cycle-signal
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "How does Kahn's algorithm signal that the graph contains a cycle?"
    options:
      - text: "The final order comes out shorter than the total number of nodes, since cycle nodes never reach in-degree 0"
        correct: true
      - text: "It throws an error the moment it starts"
      - text: "The queue becomes empty before any node is processed"
      - text: "It cannot detect cycles; a separate DFS pass is always required"
    explanation: "Every node in a cycle depends on another node stuck in that same cycle, so none of them ever reaches in-degree 0 and none gets added to the order. Comparing the order's length to the node count is the entire cycle check."
  - id_key: interview-prep-45/test-dsa-2/valid-tree-edge-count
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Graph Valid Tree checks both 'no cycle' AND 'exactly n - 1 edges.' Why isn't the no-cycle check alone enough?"
    options:
      - text: "A graph can be acyclic but still disconnected, forming a forest of separate pieces instead of one tree"
        correct: true
      - text: "Cycle detection doesn't work on undirected graphs"
      - text: "The edge-count check is redundant and can be skipped"
      - text: "A tree is defined only by having no cycles, nothing else"
    explanation: "Two separate acyclic components have no cycle anywhere, but they aren't one connected tree. The n - 1 edge-count check rules out that disconnected case cheaply, before any union-find work happens."
  - id_key: interview-prep-45/coding-drill-week-2/kth-largest
    type: coding
    difficulty: intermediate
    points: 20
    prompt: |
      **Kth Largest Element in an Array** (LeetCode 215, Heaps)

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
      **Number of Islands** (LeetCode 200, Graph BFS/DFS)

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
This test covers trees, BSTs, tries, heaps, graph traversal, topological sort, and union-find. Two problems ask you to write working code; the rest are multiple choice. Pass 70% to move on.
