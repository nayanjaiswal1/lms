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

**Complexity:** Time O(1) for all operations. Space O(n): doubled per-element overhead for the min tracking.

**Common mistakes:**
- Recomputing `min(self.stack)` inside `getMin()`: correct but O(n), defeating the purpose.
- Using a single global `min` variable without a way to restore the previous minimum on `pop()`. That only works if you never pop the current minimum, which isn't guaranteed.
