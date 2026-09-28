---
kind: lesson
id_key: interview-prep-45/dsa-mock-rounds
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Pattern Recall and Mock Coding Rounds"
position: 26
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
    - mock-interviews/29-lesson.md
    - mock-interviews/30-lesson.md
    - mock-interviews/31-lesson.md
    - mock-interviews/32-lesson.md
    - mock-interviews/33-lesson.md
    - mock-interviews/34-lesson.md
    - final-prep/38-lesson.md
    - final-prep/39-lesson.md
    - final-prep/41-lesson.md
    - final-prep/42-lesson.md
    - dsa/07-lesson.md
    - dsa/14-lesson.md
    - dsa/21-lesson.md
    - interview-days/45-lesson.md
---

A fire drill doesn't teach you anything new about where the exits are. It proves you can find them fast, in the dark, without thinking. This lesson is a fire drill for every pattern you've learned in this course: no new data structures, no new algorithms, just rehearsal until pulling out the right tool is automatic. It walks through six mock problems the way you'd actually talk through them in an interview, drills the fastest patterns until they're instant, and ends with two recall sheets you can run through before any interview.

## Talking through a mock problem, start to finish

Use this exact shape for every coding problem in an interview, timed or not:

1. **Restate the problem in your own words** (about 30 seconds). This catches misunderstandings while they're still free to fix.
2. **Ask 1-2 clarifying questions.** Input size, duplicates allowed, negative numbers, empty input; whatever the problem statement left ambiguous.
3. **State a brute-force approach and its complexity out loud, before optimizing.** Interviewers reward the reasoning path, not just the final answer.
4. **Code the optimized approach, narrating as you go.** Silence while typing is the single worst signal you can send.
5. **Walk through one example by hand.**
6. **State the final time and space complexity, unprompted.**

Pass-bar checklist to hold yourself to: the gap between "read the problem" and "start talking" is under 30 seconds; you keep talking while you code, not silent for five-plus minutes; you state complexity unprompted, correctly; you mention edge cases before or during coding, not only when asked; you notice and fix your own bugs while testing, without needing a hint.

The six problems below are worked through this exact way. Read each problem yourself first, think about how you'd talk through it, then compare against the walkthrough.

> **Remember:** restate, clarify, brute force out loud, optimize while narrating, walk an example, state complexity unprompted. Same six steps, every problem.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-framework-q1", "type": "mcq",
      "prompt": "What should you do immediately after restating a coding problem, before writing any code?",
      "options": [
        {"id": "a", "text": "Ask 1-2 clarifying questions about input size, duplicates, or edge cases, then state a brute-force approach and its complexity out loud"},
        {"id": "b", "text": "Start typing the optimized solution right away to save time"},
        {"id": "c", "text": "Ask the interviewer for a hint"},
        {"id": "d", "text": "Write all your test cases before discussing any approach"}
      ],
      "correct": "a",
      "explanation": "Clarifying questions catch misunderstandings while they're cheap to fix, and stating the brute force with its complexity shows your reasoning process before you jump to the optimized code." }
] }
```

### Two Sum and Longest Substring Without Repeating Characters

**Two Sum.** Given an array of integers `nums` and an integer `target`, return the indices of the two numbers that add up to `target`. Assume exactly one solution exists, and you may not use the same element twice.

```
Input: nums = [2, 7, 11, 15], target = 9
Output: [0, 1]   # nums[0] + nums[1] == 9
```

Clarifying questions worth asking: can the array be unsorted (yes)? are there duplicate values (yes, `[3, 3]` with `target = 6` must work)? indices or values (indices, any order)? what if no solution exists (out of scope here, but say out loud what you'd do)?

```python
def two_sum(nums: list[int], target: int) -> list[int]:
    seen: dict[int, int] = {}  # value -> index
    for i, n in enumerate(nums):
        complement = target - n
        if complement in seen:
            return [seen[complement], i]
        seen[n] = i
    raise ValueError("no two sum solution")


if __name__ == "__main__":
    assert two_sum([2, 7, 11, 15], 9) == [0, 1]
    assert two_sum([3, 3], 6) == [0, 1]
    assert sorted(two_sum([3, 2, 4], 6)) == [1, 2]
    print("ok")
```

Time: O(n), one pass. Space: O(n) for the hash map. Mention the brute force, O(n²)/O(1), then justify the trade up to hashing; interviews reward the reasoning as much as the answer.

**Longest Substring Without Repeating Characters.** Given a string `s`, find the length of the longest substring without repeating characters.

```
Input: s = "abcabcbb" -> Output: 3   # "abc"
Input: s = "bbbbb" -> Output: 1   # "b"
Input: s = "pwwkew" -> Output: 3   # "wke"
```

Clarifying questions: character set (assume any Unicode character, not just lowercase)? empty string (return 0)? substring vs subsequence (substring: must be contiguous)?

```python
def length_of_longest_substring(s: str) -> int:
    last_seen: dict[str, int] = {}
    start = 0
    best = 0
    for i, ch in enumerate(s):
        if ch in last_seen and last_seen[ch] >= start:
            start = last_seen[ch] + 1
        last_seen[ch] = i
        best = max(best, i - start + 1)
    return best


