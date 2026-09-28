---
kind: lesson
id_key: interview-prep-45/day-10
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Topological Sort and Cycle Detection"
position: 13
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---
Before you can get dressed, you put on socks before shoes. Before a build system compiles your project, it compiles the files you depend on first. Topological sort answers exactly this question in code: "in what order must these tasks run, given their dependencies?" It only makes sense for graphs with no cycles, so cycle detection and topological sort are really two names for the same idea.

## What makes an order possible at all

A **DAG** (Directed Acyclic Graph) is a directed graph with no cycles: you can never start at a node, follow edges, and arrive back where you started. That property is exactly what makes a valid ordering possible. If task A must come before task B (an edge A→B), a cycle A→B→A would make "before" meaningless, since A would need to come before B and after B at the same time. No valid order could exist.

**Topological order**: a line-up of nodes such that for every directed edge `u → v`, `u` appears before `v` in the line. A DAG can have more than one valid topological order, or exactly one if it happens to be a strict chain.

```python
# Example: 5 depends on 2 and 0; 4 depends on 0 and 1; 3 depends on 1
# edges: 5->2, 5->0, 4->0, 4->1, 2->3, 3->1
# Valid orders include: [5, 4, 2, 3, 1, 0] and [4, 5, 2, 3, 1, 0]
```
```javascript +
// Example: 5 depends on 2 and 0; 4 depends on 0 and 1; 3 depends on 1
// edges: 5->2, 5->0, 4->0, 4->1, 2->3, 3->1
// Valid orders include: [5, 4, 2, 3, 1, 0] and [4, 5, 2, 3, 1, 0]
```
```java +
public class Main {
    public static void main(String[] args) {
        // Example: 5 depends on 2 and 0; 4 depends on 0 and 1; 3 depends on 1
        // edges: 5->2, 5->0, 4->0, 4->1, 2->3, 3->1
        // Valid orders include: [5, 4, 2, 3, 1, 0] and [4, 5, 2, 3, 1, 0]
    }
}
```

**Key fact:** a graph has a valid topological order **if and only if it is a DAG**. So "can this be topologically sorted?" and "does this graph have a cycle?" are the same question asked two ways, which is why cycle detection and topological sort share one algorithm.

