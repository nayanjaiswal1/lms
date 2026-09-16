---
kind: lesson
id_key: interview-prep-45/day-19
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Union Find / DSU"
position: 19
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
---
Union-Find (Disjoint Set Union) answers one question extremely fast: "are these two elements in the same group?" and "merge these two groups." It replaces BFS/DFS connectivity checks that would otherwise be O(n) per query with near-O(1) amortized operations, and it's the difference between a working solution and a timeout on problems involving dynamic connectivity, edges arriving one at a time, as in Number of Islands II.

## Find with path compression

`find(x)` walks up the parent pointers from `x` until it reaches the root of `x`'s tree (a node that is its own parent). Without any optimization, this walk can be O(n) in a degenerate, chain-like tree. Path compression fixes this: while walking up to find the root, rewire every visited node to point directly at the root. The next `find` call on any of those nodes is then O(1).

```python
def find(self, x: int) -> int:
    if self.parent[x] != x:
        self.parent[x] = self.find(self.parent[x])   # path compression
    return self.parent[x]
```

```javascript +
function find(x) {
    if (this.parent[x] !== x) {
        this.parent[x] = find.call(this, this.parent[x]); // path compression
    }
    return this.parent[x];
}
```

```java +
public class Main {
    public static void main(String[] args) {
        DSU dsu = new DSU(new int[]{0, 0, 1, 3});
        System.out.println(dsu.find(3));
    }
}

class DSU {
    int[] parent;

    DSU(int[] parent) {
        this.parent = parent;
    }

    int find(int x) {
        if (parent[x] != x) {
            parent[x] = find(parent[x]); // path compression
        }
        return parent[x];
    }
}
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

```javascript +
function union(x, y) {
    let rootX = find.call(this, x);
    let rootY = find.call(this, y);
    if (rootX === rootY) {
        return; // already connected
    }
    if (this.rank[rootX] < this.rank[rootY]) {
        [rootX, rootY] = [rootY, rootX];
    }
    this.parent[rootY] = rootX;
    if (this.rank[rootX] === this.rank[rootY]) {
        this.rank[rootX]++;
    }
}
```

```java +
public class Main {
    public static void main(String[] args) {
        DSU dsu = new DSU(4);
        dsu.union(0, 1);
        dsu.union(2, 3);
        System.out.println(dsu.find(1) == dsu.find(0));
    }
}

class DSU {
    int[] parent;
    int[] rank;

    DSU(int n) {
        parent = new int[n];
        rank = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;
    }

    int find(int x) {
        if (parent[x] != x) {
            parent[x] = find(parent[x]);
        }
        return parent[x];
    }

    void union(int x, int y) {
        int rootX = find(x);
        int rootY = find(y);
        if (rootX == rootY) {
            return; // already connected
        }
        if (rank[rootX] < rank[rootY]) {
            int tmp = rootX;
            rootX = rootY;
            rootY = tmp;
        }
        parent[rootY] = rootX;
        if (rank[rootX] == rank[rootY]) {
            rank[rootX]++;
        }
    }
}
```

Combined, path compression and union by rank give an amortized time complexity of O(α(n)) per operation, where α is the inverse Ackermann function. For any `n` you could conceivably encounter, α(n) ≤ 4, which is why this is described as "nearly O(1)."

## Cycle detection in graphs

DSU gives an elegant way to detect cycles while building a graph edge by edge: before adding an edge `(u, v)`, check `find(u) == find(v)`. If they're already in the same component, this edge would create a cycle, so don't union them (or, if you do, you've just confirmed a cycle exists). This is exactly how Kruskal's MST algorithm decides which edges to keep, and it's the core of Graph Valid Tree below.

```python
def has_cycle_on_add(self, u: int, v: int) -> bool:
    if self.find(u) == self.find(v):
        return True   # adding this edge would close a cycle
    self.union(u, v)
    return False
```

```javascript +
function hasCycleOnAdd(u, v) {
    if (find.call(this, u) === find.call(this, v)) {
        return true; // adding this edge would close a cycle
    }
    union.call(this, u, v);
    return false;
}
```

```java +
public class Main {
    public static void main(String[] args) {
        DSU dsu = new DSU(4);
        System.out.println(dsu.hasCycleOnAdd(0, 1));
        System.out.println(dsu.hasCycleOnAdd(1, 0));
    }
}

class DSU {
    int[] parent;
    int[] rank;

    DSU(int n) {
        parent = new int[n];
        rank = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;
    }