if __name__ == "__main__":
    assert length_of_longest_substring("abcabcbb") == 3
    assert length_of_longest_substring("bbbbb") == 1
    assert length_of_longest_substring("pwwkew") == 3
    assert length_of_longest_substring("") == 0
    print("ok")
```

Time: O(n) with a sliding window, since each index enters and exits the window once. Space: O(min(n, alphabet size)) for the map. The naive substring-by-substring check is O(n³); name it, then explain why the window collapses it.

**How this pair gets scored (out of 5 each):** clarified the problem before coding (duplicates, edge cases, input assumptions); considered edge cases (empty input, no solution, single character); discussed time and space complexity for both the brute force and the optimized version; wrote clean code (meaningful names, no dead code).

### Merge Intervals

Given an array of intervals where `intervals[i] = [start_i, end_i]`, merge all overlapping intervals and return an array of the non-overlapping intervals that cover all the intervals in the input.

```
Input: [[1,3],[2,6],[8,10],[15,18]]
Output: [[1,6],[8,10],[15,18]]
```

Clarifying questions: is the input sorted (no, sort first)? do touching intervals count as overlapping, like `[1,3]` and `[3,5]` (yes here, treat `end_i >= start_{i+1}` as overlapping)? can intervals be malformed with `start > end` (assume valid, `start <= end`)?

```python
def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    if not intervals:
        return []
    intervals.sort(key=lambda iv: iv[0])
    merged = [intervals[0]]
    for start, end in intervals[1:]:
        last = merged[-1]
        if start <= last[1]:
            last[1] = max(last[1], end)
        else:
            merged.append([start, end])
    return merged


if __name__ == "__main__":
    assert merge_intervals([[1, 3], [2, 6], [8, 10], [15, 18]]) == [[1, 6], [8, 10], [15, 18]]
    assert merge_intervals([[1, 4], [4, 5]]) == [[1, 5]]
    assert merge_intervals([]) == []
    print("ok")
```

Time: O(n log n) for the sort, then O(n) to sweep. Space: O(n) for the sort and output. The key insight: once sorted, overlap can only happen with the *most recently merged* interval, so one linear pass after sorting is enough; no nested loop needed.

**Scoring:** clarified overlap semantics and the sort assumption before coding; handled edge cases (empty input, touching intervals, a single interval); stated time and space complexity unprompted; wrote clean code.

### Number of Islands

Given an `m x n` 2D binary grid representing `'1'` (land) and `'0'` (water), return the number of islands. An island is surrounded by water and formed by connecting adjacent lands horizontally or vertically.

```
Input:
[["1","1","0","0","0"],
 ["1","1","0","0","0"],
 ["0","0","1","0","0"],
 ["0","0","0","1","1"]]
Output: 3
```

Solve it with BFS first, then again with DFS, and compare the two. Clarifying questions: diagonal adjacency (no, only up/down/left/right)? can the grid be empty (yes, return 0)? can you mutate the input grid (if not, you need a separate `visited` set)?

```python
from collections import deque

def num_islands_dfs(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])

    def dfs(r: int, c: int) -> None:
        if r < 0 or r >= rows or c < 0 or c >= cols or grid[r][c] != "1":
            return
        grid[r][c] = "0"  # mark visited by sinking the island
        dfs(r + 1, c)
        dfs(r - 1, c)
        dfs(r, c + 1)
        dfs(r, c - 1)

    count = 0
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == "1":
                count += 1
                dfs(r, c)
    return count


def num_islands_bfs(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])
    count = 0
    for r in range(rows):
        for c in range(cols):
            if grid[r][c] != "1":
                continue
            count += 1
            queue = deque([(r, c)])
            grid[r][c] = "0"
            while queue:
                cr, cc = queue.popleft()
                for nr, nc in ((cr + 1, cc), (cr - 1, cc), (cr, cc + 1), (cr, cc - 1)):
                    if 0 <= nr < rows and 0 <= nc < cols and grid[nr][nc] == "1":
                        grid[nr][nc] = "0"
                        queue.append((nr, nc))
    return count


if __name__ == "__main__":
    g1 = [list(r) for r in ["11000", "11000", "00100", "00011"]]
    g2 = [list(r) for r in ["11000", "11000", "00100", "00011"]]
    assert num_islands_dfs(g1) == 3
    assert num_islands_bfs(g2) == 3
    print("ok")