> **Remember:** a topological order exists only if the graph has no cycles. Asking "is it a DAG?" and "can it be sorted?" are the same question.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-dag-q1", "type": "mcq",
      "prompt": "Why can a graph with a cycle never have a valid topological order?",
      "options": [
        {"id": "a", "text": "A cycle would require a node to come both before and after another node in the same ordering, which is a contradiction"},
        {"id": "b", "text": "Cycles just make computing the order slower, not impossible"},
        {"id": "c", "text": "Topological order only applies to trees, not general graphs"},
        {"id": "d", "text": "A cycle can be broken by picking any starting node"}
      ],
      "correct": "a",
      "explanation": "If A must come before B (A->B) and the graph also has B->A, then B must come before A too. No linear ordering can satisfy both at once, so a cycle makes a valid topological order impossible." }
] }
```

## Kahn's algorithm: peel off nodes with nothing left owed to them

Kahn's algorithm repeatedly removes nodes with **in-degree 0**, meaning no remaining dependencies point at them. That's the whole idea: a node with in-degree 0 can safely run right now, since nothing is still waiting to happen before it.

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
```javascript +
function kahnTopoSort(numNodes, edges) {
    const graph = new Map();
    const inDegree = new Array(numNodes).fill(0);
    for (const [u, v] of edges) {          // u must come before v
        if (!graph.has(u)) graph.set(u, []);
        graph.get(u).push(v);
        inDegree[v] += 1;
    }

    const queue = [];
    for (let n = 0; n < numNodes; n++) {
        if (inDegree[n] === 0) queue.push(n);
    }
    const order = [];

    while (queue.length > 0) {
        const node = queue.shift();
        order.push(node);
        for (const neighbor of graph.get(node) || []) {
            inDegree[neighbor] -= 1;
            if (inDegree[neighbor] === 0) queue.push(neighbor);
        }
    }

    if (order.length !== numNodes) return [];  // cycle detected — not all nodes could be processed
    return order;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int numNodes = 6;
        int[][] edges = {{5, 2}, {5, 0}, {4, 0}, {4, 1}, {2, 3}, {3, 1}};
        System.out.println(kahnTopoSort(numNodes, edges));
    }

    static List<Integer> kahnTopoSort(int numNodes, int[][] edges) {
        Map<Integer, List<Integer>> graph = new HashMap<>();
        int[] inDegree = new int[numNodes];
        for (int[] edge : edges) {          // u must come before v
            int u = edge[0], v = edge[1];
            graph.computeIfAbsent(u, k -> new ArrayList<>()).add(v);
            inDegree[v]++;
        }

        Deque<Integer> queue = new ArrayDeque<>();
        for (int n = 0; n < numNodes; n++) {
            if (inDegree[n] == 0) queue.add(n);
        }
        List<Integer> order = new ArrayList<>();

        while (!queue.isEmpty()) {
            int node = queue.poll();
            order.add(node);
            for (int neighbor : graph.getOrDefault(node, Collections.emptyList())) {
                inDegree[neighbor]--;
                if (inDegree[neighbor] == 0) queue.add(neighbor);
            }
        }

        if (order.size() != numNodes) return new ArrayList<>();  // cycle detected
        return order;
    }
}
```

**Complexity:** Time O(V + E), space O(V + E).

**Why it doubles as cycle detection:** if the graph has a cycle, the nodes inside that cycle never reach in-degree 0, since each one depends on another node that's also stuck in the cycle. So `order` ends up shorter than `num_nodes`. That length check IS the cycle check; no separate logic needed.

> **Remember:** repeatedly peel off nodes with in-degree 0. If the final order is shorter than the node count, a cycle ate the rest.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-kahn-q1", "type": "mcq",
      "prompt": "In Kahn's algorithm, why does a cycle in the graph cause the output order to be shorter than the total node count?",
      "options": [
        {"id": "a", "text": "Every node in the cycle depends on another node also stuck in the cycle, so none of them ever reaches in-degree 0"},
        {"id": "b", "text": "Kahn's algorithm crashes on cyclic graphs before finishing"},
        {"id": "c", "text": "Cycles cause duplicate nodes to be added to the queue"},
        {"id": "d", "text": "The queue becomes empty immediately if any cycle exists"}
      ],
      "correct": "a",
      "explanation": "A node only enters the queue once its in-degree hits 0. Inside a cycle, every node has at least one incoming edge from another cycle member that never gets processed, so their in-degree never drops to 0, and they're never added to the order." }
] }
```

## The DFS alternative

Run DFS from every unvisited node, and when a node's DFS call finishes, meaning every one of its descendants is fully processed, push that node onto a stack. Reverse the stack at the end.

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
```javascript +
function dfsTopoSort(numNodes, edges) {
    const graph = new Map();
    for (const [u, v] of edges) {
        if (!graph.has(u)) graph.set(u, []);
        graph.get(u).push(v);
    }

    const visited = new Set();
    const stack = [];

    function dfs(node) {
        visited.add(node);
        for (const neighbor of graph.get(node) || []) {
            if (!visited.has(neighbor)) dfs(neighbor);
        }
        stack.push(node);  // postorder: node goes on stack after all descendants
    }

    for (let node = 0; node < numNodes; node++) {
        if (!visited.has(node)) dfs(node);
    }

    return stack.reverse();
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int numNodes = 6;
        int[][] edges = {{5, 2}, {5, 0}, {4, 0}, {4, 1}, {2, 3}, {3, 1}};
        System.out.println(dfsTopoSort(numNodes, edges));
    }

    static List<Integer> dfsTopoSort(int numNodes, int[][] edges) {
        Map<Integer, List<Integer>> graph = new HashMap<>();
        for (int[] edge : edges) {
            graph.computeIfAbsent(edge[0], k -> new ArrayList<>()).add(edge[1]);
        }

        Set<Integer> visited = new HashSet<>();
        Deque<Integer> stack = new ArrayDeque<>();

        for (int node = 0; node < numNodes; node++) {
            if (!visited.contains(node)) {
                dfs(node, graph, visited, stack);
            }
        }

        return new ArrayList<>(stack);  // ArrayDeque.push() + iteration gives postorder reversed
    }

    static void dfs(int node, Map<Integer, List<Integer>> graph, Set<Integer> visited, Deque<Integer> stack) {
        visited.add(node);
        for (int neighbor : graph.getOrDefault(node, Collections.emptyList())) {
            if (!visited.contains(neighbor)) dfs(neighbor, graph, visited, stack);
        }
        stack.push(node);  // postorder: node goes on stack after all descendants
    }
}
```

