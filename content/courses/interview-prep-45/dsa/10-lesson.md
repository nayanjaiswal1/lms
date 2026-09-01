---
kind: lesson
id_key: interview-prep-45/day-10
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Graphs - Topological Sort and Cycles"
position: 10
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---

Topological sort answers "in what order must these tasks run given their dependencies?" Course prerequisites, build systems, package installs, and spreadsheet formula evaluation all reduce to it. It only exists for directed acyclic graphs, so cycle detection is inseparable from the topic. Today you learn both the BFS (Kahn's) and DFS approaches, and use them to solve four problems ranging from standard to hard.

## DAG properties

A **DAG** (Directed Acyclic Graph) is a directed graph with no cycles: you can never start at a node and follow edges back to itself. This property is what makes a valid ordering possible. If node A must come before node B (edge A→B), a cycle A→B→A would make "before" meaningless, so no valid order would exist.

**Topological order**: a linear ordering of vertices such that for every directed edge `u → v`, `u` appears before `v`. A DAG can have multiple valid topological orders (or exactly one, if the graph is a strict chain).

```python
# Example: 5 depends on 2 and 0; 4 depends on 0 and 1; 3 depends on 1
# edges: 5->2, 5->0, 4->0, 4->1, 2->3, 3->1
# Valid orders include: [5, 4, 2, 3, 1, 0] and [4, 5, 2, 3, 1, 0]
```

**Key fact:** a graph has a valid topological order **if and only if it is a DAG**. So "can this be topologically sorted?" and "does this graph have a cycle?" are the same question asked two ways, which is why cycle detection and topo sort share one algorithm.

## Kahn's algorithm (BFS-based)

Kahn's algorithm repeatedly removes nodes with **in-degree 0**, meaning no remaining dependencies. That's the key insight: a node with in-degree 0 can safely run now, since nothing is waiting on it.

```python
from collections import deque, defaultdict

def kahn_topo_sort(num_nodes: int, edges: list[tuple[int, int]]) -> list[int]:
    graph = defaultdict(list)
    in_degree = [0] * num_nodes
    for u, v in edges:          # u must come before v
        graph[u].append(v)
        in_degree[v] += 1

    queue = deque(n for n in range(num_nodes) if in_degree[n] == 0)
    order = []

    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    if len(order) != num_nodes:
        return []  # cycle detected — not all nodes could be processed
    return order
```

**Complexity:** Time O(V + E), space O(V + E).

**Why it doubles as cycle detection:** if the graph has a cycle, the nodes in that cycle never reach in-degree 0, since each depends on another node also stuck in the cycle. So `order` ends up shorter than `num_nodes`. That length check is the cycle check; no separate logic needed.

## DFS-based topological sort

The DFS approach: run DFS from every unvisited node, and when a node's DFS call finishes (all its descendants are fully processed), push it onto a stack. Reverse the stack at the end.

```python
def dfs_topo_sort(num_nodes: int, edges: list[tuple[int, int]]) -> list[int]:
    graph = defaultdict(list)
    for u, v in edges:
        graph[u].append(v)

    visited = set()
    stack = []

    def dfs(node):
        visited.add(node)
        for neighbor in graph[node]:
            if neighbor not in visited:
                dfs(neighbor)
        stack.append(node)  # postorder: node goes on stack after all descendants

    for node in range(num_nodes):
        if node not in visited:
            dfs(node)

    return stack[::-1]
```

**Why postorder + reverse works:** a node is only pushed after everything it depends on downstream has already been pushed. Reversing puts dependencies before dependents. This variant needs a separate 3-color (white/gray/black) cycle check, covered next, because plain `visited` alone can't distinguish "currently on the DFS path" from "already fully processed."

**Trade-off:** Kahn's is iterative, so it carries no recursion depth risk, and it detects cycles for free via the length check. DFS-based is often shorter to write when you already have DFS cycle detection in place, and it fits naturally when the problem is phrased as "process a node after its dependents," as in course scheduling frameworks.

## Cycle detection

For an **undirected** graph, a visited set alone suffices. If you reach an already-visited neighbor that isn't your immediate parent, that's a cycle.

For a **directed** graph (the interview-relevant case, e.g., Course Schedule), you need three states, not two, because a node can be "visited" from a completed branch without being part of a cycle:

```python
WHITE, GRAY, BLACK = 0, 1, 2  # unvisited, in-progress (on current DFS path), done

def has_cycle_directed(num_nodes: int, edges: list[tuple[int, int]]) -> bool:
    graph = defaultdict(list)
    for u, v in edges:
        graph[u].append(v)

    color = [WHITE] * num_nodes

    def dfs(node):
        color[node] = GRAY
        for neighbor in graph[node]:
            if color[neighbor] == GRAY:
                return True                  # back edge -> cycle
            if color[neighbor] == WHITE and dfs(neighbor):
                return True
        color[node] = BLACK
        return False

    return any(color[n] == WHITE and dfs(n) for n in range(num_nodes))
```

**Pitfall:** using a single `visited` set (two states) on a directed graph gives false positives. Two branches can both reach the same node without a cycle existing, because directed edges don't imply "coming back." The GRAY state, tracking the current recursion path, is what correctly identifies a back edge.

## Course Schedule

[LeetCode 207](https://leetcode.com/problems/course-schedule/), Topological sort, Detect cycle

**Intuition:** "Can you finish all courses?" is exactly "is this prerequisite graph a DAG?" Build the graph, run Kahn's, and check whether every course got processed.

**Approach:** Build adjacency list and in-degree array from prerequisites, then Kahn's algorithm; compare processed count to `numCourses`.

```python
def canFinish(numCourses: int, prerequisites: list[list[int]]) -> bool:
    graph = defaultdict(list)
    in_degree = [0] * numCourses
    for course, prereq in prerequisites:
        graph[prereq].append(course)
        in_degree[course] += 1

    queue = deque(c for c in range(numCourses) if in_degree[c] == 0)
    processed = 0

    while queue:
        node = queue.popleft()
        processed += 1
        for neighbor in graph[node]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    return processed == numCourses
```

**Complexity:** Time O(V + E), space O(V + E).

**Common mistakes:** Flipping the edge direction; it runs prereq to course, not course to prereq. Forgetting that courses with zero prerequisites and zero dependents still count toward `processed`.

## Course Schedule II

[LeetCode 210](https://leetcode.com/problems/course-schedule-ii/), Topological sort, Return order

**Intuition:** Identical to Course Schedule I, but instead of a boolean you return the actual valid order (or empty list if impossible).

**Approach:** Reuse Kahn's algorithm verbatim, but collect the order instead of only counting.

```python
def findOrder(numCourses: int, prerequisites: list[list[int]]) -> list[int]:
    graph = defaultdict(list)
    in_degree = [0] * numCourses
    for course, prereq in prerequisites:
        graph[prereq].append(course)
        in_degree[course] += 1

    queue = deque(c for c in range(numCourses) if in_degree[c] == 0)
    order = []

    while queue:
        node = queue.popleft()
        order.append(node)
        for neighbor in graph[node]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    return order if len(order) == numCourses else []
```

**Complexity:** Time O(V + E), space O(V + E).

**Common mistakes:** Returning a partial order instead of `[]` when a cycle exists. Always check the length before returning.

## Alien Dictionary

[LeetCode 269](https://leetcode.com/problems/alien-dictionary/), Topological sort, Hard

**Intuition:** You're given a list of words already sorted according to some unknown alien alphabet. Comparing adjacent words reveals relative character ordering constraints: the first differing character between two consecutive words tells you "this char comes before that char." Build a graph of those constraints and topologically sort the 26 letters.

**Approach:** For each pair of adjacent words, find the first index where characters differ; that gives one directed edge `word1[i] -> word2[i]`. Special case: if `word1` is longer than `word2` but is a prefix of it, such as `"abc"` before `"ab"`, the order is invalid and you return `""`. Then run Kahn's algorithm over the 26 letters.

```python
def alienOrder(words: list[str]) -> str:
    graph = defaultdict(set)
    in_degree = {c: 0 for word in words for c in word}

    for w1, w2 in zip(words, words[1:]):
        min_len = min(len(w1), len(w2))
        if len(w1) > len(w2) and w1[:min_len] == w2[:min_len]:
            return ""  # invalid: longer word can't be a prefix of the next
        for c1, c2 in zip(w1, w2):
            if c1 != c2:
                if c2 not in graph[c1]:
                    graph[c1].add(c2)
                    in_degree[c2] += 1
                break  # only the first differing pair gives a constraint

    queue = deque(c for c in in_degree if in_degree[c] == 0)
    order = []

    while queue:
        c = queue.popleft()
        order.append(c)
        for neighbor in graph[c]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    return "".join(order) if len(order) == len(in_degree) else ""
```

**Complexity:** Time O(C), where C is the total character count across all words: each adjacent pair comparison is bounded by word length, and the topo sort itself is O(26) for nodes and edges. Space is O(1) in practice, since there are at most 26 letters.

**Common mistakes:** Not handling the "prefix but longer" invalid case. Adding duplicate edges when the same letter pair appears in multiple word comparisons; the `if c2 not in graph[c1]` guard prevents inflating `in_degree`. Breaking out of the inner loop only after finding the first differing character, since later differences are meaningless once one is found.

## Longest Increasing Path in Matrix

[LeetCode 329](https://leetcode.com/problems/longest-increasing-path-in-a-matrix/), DFS + Memoization

**Intuition:** Think of each cell as a graph node with a directed edge to any 4-directional neighbor with a strictly greater value. Since values strictly increase along any path, this graph is automatically acyclic, so no separate cycle check is needed. Find the longest path in this implicit DAG using DFS with memoization; it's topological-DAG-style DP even though you never build an explicit adjacency list.

**Approach:** DFS from each cell, caching "longest increasing path starting here" so overlapping subproblems aren't recomputed.

```python
def longestIncreasingPath(matrix: list[list[int]]) -> int:
    if not matrix:
        return 0
    rows, cols = len(matrix), len(matrix[0])
    memo = {}

    def dfs(r, c):
        if (r, c) in memo:
            return memo[(r, c)]
        best = 1
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and matrix[nr][nc] > matrix[r][c]:
                best = max(best, 1 + dfs(nr, nc))
        memo[(r, c)] = best
        return best

    return max(dfs(r, c) for r in range(rows) for c in range(cols))
```

**Complexity:** Time O(rows × cols), since memoization computes each cell's answer once. Space O(rows × cols) for the memo and recursion stack.

**Common mistakes:** Trying to solve this with a visited set instead of memoization. A visited set assumes you never revisit a cell in any path, but here you legitimately want to revisit cells from different starting points. Memoization on "longest path starting at (r, c)" is the correct DP framing.