```

**BFS vs DFS out loud:** both are O(rows x cols) time and O(rows x cols) worst-case space. DFS is simpler to write but risks a stack overflow on huge grids, since recursion depth is finite; for production code on unbounded input you'd convert it to an explicit stack. BFS's space is bounded by the frontier size rather than the call stack, at the cost of a little more bookkeeping (the queue). Leading with DFS for speed of writing, then naming BFS as the safer choice for large or unbounded grids, is the strongest answer.

Keep this muscle warm with the same BFS/DFS-on-a-graph family: Clone Graph (DFS or BFS with a visited map to avoid infinite recursion on cycles), Pacific Atlantic Water Flow (multi-source BFS/DFS starting from both ocean borders inward), Walls and Gates (multi-source BFS starting from every gate at once).

**Scoring:** solved correctly with both BFS and DFS; compared the two approaches' trade-offs (recursion depth risk, space characteristics) unprompted; handled edge cases (empty grid, all water, all land); wrote clean code in both versions.

### Longest Increasing Subsequence

Given an integer array `nums`, return the length of the longest strictly increasing subsequence.

```
Input: nums = [10,9,2,5,3,7,101,18]
Output: 4   # [2,3,7,101]
```

Solve with both DP (O(n²)) and binary search (O(n log n)), and explain both. Clarifying questions: strictly increasing or non-decreasing (strictly increasing)? subsequence, not subarray, so elements don't need to be contiguous (confirm before coding, since it changes the whole approach)? length only, or the subsequence itself (length only; reconstructing needs parent pointers)?

```python
import bisect

def length_of_lis_dp(nums: list[int]) -> int:
    """O(n^2) DP: dp[i] = length of LIS ending at index i."""
    if not nums:
        return 0
    dp = [1] * len(nums)
    for i in range(len(nums)):
        for j in range(i):
            if nums[j] < nums[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)


def length_of_lis_binary_search(nums: list[int]) -> int:
    """O(n log n): maintain 'tails', tails[k] = smallest possible tail of an
    increasing subsequence of length k+1. tails stays sorted, so binary search
    finds the insertion point."""
    tails: list[int] = []
    for n in nums:
        pos = bisect.bisect_left(tails, n)
        if pos == len(tails):
            tails.append(n)
        else:
            tails[pos] = n
    return len(tails)


if __name__ == "__main__":
    nums = [10, 9, 2, 5, 3, 7, 101, 18]
    assert length_of_lis_dp(nums) == 4
    assert length_of_lis_binary_search(nums) == 4
    assert length_of_lis_binary_search([]) == 0
    assert length_of_lis_binary_search([7, 7, 7]) == 1
    print("ok")
```

**What to explain out loud:** the DP approach answers "longest increasing subsequence ending exactly at `i`," built from every valid `j < i`, O(n²). The binary-search approach reframes the problem: `tails[k]` tracks the smallest tail value achievable for any increasing subsequence of length `k+1`. `tails` is always sorted, since a smaller tail for the same length can only help extend further, which is exactly what makes binary search valid on it. `tails` does *not* hold an actual subsequence, it's a greedy invariant; say that explicitly.

Keep this muscle warm with the same DP-over-prefixes-or-amounts family: Word Break (1D DP over string prefixes), Coin Change (1D DP over amounts), Edit Distance (2D DP over two string prefixes, from the Dynamic Programming: Two Dimensions lesson).

**Scoring:** correctly implemented the O(n²) DP solution; correctly implemented and explained the O(n log n) binary-search solution, including why `tails` stays sorted; clearly contrasted the two approaches' complexity and trade-offs; handled edge cases (empty array, all-equal elements, strictly decreasing array).

### Merge K Sorted Lists

You are given an array of `k` linked lists, each sorted in ascending order. Merge all the lists into one sorted linked list and return it.

```
Input: lists = [[1,4,5],[1,3,4],[2,6]]
Output: [1,1,2,3,4,4,5,6]
```

Solve with a min-heap first, targeting O(N log k) where N is the total number of nodes and k is the number of lists. If time remains, implement divide-and-conquer as a second approach and compare. Clarifying questions: can `lists` be empty or contain empty lists (yes to both)? are values unique across lists (no, duplicates allowed)? in-place or a new list (either; reusing existing nodes is the expected style)?

```python
import heapq
from typing import Optional


class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next


