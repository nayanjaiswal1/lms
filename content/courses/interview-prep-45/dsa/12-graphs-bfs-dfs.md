---
kind: lesson
id_key: interview-prep-45/day-09
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Graphs: BFS and DFS"
position: 12
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
Think of a map of friendships: you, your friends, and their friends, connected by lines. Finding out if two people are connected, or how many steps separate them, means walking those lines without retracing your steps. That is graph traversal, the single most reused pattern in interviews. Grids, dependency chains, social networks, and state-space search all reduce to "visit nodes without visiting the same one twice."

## Two ways to draw a graph in code

A graph is a set of nodes (vertices) connected by edges. You almost always represent it one of two ways.

**Adjacency list**: a dict or array mapping each node to its neighbors.

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
```javascript +
const graph = new Map();
const edges = [[0, 1], [0, 2], [1, 2], [2, 3]];
for (const [u, v] of edges) {
    if (!graph.has(u)) graph.set(u, []);
    if (!graph.has(v)) graph.set(v, []);
    graph.get(u).push(v);
    graph.get(v).push(u); // omit this line for a directed graph
}

console.log(Object.fromEntries(graph));
// { '0': [ 1, 2 ], '1': [ 0, 2 ], '2': [ 0, 1, 3 ], '3': [ 2 ] }
```
```java +
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Map<Integer, List<Integer>> graph = new LinkedHashMap<>();
        int[][] edges = {{0, 1}, {0, 2}, {1, 2}, {2, 3}};
        for (int[] edge : edges) {
            int u = edge[0];
            int v = edge[1];
            graph.computeIfAbsent(u, k -> new ArrayList<>()).add(v);
            graph.computeIfAbsent(v, k -> new ArrayList<>()).add(u); // omit this line for a directed graph
        }

        System.out.println(graph);
        // {0=[1, 2], 1=[0, 2], 2=[0, 1, 3], 3=[2]}
    }
}
```

**Adjacency matrix**: an `n x n` grid where `matrix[i][j] = 1` if an edge exists.

```python
n = 4
matrix = [[0] * n for _ in range(n)]
for u, v in edges:
    matrix[u][v] = 1
    matrix[v][u] = 1
```
```javascript +
const n = 4;
const edges = [[0, 1], [0, 2], [1, 2], [2, 3]];
const matrix = Array.from({ length: n }, () => new Array(n).fill(0));
for (const [u, v] of edges) {
    matrix[u][v] = 1;
    matrix[v][u] = 1;
}
```
```java +
import java.util.Arrays;

public class Main {
    public static void main(String[] args) {
        int n = 4;
        int[][] edges = {{0, 1}, {0, 2}, {1, 2}, {2, 3}};
        int[][] matrix = new int[n][n];
        for (int[] edge : edges) {
            int u = edge[0];
            int v = edge[1];
            matrix[u][v] = 1;
            matrix[v][u] = 1;
        }

        for (int[] row : matrix) {
            System.out.println(Arrays.toString(row));
        }
    }
}
```

| | Adjacency list | Adjacency matrix |
|---|---|---|
| Space | O(V + E) | O(V²) |
| "Are u, v connected?" | O(degree(u)) | O(1) |
| Iterate neighbors of u | O(degree(u)) | O(V) |
| Best for | Sparse graphs (most interview problems) | Dense graphs, small V, or when you need O(1) edge lookup |

**Pitfall:** grid problems (Number of Islands, Rotting Oranges) don't hand you a graph object at all. The 2D grid itself is the implicit adjacency structure, with a cell's neighbors being the 4 (or 8) cells around it. Recognizing that a grid IS a graph is half the battle.

