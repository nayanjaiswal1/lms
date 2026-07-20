---
kind: lesson
id_key: interview-prep-45/day-09
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 9 — Graphs - BFS and DFS"
position: 9
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---

Graph traversal is the single most reused pattern in interviews — grids, dependency chains, social networks, and state-space search all reduce to "visit nodes without revisiting them." Today you build the adjacency list, BFS, and DFS primitives you'll reuse for the rest of the course, then apply them to four classic problems.

## Graph representation: adjacency list vs matrix

A graph is a set of nodes (vertices) connected by edges. You almost always represent it one of two ways.

**Adjacency list** — a dict/array mapping each node to its neighbors.

```python
from collections import defaultdict

graph = defaultdict(list)
edges = [(0, 1), (0, 2), (1, 2), (2, 3)]
for u, v in edges:
    graph[u].append(v)
    graph[v].append(u)  # omit this line for a directed graph

print(dict(graph))
# {0: [1, 2], 1: [0, 2], 2: [0, 1, 3], 3: [2]}
```

**Adjacency matrix** — an `n x n` grid where `matrix[i][j] = 1` if an edge exists.

```python
n = 4
matrix = [[0] * n for _ in range(n)]
for u, v in edges:
    matrix[u][v] = 1
    matrix[v][u] = 1
```

| | Adjacency list | Adjacency matrix |
|---|---|---|
| Space | O(V + E) | O(V²) |
| "Are u, v connected?" | O(degree(u)) | O(1) |
| Iterate neighbors of u | O(degree(u)) | O(V) |
| Best for | Sparse graphs (most interview problems) | Dense graphs, small V, or when you need O(1) edge lookup |

**Pitfall:** LeetCode grid problems (Number of Islands, Rotting Oranges) don't hand you a graph at all — the 2D grid *is* the implicit adjacency structure, with neighbors being the 4 (or 8) adjacent cells. Recognizing "this grid is a graph" is half the battle.

## When to use BFS vs DFS

Both visit every reachable node exactly once, but they explore in different orders and suit different questions.

| | BFS | DFS |
|---|---|---|
| Data structure | Queue (FIFO) | Stack (explicit) or recursion (call stack) |
| Explores | Level by level, outward from source | One path all the way down before backtracking |
| Use for | Shortest path in unweighted graph, "minimum steps", multi-source spread | Path existence, connected components, cycle detection, backtracking, topological order |
| Space | O(V) — can hold a full level | O(V) worst case (deep recursion) — but often less for wide, shallow graphs |

Rule of thumb: **if the question says "shortest," "minimum," or "fewest steps," reach for BFS.** If it says "does a path exist," "find all paths," or "explore everything," DFS (often recursive) is simpler to write and reason about.

## Visited set management

Without tracking visited nodes, cyclic graphs cause infinite loops. The critical detail interviewers probe: **mark a node visited the moment you enqueue/push it, not when you pop it.**

```python
from collections import deque

def bfs(graph, start):
    visited = {start}          # mark on enqueue
    queue = deque([start])
    order = []
    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                visited.add(neighbor)   # mark here, not after popping
                queue.append(neighbor)
    return order
```

If you mark visited only when you pop, the same node can be pushed onto the queue multiple times before it's ever processed — wasted work, and in weighted-BFS variants (like multi-source problems) it can produce wrong answers. For grids, `visited` is usually a 2D boolean array or you mutate the grid in place (e.g., flip `'1'` to `'0'`) to save space.

## Number of Islands

