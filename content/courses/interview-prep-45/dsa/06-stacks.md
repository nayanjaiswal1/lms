---
kind: lesson
id_key: interview-prep-45/day-05
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Stacks"
position: 6
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---
Picture a stack of plates on a kitchen counter, 20 plates high. You add a new plate on top, and you take one off the top too. You never grab a plate from the middle without knocking the rest over. That is a stack, one of the simplest data structures there is, and the monotonic stack pattern built on top of it solves a whole family of "next greater or smaller element" problems in O(n), about 20 steps for 20 elements, that look like they need O(n²), about 400 comparisons, at first glance.

## LIFO principle

Like the plate stack, a data-structure stack supports two core operations, both O(1) (one step, regardless of how many plates are underneath): `push` (add to the top) and `pop` (remove from the top). Last-In-First-Out (LIFO) means the most recently added element leaves first, the same way the plate you set down last is the one you pick back up first. A queue (FIFO, First-In-First-Out) is the opposite: like a line at a coffee shop, the oldest person waiting is served first.

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

Python's `list` is a perfectly good stack (`append`/`pop` from the end are both O(1) amortized). Do not use `list.insert(0, x)` or `list.pop(0)` as a stack; those are O(n) because they shift every element.

> **Remember:** a stack is last-in-first-out. In Python, `append`/`pop` from the end. Never insert or pop from the front of a list-backed stack.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-lifo-q1", "type": "mcq",
      "prompt": "Why is `list.pop(0)` a poor choice for popping from a Python-list-backed stack?",
      "options": [
        {"id": "a", "text": "It is O(n) because every remaining element has to shift left"},
        {"id": "b", "text": "It raises an exception on an empty list"},
        {"id": "c", "text": "It removes the wrong element"},
        {"id": "d", "text": "Python lists don't support pop(0) at all"}
      ],
      "correct": "a",
      "explanation": "Removing from the front of a Python list shifts every remaining element one slot left, an O(n) operation. Popping from the end with plain pop() is O(1) amortized, which is what a stack should cost." }
] }
```

## Stack vs recursion

Picture a stack of sticky notes, one added every time you pause a task to start a smaller sub-task, and removed the moment that sub-task finishes and you go back to the one below it. That is exactly what a computer does on every recursive function call: it is an implicit stack. Each call pushes a new frame, its local variables and where to return to, onto the call stack, and returning pops it off. Any recursive algorithm can be rewritten iteratively with an explicit stack you manage yourself. That matters for two reasons.

1. Deep recursion can hit Python's recursion limit (1,000 calls deep by default) or overflow the real call stack, the same way a pile of 1,000 sticky notes eventually topples. An explicit stack has no such limit, bounded only by however much heap memory is free.
2. Interviewers sometimes ask directly for the iterative version, to check that you understand what recursion is doing underneath.

The mechanical translation: whatever you would pass as arguments to the recursive call, push as a tuple onto an explicit stack instead. A `while stack:` loop replaces the call.

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

> **Remember:** every recursive call is a push; every return is a pop. An explicit stack turns recursion into a loop with no depth limit.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-vs-recursion-q1", "type": "mcq",
      "prompt": "What is the main advantage of an iterative DFS using an explicit stack over a recursive DFS?",
      "options": [
        {"id": "a", "text": "It avoids hitting the language's recursion depth limit on deep graphs"},
        {"id": "b", "text": "It visits nodes in a different order that's always faster"},
        {"id": "c", "text": "It uses less memory in every case"},
        {"id": "d", "text": "It doesn't need a visited set"}
      ],
      "correct": "a",
      "explanation": "A recursive call stack has a fixed depth limit (1000 in Python by default) and can overflow on deep or highly connected graphs. An explicit stack on the heap has no such limit." }
] }
```

## Monotonic stack pattern

Picture 100 people lined up by height, and every time a taller person walks up to join the back of the line, everyone shorter than them steps out, because they just found the next taller person behind them. Whoever is left in line is always ordered shortest to tallest. A monotonic stack works the same way: it keeps its elements in strictly increasing or strictly decreasing order at all times. When a new element would break that order, you pop elements off the top until the order holds again, and each pop is a signal: the element just popped just found its next greater (or smaller) element.