> **Remember:** most interview graphs are sparse, so default to an adjacency list. A grid is a graph in disguise; its cells are nodes, adjacency is "next door."

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-representation-q1", "type": "mcq",
      "prompt": "Why do most interview problems default to an adjacency list instead of an adjacency matrix?",
      "options": [
        {"id": "a", "text": "Most interview graphs are sparse, and a list uses O(V + E) space instead of O(V²)"},
        {"id": "b", "text": "Adjacency matrices can't represent directed graphs"},
        {"id": "c", "text": "Adjacency lists are always faster for every operation"},
        {"id": "d", "text": "Matrices can only hold numeric node labels"}
      ],
      "correct": "a",
      "explanation": "A sparse graph has far fewer edges than the V² an adjacency matrix would allocate. The list only stores space proportional to the edges that actually exist, which is the common case in interview problems." }
] }
```

## Choosing BFS or DFS

Both visit every reachable node exactly once, but they explore in different orders and answer different questions.

| | BFS | DFS |
|---|---|---|
| Data structure | Queue (FIFO) | Stack (explicit) or recursion (call stack) |
| Explores | Level by level, outward from the source | One path all the way down before backtracking |
| Use for | Shortest path in an unweighted graph, "minimum steps", spreading from multiple sources | Path existence, connected components, cycle detection, backtracking, topological order |
| Space | O(V), can hold a full level | O(V) worst case (deep recursion), often less for wide, shallow graphs |

Rule of thumb: **if the question says "shortest," "minimum," or "fewest steps," reach for BFS.** If it says "does a path exist," "find all paths," or "explore everything," DFS, often recursive, is simpler to write and reason about.

> **Remember:** "shortest" or "fewest steps" means BFS. "Does a path exist" or "find all X" means DFS.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-choosing-q1", "type": "mcq",
      "prompt": "A problem asks for the minimum number of moves to reach a target cell. Which traversal should you reach for first?",
      "options": [
        {"id": "a", "text": "BFS, since it explores level by level and finds the shortest path in an unweighted graph"},
        {"id": "b", "text": "DFS, since it's simpler to write"},
        {"id": "c", "text": "Either works equally well for shortest-path questions"},
        {"id": "d", "text": "Neither; shortest path always needs Dijkstra's algorithm"}
      ],
      "correct": "a",
      "explanation": "BFS visits nodes in order of distance from the source, so the first time it reaches the target is guaranteed to be via the shortest path, as long as edges are unweighted." }
] }
```

## Marking nodes visited at the right moment

Without tracking visited nodes, a cyclic graph causes an infinite loop. The detail interviewers probe hardest: **mark a node visited the moment you enqueue or push it, not when you pop it.**

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
```javascript +
function bfs(graph, start) {
    const visited = new Set([start]); // mark on enqueue
    const queue = [start];
    const order = [];
    while (queue.length > 0) {
        const node = queue.shift();
        order.push(node);
        for (const neighbor of graph.get(node) ?? []) {
            if (!visited.has(neighbor)) {
                visited.add(neighbor); // mark here, not after popping
                queue.push(neighbor);
            }
        }
    }
    return order;
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        Map<Integer, List<Integer>> graph = Map.of(
                0, List.of(1, 2),
                1, List.of(0, 2),
                2, List.of(0, 1, 3),
                3, List.of(2)
        );
        System.out.println(bfs(graph, 0));
    }

    static List<Integer> bfs(Map<Integer, List<Integer>> graph, int start) {
        Set<Integer> visited = new HashSet<>();
        visited.add(start); // mark on enqueue
        Deque<Integer> queue = new ArrayDeque<>();
        queue.add(start);
        List<Integer> order = new ArrayList<>();
        while (!queue.isEmpty()) {
            int node = queue.poll();
            order.add(node);
            for (int neighbor : graph.getOrDefault(node, List.of())) {
                if (!visited.contains(neighbor)) {
                    visited.add(neighbor); // mark here, not after popping
                    queue.add(neighbor);
                }
            }
        }
        return order;
    }
}
```