**Why postorder + reverse works:** a node is only pushed after everything it depends on downstream has already been pushed. Reversing puts dependencies before the things that depend on them. This variant needs a separate 3-color cycle check, covered next, because a plain visited set alone can't tell "currently on this DFS path" apart from "already fully processed."

**Trade-off:** Kahn's is iterative, so it carries no recursion-depth risk, and it detects cycles for free via the length check. DFS-based is often shorter to write when you already have DFS cycle detection in place, and it fits naturally when the problem is phrased as "process a node only after its dependents," as in course-scheduling frameworks.

> **Remember:** DFS-based topo sort pushes a node onto a stack only after all its descendants are done, then reverses. That reversal is the whole trick.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-dfs-q1", "type": "mcq",
      "prompt": "In the DFS-based topological sort, why must the final stack be reversed before returning it as the order?",
      "options": [
        {"id": "a", "text": "A node is pushed only after all its descendants are already pushed, so the stack has dependents before their dependencies until reversed"},
        {"id": "b", "text": "Reversing fixes a bug in the DFS traversal itself"},
        {"id": "c", "text": "It's an arbitrary style choice with no effect on correctness"},
        {"id": "d", "text": "It only matters when the graph has a cycle"}
      ],
      "correct": "a",
      "explanation": "Since a node's descendants finish (and get pushed) before the node itself, the stack builds up with 'later' nodes at the bottom and 'earlier' nodes at the top. Reversing puts dependencies before the things that depend on them, the correct topological order." }
] }
```

## Detecting a cycle correctly

For an **undirected** graph, a plain visited set is enough. If you reach an already-visited neighbor that isn't your immediate parent, that's a cycle.

For a **directed** graph, the interview-relevant case (Course Schedule and friends), you need three states, not two, because a node can be "visited" from a completed branch without being part of any cycle:

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
```javascript +
const WHITE = 0, GRAY = 1, BLACK = 2;  // unvisited, in-progress (on current DFS path), done

function hasCycleDirected(numNodes, edges) {
    const graph = new Map();
    for (const [u, v] of edges) {
        if (!graph.has(u)) graph.set(u, []);
        graph.get(u).push(v);
    }

    const color = new Array(numNodes).fill(WHITE);

    function dfs(node) {
        color[node] = GRAY;
        for (const neighbor of graph.get(node) || []) {
            if (color[neighbor] === GRAY) return true;   // back edge -> cycle
            if (color[neighbor] === WHITE && dfs(neighbor)) return true;
        }
        color[node] = BLACK;
        return false;
    }

    for (let n = 0; n < numNodes; n++) {
        if (color[n] === WHITE && dfs(n)) return true;
    }
    return false;
}
```
```java +
import java.util.*;

public class Main {
    static final int WHITE = 0, GRAY = 1, BLACK = 2;  // unvisited, in-progress, done

    public static void main(String[] args) {
        int numNodes = 4;
        int[][] edges = {{0, 1}, {1, 2}, {2, 0}, {2, 3}};
        System.out.println(hasCycleDirected(numNodes, edges));
    }

    static boolean hasCycleDirected(int numNodes, int[][] edges) {
        Map<Integer, List<Integer>> graph = new HashMap<>();
        for (int[] edge : edges) {
            graph.computeIfAbsent(edge[0], k -> new ArrayList<>()).add(edge[1]);
        }

        int[] color = new int[numNodes];  // defaults to WHITE (0)

        for (int n = 0; n < numNodes; n++) {
            if (color[n] == WHITE && dfs(n, graph, color)) return true;
        }
        return false;
    }