def merge_k_lists_heap(lists: list[Optional[ListNode]]) -> Optional[ListNode]:
    """Push the head of every list into a min-heap. Pop the smallest, attach it
    to the output, and push its successor. The heap never holds more than k
    nodes, so each of the N pops/pushes costs O(log k)."""
    heap: list[tuple[int, int, ListNode]] = []
    for i, node in enumerate(lists):
        if node:
            # tie-break on i (list index) since ListNode isn't orderable and
            # heapq needs a total order when values are equal.
            heapq.heappush(heap, (node.val, i, node))

    dummy = ListNode()
    tail = dummy
    while heap:
        val, i, node = heapq.heappop(heap)
        tail.next = node
        tail = tail.next
        if node.next:
            heapq.heappush(heap, (node.next.val, i, node.next))
    return dummy.next


def merge_two_lists(a: Optional[ListNode], b: Optional[ListNode]) -> Optional[ListNode]:
    dummy = ListNode()
    tail = dummy
    while a and b:
        if a.val <= b.val:
            tail.next, a = a, a.next
        else:
            tail.next, b = b, b.next
        tail = tail.next
    tail.next = a or b
    return dummy.next


def merge_k_lists_divide_and_conquer(lists: list[Optional[ListNode]]) -> Optional[ListNode]:
    """Pair up lists and merge two at a time, halving the count each round.
    Same O(N log k) bound as the heap, without needing a heap at all."""
    if not lists:
        return None
    lists = list(lists)
    while len(lists) > 1:
        merged = []
        for i in range(0, len(lists), 2):
            l1 = lists[i]
            l2 = lists[i + 1] if i + 1 < len(lists) else None
            merged.append(merge_two_lists(l1, l2))
        lists = merged
    return lists[0]


def build(values: list[int]) -> Optional[ListNode]:
    dummy = ListNode()
    tail = dummy
    for v in values:
        tail.next = ListNode(v)
        tail = tail.next
    return dummy.next


def to_list(node: Optional[ListNode]) -> list[int]:
    out = []
    while node:
        out.append(node.val)
        node = node.next
    return out


if __name__ == "__main__":
    lists = [build([1, 4, 5]), build([1, 3, 4]), build([2, 6])]
    assert to_list(merge_k_lists_heap(lists)) == [1, 1, 2, 3, 4, 4, 5, 6]

    lists2 = [build([1, 4, 5]), build([1, 3, 4]), build([2, 6])]
    assert to_list(merge_k_lists_divide_and_conquer(lists2)) == [1, 1, 2, 3, 4, 4, 5, 6]

    assert merge_k_lists_heap([]) is None
    assert to_list(merge_k_lists_heap([None, build([1])])) == [1]
    print("ok")
```

**What to explain out loud:** the naive approach, collect all N values, sort, rebuild, is O(N log N) and throws away the fact that each list is already sorted. Merging lists one at a time is O(N·k), since the accumulated list gets scanned against every remaining list. The heap keeps only the k current heads in memory; every pop and push is O(log k), N total nodes processed, giving O(N log k). Divide-and-conquer reaches the same bound differently: log k rounds, each doing O(N) work total, so O(N log k) again, and it's often preferred in practice because it avoids heap overhead and parallelizes more easily.

Keep this muscle warm with the same "running structure over a stream or window" family: Median of Data Stream (two heaps, one max-heap for the lower half and one min-heap for the upper half, rebalanced after every insert), Sliding Window Maximum (a monotonic deque of indices), Top K Frequent Elements (a hash map count, then a min-heap of size k, or bucket sort by frequency).

**Scoring:** reached the heap approach and correctly bounded it at O(N log k); implemented divide-and-conquer as the comparison approach and explained why it hits the same bound differently; handled edge cases (empty `lists`, lists containing `None`, duplicate values); wrote clean code (heap tie-breaking, dummy-node pattern).

### Binary Tree Level Order Traversal

Given the root of a binary tree, return the level order traversal of its node values, left to right, level by level, as a list of lists.

```
Input: root = [3,9,20,null,null,15,7]
Output: [[3],[9,20],[15,7]]
```

Solve with BFS first, then implement a DFS version that produces the same output. Clarifying questions: empty tree (return `[]`)? does node value range matter, negatives or duplicates (no constraint)? left-to-right order within a level, confirmed (yes, that's the definition, say it back before coding)?

```python
from collections import deque
from typing import Optional


class TreeNode:
    def __init__(self, val=0, left=None, right=None):
        self.val = val
        self.left = left
        self.right = right


def level_order_bfs(root: Optional[TreeNode]) -> list[list[int]]:
    """Queue-based BFS. The 'snapshot the queue length before draining it'
    trick is what separates levels without needing a sentinel value."""
    if not root:
        return []
    result: list[list[int]] = []
    queue = deque([root])
    while queue:
        level_size = len(queue)
        level = []
        for _ in range(level_size):
            node = queue.popleft()
            level.append(node.val)
            if node.left:
                queue.append(node.left)
            if node.right:
                queue.append(node.right)
        result.append(level)
    return result


