---
kind: lesson
id_key: interview-prep-45/day-14
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Checkpoint 2"
position: 14
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---

Week 2 covered five dense topics — BSTs, graph traversal, topological sort, heaps, and the first two layers of dynamic programming. This checkpoint isn't new material: it's a forced consolidation pass. Interview performance comes from pattern recognition under pressure, and pattern recognition only sticks after you've deliberately reviewed what you learned, not just solved it once and moved on.

## Progress review

| Area | Problems completed | Core pattern to recall |
|---|---|---|
| Trees (BST) | 4 | In-order traversal gives sorted output; BST property prunes search space to O(log n) on balanced trees |
| Graphs (BFS/DFS + topo sort) | 8 | BFS = shortest path/minimum steps; DFS = path existence/components; Kahn's algorithm = topo sort + free cycle detection |
| Heaps | 4 | Size-K heap for top-K problems; two-heap split for running median; heapify is O(n) |
| DP Basics | 4 | 1D state, recurrence from naive recursion, then memoize, then tabulate, then compress to O(1) space |
| DP Intermediate | 4 | 2D state for two-sequence problems; base-case row/column must be initialized explicitly |

**Total: 42 LeetCode problems solved**

## Pattern recall drill

Before re-solving anything, do this from memory — no notes, no code, just the recurrence or algorithm shape. This is the fastest way to expose which patterns are shallow (you followed a solution) vs deep (you can regenerate it).

**Graph traversal decision:**

```python
# Ask: does the question say "shortest" / "minimum steps" / "fewest"?
#   Yes -> BFS with a queue, mark visited at ENQUEUE time
#   No, asks "does a path exist" / "find all X" / "connected components"?
#   Yes -> DFS, recursive or explicit stack
```

**Topological sort (Kahn's), from memory:**

```python
from collections import deque, defaultdict

def kahn_topo_sort(num_nodes, edges):
    graph = defaultdict(list)
    in_degree = [0] * num_nodes
    for u, v in edges:
        graph[u].append(v)
        in_degree[v] += 1
    queue = deque(n for n in range(num_nodes) if in_degree[n] == 0)
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for nxt in graph[node]:
            in_degree[nxt] -= 1
            if in_degree[nxt] == 0:
                queue.append(nxt)
    return order if len(order) == num_nodes else []  # [] means a cycle exists
```

**Heap top-K skeleton, from memory:**

```python
import heapq

def top_k_pattern(items, k, key=lambda x: x):
    heap = []
    for item in items:
        heapq.heappush(heap, (key(item), item))
        if len(heap) > k:
            heapq.heappop(heap)
    return [item for _, item in heap]
```

**DP progression, from memory — say it out loud before writing code:**

1. What's the state? (`dp[i]` or `dp[i][j]` — what does each index represent?)
2. What's the base case? (Smallest subproblem, answered without recursion.)
3. What's the transition? (How does `dp[i]` combine smaller already-solved states?)
4. Can the space be compressed? (Does `dp[i]` only depend on a fixed window of previous states?)

If you can't answer all four for a problem you "solved" this week, that problem needs a re-solve, not just a re-read.

## Where candidates actually lose points

- **Graphs:** conflating "visited" semantics between BFS (mark at enqueue) and recursive DFS (mark at visit) — mixing the two causes duplicate work or infinite loops on cycles.
- **Topological sort:** using a 2-state (`visited`/`unvisited`) cycle check on a *directed* graph — this gives false results. Directed cycle detection needs 3 states (white/gray/black) to distinguish "currently on this DFS path" from "already fully explored."
- **Heaps:** forgetting Python's `heapq` is min-heap only, and forgetting to negate back after popping from a simulated max heap.
- **DP:** jumping straight to code without stating the state definition first — this is the single biggest predictor of getting stuck mid-solution in a live interview.

## Revision tasks

Re-solve without looking at your previous solution or these notes. Time yourself. If you can't finish in a reasonable interview window (25-35 minutes for a medium, 40-45 for a hard), that's the signal to revisit the underlying pattern, not just the specific problem.

- [ ] Re-solve Clone Graph (LeetCode 133) — tests visited-map + BFS/DFS combined
- [ ] Re-solve Alien Dictionary (LeetCode 269) — hardest topo-sort problem this week, exercises edge construction *and* Kahn's
- [ ] Re-solve Find Median from Data Stream (LeetCode 295) — tests the two-heap balancing invariant
- [ ] Re-solve Edit Distance (LeetCode 72) — tests 2D DP base-case initialization and transition recall
- [ ] Re-solve Longest Increasing Subsequence (LeetCode 300) — attempt the O(n log n) binary-search version from memory, not just O(n²)

## Key takeaways

- Pattern recognition beats memorized solutions — if you can regenerate the recurrence/algorithm shape from a one-line prompt, you own the pattern; if you need to recall a specific solution, you don't yet.
- BFS vs DFS is a two-question decision tree: shortest/minimum → BFS; existence/enumeration/components → DFS.
- Directed-graph cycle detection needs 3 states, not 2 — this is the most common graph bug in interviews.
- DP problems are solved in a fixed order every time: state → base case → transition → space optimization. State the state out loud before writing any code.
- A problem "completed" a week ago that you can't re-solve cold today isn't actually learned — re-solving under light time pressure is what converts exposure into recall.