    int find(int x) {
        if (parent[x] != x) {
            parent[x] = find(parent[x]);
        }
        return parent[x];
    }

    void union(int x, int y) {
        int rootX = find(x);
        int rootY = find(y);
        if (rootX == rootY) return;
        if (rank[rootX] < rank[rootY]) {
            int tmp = rootX;
            rootX = rootY;
            rootY = tmp;
        }
        parent[rootY] = rootX;
        if (rank[rootX] == rank[rootY]) {
            rank[rootX]++;
        }
    }

    boolean hasCycleOnAdd(int u, int v) {
        if (find(u) == find(v)) {
            return true; // adding this edge would close a cycle
        }
        union(u, v);
        return false;
    }
}
```

### Number of Connected Components in an Undirected Graph

[LeetCode 323 · Number of Connected Components](https://leetcode.com/problems/number-of-connected-components-in-an-undirected-graph/) · DSU

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

```javascript +
class DSU {
    constructor(n) {
        this.parent = Array.from({ length: n }, (_, i) => i);
        this.rank = new Array(n).fill(0);
        this.count = n; // number of distinct components
    }

    find(x) {
        if (this.parent[x] !== x) {
            this.parent[x] = this.find(this.parent[x]);
        }
        return this.parent[x];
    }

    union(x, y) {
        let rootX = this.find(x);
        let rootY = this.find(y);
        if (rootX === rootY) return;
        if (this.rank[rootX] < this.rank[rootY]) {
            [rootX, rootY] = [rootY, rootX];
        }
        this.parent[rootY] = rootX;
        if (this.rank[rootX] === this.rank[rootY]) {
            this.rank[rootX]++;
        }
        this.count--;
    }
}

function countComponents(n, edges) {
    const dsu = new DSU(n);
    for (const [u, v] of edges) {
        dsu.union(u, v);
    }
    return dsu.count;
}
```

```java +
public class Main {
    public static void main(String[] args) {
        int[][] edges = {{0, 1}, {1, 2}, {3, 4}};
        System.out.println(countComponents(5, edges));
    }

    static int countComponents(int n, int[][] edges) {
        DSU dsu = new DSU(n);
        for (int[] edge : edges) {
            dsu.union(edge[0], edge[1]);
        }
        return dsu.count;
    }
}

class DSU {
    int[] parent;
    int[] rank;
    int count;

    DSU(int n) {
        parent = new int[n];
        rank = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;
        count = n; // number of distinct components
    }

    int find(int x) {
        if (parent[x] != x) {
            parent[x] = find(parent[x]);
        }
        return parent[x];
    }