Mark visited only at pop time instead, and the same node can land in the queue multiple times before it's ever processed. That's wasted work at best, and in multi-source variants it can produce wrong answers. For grids, `visited` is usually a 2D boolean array, or you mutate the grid in place (flipping `'1'` to `'0'`, say) to save space.

> **Remember:** mark visited at enqueue/push time, not at pop/process time. Marking late lets duplicates pile into the queue.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-visited-q1", "type": "mcq",
      "prompt": "What goes wrong if you mark a node visited only when you pop it from the BFS queue, instead of when you enqueue it?",
      "options": [
        {"id": "a", "text": "The same node can be enqueued multiple times before it's processed, wasting work or breaking multi-source variants"},
        {"id": "b", "text": "BFS will visit nodes in the wrong order entirely"},
        {"id": "c", "text": "It has no effect either way"},
        {"id": "d", "text": "It makes BFS behave like DFS"}
      ],
      "correct": "a",
      "explanation": "If visited is only checked, not set, at enqueue time, a node can be discovered as a neighbor of several different nodes before it's ever popped, so it gets pushed into the queue more than once." }
] }
```

## Number of Islands

[LeetCode 200](https://leetcode.com/problems/number-of-islands/), DFS/BFS, Grid traversal

Each connected group of `'1'`s is one island. Scan every cell; whenever you find an unvisited `'1'`, that's a brand-new island, so flood-fill it (DFS or BFS) to mark every connected land cell and avoid counting it twice.

**Approach:** Iterate all cells. On an unvisited land cell, increment the island count and run DFS/BFS to sink the entire connected component (mutate it to `'0'` as "visited").

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
```javascript +
function numIslands(grid) {
    if (grid.length === 0) {
        return 0;
    }
    const rows = grid.length;
    const cols = grid[0].length;

    function dfs(r, c) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] !== '1') {
            return;
        }
        grid[r][c] = '0'; // sink it so we never revisit
        dfs(r + 1, c);
        dfs(r - 1, c);
        dfs(r, c + 1);
        dfs(r, c - 1);
    }

    let islands = 0;
    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            if (grid[r][c] === '1') {
                islands += 1;
                dfs(r, c);
            }
        }
    }
    return islands;
}
```
```java +
public class Main {
    static int rows;
    static int cols;

    public static void main(String[] args) {
        char[][] grid = {
                {'1', '1', '0', '0'},
                {'1', '1', '0', '0'},
                {'0', '0', '1', '0'},
                {'0', '0', '0', '1'}
        };
        System.out.println(numIslands(grid));
    }

    static int numIslands(char[][] grid) {
        if (grid.length == 0) {
            return 0;
        }
        rows = grid.length;
        cols = grid[0].length;

        int islands = 0;
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == '1') {
                    islands += 1;
                    dfs(grid, r, c);
                }
            }
        }
        return islands;
    }

    static void dfs(char[][] grid, int r, int c) {
        if (r < 0 || r >= rows || c < 0 || c >= cols || grid[r][c] != '1') {
            return;
        }
        grid[r][c] = '0'; // sink it so we never revisit
        dfs(grid, r + 1, c);
        dfs(grid, r - 1, c);
        dfs(grid, r, c + 1);
        dfs(grid, r, c - 1);
    }
}
```

**Complexity:** Time O(rows × cols), each cell is visited a constant number of times. Space O(rows × cols) worst case for the recursion stack, when the grid is entirely land.

**Common mistakes:** Forgetting boundary checks before indexing, which crashes with an out-of-range error. Mutating the grid without realizing the interviewer may not want the input destroyed; mention the trade-off and offer a separate `visited` set as an alternative. Using DFS recursion on a huge grid can hit a recursion-depth limit, something BFS with an explicit queue avoids entirely.

> **Remember:** scan every cell; each unvisited land cell you find starts a new island. Flood-fill it so you never count it again.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-islands-q1", "type": "mcq",
      "prompt": "Why does mutating grid[r][c] to '0' after visiting it prevent double-counting islands?",
      "options": [
        {"id": "a", "text": "It marks the cell as no longer land, so the outer scan and the flood-fill both skip it on any later visit"},
        {"id": "b", "text": "It changes the island's shape"},
        {"id": "c", "text": "It has no effect on the count; islands+=1 alone prevents double counting"},
        {"id": "d", "text": "It's only needed for BFS, not DFS"}
      ],
      "correct": "a",
      "explanation": "Sinking a visited land cell to '0' acts as a visited marker built into the grid itself. Since the outer loop and the flood-fill both check for '1', a sunk cell is never picked up again by either." }
] }
```