def level_order_dfs(root: Optional[TreeNode]) -> list[list[int]]:
    """Pre-order DFS carrying a depth counter. Appends a new level list the
    first time a given depth is reached, then appends into it on every
    subsequent visit at that depth."""
    result: list[list[int]] = []

    def dfs(node: Optional[TreeNode], depth: int) -> None:
        if not node:
            return
        if depth == len(result):
            result.append([])
        result[depth].append(node.val)
        dfs(node.left, depth + 1)
        dfs(node.right, depth + 1)

    dfs(root, 0)
    return result


if __name__ == "__main__":
    root = TreeNode(3, TreeNode(9), TreeNode(20, TreeNode(15), TreeNode(7)))
    assert level_order_bfs(root) == [[3], [9, 20], [15, 7]]
    assert level_order_dfs(root) == [[3], [9, 20], [15, 7]]
    assert level_order_bfs(None) == []
    assert level_order_dfs(None) == []
    assert level_order_bfs(TreeNode(1)) == [[1]]
    print("ok")
```

**What to explain, comparing the two:** BFS is the natural fit; a queue processes nodes in the exact order levels are defined, and "capture `len(queue)` before draining it" is the one piece of mechanics worth having cold. Both are O(n) time and O(n) space (BFS: the queue holds up to the width of the tree; DFS: the recursion stack holds up to the height, and the output list is O(n) either way). DFS is less intuitive here but shows you can adapt a traversal you already have running to also produce level order, without a second data structure. BFS is the default reasonable choice; DFS is preferable mainly if you're already deep in a DFS-based traversal elsewhere and don't want a second pass.

Keep this muscle warm with the same traversal family: Validate BST (DFS with a running `(low, high)` bound tightened at every step, not just comparing to immediate children), Lowest Common Ancestor (general tree: DFS returns the node itself when found, or the current node when both children return non-null; BST: exploit ordering, O(h), no full traversal), Invert Binary Tree (swap `left`/`right` at every node, O(n) time).

**Scoring:** BFS solution correct and used the level-size-snapshot technique cleanly; DFS solution correct and produced identical output; explained complexity and the real trade-off between the two, not just "both are O(n)"; handled edge cases (empty tree, single node, unbalanced tree).

## Speed round: four patterns in fifteen minutes each

Speed comes from recognizing the pattern instantly, not from typing faster. Time yourself: one problem per pattern, fifteen minutes each, cold, with correct edge cases (empty input, single element, no match). If any of these four templates isn't automatic, revisit its full lesson before your next mock round.

**Two pointers** (full lesson: Two Pointers)
```python
def two_sum_sorted(nums: list[int], target: int) -> list[int]:
    lo, hi = 0, len(nums) - 1
    while lo < hi:
        s = nums[lo] + nums[hi]
        if s == target:
            return [lo, hi]
        elif s < target:
            lo += 1   # need a bigger sum
        else:
            hi -= 1   # need a smaller sum
    return []
```
Use when: a sorted array or string needs a pair or triple matching a sum or comparison condition, or an in-place partition (Dutch flag).

**Sliding window** (full lesson: Sliding Window)
```python
def longest_substring_no_repeat(s: str) -> int:
    seen = {}
    left = 0
    best = 0
    for right, ch in enumerate(s):
        if ch in seen and seen[ch] >= left:
            left = seen[ch] + 1   # shrink window past the duplicate
        seen[ch] = right
        best = max(best, right - left + 1)
    return best
