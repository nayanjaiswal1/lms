---
kind: lesson
id_key: interview-prep-45/day-05
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Stacks"
position: 5
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
The stack is the simplest data structure in this course, and yet the monotonic stack pattern built on top of it solves a whole family of "next greater/smaller element" problems in O(n) that look like they need O(n²) at first glance. Today covers the structure itself and the one non-obvious pattern that makes it interview-relevant beyond "match the parentheses."

## LIFO principle

A stack supports two core operations, both O(1): `push` (add to the top) and `pop` (remove from the top). Last-In-First-Out means the most recently added element is the first one removed, unlike a queue (FIFO), where the oldest element leaves first.

```python
stack = []
stack.append(1)   # push
stack.append(2)
stack.append(3)
stack.pop()        # removes 3
stack[-1]          # peek: 2, without removing
```
```javascript +
const stack = [];
stack.push(1);   // push
stack.push(2);
stack.push(3);
stack.pop();               // removes 3
stack[stack.length - 1];  // peek: 2, without removing
```
```java +
import java.util.ArrayDeque;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        Deque<Integer> stack = new ArrayDeque<>();
        stack.push(1);   // push
        stack.push(2);
        stack.push(3);
        stack.pop();               // removes 3
        int peek = stack.peek();  // peek: 2, without removing
        System.out.println("Peek: " + peek);
    }
}
```

Python's `list` is a perfectly good stack (`append`/`pop` from the end are both O(1) amortized). Don't use `list.insert(0, x)` / `list.pop(0)` as a stack; those are O(n) because they shift every element.

## Stack vs recursion

Recursion *is* an implicit stack: each recursive call pushes a new frame (local variables, return address) onto the call stack, and returning pops it. Any recursive algorithm can be rewritten iteratively using an explicit stack. This matters in interviews for two reasons.

1. Deep recursion can hit Python's recursion limit (default 1000) or blow the real call stack; an explicit stack has no such limit (bounded only by heap memory).
2. Interviewers sometimes explicitly ask for the iterative version to test whether you understand what recursion is doing under the hood.

The mechanical translation: whatever you'd pass as recursive-call arguments, push as a tuple onto an explicit stack instead; a `while stack:` loop replaces the call.

```python
# Recursive DFS
def dfs_recursive(node, visited):
    if node in visited:
        return
    visited.add(node)
    for neighbor in node.neighbors:
        dfs_recursive(neighbor, visited)

# Iterative DFS using an explicit stack
def dfs_iterative(start):
    visited = set()
    stack = [start]
    while stack:
        node = stack.pop()
        if node in visited:
            continue
        visited.add(node)
        for neighbor in node.neighbors:
            if neighbor not in visited:
                stack.append(neighbor)
    return visited
```
```javascript +
// Recursive DFS
function dfsRecursive(node, visited) {
    if (visited.has(node)) {
        return;
    }
    visited.add(node);
    for (const neighbor of node.neighbors) {
        dfsRecursive(neighbor, visited);
    }
}

// Iterative DFS using an explicit stack
function dfsIterative(start) {
    const visited = new Set();
    const stack = [start];
    while (stack.length > 0) {
        const node = stack.pop();
        if (visited.has(node)) {
            continue;
        }
        visited.add(node);
        for (const neighbor of node.neighbors) {
            if (!visited.has(neighbor)) {
                stack.push(neighbor);
            }
        }
    }
    return visited;
}
```
```java +
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class Main {
    public static void main(String[] args) {
        GraphNode a = new GraphNode("A");
        GraphNode b = new GraphNode("B");
        GraphNode c = new GraphNode("C");
        a.neighbors.add(b);
        b.neighbors.add(c);
        c.neighbors.add(a); // cycle

        Set<GraphNode> visitedRecursive = new HashSet<>();
        dfsRecursive(a, visitedRecursive);
        System.out.println("Recursive visited: " + visitedRecursive.size());

        Set<GraphNode> visitedIterative = dfsIterative(a);
        System.out.println("Iterative visited: " + visitedIterative.size());
    }

    // Recursive DFS
    static void dfsRecursive(GraphNode node, Set<GraphNode> visited) {
        if (visited.contains(node)) {
            return;
        }
        visited.add(node);
        for (GraphNode neighbor : node.neighbors) {
            dfsRecursive(neighbor, visited);
        }
    }

    // Iterative DFS using an explicit stack
    static Set<GraphNode> dfsIterative(GraphNode start) {
        Set<GraphNode> visited = new HashSet<>();
        ArrayDeque<GraphNode> stack = new ArrayDeque<>();
        stack.push(start);
        while (!stack.isEmpty()) {
            GraphNode node = stack.pop();
            if (visited.contains(node)) {
                continue;
            }
            visited.add(node);
            for (GraphNode neighbor : node.neighbors) {
                if (!visited.contains(neighbor)) {
                    stack.push(neighbor);
                }
            }
        }
        return visited;
    }
}

class GraphNode {
    String label;
    List<GraphNode> neighbors = new ArrayList<>();

    GraphNode(String label) {
        this.label = label;
    }
}
```