    static boolean dfs(int node, Map<Integer, List<Integer>> graph, int[] color) {
        color[node] = GRAY;
        for (int neighbor : graph.getOrDefault(node, Collections.emptyList())) {
            if (color[neighbor] == GRAY) return true;                 // back edge -> cycle
            if (color[neighbor] == WHITE && dfs(neighbor, graph, color)) return true;
        }
        color[node] = BLACK;
        return false;
    }
}
```

**Pitfall:** using a single visited set (two states) on a directed graph gives false positives. Two different branches can both reach the same node without a cycle existing at all, since directed edges don't imply "coming back." The GRAY state, tracking the current recursion path specifically, is what correctly identifies a true back edge.

> **Remember:** directed-graph cycle detection needs three states (white/gray/black), not two. GRAY means "on my current path right now," which is the only thing a true cycle can hit.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-cycle-detect-q1", "type": "mcq",
      "prompt": "Why does a plain 2-state visited set give false positives for cycle detection on a directed graph?",
      "options": [
        {"id": "a", "text": "Two separate branches can both legitimately reach the same node without any cycle existing, since directed edges don't imply coming back"},
        {"id": "b", "text": "A 2-state set only works on trees, never on graphs"},
        {"id": "c", "text": "It's actually fine; 3 states are only needed for undirected graphs"},
        {"id": "d", "text": "2-state visited sets can't be implemented with DFS"}
      ],
      "correct": "a",
      "explanation": "A node reached from two unrelated branches would look 'already visited' under a 2-state scheme even with no cycle. The 3rd state (GRAY, meaning 'on the current DFS path') distinguishes that harmless case from a true back edge, which only happens when you re-reach a node still on your own current path." }
] }
```

## Course Schedule

