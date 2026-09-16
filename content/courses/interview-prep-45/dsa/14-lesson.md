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

Week 2 covered five dense topics: BSTs, graph traversal, topological sort, heaps, and the first two layers of dynamic programming. This checkpoint isn't new material. It's a forced consolidation pass. Interview performance comes from pattern recognition under pressure, and that recognition only sticks once you've deliberately reviewed the material, beyond simply solving it once and moving on.

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

Before re-solving anything, do this from memory: no notes, no code, just the recurrence or algorithm shape. It's the fastest way to expose which patterns are shallow, meaning you followed a solution, versus deep, meaning you can regenerate it.

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
```javascript +
function kahnTopoSort(numNodes, edges) {
    const graph = Array.from({ length: numNodes }, () => []);
    const inDegree = new Array(numNodes).fill(0);
    for (const [u, v] of edges) {
        graph[u].push(v);
        inDegree[v] += 1;
    }
    const queue = [];
    for (let n = 0; n < numNodes; n++) {
        if (inDegree[n] === 0) queue.push(n);
    }
    const order = [];
    let head = 0;
    while (head < queue.length) {
        const node = queue[head++];
        order.push(node);
        for (const nxt of graph[node]) {
            inDegree[nxt] -= 1;
            if (inDegree[nxt] === 0) queue.push(nxt);
        }
    }
    return order.length === numNodes ? order : []; // [] means a cycle exists
}
```
```java +
import java.util.*;

public class Main {
    public static List<Integer> kahnTopoSort(int numNodes, int[][] edges) {
        List<List<Integer>> graph = new ArrayList<>();
        for (int i = 0; i < numNodes; i++) graph.add(new ArrayList<>());
        int[] inDegree = new int[numNodes];
        for (int[] edge : edges) {
            int u = edge[0], v = edge[1];
            graph.get(u).add(v);
            inDegree[v]++;
        }
        Deque<Integer> queue = new ArrayDeque<>();
        for (int n = 0; n < numNodes; n++) {
            if (inDegree[n] == 0) queue.addLast(n);
        }
        List<Integer> order = new ArrayList<>();
        while (!queue.isEmpty()) {
            int node = queue.pollFirst();
            order.add(node);
            for (int nxt : graph.get(node)) {
                inDegree[nxt]--;
                if (inDegree[nxt] == 0) queue.addLast(nxt);
            }
        }
        return order.size() == numNodes ? order : new ArrayList<>(); // empty means a cycle exists
    }

    public static void main(String[] args) {
        int[][] edges = { {0, 1}, {0, 2}, {1, 3}, {2, 3} };
        System.out.println(kahnTopoSort(4, edges));
    }
}
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
```javascript +
function topKPattern(items, k, key = (x) => x) {
    const heap = []; // min-heap of [keyValue, item] pairs

    const siftUp = (i) => {
        while (i > 0) {
            const parent = (i - 1) >> 1;
            if (heap[parent][0] <= heap[i][0]) break;
            [heap[parent], heap[i]] = [heap[i], heap[parent]];
            i = parent;
        }
    };

    const siftDown = (i) => {
        const n = heap.length;
        while (true) {
            let smallest = i;
            const left = 2 * i + 1;
            const right = 2 * i + 2;
            if (left < n && heap[left][0] < heap[smallest][0]) smallest = left;
            if (right < n && heap[right][0] < heap[smallest][0]) smallest = right;
            if (smallest === i) break;
            [heap[smallest], heap[i]] = [heap[i], heap[smallest]];
            i = smallest;
        }
    };

    for (const item of items) {
        heap.push([key(item), item]);
        siftUp(heap.length - 1);
        if (heap.length > k) {
            heap[0] = heap[heap.length - 1];
            heap.pop();
            siftDown(0);
        }
    }

    return heap.map(([, item]) => item);
}
```
```java +
import java.util.*;
import java.util.function.Function;

public class Main {
    public static <T> List<T> topKPattern(List<T> items, int k, Function<T, Integer> key) {
        PriorityQueue<T> heap = new PriorityQueue<>(Comparator.comparing(key));
        for (T item : items) {
            heap.offer(item);
            if (heap.size() > k) {
                heap.poll();
            }
        }
        return new ArrayList<>(heap);
    }

    public static void main(String[] args) {
        List<Integer> items = Arrays.asList(3, 1, 5, 12, 2, 11);
        System.out.println(topKPattern(items, 3, x -> x));
    }
}
```

**DP progression, from memory. Say it out loud before writing code:**

1. What's the state? (`dp[i]` or `dp[i][j]`: what does each index represent?)
2. What's the base case? (Smallest subproblem, answered without recursion.)
3. What's the transition? (How does `dp[i]` combine smaller already-solved states?)
4. Can the space be compressed? (Does `dp[i]` only depend on a fixed window of previous states?)

If you can't answer all four for a problem you "solved" this week, that problem needs a re-solve, not just a re-read.

## Where candidates actually lose points

- **Graphs:** conflating "visited" semantics between BFS, which marks at enqueue, and recursive DFS, which marks at visit. Mixing the two causes duplicate work or infinite loops on cycles.
- **Topological sort:** using a 2-state (`visited`/`unvisited`) cycle check on a directed graph gives false results. Directed cycle detection needs 3 states (white/gray/black) to distinguish "currently on this DFS path" from "already fully explored."
- **Heaps:** forgetting Python's `heapq` is min-heap only, and forgetting to negate back after popping from a simulated max heap.
- **DP:** jumping straight to code without stating the state definition first. This is the single biggest predictor of getting stuck mid-solution in a live interview.

## Revision tasks

Re-solve without looking at your previous solution or these notes. Time yourself. If you can't finish in a reasonable interview window (25-35 minutes for a medium, 40-45 for a hard), treat that as the signal to revisit the underlying pattern rather than the specific problem.

- [ ] Re-solve Clone Graph (LeetCode 133): tests visited-map + BFS/DFS combined
- [ ] Re-solve Alien Dictionary (LeetCode 269): hardest topo-sort problem this week, exercises edge construction *and* Kahn's
- [ ] Re-solve Find Median from Data Stream (LeetCode 295): tests the two-heap balancing invariant
- [ ] Re-solve Edit Distance (LeetCode 72): tests 2D DP base-case initialization and transition recall
- [ ] Re-solve Longest Increasing Subsequence (LeetCode 300): attempt the O(n log n) binary-search version from memory, instead of just O(n²)