    void union(int x, int y) {
        int rootX = find(x);
        int rootY = find(y);
        if (rootX == rootY) return;
        if (rank[rootX] < rank[rootY]) {
            int tmp = rootX;
            rootX = rootY;
            rootY = tmp;
        }
        parent[rootY] = rootX;
        if (rank[rootX] == rank[rootY]) {
            rank[rootX]++;
        }
        count--;
    }
}
```

**Complexity:** O(n + E * α(n)) time, O(n) space. This `DSU` class is the reusable template for all four problems today.

**Common mistakes:** recomputing the component count with a separate pass over `find(i)` for every node instead of tracking it incrementally in `union`; forgetting path compression, which degrades `find` to O(n) on adversarial inputs, such as a chain graph.

### Longest Consecutive Sequence

[LeetCode 128 · Longest Consecutive Sequence](https://leetcode.com/problems/longest-consecutive-sequence/) · DSU

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

```javascript +
function longestConsecutive(nums) {
    if (nums.length === 0) return 0;

    const uniqueNums = Array.from(new Set(nums));
    const indexOf = new Map(uniqueNums.map((num, i) => [num, i]));
    const n = uniqueNums.length;

    const parent = Array.from({ length: n }, (_, i) => i);
    const size = new Array(n).fill(1);

    function find(x) {
        if (parent[x] !== x) {
            parent[x] = find(parent[x]);
        }
        return parent[x];
    }

    function union(x, y) {
        let rx = find(x);
        let ry = find(y);
        if (rx === ry) return;
        if (size[rx] < size[ry]) {
            [rx, ry] = [ry, rx];
        }
        parent[ry] = rx;
        size[rx] += size[ry];
    }

    for (const num of uniqueNums) {
        if (indexOf.has(num + 1)) {
            union(indexOf.get(num), indexOf.get(num + 1));
        }
    }

    let longest = 0;
    for (let i = 0; i < n; i++) {
        longest = Math.max(longest, size[find(i)]);
    }
    return longest;
}
```

```java +
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        int[] nums = {100, 4, 200, 1, 3, 2};
        System.out.println(longestConsecutive(nums));
    }

    static int longestConsecutive(int[] nums) {
        if (nums.length == 0) return 0;

        Set<Integer> uniqueSet = new HashSet<>();
        for (int num : nums) uniqueSet.add(num);
        Integer[] uniqueNums = uniqueSet.toArray(new Integer[0]);
        int n = uniqueNums.length;

        Map<Integer, Integer> indexOf = new HashMap<>();
        for (int i = 0; i < n; i++) indexOf.put(uniqueNums[i], i);

        int[] parent = new int[n];
        int[] size = new int[n];
        for (int i = 0; i < n; i++) {
            parent[i] = i;
            size[i] = 1;
        }

        for (int num : uniqueNums) {
            if (indexOf.containsKey(num + 1)) {
                union(parent, size, indexOf.get(num), indexOf.get(num + 1));
            }
        }

        int longest = 0;
        for (int i = 0; i < n; i++) {
            longest = Math.max(longest, size[find(parent, i)]);
        }
        return longest;
    }

    static int find(int[] parent, int x) {
        if (parent[x] != x) {
            parent[x] = find(parent, parent[x]);
        }
        return parent[x];
    }

    static void union(int[] parent, int[] size, int x, int y) {
        int rx = find(parent, x);
        int ry = find(parent, y);
        if (rx == ry) return;
        if (size[rx] < size[ry]) {
            int tmp = rx;
            rx = ry;
            ry = tmp;
        }
        parent[ry] = rx;
        size[rx] += size[ry];
    }
}
```

**Complexity:** O(n * α(n)) time, O(n) space. The pure hash-set approach (expand upward from numbers that have no `num - 1` predecessor) achieves plain O(n) without DSU overhead. Mention both, and lead with whichever the interviewer seems to want.

**Common mistakes:** unioning by raw value instead of by index, since DSU arrays are indexed 0..n-1, not by arbitrary integer value; forgetting to dedupe the input first, which wastes work re-processing duplicate values.

### Graph Valid Tree

[LeetCode 261 · Graph Valid Tree](https://leetcode.com/problems/graph-valid-tree/) · DSU

**Intuition:** A graph with `n` nodes is a valid tree if and only if it has exactly `n - 1` edges AND is fully connected (no cycles, no separate components). DSU checks both conditions in one pass: if any edge connects two nodes already in the same component, that's a cycle, and immediately invalid.

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

```javascript +
function validTree(n, edges) {
    if (edges.length !== n - 1) {
        return false; // too many edges (cycle) or too few (disconnected)
    }

    const parent = Array.from({ length: n }, (_, i) => i);

    function find(x) {
        if (parent[x] !== x) {
            parent[x] = find(parent[x]);
        }
        return parent[x];
    }

    for (const [u, v] of edges) {
        const rootU = find(u);
        const rootV = find(v);
        if (rootU === rootV) {
            return false; // cycle detected
        }
        parent[rootV] = rootU;
    }

    return true;
}
```

```java +
public class Main {
    public static void main(String[] args) {
        int[][] edges = {{0, 1}, {0, 2}, {0, 3}, {1, 4}};
        System.out.println(validTree(5, edges));
    }

    static boolean validTree(int n, int[][] edges) {
        if (edges.length != n - 1) {
            return false; // too many edges (cycle) or too few (disconnected)
        }

        int[] parent = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;

        for (int[] edge : edges) {
            int rootU = find(parent, edge[0]);
            int rootV = find(parent, edge[1]);
            if (rootU == rootV) {
                return false; // cycle detected
            }
            parent[rootV] = rootU;
        }

        return true;
    }