[LeetCode 207](https://leetcode.com/problems/course-schedule/), Topological sort, Detect cycle

"Can you finish all courses?" is exactly "is this prerequisite graph a DAG?" Build the graph, run Kahn's algorithm, and check whether every course got processed.

**Approach:** Build the adjacency list and in-degree array from the prerequisites, then run Kahn's algorithm; compare the processed count to `numCourses`.

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
```javascript +
function canFinish(numCourses, prerequisites) {
    const graph = new Map();
    const inDegree = new Array(numCourses).fill(0);
    for (const [course, prereq] of prerequisites) {
        if (!graph.has(prereq)) graph.set(prereq, []);
        graph.get(prereq).push(course);
        inDegree[course] += 1;
    }

    const queue = [];
    for (let c = 0; c < numCourses; c++) {
        if (inDegree[c] === 0) queue.push(c);
    }
    let processed = 0;

    while (queue.length > 0) {
        const node = queue.shift();
        processed += 1;
        for (const neighbor of graph.get(node) || []) {
            inDegree[neighbor] -= 1;
            if (inDegree[neighbor] === 0) queue.push(neighbor);
        }
    }

    return processed === numCourses;
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int numCourses = 2;
        int[][] prerequisites = {{1, 0}};
        System.out.println(canFinish(numCourses, prerequisites));
    }

    static boolean canFinish(int numCourses, int[][] prerequisites) {
        Map<Integer, List<Integer>> graph = new HashMap<>();
        int[] inDegree = new int[numCourses];
        for (int[] p : prerequisites) {
            int course = p[0], prereq = p[1];
            graph.computeIfAbsent(prereq, k -> new ArrayList<>()).add(course);
            inDegree[course]++;
        }

        Deque<Integer> queue = new ArrayDeque<>();
        for (int c = 0; c < numCourses; c++) {
            if (inDegree[c] == 0) queue.add(c);
        }
        int processed = 0;

        while (!queue.isEmpty()) {
            int node = queue.poll();
            processed++;
            for (int neighbor : graph.getOrDefault(node, Collections.emptyList())) {
                inDegree[neighbor]--;
                if (inDegree[neighbor] == 0) queue.add(neighbor);
            }
        }

        return processed == numCourses;
    }
}
```

**Complexity:** Time O(V + E), space O(V + E).

**Common mistakes:** Flipping the edge direction; it runs prereq to course, not course to prereq. Forgetting that courses with zero prerequisites and zero dependents still count toward `processed`.

> **Remember:** this is topological sort wearing a boolean costume. Just check whether Kahn's algorithm processed every course.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-course-schedule-q1", "type": "mcq",
      "prompt": "In Course Schedule, what does it mean if the number of courses processed by Kahn's algorithm is less than numCourses?",
      "options": [
        {"id": "a", "text": "There is a cycle in the prerequisite graph, so not all courses can be completed"},
        {"id": "b", "text": "The input contains a course with no prerequisites"},
        {"id": "c", "text": "The graph has more edges than nodes"},
        {"id": "d", "text": "It always means the input was malformed"}
      ],
      "correct": "a",
      "explanation": "Courses stuck in a prerequisite cycle never reach in-degree 0, so Kahn's algorithm never processes them. A processed count below numCourses is exactly the signal that a cycle exists somewhere in the prerequisites." }
] }
```

## Course Schedule II

[LeetCode 210](https://leetcode.com/problems/course-schedule-ii/), Topological sort, Return order

Identical to Course Schedule I, but instead of a true/false answer, you return the actual valid order (or an empty list if it's impossible).

**Approach:** Reuse Kahn's algorithm verbatim, but collect the order instead of only counting it.

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
```javascript +
function findOrder(numCourses, prerequisites) {
    const graph = new Map();
    const inDegree = new Array(numCourses).fill(0);
    for (const [course, prereq] of prerequisites) {
        if (!graph.has(prereq)) graph.set(prereq, []);
        graph.get(prereq).push(course);
        inDegree[course] += 1;
    }

    const queue = [];
    for (let c = 0; c < numCourses; c++) {
        if (inDegree[c] === 0) queue.push(c);
    }
    const order = [];

    while (queue.length > 0) {
        const node = queue.shift();
        order.push(node);
        for (const neighbor of graph.get(node) || []) {
            inDegree[neighbor] -= 1;
            if (inDegree[neighbor] === 0) queue.push(neighbor);
        }
    }

    return order.length === numCourses ? order : [];
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        int numCourses = 4;
        int[][] prerequisites = {{1, 0}, {2, 0}, {3, 1}, {3, 2}};
        System.out.println(findOrder(numCourses, prerequisites));
    }

    static List<Integer> findOrder(int numCourses, int[][] prerequisites) {
        Map<Integer, List<Integer>> graph = new HashMap<>();
        int[] inDegree = new int[numCourses];
        for (int[] p : prerequisites) {
            int course = p[0], prereq = p[1];
            graph.computeIfAbsent(prereq, k -> new ArrayList<>()).add(course);
            inDegree[course]++;
        }

        Deque<Integer> queue = new ArrayDeque<>();
        for (int c = 0; c < numCourses; c++) {
            if (inDegree[c] == 0) queue.add(c);
        }
        List<Integer> order = new ArrayList<>();

        while (!queue.isEmpty()) {
            int node = queue.poll();
            order.add(node);
            for (int neighbor : graph.getOrDefault(node, Collections.emptyList())) {
                inDegree[neighbor]--;
                if (inDegree[neighbor] == 0) queue.add(neighbor);
            }
        }

        return order.size() == numCourses ? order : new ArrayList<>();
    }
}
```

**Complexity:** Time O(V + E), space O(V + E).

**Common mistakes:** Returning a partial order instead of an empty list when a cycle exists. Always check the length before returning.

> **Remember:** same algorithm as Course Schedule I, just return the collected order instead of a boolean.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-course-schedule-ii-q1", "type": "mcq",
      "prompt": "In Course Schedule II, what should findOrder return if a cycle makes it impossible to complete all courses?",
      "options": [
        {"id": "a", "text": "An empty list, not the partial order that was collected before the cycle blocked further progress"},
        {"id": "b", "text": "The partial order collected so far"},
        {"id": "c", "text": "A list containing only the courses involved in the cycle"},
        {"id": "d", "text": "The value -1"}
      ],
      "correct": "a",
      "explanation": "A partial order isn't a valid answer since it doesn't cover every course. The problem expects an empty list specifically when the full ordering is impossible, which the length check against numCourses catches." }
] }
```

## Alien Dictionary