This is the trick behind "next greater element" style problems. Instead of scanning forward from each element to find the next bigger one, which for 100 elements can mean close to 10,000 comparisons (O(n²)), you keep a stack of indices whose answer is not known yet, and resolve them as you scan once, left to right, about 100 steps total (O(n), since each index is pushed once and popped at most once).

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

Arrays make a fine stack, but interviewers sometimes ask for one implemented over a singly linked list, where push and pop happen at the head so both stay O(1) with no resizing:

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

No amortized cost here. Every operation is worst-case O(1) since there is never a resize, at the cost of the per-node pointer overhead an array-backed stack does not pay.

> **Remember:** a monotonic stack turns "find the next greater element for everyone" into one O(n) pass. Each index is pushed once, popped at most once.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-monotonic-q1", "type": "mcq",
      "prompt": "In a monotonic decreasing stack used for \"next greater element,\" what does popping an index off the stack signal?",
      "options": [
        {"id": "a", "text": "The current element is the popped index's next greater element"},
        {"id": "b", "text": "The stack is now empty"},
        {"id": "c", "text": "An error occurred and the algorithm should restart"},
        {"id": "d", "text": "The popped index has no next greater element"}
      ],
      "correct": "a",
      "explanation": "You only pop when the current value breaks the decreasing order, meaning the current value is bigger than the value at the popped index. That's exactly the definition of \"next greater element\" for the popped index." }
] }
```

## Valid Parentheses

[Valid Parentheses (LeetCode 20)](https://leetcode.com/problems/valid-parentheses/)

**Intuition:** Every closing bracket must match the most recently opened, unclosed bracket. "Most recent unmatched" is exactly what a stack tracks.

**Approach:** Push opening brackets. On a closing bracket, pop and check it matches the expected opener; a mismatch or an empty stack means invalid. The string is valid only if the stack is empty at the end.

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
- Forgetting to check `not stack` before popping on a closing bracket. A lone `")"` would crash or misbehave without that guard.
- Forgetting the final `not stack` check. A string like `"((("` never triggers a mismatch mid-scan, but is still invalid.

> **Remember:** push openers, pop and match on closers, and the stack must end empty.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-valid-parentheses-q1", "type": "mcq",
      "prompt": "Why does Valid Parentheses need to check that the stack is empty at the very end, not just during the scan?",
      "options": [
        {"id": "a", "text": "A string of only unmatched openers, like \"(((\", never triggers a mismatch mid-scan but is still invalid"},
        {"id": "b", "text": "The final check improves the time complexity"},
        {"id": "c", "text": "It's only needed for strings longer than 10 characters"},
        {"id": "d", "text": "It prevents integer overflow"}
      ],
      "correct": "a",
      "explanation": "Unmatched openers never cause a mismatch while scanning; they just sit on the stack. Only checking the stack is empty at the end catches a string that opened brackets it never closed." }
] }
```

## Daily Temperatures