[LeetCode 200](https://leetcode.com/problems/number-of-islands/) — DFS/BFS — Grid traversal

**Intuition:** Each connected group of `'1'`s is one island. Scan every cell; whenever you find an unvisited `'1'`, that's a new island — flood-fill (DFS or BFS) to mark every connected land cell so you don't count it again.

**Approach:** Iterate all cells. On an unvisited land cell, increment the island count and run DFS/BFS to sink the entire connected component (mutate to `'0'` as "visited").

```python
def numIslands(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])

    def dfs(r, c):
        if r < 0 or r >= rows or c < 0 or c >= cols or grid[r][c] != '1':
            return
        grid[r][c] = '0'  # sink it so we never revisit
        dfs(r + 1, c)
        dfs(r - 1, c)
        dfs(r, c + 1)
        dfs(r, c - 1)

    islands = 0
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == '1':
                islands += 1
                dfs(r, c)
    return islands
```

**Complexity:** Time O(rows × cols) — each cell visited a constant number of times. Space O(rows × cols) worst case for the recursion stack (a grid that's entirely land).

**Common mistakes:** Forgetting boundary checks before indexing (index-out-of-range crash); mutating the grid without realizing the interviewer may not want the input destroyed (mention the trade-off, offer a separate `visited` set as an alternative); using DFS recursion on a huge grid can hit Python's recursion limit — BFS with an explicit queue avoids that risk entirely.

## Clone Graph

[LeetCode 133](https://leetcode.com/problems/clone-graph/) — BFS/DFS — Deep copy

**Intuition:** You must create a completely new graph with new node objects, preserving the same connectivity. The trick is avoiding infinite loops on cycles — you need a map from original node → cloned node so you never clone the same node twice.

**Approach:** BFS or DFS from the given start node. Use a hash map `old -> new`. Whenever you encounter a neighbor you haven't cloned yet, create its clone and enqueue it; either way, append the clone to the current node's clone's neighbor list.

```python
class Node:
    def __init__(self, val=0, neighbors=None):
        self.val = val
        self.neighbors = neighbors if neighbors is not None else []

def cloneGraph(node: 'Node') -> 'Node':
    if not node:
        return None

    old_to_new = {node: Node(node.val)}
    queue = deque([node])

    while queue:
        cur = queue.popleft()
        for neighbor in cur.neighbors:
            if neighbor not in old_to_new:
                old_to_new[neighbor] = Node(neighbor.val)
                queue.append(neighbor)
            old_to_new[cur].neighbors.append(old_to_new[neighbor])

    return old_to_new[node]
```

**Complexity:** Time O(V + E), space O(V) for the map and queue.

**Common mistakes:** Cloning a neighbor's *value* instead of wiring up the *clone object*; not handling the single-node-with-no-neighbors edge case; re-cloning a node already in the map (always check `old_to_new` before creating a new `Node`).

## Rotting Oranges

[LeetCode 994](https://leetcode.com/problems/rotting-oranges/) — BFS — Multi-source BFS

**Intuition:** Every rotten orange rots its fresh neighbors simultaneously, one minute at a time. This is BFS from *multiple sources at once* — seed the queue with all initially-rotten oranges, then expand level by level; each level = one minute.

**Approach:** Push all rotten cells into the queue first (minute 0). Track `fresh` count. BFS level by level; each popped-and-expanded level that rots at least one orange increments the minute counter. If `fresh > 0` after BFS exhausts, return -1.

```python
def orangesRotting(grid: list[list[int]]) -> int:
    rows, cols = len(grid), len(grid[0])
    queue = deque()
    fresh = 0

    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == 2:
                queue.append((r, c))
            elif grid[r][c] == 1:
                fresh += 1

    minutes = 0
    directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    while queue and fresh > 0:
        minutes += 1
        for _ in range(len(queue)):  # process one full level = one minute
            r, c = queue.popleft()
            for dr, dc in directions:
                nr, nc = r + dr, c + dc
                if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] == 1:
                    grid[nr][nc] = 2
                    fresh -= 1
                    queue.append((nr, nc))

    return minutes if fresh == 0 else -1
```

**Complexity:** Time O(rows × cols), space O(rows × cols) for the queue.

**Common mistakes:** Incrementing `minutes` even on the final level when nothing new rotted (the `for _ in range(len(queue))` level-batching pattern handles this correctly — verify against the "no fresh oranges at all" edge case, which should return 0); forgetting multi-source seeding and instead running BFS from a single rotten cell.

## Walls and Gates

[LeetCode 286](https://leetcode.com/problems/walls-and-gates/) — BFS — Fill distances

**Intuition:** Same multi-source BFS pattern as Rotting Oranges, but instead of counting minutes you're writing the BFS depth directly into each empty room as its distance to the nearest gate.

**Approach:** Seed the queue with every gate (value `0`). BFS outward; whenever you reach an empty room (`INF`), set its distance to `current_distance + 1` and enqueue it.

```python
INF = 2147483647

def wallsAndGates(rooms: list[list[int]]) -> None:
    if not rooms:
        return
    rows, cols = len(rooms), len(rooms[0])
    queue = deque()

    for r in range(rows):
        for c in range(cols):
            if rooms[r][c] == 0:
                queue.append((r, c))

    directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    while queue:
        r, c = queue.popleft()
        for dr, dc in directions:
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and rooms[nr][nc] == INF:
                rooms[nr][nc] = rooms[r][c] + 1
                queue.append((nr, nc))
```

**Complexity:** Time O(rows × cols), space O(rows × cols).

**Common mistakes:** Running BFS separately from every gate instead of seeding all gates into one shared queue (that gives the *correct* answer too, but is O(gates × cells) instead of O(cells) — mention the multi-source optimization explicitly, interviewers look for it); walls (`-1`) must simply be skipped, not treated as an error case.

## Key takeaways

- Adjacency list is the default representation for interview-scale graphs; matrices only earn their O(V²) space when you need O(1) edge lookups on a dense/small graph.
- BFS = shortest path / minimum steps in unweighted graphs. DFS = does-a-path-exist, enumerate-all-paths, or components — pick based on what the question asks for.
- Mark nodes visited at enqueue/push time, never at pop/process time, or you'll do duplicate work (and get wrong answers in weighted variants).
- Grid problems are graphs in disguise — 4-directional (or 8-directional) neighbor checks replace `graph[node]` lookups.
- Multi-source BFS (seed the queue with *all* starting points before the first pop) is the pattern behind Rotting Oranges and Walls and Gates — recognize it whenever "simultaneously" or "nearest of several sources" appears.

## Today's checklist

- [ ] Explain adjacency list vs matrix trade-offs out loud
- [ ] State when BFS beats DFS and vice versa
- [ ] Solve Number of Islands (LeetCode 200)
- [ ] Solve Clone Graph (LeetCode 133)
- [ ] Solve Rotting Oranges (LeetCode 994)
- [ ] Solve Walls and Gates (LeetCode 286)
- [ ] Implement a graph with an adjacency list from scratch
- [ ] Implement BFS and DFS from scratch, without looking at today's examples