    static int find(int[] parent, int x) {
        if (parent[x] != x) {
            parent[x] = find(parent, parent[x]);
        }
        return parent[x];
    }
}
```

**Complexity:** O(n * α(n)) time, O(n) space.

**Common mistakes:** skipping the `len(edges) != n - 1` pre-check and relying purely on cycle detection: a graph can be cycle-free but still disconnected (a forest), and edge count is what rules that out cheaply; forgetting that a valid tree also requires connectivity, not just acyclicity.

### Number of Islands II

[LeetCode 305 · Number of Islands II](https://leetcode.com/problems/number-of-islands-ii/) · DSU · Hard

**Intuition:** Land cells are added one at a time, and after each addition you need the current island count. Recomputing with BFS/DFS after every addition is O(n) per query. DSU processes each addition in near-O(1), which is the entire reason DSU exists for *dynamic* (incremental) connectivity problems, as opposed to static ones where BFS/DFS is simpler.

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

```javascript +
function numIslands2(m, n, positions) {
    const parent = new Map();
    const rank = new Map();
    const land = new Set();
    const result = [];
    let count = 0;

    function find(x) {
        if (parent.get(x) !== x) {
            parent.set(x, find(parent.get(x)));
        }
        return parent.get(x);
    }

    function union(x, y) {
        let rx = find(x);
        let ry = find(y);
        if (rx === ry) return false;
        if (rank.get(rx) < rank.get(ry)) {
            [rx, ry] = [ry, rx];
        }
        parent.set(ry, rx);
        if (rank.get(rx) === rank.get(ry)) {
            rank.set(rx, rank.get(rx) + 1);
        }
        return true;
    }

    for (const [r, c] of positions) {
        const idx = r * n + c;
        if (land.has(idx)) {
            result.push(count); // duplicate addition, no change
            continue;
        }
        land.add(idx);
        parent.set(idx, idx);
        rank.set(idx, 0);
        count++;

        for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            const nr = r + dr;
            const nc = c + dc;
            const nIdx = nr * n + nc;
            if (nr >= 0 && nr < m && nc >= 0 && nc < n && land.has(nIdx)) {
                if (union(idx, nIdx)) {
                    count--;
                }
            }
        }

        result.push(count);
    }

    return result;
}
```

```java +
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        int[][] positions = {{0, 0}, {0, 1}, {1, 2}, {2, 1}};
        System.out.println(numIslands2(3, 3, positions));
    }

    static Map<Integer, Integer> parent = new HashMap<>();
    static Map<Integer, Integer> rank = new HashMap<>();
    static Set<Integer> land = new HashSet<>();

    static List<Integer> numIslands2(int m, int n, int[][] positions) {
        List<Integer> result = new ArrayList<>();
        int count = 0;
        int[][] dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

        for (int[] pos : positions) {
            int r = pos[0], c = pos[1];
            int idx = r * n + c;
            if (land.contains(idx)) {
                result.add(count); // duplicate addition, no change
                continue;
            }
            land.add(idx);
            parent.put(idx, idx);
            rank.put(idx, 0);
            count++;

            for (int[] dir : dirs) {
                int nr = r + dir[0], nc = c + dir[1];
                int nIdx = nr * n + nc;
                if (nr >= 0 && nr < m && nc >= 0 && nc < n && land.contains(nIdx)) {
                    if (union(idx, nIdx)) {
                        count--;
                    }
                }
            }

            result.add(count);
        }

        return result;
    }

    static int find(int x) {
        if (parent.get(x) != x) {
            parent.put(x, find(parent.get(x)));
        }
        return parent.get(x);
    }

    static boolean union(int x, int y) {
        int rx = find(x);
        int ry = find(y);
        if (rx == ry) return false;
        if (rank.get(rx) < rank.get(ry)) {
            int tmp = rx;
            rx = ry;
            ry = tmp;
        }
        parent.put(ry, rx);
        if (rank.get(rx).equals(rank.get(ry))) {
            rank.put(rx, rank.get(rx) + 1);
        }
        return true;
    }
}
```

**Complexity:** O(k * α(k)) time for `k` position updates, O(k) space (only land cells get DSU entries, via a dict-based sparse DSU, not a full `m*n` array).

**Common mistakes:** allocating a dense `parent` array of size `m*n` when a dict keyed by only-visited cells is both simpler and avoids wasted memory for large sparse grids; forgetting to handle duplicate positions in the input, since the same cell can appear twice and must not be double-counted as a new island; not decrementing `count` on every successful union (each merge reduces the island count by exactly one, and a cell can merge with up to 4 neighbors).

The four problems above split cleanly along one axis: whether the graph is built once (Connected Components, Graph Valid Tree) or grows incrementally (Longest Consecutive Sequence's value-by-value unions, Number of Islands II's cell-by-cell additions). For the static case, BFS/DFS is usually just as good as DSU and sometimes simpler to write. DSU earns its place specifically when connectivity has to be queried *between* additions, not just once at the end.