## Monotonic stack pattern

A **monotonic stack** keeps its elements in strictly increasing or strictly decreasing order at all times. When a new element would violate that order, you pop elements off the top until the invariant holds again, and each pop is a signal: the element just popped just found its next greater (or smaller) element.

This is the trick behind "next greater element" style problems. Instead of, for each element, scanning forward to find the next bigger one (O(n²)), you maintain a stack of indices whose answer isn't known yet, and resolve them opportunistically as you scan once left to right (O(n), because each index is pushed once and popped at most once).

```python
def next_greater_elements(nums: list[int]) -> list[int]:
    n = len(nums)
    result = [-1] * n
    stack = []  # indices, values decreasing bottom to top
    for i in range(n):
        while stack and nums[stack[-1]] < nums[i]:
            idx = stack.pop()
            result[idx] = nums[i]
        stack.append(i)
    return result
```
```javascript +
function nextGreaterElements(nums) {
    const n = nums.length;
    const result = new Array(n).fill(-1);
    const stack = []; // indices, values decreasing bottom to top
    for (let i = 0; i < n; i++) {
        while (stack.length > 0 && nums[stack[stack.length - 1]] < nums[i]) {
            const idx = stack.pop();
            result[idx] = nums[i];
        }
        stack.push(i);
    }
    return result;
}
```
```java +
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        int[] nums = {2, 1, 2, 4, 3};
        System.out.println(Arrays.toString(nextGreaterElements(nums)));
    }

    static int[] nextGreaterElements(int[] nums) {
        int n = nums.length;
        int[] result = new int[n];
        Arrays.fill(result, -1);
        Deque<Integer> stack = new ArrayDeque<>(); // indices, values decreasing bottom to top
        for (int i = 0; i < n; i++) {
            while (!stack.isEmpty() && nums[stack.peek()] < nums[i]) {
                int idx = stack.pop();
                result[idx] = nums[i];
            }
            stack.push(i);
        }
        return result;
    }
}
```

### Stack using a linked list

Arrays make a fine stack, but interviewers sometimes ask you to implement one over a singly linked list, where push/pop happen at the head so both stay O(1) without any resizing:

```python
class StackNode:
    def __init__(self, val, next=None):
        self.val = val
        self.next = next

class LinkedListStack:
    def __init__(self):
        self.head = None
        self.size = 0

    def push(self, val) -> None:
        self.head = StackNode(val, self.head)
        self.size += 1

    def pop(self):
        if not self.head:
            raise IndexError("pop from empty stack")
        val = self.head.val
        self.head = self.head.next
        self.size -= 1
        return val

    def peek(self):
        if not self.head:
            raise IndexError("peek from empty stack")
        return self.head.val

    def is_empty(self) -> bool:
        return self.head is None
```
```javascript +
class StackNode {
    constructor(val, next = null) {
        this.val = val;
        this.next = next;
    }
}

class LinkedListStack {
    constructor() {
        this.head = null;
        this.size = 0;
    }

    push(val) {
        this.head = new StackNode(val, this.head);
        this.size += 1;
    }

    pop() {
        if (!this.head) {
            throw new Error('pop from empty stack');
        }
        const val = this.head.val;
        this.head = this.head.next;
        this.size -= 1;
        return val;
    }

    peek() {
        if (!this.head) {
            throw new Error('peek from empty stack');
        }
        return this.head.val;
    }

    isEmpty() {
        return this.head === null;
    }
}
```
```java +
public class Main {
    public static void main(String[] args) {
        LinkedListStack stack = new LinkedListStack();
        stack.push(1);
        stack.push(2);
        stack.push(3);
        System.out.println("Popped: " + stack.pop());
        System.out.println("Peek: " + stack.peek());
        System.out.println("Empty? " + stack.isEmpty());
    }
}

class StackNode {
    int val;
    StackNode next;

    StackNode(int val, StackNode next) {
        this.val = val;
        this.next = next;
    }
}

class LinkedListStack {
    private StackNode head;
    private int size;

    void push(int val) {
        head = new StackNode(val, head);
        size += 1;
    }

    int pop() {
        if (head == null) {
            throw new IllegalStateException("pop from empty stack");
        }
        int val = head.val;
        head = head.next;
        size -= 1;
        return val;
    }

    int peek() {
        if (head == null) {
            throw new IllegalStateException("peek from empty stack");
        }
        return head.val;
    }

    boolean isEmpty() {
        return head == null;
    }
}
```

No amortized cost here. Every op is worst-case O(1) since there's never a resize, at the cost of per-node pointer overhead that an array-backed stack doesn't pay.

## Valid Parentheses

