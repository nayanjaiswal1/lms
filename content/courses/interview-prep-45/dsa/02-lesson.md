---
kind: lesson
id_key: interview-prep-45/day-02
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Two Pointers Pattern"
position: 2
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Two pointers is the first pattern where the win isn't a smarter data structure but a smarter *scan order*. It collapses an O(n²) nested-loop search over pairs into O(n) by exploiting structure in the input, usually sortedness. Interviewers use it to see whether you reach for hashing reflexively or actually check the problem's shape first.

## When to use two pointers vs hash maps

Both patterns often solve "find a pair/triple with some property" problems, but they exploit different things:

- **Hash map**: exploits nothing about the input's order. Works on unsorted data, costs O(n) extra space, answers "does X exist" in O(1).
- **Two pointers**: exploits *sortedness* (or a similar monotonic structure). Works in O(1) extra space, but usually requires the array to be sorted first (which costs O(n log n) if it isn't already).

Rule of thumb for interviews: if the array is already sorted, or you're free to sort it and don't need to preserve original order or indices, reach for two pointers to save space. If you need original indices (like Two Sum) or the input can't be reordered, use a hash map.

| | Hash map | Two pointers |
|---|---|---|
| Requires sorted input | No | Usually yes |
| Extra space | O(n) | O(1) |
| Preserves original indices | Yes | No (unless tracked separately) |
| Typical complexity | O(n) time | O(n) time after O(n log n) sort |

## Sorted array assumptions

Two pointers works because in a sorted array, moving the left pointer right only increases the value at that position, and moving the right pointer left only decreases it. This monotonic behavior lets you discard half the remaining search space at each step instead of trying every pair.

For 3Sum-style problems: fix one element, then use two pointers on the *remaining sorted subarray* to find pairs that sum to the needed complement. That's why sorting first turns an O(n³) triple-nested-loop into O(n²).

## In-place modifications

Many two-pointer problems ask you to modify the array in place (remove duplicates, move zeroes, partition) using O(1) extra space. The pattern: one pointer (`write` or `slow`) tracks where the next valid element should go; another pointer (`read` or `fast`) scans ahead looking for valid elements to bring back.

```python
def remove_duplicates(nums: list[int]) -> int:
    """Removes duplicates from a sorted array in place, returns new length."""
    if not nums:
        return 0
    write = 1
    for read in range(1, len(nums)):
        if nums[read] != nums[write - 1]:
            nums[write] = nums[read]
            write += 1
    return write
```

**Pitfall:** in-place two-pointer solutions are easy to get subtly wrong around the boundary condition (`!=` vs `<`, starting `write` at 0 vs 1). Always trace through a 2-3 element example by hand before declaring it correct.

## Valid Palindrome

[Valid Palindrome (LeetCode 125)](https://leetcode.com/problems/valid-palindrome/)

**Intuition:** A palindrome reads the same forwards and backwards. Instead of building a cleaned string and reversing it (extra space), walk from both ends toward the middle, comparing characters directly.

**Approach:** Use `left` and `right` pointers starting at the two ends. Skip non-alphanumeric characters on either side. Compare lowercase versions of the characters; a mismatch means not a palindrome. Pointers crossing means success.

```python
def is_palindrome(s: str) -> bool:
    left, right = 0, len(s) - 1
    while left < right:
        while left < right and not s[left].isalnum():
            left += 1
        while left < right and not s[right].isalnum():
            right -= 1
        if s[left].lower() != s[right].lower():
            return False
        left += 1
        right -= 1
    return True
```

**Complexity:** Time O(n), space O(1). No extra string built.

**Common mistakes:**
- Building a cleaned/lowercased copy of the string first: correct but O(n) extra space when O(1) is achievable.
- Inner `while` loops missing the `left < right` bound, causing an index-out-of-range when the string is all punctuation.
- Forgetting `.isalnum()` handles both letters and digits, not letters alone.

## 3Sum

[3Sum (LeetCode 15)](https://leetcode.com/problems/3sum/)

**Intuition:** Two Sum with a hash map generalizes awkwardly to three numbers because of duplicate-handling complexity. Sorting first and fixing one number reduces the problem to a Two Sum variant solvable with two pointers, and sorted order makes duplicate-skipping mechanical.

**Approach:** Sort the array. For each index `i` (skipping duplicate values of `nums[i]`), run two pointers (`left = i+1`, `right = n-1`) across the rest of the array looking for pairs summing to `-nums[i]`. Skip duplicate values at `left` and `right` after finding a match to avoid duplicate triplets.

```python
def three_sum(nums: list[int]) -> list[list[int]]:
    nums.sort()
    result = []
    n = len(nums)
    for i in range(n - 2):
        if i > 0 and nums[i] == nums[i - 1]:
            continue  # skip duplicate anchors
        if nums[i] > 0:
            break  # smallest remaining value is positive, no triplet can sum to 0
        left, right = i + 1, n - 1
        while left < right:
            total = nums[i] + nums[left] + nums[right]
            if total < 0:
                left += 1
            elif total > 0:
                right -= 1
            else:
                result.append([nums[i], nums[left], nums[right]])
                left += 1
                right -= 1
                while left < right and nums[left] == nums[left - 1]:
                    left += 1
                while left < right and nums[right] == nums[right + 1]:
                    right -= 1
    return result
```

**Complexity:** Time O(n²): O(n log n) sort plus an O(n) outer loop times an O(n) two-pointer scan. Space O(1) extra (excluding sort and output).

**Common mistakes:**
- Forgetting to skip duplicate anchors, producing duplicate triplets in the result.
- Skipping duplicates for `left`/`right` *before* recording the match instead of after.
- Using a hash-set based dedup on the output as a patch instead of the sorted-skip technique. It works, but it's slower and messier.

## Container With Most Water

[Container With Most Water (LeetCode 11)](https://leetcode.com/problems/container-with-most-water/)

**Intuition:** The area between two lines is `min(height[left], height[right]) * (right - left)`. Starting pointers at both ends maximizes the width term first. The key insight: moving the pointer at the *taller* line inward can never increase the area, since the width shrinks and height is capped by the shorter line either way. So you always move the *shorter* line's pointer.

**Approach:** Start `left = 0`, `right = n - 1`. Track the max area seen. Move whichever pointer points to the shorter line inward; repeat until pointers meet.

```python
def max_area(height: list[int]) -> int:
    left, right = 0, len(height) - 1
    best = 0
    while left < right:
        h = min(height[left], height[right])
        best = max(best, h * (right - left))
        if height[left] < height[right]:
            left += 1
        else:
            right -= 1
    return best
```

**Complexity:** Time O(n): a single pass, with each pointer moving at most n times total. Space O(1).

**Common mistakes:**
- Trying every pair (O(n²)) instead of recognizing the greedy "move the shorter side" argument.
- Moving the taller pointer, or moving both pointers every iteration: both break the correctness proof.
- Forgetting the area formula uses `min`, not `max`, of the two heights, since water can't rise above the shorter wall.

### Linked list node class

Several upcoming days (linked-list problems, tree/graph nodes) reuse a minimal node class. Get the boilerplate right now so it's not a distraction later:

```python
class ListNode:
    def __init__(self, val=0, next=None):
        self.val = val
        self.next = next

    def __repr__(self):
        return f"ListNode({self.val})"

def build_linked_list(values: list[int]) -> ListNode | None:
    dummy = ListNode()
    tail = dummy
    for v in values:
        tail.next = ListNode(v)
        tail = tail.next
    return dummy.next
```

The `dummy` head node is the recurring trick: it removes the special case of "is this the first node?" from insertion logic, since `dummy.next` always points at the real head.