[Daily Temperatures (LeetCode 739)](https://leetcode.com/problems/daily-temperatures/)

**Intuition:** For each day, find how many days until a warmer temperature. This is "next greater element," but returning the distance instead of the value.

**Approach:** A monotonic decreasing stack of indices. When the current temperature beats the temperature at the stack's top index, pop and record `current_index - popped_index` as the wait.

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
- Brute-forcing with a nested loop (O(n²)). Works, but it is the naive baseline interviewers expect you to improve on.
- Storing values instead of indices on the stack. You need the index to compute the distance, not the temperature.

> **Remember:** store indices, not values, so you can compute the distance once you find the warmer day.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-daily-temperatures-q1", "type": "mcq",
      "prompt": "In Daily Temperatures, why does the monotonic stack store indices instead of temperature values?",
      "options": [
        {"id": "a", "text": "The index is needed to compute the distance (days to wait) once a warmer temperature is found"},
        {"id": "b", "text": "Indices take less memory than temperatures"},
        {"id": "c", "text": "Temperatures can't be compared directly"},
        {"id": "d", "text": "It makes the stack strictly increasing instead of decreasing"}
      ],
      "correct": "a",
      "explanation": "The answer needed is a distance in days, current index minus the stored index. You can always look up the temperature at a stored index, but you can't recover the index from just a temperature value." }
] }
```

## Largest Rectangle in Histogram

[Largest Rectangle in Histogram (LeetCode 84)](https://leetcode.com/problems/largest-rectangle-in-histogram/)

**Intuition:** For each bar, the largest rectangle using that bar as its shortest (limiting) height extends as far left and right as neighboring bars stay at least as tall. A monotonic increasing stack finds, for each bar, the nearest shorter bar on both sides in a single O(n) pass; those boundaries set the max width for that bar's height.

**Approach:** Keep a stack of indices with increasing heights. When the current bar is shorter than the stack's top, pop and compute the area using the popped bar's height, with width equal to the current index minus the new stack top's index minus 1 (or just the current index if the stack is empty). Append a sentinel height of `0` at the end to flush the remaining bars.

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
- Getting the width formula wrong. It is `i - stack[-1] - 1` (excluding both boundary indices), not `i - stack[-1]`.
- Trying brute force (checking every pair of left/right boundaries, O(n²) or O(n³)) as the final answer instead of a starting point.

> **Remember:** a monotonic increasing stack finds each bar's nearest shorter neighbor on both sides in one pass. Add a sentinel zero to flush the stack at the end.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-largest-rectangle-q1", "type": "mcq",
      "prompt": "Why does the Largest Rectangle in Histogram solution append a sentinel value of 0 at the end of the heights array?",
      "options": [
        {"id": "a", "text": "It forces every remaining bar on the stack to be popped and its area computed"},
        {"id": "b", "text": "It increases the maximum possible area"},
        {"id": "c", "text": "It is required to make the array length even"},
        {"id": "d", "text": "It prevents the stack from ever being empty"}
      ],
      "correct": "a",
      "explanation": "Without a final value shorter than everything on the stack, some bars would never get popped and their rectangle areas would never be computed. The sentinel 0 guarantees every bar eventually gets resolved." }
] }
```

## Min Stack

[Min Stack (LeetCode 155)](https://leetcode.com/problems/min-stack/)

**Intuition:** A normal stack gives O(1) push, pop, and top, but O(n) minimum, since you would have to scan. Track the running minimum alongside each element, so every push carries "the minimum including me," giving O(1) minimum retrieval too.

**Approach:** Store `(value, current_min)` pairs in a single stack, where `current_min` is the smaller of the new value and the previous entry's minimum.

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

**Complexity:** Time O(1) for every operation. Space O(n): double the per-element storage, for the min tracking.

**Common mistakes:**
- Recomputing `min(self.stack)` inside `getMin()`. Correct, but O(n), defeating the purpose.
- Using one global `min` variable with no way to restore the previous minimum on `pop()`. That only works if you never pop the current minimum, which is not guaranteed.

> **Remember:** store the running minimum alongside every value, so popping an old minimum automatically reveals the one before it.

```knowledge-check
{ "questions": [
    { "id": "dsa-stacks-min-stack-q1", "type": "mcq",
      "prompt": "Why does Min Stack store a (value, min_so_far) pair at every level instead of one global minimum variable?",
      "options": [
        {"id": "a", "text": "So that popping the current minimum automatically restores the correct previous minimum"},
        {"id": "b", "text": "It makes push and pop run faster"},
        {"id": "c", "text": "A single global variable can't be updated inside a class"},
        {"id": "d", "text": "It reduces the space complexity to O(1)"}
      ],
      "correct": "a",
      "explanation": "A single global minimum has no way to know the previous minimum once the current one is popped. Storing the minimum-so-far at each stack level means popping always reveals the correct minimum for what remains." }
] }
```