[Valid Parentheses (LeetCode 20)](https://leetcode.com/problems/valid-parentheses/)

**Intuition:** Every closing bracket must match the most recently opened, unclosed bracket. That "most recent unmatched" property is exactly a stack.

**Approach:** Push opening brackets. On a closing bracket, pop and check it matches the expected opener; a mismatch or empty stack means invalid. The string is valid only if the stack is empty at the end.

```python
def is_valid(s: str) -> bool:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack = []
    for ch in s:
        if ch in pairs:
            if not stack or stack.pop() != pairs[ch]:
                return False
        else:
            stack.append(ch)
    return not stack
```
```javascript +
function isValid(s) {
    const pairs = { ')': '(', ']': '[', '}': '{' };
    const stack = [];
    for (const ch of s) {
        if (ch in pairs) {
            if (stack.length === 0 || stack.pop() !== pairs[ch]) {
                return false;
            }
        } else {
            stack.push(ch);
        }
    }
    return stack.length === 0;
}
```
```java +
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;

public class Main {
    public static void main(String[] args) {
        System.out.println(isValid("()[]{}"));
        System.out.println(isValid("(]"));
    }

    static boolean isValid(String s) {
        Map<Character, Character> pairs = Map.of(')', '(', ']', '[', '}', '{');
        Deque<Character> stack = new ArrayDeque<>();
        for (char ch : s.toCharArray()) {
            if (pairs.containsKey(ch)) {
                if (stack.isEmpty() || stack.pop() != pairs.get(ch)) {
                    return false;
                }
            } else {
                stack.push(ch);
            }
        }
        return stack.isEmpty();
    }
}
```

**Complexity:** Time O(n), space O(n) worst case (all openers).

**Common mistakes:**
- Forgetting to check `not stack` before popping on a closing bracket with an empty stack (`")"` alone would crash or misbehave without the guard).
- Forgetting the final `not stack` check. A string like `"((("` never triggers a mismatch mid-scan but is still invalid.

## Daily Temperatures

[Daily Temperatures (LeetCode 739)](https://leetcode.com/problems/daily-temperatures/)

**Intuition:** For each day, find how many days until a warmer temperature. This is "next greater element," but returning the *distance* instead of the value.

**Approach:** Monotonic decreasing stack of indices. When the current temperature beats the temperature at the stack's top index, pop and record `current_index - popped_index` as the wait.

```python
def daily_temperatures(temperatures: list[int]) -> list[int]:
    n = len(temperatures)
    result = [0] * n
    stack = []  # indices with temps not yet resolved, decreasing order
    for i, temp in enumerate(temperatures):
        while stack and temperatures[stack[-1]] < temp:
            prev_idx = stack.pop()
            result[prev_idx] = i - prev_idx
        stack.append(i)
    return result
```
```javascript +
function dailyTemperatures(temperatures) {
    const n = temperatures.length;
    const result = new Array(n).fill(0);
    const stack = []; // indices with temps not yet resolved, decreasing order
    for (let i = 0; i < n; i++) {
        while (stack.length > 0 && temperatures[stack[stack.length - 1]] < temperatures[i]) {
            const prevIdx = stack.pop();
            result[prevIdx] = i - prevIdx;
        }
        stack.push(i);
    }
    return result;
}
```
```java +
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        int[] temperatures = {73, 74, 75, 71, 69, 72, 76, 73};
        System.out.println(Arrays.toString(dailyTemperatures(temperatures)));
    }

    static int[] dailyTemperatures(int[] temperatures) {
        int n = temperatures.length;
        int[] result = new int[n];
        Deque<Integer> stack = new ArrayDeque<>(); // indices with temps not yet resolved, decreasing order
        for (int i = 0; i < n; i++) {
            while (!stack.isEmpty() && temperatures[stack.peek()] < temperatures[i]) {
                int prevIdx = stack.pop();
                result[prevIdx] = i - prevIdx;
            }
            stack.push(i);
        }
        return result;
    }
}
```

**Complexity:** Time O(n): each index pushed once, popped at most once. Space O(n) worst case (strictly decreasing input).

**Common mistakes:**
- Brute-forcing with a nested loop (O(n²)): works, but it's the naive baseline interviewers expect you to improve on.
- Storing values instead of indices on the stack. You need the index to compute the distance, not the temperature alone.

## Largest Rectangle in Histogram

[Largest Rectangle in Histogram (LeetCode 84)](https://leetcode.com/problems/largest-rectangle-in-histogram/)

**Intuition:** For each bar, the largest rectangle that uses that bar as its shortest (limiting) height extends as far left and right as neighboring bars stay `>=` its height. A monotonic increasing stack lets you find, for each bar, the nearest shorter bar on both sides in a single O(n) pass; those boundaries define the max width for that bar's height.

**Approach:** Maintain a stack of indices with increasing heights. When the current bar is shorter than the stack's top, pop and compute the area using the popped bar's height, with width = current index minus the new stack top's index minus 1 (or just current index if the stack is empty). Append a sentinel `0` height at the end to flush remaining bars.

```python
def largest_rectangle_area(heights: list[int]) -> int:
    stack = []  # indices, increasing height
    max_area = 0
    heights = heights + [0]  # sentinel to flush the stack

    for i, h in enumerate(heights):
        while stack and heights[stack[-1]] > h:
            height = heights[stack.pop()]
            width = i if not stack else i - stack[-1] - 1
            max_area = max(max_area, height * width)
        stack.append(i)

    return max_area
```
```javascript +
function largestRectangleArea(heights) {
    const stack = []; // indices, increasing height
    let maxArea = 0;
    const withSentinel = [...heights, 0]; // sentinel to flush the stack

    for (let i = 0; i < withSentinel.length; i++) {
        const h = withSentinel[i];
        while (stack.length > 0 && withSentinel[stack[stack.length - 1]] > h) {
            const height = withSentinel[stack.pop()];
            const width = stack.length === 0 ? i : i - stack[stack.length - 1] - 1;
            maxArea = Math.max(maxArea, height * width);
        }
        stack.push(i);
    }

    return maxArea;
}
```
```java +
import java.util.ArrayDeque;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        int[] heights = {2, 1, 5, 6, 2, 3};
        System.out.println(largestRectangleArea(heights));
    }

    static int largestRectangleArea(int[] heights) {
        int n = heights.length;
        int[] withSentinel = new int[n + 1];
        System.arraycopy(heights, 0, withSentinel, 0, n); // sentinel 0 to flush the stack

        Deque<Integer> stack = new ArrayDeque<>(); // indices, increasing height
        int maxArea = 0;

        for (int i = 0; i < withSentinel.length; i++) {
            int h = withSentinel[i];
            while (!stack.isEmpty() && withSentinel[stack.peek()] > h) {
                int height = withSentinel[stack.pop()];
                int width = stack.isEmpty() ? i : i - stack.peek() - 1;
                maxArea = Math.max(maxArea, height * width);
            }
            stack.push(i);
        }

        return maxArea;
    }
}
```

**Complexity:** Time O(n): each index pushed and popped once. Space O(n).

**Common mistakes:**
- Forgetting the sentinel `0` at the end, which leaves bars still on the stack unresolved.
- Getting the width formula wrong. It's `i - stack[-1] - 1` (exclusive of both boundary indices), not `i - stack[-1]`.
- Trying brute force (check every pair of left/right boundaries, O(n²) or O(n³)) as the final answer instead of a starting point.

## Min Stack

[Min Stack (LeetCode 155)](https://leetcode.com/problems/min-stack/)

**Intuition:** A normal stack gives O(1) push/pop/top but O(n) minimum, since you'd have to scan. Track the running minimum *alongside* each element so every push carries "what was the min including me," giving O(1) min retrieval too.

**Approach:** Use two parallel stacks, one for values and one for the minimum-so-far at each depth (or store `(value, current_min)` tuples in a single stack).

```python
class MinStack:
    def __init__(self):
        self.stack = []  # each entry: (value, min_so_far)

    def push(self, val: int) -> None:
        current_min = val if not self.stack else min(val, self.stack[-1][1])
        self.stack.append((val, current_min))

    def pop(self) -> None:
        self.stack.pop()

    def top(self) -> int:
        return self.stack[-1][0]

    def getMin(self) -> int:
        return self.stack[-1][1]
```
```javascript +
class MinStack {
    constructor() {
        this.stack = []; // each entry: [value, minSoFar]
    }

    push(val) {
        const currentMin = this.stack.length === 0 ? val : Math.min(val, this.stack[this.stack.length - 1][1]);
        this.stack.push([val, currentMin]);
    }

    pop() {
        this.stack.pop();
    }

    top() {
        return this.stack[this.stack.length - 1][0];
    }

    getMin() {
        return this.stack[this.stack.length - 1][1];
    }
}
```
```java +
import java.util.ArrayDeque;
import java.util.Deque;

public class Main {
    public static void main(String[] args) {
        MinStack minStack = new MinStack();
        minStack.push(3);
        minStack.push(1);
        minStack.push(2);
        System.out.println("Min: " + minStack.getMin());
        minStack.pop();
        System.out.println("Top: " + minStack.top());
        System.out.println("Min: " + minStack.getMin());
    }
}

class MinStack {
    private static class Entry {
        int value;
        int minSoFar;

        Entry(int value, int minSoFar) {
            this.value = value;
            this.minSoFar = minSoFar;
        }
    }

    private final Deque<Entry> stack = new ArrayDeque<>();

    void push(int val) {
        int currentMin = stack.isEmpty() ? val : Math.min(val, stack.peek().minSoFar);
        stack.push(new Entry(val, currentMin));
    }

    void pop() {
        stack.pop();
    }

    int top() {
        return stack.peek().value;
    }

    int getMin() {
        return stack.peek().minSoFar;
    }
}
```

**Complexity:** Time O(1) for all operations. Space O(n): doubled per-element overhead for the min tracking.

**Common mistakes:**
- Recomputing `min(self.stack)` inside `getMin()`: correct but O(n), defeating the purpose.
- Using a single global `min` variable without a way to restore the previous minimum on `pop()`. That only works if you never pop the current minimum, which isn't guaranteed.