## Clone Graph

[LeetCode 133](https://leetcode.com/problems/clone-graph/), BFS/DFS, Deep copy

You must build a completely new graph with new node objects, while preserving the same connections. The trick is avoiding infinite loops on cycles: keep a map from original node to cloned node so you never clone the same node twice.

**Approach:** BFS or DFS from the given start node. Use a hash map `old -> new`. Whenever you meet a neighbor you haven't cloned yet, create its clone and enqueue it; either way, append the clone to the current node's clone's neighbor list.

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
```javascript +
class Node {
    constructor(val = 0, neighbors = null) {
        this.val = val;
        this.neighbors = neighbors !== null ? neighbors : [];
    }
}

function cloneGraph(node) {
    if (!node) {
        return null;
    }

    const oldToNew = new Map([[node, new Node(node.val)]]);
    const queue = [node];

    while (queue.length > 0) {
        const cur = queue.shift();
        for (const neighbor of cur.neighbors) {
            if (!oldToNew.has(neighbor)) {
                oldToNew.set(neighbor, new Node(neighbor.val));
                queue.push(neighbor);
            }
            oldToNew.get(cur).neighbors.push(oldToNew.get(neighbor));
        }
    }

    return oldToNew.get(node);
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        Node a = new Node(1);
        Node b = new Node(2);
        a.neighbors.add(b);
        b.neighbors.add(a);

        Node clonedA = cloneGraph(a);
        System.out.println("Cloned root val: " + clonedA.val + ", neighbor count: " + clonedA.neighbors.size());
    }

    static Node cloneGraph(Node node) {
        if (node == null) {
            return null;
        }

        Map<Node, Node> oldToNew = new HashMap<>();
        oldToNew.put(node, new Node(node.val));
        Deque<Node> queue = new ArrayDeque<>();
        queue.add(node);

        while (!queue.isEmpty()) {
            Node cur = queue.poll();
            for (Node neighbor : cur.neighbors) {
                if (!oldToNew.containsKey(neighbor)) {
                    oldToNew.put(neighbor, new Node(neighbor.val));
                    queue.add(neighbor);
                }
                oldToNew.get(cur).neighbors.add(oldToNew.get(neighbor));
            }
        }

        return oldToNew.get(node);
    }
}

class Node {
    int val;
    List<Node> neighbors = new ArrayList<>();

    Node(int val) {
        this.val = val;
    }
}
```

**Complexity:** Time O(V + E), space O(V) for the map and queue.

**Common mistakes:** Cloning a neighbor's value instead of wiring up the actual clone object. Not handling the single-node-with-no-neighbors edge case. Re-cloning a node already in the map; always check the map before creating a new `Node`.

> **Remember:** a map from old node to new node is what stops a cycle from cloning the same node twice, or looping forever.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-clone-q1", "type": "mcq",
      "prompt": "What role does the old-to-new hash map play in Clone Graph?",
      "options": [
        {"id": "a", "text": "It prevents re-cloning the same node twice and avoids infinite loops on cyclic graphs"},
        {"id": "b", "text": "It stores the final answer directly"},
        {"id": "c", "text": "It sorts nodes by value before cloning"},
        {"id": "d", "text": "It's only needed for graphs with more than 100 nodes"}
      ],
      "correct": "a",
      "explanation": "Without the map, a cycle (A points to B, B points back to A) would cause the clone process to keep creating new clones of the same nodes forever. Checking the map before cloning ensures each original node is cloned exactly once." }
] }
```

## Rotting Oranges

[LeetCode 994](https://leetcode.com/problems/rotting-oranges/), BFS, Multi-source BFS

Every rotten orange rots its fresh neighbors at the same time, one minute at a time. That is BFS starting from multiple sources at once: seed the queue with every initially-rotten orange, then expand level by level, where each level equals exactly one minute.

**Approach:** Push all rotten cells into the queue first (minute 0). Track the `fresh` count. BFS level by level; each level that rots at least one orange increments the minute counter. If `fresh > 0` after the BFS runs out, return -1.

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
```javascript +
function orangesRotting(grid) {
    const rows = grid.length;
    const cols = grid[0].length;
    const queue = [];
    let fresh = 0;

    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            if (grid[r][c] === 2) {
                queue.push([r, c]);
            } else if (grid[r][c] === 1) {
                fresh += 1;
            }
        }
    }

    let minutes = 0;
    const directions = [[1, 0], [-1, 0], [0, 1], [0, -1]];

    while (queue.length > 0 && fresh > 0) {
        minutes += 1;
        const levelSize = queue.length; // process one full level = one minute
        for (let i = 0; i < levelSize; i++) {
            const [r, c] = queue.shift();
            for (const [dr, dc] of directions) {
                const nr = r + dr;
                const nc = c + dc;
                if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] === 1) {
                    grid[nr][nc] = 2;
                    fresh -= 1;
                    queue.push([nr, nc]);
                }
            }
        }
    }

    return fresh === 0 ? minutes : -1;
}
```
```java +
import java.util.ArrayDeque;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        int[][] grid = {
                {2, 1, 1},
                {1, 1, 0},
                {0, 1, 1}
        };
        System.out.println(orangesRotting(grid));
    }

    static int orangesRotting(int[][] grid) {
        int rows = grid.length;
        int cols = grid[0].length;
        Deque<int[]> queue = new ArrayDeque<>();
        int fresh = 0;

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (grid[r][c] == 2) {
                    queue.add(new int[]{r, c});
                } else if (grid[r][c] == 1) {
                    fresh += 1;
                }
            }
        }

        int minutes = 0;
        int[][] directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        while (!queue.isEmpty() && fresh > 0) {
            minutes += 1;
            int levelSize = queue.size(); // process one full level = one minute
            for (int i = 0; i < levelSize; i++) {
                int[] cell = queue.poll();
                int r = cell[0];
                int c = cell[1];
                for (int[] dir : directions) {
                    int nr = r + dir[0];
                    int nc = c + dir[1];
                    if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] == 1) {
                        grid[nr][nc] = 2;
                        fresh -= 1;
                        queue.add(new int[]{nr, nc});
                    }
                }
            }
        }

        return fresh == 0 ? minutes : -1;
    }
}
```

**Complexity:** Time O(rows × cols), space O(rows × cols) for the queue.

**Common mistakes:** Incrementing `minutes` even on a final level where nothing new rotted. The level-batching pattern above handles this correctly; verify it against the "no fresh oranges at all" edge case, which should return 0. Forgetting multi-source seeding and instead running BFS from just one rotten cell.

> **Remember:** seed the queue with every rotten orange at once. One BFS level equals exactly one minute passing.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-rotting-oranges-q1", "type": "mcq",
      "prompt": "Why does Rotting Oranges start BFS by pushing ALL initially-rotten cells into the queue at once, instead of one at a time?",
      "options": [
        {"id": "a", "text": "All rotten oranges rot their neighbors simultaneously each minute, so BFS needs every rotten cell as a starting source"},
        {"id": "b", "text": "Pushing one at a time would give a wrong final count but the same minute total"},
        {"id": "c", "text": "It's only a minor optimization with no effect on correctness"},
        {"id": "d", "text": "BFS requires exactly one starting node by definition"}
      ],
      "correct": "a",
      "explanation": "The problem's real-world rule is that every rotten orange spreads at the same time each minute. Seeding all of them at once and processing one full BFS level per minute directly models that simultaneous spread; seeding one at a time would compute the wrong timeline entirely." }
] }
```

