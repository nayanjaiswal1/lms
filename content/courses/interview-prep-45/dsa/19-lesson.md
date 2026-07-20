---
kind: lesson
id_key: interview-prep-45/day-19
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 19 — Union Find / DSU"
position: 19
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---
Union-Find (Disjoint Set Union) answers one question extremely fast: "are these two elements in the same group?" and "merge these two groups." It replaces BFS/DFS connectivity checks that would otherwise be O(n) per query with near-O(1) amortized operations, and it's the difference between a working solution and a timeout on problems involving dynamic connectivity (edges arriving one at a time, as in Number of Islands II).

## Find with path compression

`find(x)` walks up the parent pointers from `x` until it reaches the root of `x`'s tree (a node that is its own parent). Without any optimization, this walk can be O(n) in a degenerate, chain-like tree. Path compression fixes this: while walking up to find the root, rewire every visited node to point directly at the root. The next `find` call on any of those nodes is then O(1).

```python
def find(self, x: int) -> int:
    if self.parent[x] != x:
        self.parent[x] = self.find(self.parent[x])   # path compression
    return self.parent[x]
```

This is a recursive one-liner but it's doing real work: the recursive call returns the root, and the assignment `self.parent[x] = ...` flattens `x`'s pointer to point directly at that root, permanently shortening the path for every future call through `x`.

## Union by rank

`union(x, y)` merges the two trees containing `x` and `y` by attaching one tree's root under the other's. Naively attaching arbitrarily can build a tall, unbalanced tree over many unions. Union by rank (or by size) always attaches the shorter/smaller tree under the taller/larger one's root, keeping the overall tree shallow.

```python
def union(self, x: int, y: int) -> None:
    root_x, root_y = self.find(x), self.find(y)
    if root_x == root_y:
        return   # already connected
    if self.rank[root_x] < self.rank[root_y]:
        root_x, root_y = root_y, root_x
    self.parent[root_y] = root_x
    if self.rank[root_x] == self.rank[root_y]:
        self.rank[root_x] += 1
```

Combined, path compression and union by rank give an amortized time complexity of O(α(n)) per operation, where α is the inverse Ackermann function — for any `n` you could conceivably encounter, α(n) ≤ 4, which is why this is described as "nearly O(1)."

## Cycle detection in graphs