[LeetCode 269](https://leetcode.com/problems/alien-dictionary/), Topological sort, Hard

You're given a list of words already sorted according to some unknown alien alphabet. Comparing adjacent words reveals relative character ordering: the first character where two consecutive words differ tells you "this letter comes before that letter." Build a graph of those constraints and topologically sort the alphabet's letters.

**Approach:** For each pair of adjacent words, find the first index where the characters differ; that gives one directed edge `word1[i] -> word2[i]`. Special case: if `word1` is longer than `word2` but `word2` is exactly its prefix, such as `"abc"` before `"ab"`, the order is invalid and you return `""`. Then run Kahn's algorithm over the 26 letters.

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
```javascript +
function alienOrder(words) {
    const graph = new Map();
    const inDegree = new Map();
    for (const word of words) {
        for (const c of word) {
            if (!inDegree.has(c)) inDegree.set(c, 0);
        }
    }

    for (let i = 0; i < words.length - 1; i++) {
        const w1 = words[i], w2 = words[i + 1];
        const minLen = Math.min(w1.length, w2.length);
        if (w1.length > w2.length && w1.slice(0, minLen) === w2.slice(0, minLen)) {
            return "";  // invalid: longer word can't be a prefix of the next
        }
        for (let j = 0; j < minLen; j++) {
            const c1 = w1[j], c2 = w2[j];
            if (c1 !== c2) {
                if (!graph.has(c1)) graph.set(c1, new Set());
                if (!graph.get(c1).has(c2)) {
                    graph.get(c1).add(c2);
                    inDegree.set(c2, inDegree.get(c2) + 1);
                }
                break;  // only the first differing pair gives a constraint
            }
        }
    }

    const queue = [...inDegree.keys()].filter((c) => inDegree.get(c) === 0);
    const order = [];

    while (queue.length > 0) {
        const c = queue.shift();
        order.push(c);
        for (const neighbor of graph.get(c) || []) {
            inDegree.set(neighbor, inDegree.get(neighbor) - 1);
            if (inDegree.get(neighbor) === 0) queue.push(neighbor);
        }
    }

    return order.length === inDegree.size ? order.join("") : "";
}
```
```java +
import java.util.*;

public class Main {
    public static void main(String[] args) {
        String[] words = {"wrt", "wrf", "er", "ett", "rftt"};
        System.out.println(alienOrder(words));
    }

    static String alienOrder(String[] words) {
        Map<Character, Set<Character>> graph = new HashMap<>();
        Map<Character, Integer> inDegree = new HashMap<>();
        for (String word : words) {
            for (char c : word.toCharArray()) {
                inDegree.putIfAbsent(c, 0);
            }
        }

        for (int i = 0; i < words.length - 1; i++) {
            String w1 = words[i], w2 = words[i + 1];
            int minLen = Math.min(w1.length(), w2.length());
            if (w1.length() > w2.length() && w1.substring(0, minLen).equals(w2.substring(0, minLen))) {
                return "";  // invalid: longer word can't be a prefix of the next
            }
            for (int j = 0; j < minLen; j++) {
                char c1 = w1.charAt(j), c2 = w2.charAt(j);
                if (c1 != c2) {
                    Set<Character> neighbors = graph.computeIfAbsent(c1, k -> new HashSet<>());
                    if (!neighbors.contains(c2)) {
                        neighbors.add(c2);
                        inDegree.put(c2, inDegree.get(c2) + 1);
                    }
                    break;  // only the first differing pair gives a constraint
                }
            }
        }

        Deque<Character> queue = new ArrayDeque<>();
        for (Map.Entry<Character, Integer> entry : inDegree.entrySet()) {
            if (entry.getValue() == 0) queue.add(entry.getKey());
        }
        StringBuilder order = new StringBuilder();

        while (!queue.isEmpty()) {
            char c = queue.poll();
            order.append(c);
            for (char neighbor : graph.getOrDefault(c, Collections.emptySet())) {
                inDegree.put(neighbor, inDegree.get(neighbor) - 1);
                if (inDegree.get(neighbor) == 0) queue.add(neighbor);
            }
        }

        return order.length() == inDegree.size() ? order.toString() : "";
    }
}
```

**Complexity:** Time O(C), where C is the total character count across all words: each adjacent-pair comparison is bounded by word length, and the topological sort itself is O(26) for nodes and edges. Space is O(1) in practice, since there are at most 26 letters.

**Common mistakes:** Not handling the "prefix but longer" invalid case. Adding duplicate edges when the same letter pair appears across multiple word comparisons; the "already in graph" guard prevents inflating in-degree counts. Continuing the inner loop past the first differing character, since later differences carry no information once the first one is found.

> **Remember:** compare only adjacent words, take only the FIRST differing character per pair, and watch for the "longer word is a prefix of the shorter one" invalid case.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-alien-dictionary-q1", "type": "mcq",
      "prompt": "In Alien Dictionary, why do you stop at the FIRST differing character between two adjacent words instead of comparing every differing pair?",
      "options": [
        {"id": "a", "text": "Only the first difference gives a valid ordering constraint; any later differences are meaningless once the words have already diverged"},
        {"id": "b", "text": "Comparing more than one pair would make the algorithm too slow"},
        {"id": "c", "text": "Later characters are guaranteed to be equal anyway"},
        {"id": "d", "text": "It doesn't matter; comparing all differing pairs gives the same result"}
      ],
      "correct": "a",
      "explanation": "Once two words diverge at some character, that single difference already tells you the ordering constraint between those two letters. Any characters after that point say nothing reliable about the whole alphabet's order, since the words have already been distinguished." }
] }
```

## Longest Increasing Path in a Matrix

[LeetCode 329](https://leetcode.com/problems/longest-increasing-path-in-a-matrix/), DFS + Memoization

Treat each cell as a graph node with a directed edge to any 4-directional neighbor holding a strictly greater value. Since values strictly increase along any path, this graph is automatically acyclic, no separate cycle check needed. Find the longest path in this implicit DAG with DFS plus memoization; it's topological-DAG-style DP even though you never build an explicit adjacency list.

**Approach:** DFS from each cell, caching "longest increasing path starting here" so overlapping subproblems are never recomputed.

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
```javascript +
function longestIncreasingPath(matrix) {
    if (!matrix || matrix.length === 0) return 0;
    const rows = matrix.length, cols = matrix[0].length;
    const memo = new Map();
    const directions = [[1, 0], [-1, 0], [0, 1], [0, -1]];

    function dfs(r, c) {
        const key = `${r},${c}`;
        if (memo.has(key)) return memo.get(key);
        let best = 1;
        for (const [dr, dc] of directions) {
            const nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && matrix[nr][nc] > matrix[r][c]) {
                best = Math.max(best, 1 + dfs(nr, nc));
            }
        }
        memo.set(key, best);
        return best;
    }

    let result = 0;
    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            result = Math.max(result, dfs(r, c));
        }
    }
    return result;
}
```
```java +
public class Main {
    static int rows, cols;
    static int[][] memo;
    static int[][] grid;
    static final int[][] DIRECTIONS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};

    public static void main(String[] args) {
        int[][] matrix = {{9, 9, 4}, {6, 6, 8}, {2, 1, 1}};
        System.out.println(longestIncreasingPath(matrix));
    }

    static int longestIncreasingPath(int[][] matrix) {
        if (matrix == null || matrix.length == 0) return 0;
        grid = matrix;
        rows = matrix.length;
        cols = matrix[0].length;
        memo = new int[rows][cols];

        int result = 0;
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                result = Math.max(result, dfs(r, c));
            }
        }
        return result;
    }

    static int dfs(int r, int c) {
        if (memo[r][c] != 0) return memo[r][c];
        int best = 1;
        for (int[] d : DIRECTIONS) {
            int nr = r + d[0], nc = c + d[1];
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] > grid[r][c]) {
                best = Math.max(best, 1 + dfs(nr, nc));
            }
        }
        memo[r][c] = best;
        return best;
    }
}
```

**Complexity:** Time O(rows × cols), since memoization computes each cell's answer exactly once. Space O(rows × cols) for the memo and recursion stack.

**Common mistakes:** Trying to solve this with a visited set instead of memoization. A visited set assumes you never revisit a cell in any path, but here you legitimately want to revisit cells from different starting points. "Longest path starting at (r, c)," cached, is the correct DP framing.

> **Remember:** strictly increasing values make the implicit graph automatically acyclic. Cache "best path starting here" instead of using a visited set.

```knowledge-check
{ "questions": [
    { "id": "dsa-graphs-topo-lip-q1", "type": "mcq",
      "prompt": "Why is a plain visited set the wrong tool for Longest Increasing Path in a Matrix, even though it's a graph traversal problem?",
      "options": [
        {"id": "a", "text": "You legitimately need to revisit the same cell from different starting points, which a visited set would incorrectly block"},
        {"id": "b", "text": "Visited sets only work on undirected graphs"},
        {"id": "c", "text": "The matrix might contain negative numbers"},
        {"id": "d", "text": "A visited set would make the algorithm run faster than necessary"}
      ],
      "correct": "a",
      "explanation": "Each cell's longest increasing path is computed independently for every starting cell that can reach it. A visited set, once a cell is marked, would wrongly prevent it from being explored again as part of a different starting path. Memoization caches the per-cell answer instead, which is safe to reuse across different starts." }
] }
```