## Walls and Gates

[LeetCode 286](https://leetcode.com/problems/walls-and-gates/), BFS, Fill distances

Same multi-source BFS pattern as Rotting Oranges, but instead of counting minutes, you write the BFS depth directly into each empty room as its distance to the nearest gate.

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
```javascript +
const INF = 2147483647;

function wallsAndGates(rooms) {
    if (rooms.length === 0) {
        return;
    }
    const rows = rooms.length;
    const cols = rooms[0].length;
    const queue = [];

    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            if (rooms[r][c] === 0) {
                queue.push([r, c]);
            }
        }
    }

    const directions = [[1, 0], [-1, 0], [0, 1], [0, -1]];
    while (queue.length > 0) {
        const [r, c] = queue.shift();
        for (const [dr, dc] of directions) {
            const nr = r + dr;
            const nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && rooms[nr][nc] === INF) {
                rooms[nr][nc] = rooms[r][c] + 1;
                queue.push([nr, nc]);
            }
        }
    }
}
```
```java +
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

public class Main {
    static final int INF = Integer.MAX_VALUE;

    public static void main(String[] args) {
        int[][] rooms = {
                {INF, -1, 0, INF},
                {INF, INF, INF, -1},
                {INF, -1, INF, -1},
                {0, -1, INF, INF}
        };
        wallsAndGates(rooms);
        for (int[] row : rooms) {
            System.out.println(Arrays.toString(row));
        }
    }

    static void wallsAndGates(int[][] rooms) {
        if (rooms.length == 0) {
            return;
        }
        int rows = rooms.length;
        int cols = rooms[0].length;
        Deque<int[]> queue = new ArrayDeque<>();

        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (rooms[r][c] == 0) {
                    queue.add(new int[]{r, c});
                }
            }
        }

        int[][] directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
        while (!queue.isEmpty()) {
            int[] cell = queue.poll();
            int r = cell[0];
            int c = cell[1];
            for (int[] dir : directions) {
                int nr = r + dir[0];
                int nc = c + dir[1];
                if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && rooms[nr][nc] == INF) {
                    rooms[nr][nc] = rooms[r][c] + 1;
                    queue.add(new int[]{nr, nc});
                }
            }
        }
    }
}
```

**Complexity:** Time O(rows × cols), space O(rows × cols).

**Common mistakes:** Running BFS separately from every gate instead of seeding all gates into one shared queue. That still gives the correct answer, but it costs O(gates × cells) instead of O(cells); mention the multi-source optimization explicitly, since interviewers look for it. Walls (`-1`) should simply be skipped, not treated as an error case.

> **Remember:** seed every gate into one shared queue, one BFS. Don't run a separate BFS per gate.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-bfs-dfs-walls-gates-q1", "type": "mcq",
      "prompt": "What is the benefit of seeding all gates into one shared BFS queue at once, rather than running a separate BFS from each gate?",
      "options": [
        {"id": "a", "text": "It reduces the total cost from O(gates × cells) to O(cells)"},
        {"id": "b", "text": "It's required for the algorithm to produce a correct answer at all"},
        {"id": "c", "text": "It reduces the space used by the grid itself"},
        {"id": "d", "text": "Running per-gate BFS produces a different, wrong distance value"}
      ],
      "correct": "a",
      "explanation": "A separate BFS per gate would each visit up to every cell, multiplying cost by the number of gates. A single multi-source BFS visits each cell once total, since the first time a room is reached is guaranteed to be via its nearest gate." }
] }
```