DSU gives an elegant way to detect cycles while building a graph edge by edge: before adding an edge `(u, v)`, check `find(u) == find(v)`. If they're already in the same component, this edge would create a cycle — don't union them (or, if you do, you've just confirmed a cycle exists). This is exactly how Kruskal's MST algorithm decides which edges to keep, and it's the core of Graph Valid Tree below.

```python
def has_cycle_on_add(self, u: int, v: int) -> bool:
    if self.find(u) == self.find(v):
        return True   # adding this edge would close a cycle
    self.union(u, v)
    return False
```

### Number of Connected Components in an Undirected Graph

[LeetCode 323 — Number of Connected Components](https://leetcode.com/problems/number-of-connected-components-in-an-undirected-graph/) — DSU

**Intuition:** Start with `n` components (every node isolated). Each edge that connects two *different* components reduces the component count by one; an edge between nodes already in the same component doesn't change anything.

**Approach:** Initialize DSU with `n` singleton sets. Union across every edge; track the count directly by decrementing on a successful union (root differs).

```python
class DSU:
    def __init__(self, n: int) -> None:
        self.parent = list(range(n))
        self.rank = [0] * n
        self.count = n   # number of distinct components

    def find(self, x: int) -> int:
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])
        return self.parent[x]

    def union(self, x: int, y: int) -> None:
        root_x, root_y = self.find(x), self.find(y)
        if root_x == root_y:
            return
        if self.rank[root_x] < self.rank[root_y]:
            root_x, root_y = root_y, root_x
        self.parent[root_y] = root_x
        if self.rank[root_x] == self.rank[root_y]:
            self.rank[root_x] += 1
        self.count -= 1


def count_components(n: int, edges: list[list[int]]) -> int:
    dsu = DSU(n)
    for u, v in edges:
        dsu.union(u, v)
    return dsu.count
```

**Complexity:** O(n + E * α(n)) time, O(n) space. This `DSU` class is the reusable template for all four problems today.

**Common mistakes:** recomputing the component count with a separate pass over `find(i)` for every node instead of tracking it incrementally in `union`; forgetting path compression, which degrades `find` to O(n) on adversarial inputs (a chain graph).

### Longest Consecutive Sequence

[LeetCode 128 — Longest Consecutive Sequence](https://leetcode.com/problems/longest-consecutive-sequence/) — DSU

**Intuition:** Values that are consecutive integers (`x` and `x+1`) belong in the same "run." Union every value with `value + 1` if that neighbor is present in the array, then the answer is the size of the largest resulting component. (The hash-set expand-from-start approach is O(n) and usually preferred in an interview, but DSU is worth knowing since today's topic is DSU, and the same "union adjacent related values" idea recurs elsewhere.)

**Approach:** Map each value to an index. Union `value` with `value + 1` whenever both are present. Track component sizes in the DSU to answer "largest run" directly.

```python
def longest_consecutive(nums: list[int]) -> int:
    if not nums:
        return 0

    unique_nums = list(set(nums))
    index_of = {num: i for i, num in enumerate(unique_nums)}
    n = len(unique_nums)

    parent = list(range(n))
    size = [1] * n

    def find(x: int) -> int:
        if parent[x] != x:
            parent[x] = find(parent[x])
        return parent[x]

    def union(x: int, y: int) -> None:
        rx, ry = find(x), find(y)
        if rx == ry:
            return
        if size[rx] < size[ry]:
            rx, ry = ry, rx
        parent[ry] = rx
        size[rx] += size[ry]

    for num in unique_nums:
        if num + 1 in index_of:
            union(index_of[num], index_of[num + 1])

    return max(size[find(i)] for i in range(n))
```

**Complexity:** O(n * α(n)) time, O(n) space. The pure hash-set approach (expand upward from numbers that have no `num - 1` predecessor) achieves plain O(n) without DSU overhead — mention both, lead with whichever the interviewer seems to want.

**Common mistakes:** unioning by raw value instead of by index (DSU arrays are indexed 0..n-1, not by arbitrary integer value); forgetting to dedupe the input first, which wastes work re-processing duplicate values.

### Graph Valid Tree

[LeetCode 261 — Graph Valid Tree](https://leetcode.com/problems/graph-valid-tree/) — DSU

**Intuition:** A graph with `n` nodes is a valid tree if and only if it has exactly `n - 1` edges AND is fully connected (no cycles, no separate components). DSU checks both conditions in one pass: if any edge connects two nodes already in the same component, that's a cycle — immediately invalid.

**Approach:** Quick edge-count check first (`len(edges) != n - 1` fails immediately, avoiding wasted DSU work). Then union each edge, failing fast on any cycle detection.

```python
def valid_tree(n: int, edges: list[list[int]]) -> bool:
    if len(edges) != n - 1:
        return False   # too many edges (cycle) or too few (disconnected)

    parent = list(range(n))

    def find(x: int) -> int:
        if parent[x] != x:
            parent[x] = find(parent[x])
        return parent[x]

    for u, v in edges:
        root_u, root_v = find(u), find(v)
        if root_u == root_v:
            return False   # cycle detected
        parent[root_v] = root_u

    return True
```

**Complexity:** O(n * α(n)) time, O(n) space.

**Common mistakes:** skipping the `len(edges) != n - 1` pre-check and relying purely on cycle detection — a graph can be cycle-free but still disconnected (a forest), and edge count is what rules that out cheaply; forgetting that a valid tree also requires connectivity, not just acyclicity.

### Number of Islands II

[LeetCode 305 — Number of Islands II](https://leetcode.com/problems/number-of-islands-ii/) — DSU — Hard

**Intuition:** Land cells are added one at a time, and after each addition you need the current island count. Recomputing with BFS/DFS after every addition is O(n) per query — DSU processes each addition in near-O(1), which is the entire reason DSU exists for *dynamic* (incremental) connectivity problems, as opposed to static ones where BFS/DFS is simpler.

**Approach:** Maintain a DSU over the grid's flattened cell indices, plus a `land` set/grid tracking which cells are filled. On each new land cell, increment the island count by 1 (a new component), then union with any of its 4 already-land neighbors, decrementing the count once per successful merge.

```python
def num_islands2(m: int, n: int, positions: list[list[int]]) -> list[int]:
    parent = {}
    rank = {}
    land = set()
    result = []
    count = 0

    def find(x: int) -> int:
        if parent[x] != x:
            parent[x] = find(parent[x])
        return parent[x]

    def union(x: int, y: int) -> bool:
        rx, ry = find(x), find(y)
        if rx == ry:
            return False
        if rank[rx] < rank[ry]:
            rx, ry = ry, rx
        parent[ry] = rx
        if rank[rx] == rank[ry]:
            rank[rx] += 1
        return True

    for r, c in positions:
        idx = r * n + c
        if idx in land:
            result.append(count)   # duplicate addition, no change
            continue
        land.add(idx)
        parent[idx] = idx
        rank[idx] = 0
        count += 1

        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            n_idx = nr * n + nc
            if 0 <= nr < m and 0 <= nc < n and n_idx in land:
                if union(idx, n_idx):
                    count -= 1

        result.append(count)

    return result
```

**Complexity:** O(k * α(k)) time for `k` position updates, O(k) space (only land cells get DSU entries — a dict-based sparse DSU, not a full `m*n` array).

**Common mistakes:** allocating a dense `parent` array of size `m*n` when a dict keyed by only-visited cells is both simpler and avoids wasted memory for large sparse grids; forgetting to handle duplicate positions in the input (the same cell can appear twice — must not double-count it as a new island); not decrementing `count` on every successful union (each merge reduces the island count by exactly one, and a cell can merge with up to 4 neighbors).

## Key takeaways

- Path compression + union by rank together give amortized O(α(n)) — nearly O(1) — per operation.
- `find` should always compress the path on the way up; `union` should always attach the smaller/shorter tree under the larger/taller one.
- Cycle detection with DSU is just: "if `find(u) == find(v)` before unioning, this edge closes a cycle."
- Graph Valid Tree needs both the edge-count check (`n - 1` edges) and the cycle check — acyclic alone doesn't guarantee connectivity.
- DSU shines specifically for *dynamic* / incremental connectivity (edges or nodes arriving over time, as in Number of Islands II) — for static, one-shot connectivity questions, BFS/DFS is simpler and equally efficient.
- Use a dict-based sparse DSU when the universe of elements is large but only a few are ever touched.

## Today's checklist

- [ ] Solve Number of Connected Components (LeetCode 323)
- [ ] Solve Longest Consecutive Sequence (LeetCode 128)
- [ ] Solve Graph Valid Tree (LeetCode 261)
- [ ] Solve Number of Islands II (LeetCode 305)
- [ ] Implement DSU with both path compression and union by rank
- [ ] Compare DSU's incremental approach against a BFS/DFS re-scan approach
- [ ] Memorize: DSU is nearly O(1) amortized per operation
- [ ] Review when to reach for DSU vs. plain DFS/BFS