```
Use when: a contiguous subarray or substring is optimizing a size, sum, or count of distinct elements. The window only ever expands right and shrinks left, never resets.

**Binary search** (full lesson: Binary Search)
```python
def search_rotated(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if nums[mid] == target:
            return mid
        if nums[lo] <= nums[mid]:            # left half is sorted
            if nums[lo] <= target < nums[mid]:
                hi = mid - 1
            else:
                lo = mid + 1
        else:                                 # right half is sorted
            if nums[mid] < target <= nums[hi]:
                lo = mid + 1
            else:
                hi = mid - 1
    return -1
```
Use when: the search space is sorted, or "sorted with a twist," or you spot the classic tell "minimize the maximum" / "maximize the minimum" over a monotonic condition, which means binary search on the answer, not the array.

**BFS/DFS** (full lesson: Graphs: BFS and DFS)
```python
from collections import deque

def num_islands(grid: list[list[str]]) -> int:
    if not grid:
        return 0
    rows, cols = len(grid), len(grid[0])
    visited = set()
    count = 0

    def bfs(r, c):
        q = deque([(r, c)])
        visited.add((r, c))
        while q:
            cr, cc = q.popleft()
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nr, nc = cr + dr, cc + dc
                if (0 <= nr < rows and 0 <= nc < cols
                        and (nr, nc) not in visited
                        and grid[nr][nc] == "1"):
                    visited.add((nr, nc))
                    q.append((nr, nc))

    for r in range(rows):
        for c in range(cols):
            if grid[r][c] == "1" and (r, c) not in visited:
                bfs(r, c)
                count += 1
    return count
```
Use when: traversing a graph or grid. BFS for shortest path in an unweighted graph or level-order processing; DFS for connectivity, cycle detection, backtracking, or wherever recursion naturally fits, like trees.

> **Remember:** the fifteen-minute test isn't about speed for its own sake. If a template takes longer than that cold, the gap is recognition, not typing.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-speed-round-q1", "type": "mcq",
      "prompt": "What does it mean if you can't write one of the four speed-round templates (two pointers, sliding window, binary search, BFS/DFS) from memory within 15 minutes?",
      "options": [
        {"id": "a", "text": "The gap is in pattern recognition or muscle memory, not typing speed, and that specific lesson needs another pass"},
        {"id": "b", "text": "That pattern is not actually important for interviews"},
        {"id": "c", "text": "You should abandon that pattern and focus only on the other three"},
        {"id": "d", "text": "It means the pattern only applies to hard-difficulty problems"}
      ],
      "correct": "a",
      "explanation": "Speed drills exist to expose exactly this: if a template isn't automatic, that's a signal to revisit the full lesson, not a sign the pattern doesn't matter." }
] }
```

## The clean-solution checklist

Apply this checklist to every problem you solve, mock or real:

- Meaningful variable names (`left`/`right`, not `i`/`j`, for pointers with semantic meaning; `slow`/`fast` for cycle detection).
- No dead code left behind from a discarded approach.
- Edge cases handled explicitly, not accidentally working (empty input, single element, all-same values).
- The correct final complexity stated in a one-line comment or said out loud.

Set a fifteen-minute hard stop per problem, whether you solved it or not. If you solved it under 10 minutes, ask yourself: "was my first approach actually optimal, or did I get lucky with a working-but-suboptimal solution?" and state the real time and space complexity out loud. If it took 10-15 minutes, note what slowed you down: pattern recognition, an edge case, an off-by-one. If you haven't solved it by 15 minutes, stop, look at just the approach, not the code, understand the gap, and move on.

> **Remember:** a fifteen-minute hard stop applies whether you solved the problem or not. What you do after the timer is what turns practice into improvement.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-checklist-q1", "type": "mcq",
      "prompt": "If you solve a mock problem in under 10 minutes, what question should you ask yourself before moving on?",
      "options": [
        {"id": "a", "text": "Was my first approach actually optimal, or did I get lucky with a working-but-suboptimal solution, and can I state the real complexity out loud?"},
        {"id": "b", "text": "Should I immediately attempt a harder problem to prove I'm ready?"},
        {"id": "c", "text": "Nothing; solving quickly means no further reflection is needed"},
        {"id": "d", "text": "Whether the interviewer would have given a hint by now"}
      ],
      "correct": "a",
      "explanation": "Solving fast doesn't guarantee the approach was optimal. Explicitly checking complexity and questioning whether you got lucky turns a fast solve into a genuine confidence check." }
] }
```

## Recall these from memory: graph, topological sort, and heap skeletons

Say the shape out loud before writing any code, for each of these:

**Graph traversal decision.**
```python
# Graph traversal decision:
# Ask: does the question say "shortest" / "minimum steps" / "fewest"?
#   Yes -> BFS with a queue, mark visited at ENQUEUE time
#   No, asks "does a path exist" / "find all X" / "connected components"?
#   Yes -> DFS, recursive or explicit stack
```

**Topological sort (Kahn's algorithm).**
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

**Heap top-K skeleton.**
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

**DP progression**, said out loud before writing code: what's the state (`dp[i]` or `dp[i][j]`)? what's the base case? what's the transition? can the space be compressed?

**Common mistakes that repeat across mock rounds:** confusing BFS's "mark visited at enqueue" with DFS's "mark visited at visit," which causes duplicate work or infinite loops on cycles; using a 2-state visited/unvisited cycle check on a directed graph instead of the 3-state (white/gray/black) check that topological sort actually needs; forgetting Python's `heapq` is min-heap only and forgetting to negate back after popping a simulated max-heap value; jumping straight to code without stating the DP state definition first.

> **Remember:** graph, topological sort, and heap top-K are the three skeletons worth having so automatic you never have to think about their shape, only their inputs.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-recall-skeletons-q1", "type": "mcq",
      "prompt": "What's the key difference between BFS's and DFS's visited-marking convention that, if confused, causes duplicate work or infinite loops on cycles?",
      "options": [
        {"id": "a", "text": "BFS marks a node visited when it's enqueued; DFS marks a node visited when it's actually visited"},
        {"id": "b", "text": "BFS never needs a visited set; only DFS does"},
        {"id": "c", "text": "DFS marks nodes visited before the traversal even starts"},
        {"id": "d", "text": "There is no difference; both mark visited at the same point"}
      ],
      "correct": "a",
      "explanation": "BFS marks a node visited the moment it's added to the queue, to avoid enqueuing it twice from different neighbors. DFS marks it visited when actually processed. Mixing these conventions up causes bugs." }
] }
```

## Running your own mock round

Structure your own practice the same way a real interview panel would: pick one problem, set a 30-minute timer, and grade yourself against the pass-bar checklist from the top of this lesson. Then run this after-action routine, since it's the most useful part of practicing alone:

- **Log every stumble**, pattern gaps and communication misses both, and drill exactly those weaknesses next. Mocks are diagnostic instruments; re-solving what you're already good at feels productive but moves nothing.
- **Rate yourself honestly** against the patterns you've covered so far: can you state the trigger cold, code it in under 20 minutes without notes, and explain the complexity trade-offs? Anything that fails even one of those three isn't "done," it's a candidate for re-solving.
- **Track two numbers**, not just problem count: time per problem split by phase (recognizing the pattern vs. writing the code vs. debugging edge cases), and which specific pattern keeps reappearing in your stumble log. A pattern that breaks once is bad luck. A pattern that breaks three times is a structural gap.

If you blank on the optimal approach mid-round, don't sit in silence. State the brute force, code it if you need to, then optimize out loud. A working O(n²) beats an imaginary O(n) every time; interviewers reward the trajectory from correct to fast, not a silent leap straight to the best answer.

> **Remember:** the most useful part of a mock round happens after the timer stops. Log the specific stumble, then drill that exact gap next, not a random new problem.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-self-run-q1", "type": "mcq",
      "prompt": "After running your own mock round, what's the most useful thing to do with the results?",
      "options": [
        {"id": "a", "text": "Log the specific stumbles (pattern gaps or communication misses) and drill exactly those weaknesses next"},
        {"id": "b", "text": "Immediately schedule another mock round to stay warm"},
        {"id": "c", "text": "Re-solve only the problems you already got right, to build confidence"},
        {"id": "d", "text": "Memorize the exact solution to that one problem"}
      ],
      "correct": "a",
      "explanation": "Mocks are diagnostic. Repeating what you're already good at feels productive but changes nothing; logging specific weaknesses and drilling them directly is what actually closes gaps." }
] }
```

## Which pattern for which clue

Use this table to train pattern recognition itself: read the left column as a clue you might see in a fresh problem statement, and answer with the pattern before you've even finished reading the problem.

| Clue in the problem | Pattern | Full lesson |
|---|---|---|
| Need fast lookup, frequency count, "have I seen this before" | Hashing | Arrays and Hashing |
| Sorted array or string, find a pair or triple by sum/comparison | Two pointers | Two Pointers |
| Contiguous subarray or substring, optimize a size/sum/count | Sliding window | Sliding Window |
| Sorted (or "sorted with a twist") search space | Binary search | Binary Search |
| "Minimize the maximum" / "maximize the minimum" over a monotonic check | Binary search on the answer | Binary Search |
| Matching brackets, "next greater/smaller element" | Stacks | Stacks |
| Hierarchy, ancestor/descendant, tree shape questions | Tree traversal | Trees: Basics |
| Rebuild a tree from traversal orders, validate a BST | BST properties | Trees: BST and Rebuilding |
| Prefix search, autocomplete, "starts with" | Tries | Tries |
| "Kth largest/smallest," "top K," running median | Heaps | Heaps and Priority Queues |
| Grid or graph connectivity, shortest path in an unweighted graph | BFS/DFS | Graphs: BFS and DFS |
| Ordering with dependencies, cycle detection in a directed graph | Topological sort | Graphs: Topological Sort and Cycles |
| Grouping or connectivity queries over time, "redundant connection" | Union-Find | Union-Find |
| "Count the ways" / "min or max cost," one moving index | 1D DP | Dynamic Programming Basics |
| Two sequences compared, or one sequence plus an extra flag | 2D DP | Dynamic Programming: Two Dimensions |
| `*` or `?` wildcard, or regex-style pattern matching | Hard string-matching DP | Dynamic Programming: Hard String Matching |
| "Generate all subsets/combinations/permutations" | Backtracking | Backtracking |
| Board placement with several simultaneous constraints (N-Queens, Sudoku) | Constraint-satisfaction backtracking | Backtracking: Constraint Satisfaction |
| A locally safe choice that never needs undoing | Greedy | Greedy Algorithms |
| Merge, insert, or schedule time ranges | Intervals | Interval Problems |
| "Appears twice except one," popcount, power-of-2 check | Bit manipulation | Bit Manipulation |
| Primes, GCD/LCM, in-place matrix rotation, fast exponentiation | Math and geometry | Math and Geometry |
| Anagram windows, substring search, efficient string building | Strings | String Manipulation |

> **Remember:** the fastest interviewers-are-impressed moment is naming the pattern out loud within the first thirty seconds of reading the problem. This table is what makes that automatic.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-pattern-table-q1", "type": "mcq",
      "prompt": "A problem asks you to find the ordering of course prerequisites and detect if that ordering is impossible. Which pattern does that clue point to?",
      "options": [
        {"id": "a", "text": "Topological sort, since it's about ordering with dependencies and detecting a cycle in a directed graph"},
        {"id": "b", "text": "Two pointers, since course lists are usually sorted"},
        {"id": "c", "text": "Sliding window, since prerequisites form a contiguous range"},
        {"id": "d", "text": "Bit manipulation, since courses are numbered"}
      ],
      "correct": "a",
      "explanation": "\"Ordering with dependencies\" plus \"detect if it's impossible\" is exactly the topological-sort clue: Kahn's algorithm produces the order, and a leftover unprocessed node signals a cycle." }
] }
```

## Self-check: are you ready

Rate yourself honestly, not aspirationally, on each pattern below. Anything that fails its verification isn't done yet; it's a candidate for re-solving before your next real interview.

| Pattern | Verify with |
|---|---|
| Hashing (Two Sum, Anagram, Duplicate) | Solve a medium two-sum or frequency variant in under 15 minutes, cold |
| Two Pointers / Sliding Window | Solve a medium substring or subarray problem in under 20 minutes, cold |
| Binary Search (basic, rotated, boundaries) | Write the overflow-safe midpoint formula and the rotated-array template from memory |
| Stacks (parentheses, monotonic stack, Min Stack) | Explain when a monotonic stack applies without looking anything up |
| Trees (traversals, BFS/DFS, BST) | Implement iterative in-order traversal and level-order BFS from memory |
| Graphs (BFS/DFS, topological sort) | Explain when to use BFS vs. a weighted shortest-path algorithm without hesitating |
| Union-Find | Implement path compression and union by rank from memory |
| DP (1D) | Solve House Robber or Climbing Stairs in under 10 minutes |
| DP (2D / string matching) | Re-derive the `dp[i][j]` state definition from a blank file, no notes |
| Backtracking | Solve N-Queens or Subsets from a blank file; the recursion tree should be obvious immediately |
| Greedy | State the exchange-argument proof for one greedy problem you've solved |
| Heaps / Priority Queue | Explain why building a heap from an array is O(n), not O(n log n) |
| Bit Manipulation | Explain why XOR finds the single unpaired number, and what `n & (n-1)` does |
| Math and Geometry | Derive the transpose-plus-reverse-rows matrix rotation on paper |
| Strings | Implement the sliding-window anagram check without looking anything up |

**Rapid-fire self-test**, answer out loud in one breath: when is a greedy solution valid? (When the problem has the optimal-substructure-plus-no-regret property: a locally optimal choice never gets undone later. If you can't prove that, use DP instead.) What's the time complexity of building a heap from an array? (O(n), not O(n log n), because most nodes are near the bottom and sift down only a short distance; that's amortized analysis, not a naive per-node bound.) When does BFS beat DFS? (Whenever "shortest path" or "fewest steps" in an unweighted graph is the actual question; BFS explores by distance layer, DFS doesn't.)

> **Remember:** "I recognize the solution when I read it" is not the same as "I can generate it cold." The second one is what the interview actually tests.

```knowledge-check
{ "questions": [
    { "id": "dsa-mock-rounds-self-check-q1", "type": "mcq",
      "prompt": "Why is heap construction from an array O(n) instead of O(n log n), even though each insert into an empty heap would be O(log n)?",
      "options": [
        {"id": "a", "text": "Most nodes in a heap are near the bottom of the tree, so they only sift down a short distance; the amortized total across all nodes works out to O(n), not n times O(log n)"},
        {"id": "b", "text": "Because heaps don't actually need to maintain their shape during construction"},
        {"id": "c", "text": "Because building a heap doesn't require any comparisons"},
        {"id": "d", "text": "It's actually O(n log n); O(n) is a common misconception"}
      ],
      "correct": "a",
      "explanation": "Heapify (build-heap) works bottom-up: the bulk of nodes are near the leaves and sift down only a few levels, so the total work sums to a linear amount rather than n log n." }
] }
```
