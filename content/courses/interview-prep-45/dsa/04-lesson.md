---
kind: lesson
id_key: interview-prep-45/day-04
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 4 — Binary Search"
position: 4
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---
Binary search looks trivial until you're implementing it live and hit an off-by-one that loops forever. It's also one of the most transferable ideas in the whole interview canon: once you see it as "eliminate half the search space using a monotonic condition," it applies far beyond sorted arrays — rotated arrays, 2D grids, and even "search the answer" optimization problems. Today is about building a template you never second-guess.

## Search space reduction

Binary search works whenever you can define a boolean condition over the search space that is **monotonic** — false for a prefix, then true for the rest (or vice versa). At each step you evaluate the condition at the midpoint and discard the half that can't contain the answer. That's a guaranteed halving of the remaining space every iteration, which is what gives O(log n).

```python
def binary_search(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums) - 1
    while lo <= hi:
        mid = lo + (hi - lo) // 2  # avoids overflow in other languages, good habit
        if nums[mid] == target:
            return mid
        elif nums[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1
```

`lo + (hi - lo) // 2` instead of `(lo + hi) // 2` is a habit worth keeping even in Python (where integers don't overflow) — it signals you understand why the naive version breaks in languages with fixed-width integers.

## Finding boundaries (lower bound, upper bound)

Many real problems don't ask "does target exist" — they ask "where would target go" or "what's the first/last position satisfying a condition." That's a **boundary search**, and it needs a variant template that never lets `lo` and `hi` cross prematurely:

```python
def lower_bound(nums: list[int], target: int) -> int:
    """First index where nums[index] >= target."""
    lo, hi = 0, len(nums)
    while lo < hi:
        mid = lo + (hi - lo) // 2
        if nums[mid] < target:
            lo = mid + 1
        else:
            hi = mid
    return lo

def upper_bound(nums: list[int], target: int) -> int:
    """First index where nums[index] > target."""
    lo, hi = 0, len(nums)
    while lo < hi:
        mid = lo + (hi - lo) // 2
        if nums[mid] <= target:
            lo = mid + 1
        else:
            hi = mid
    return lo
```

Key differences from the exact-match template: `hi` starts at `len(nums)` (one past the end, representing "not found, insert here"), the loop condition is `lo < hi` (not `<=`), and there's no early return — the loop converges `lo == hi` on the answer. Mixing this template's conventions with the exact-match template's is the #1 source of infinite loops.

## Monotonic functions

"Search the answer" problems (e.g., "minimum capacity to ship packages within D days") aren't phrased as array search at all, but they hide a monotonic predicate: "can we ship within D days using capacity C?" is false for small C and true for large C, monotonically. Binary search over the *answer space* (capacities from 1 to sum of weights), applying the boundary-search template to find the smallest C where the predicate flips to true. Recognizing this shape — a yes/no question that flips monotonically as some parameter increases — is what separates candidates who only know "binary search on sorted array" from those who can apply it broadly.

## Binary Search

[Binary Search (LeetCode 704)](https://leetcode.com/problems/binary-search/)

**Intuition:** The baseline exact-match template — confirm you can write it cold, with correct bounds, in under a minute.

**Approach:** Standard `lo <= hi` loop, compare midpoint to target, narrow the half that can't contain it.

```python
def search(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums) - 1
    while lo <= hi:
        mid = lo + (hi - lo) // 2
        if nums[mid] == target:
            return mid
        elif nums[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1
```

**Complexity:** Time O(log n), space O(1).

**Common mistakes:**
- Using `hi = len(nums)` with `lo <= hi` (mixing template conventions) — causes an out-of-range access at `nums[hi]` when `hi == len(nums)`.
- Forgetting `mid + 1` / `mid - 1` and instead setting `lo = mid` / `hi = mid`, which can infinite-loop when `lo` and `hi` are adjacent.

## Search in Rotated Sorted Array

[Search in Rotated Sorted Array (LeetCode 33)](https://leetcode.com/problems/search-in-rotated-sorted-array/)

**Intuition:** The array isn't fully sorted, but at any midpoint, *at least one half* (left-of-mid or mid-to-right) is guaranteed to be normally sorted. Identify which half is sorted, then check whether the target lies within that half's range — if so recurse there, otherwise recurse into the other half.

**Approach:** Standard binary search loop, but before narrowing, determine sortedness of `nums[lo..mid]` by comparing `nums[lo]` and `nums[mid]`.

```python
def search_rotated(nums: list[int], target: int) -> int:
    lo, hi = 0, len(nums) - 1
    while lo <= hi:
        mid = lo + (hi - lo) // 2
        if nums[mid] == target:
            return mid

        if nums[lo] <= nums[mid]:  # left half is sorted
            if nums[lo] <= target < nums[mid]:
                hi = mid - 1
            else:
                lo = mid + 1
        else:  # right half is sorted
            if nums[mid] < target <= nums[hi]:
                lo = mid + 1
            else:
                hi = mid - 1
    return -1
```

**Complexity:** Time O(log n), space O(1).

**Common mistakes:**
- Using `<` instead of `<=` when checking `nums[lo] <= nums[mid]` — with only one element or two equal boundary values, this misclassifies which half is sorted.
- Forgetting the boundary comparisons must be inclusive/exclusive correctly (`nums[lo] <= target < nums[mid]`) to avoid missing the target sitting exactly at a boundary.

## Find Minimum in Rotated Sorted Array

[Find Minimum in Rotated Sorted Array (LeetCode 153)](https://leetcode.com/problems/find-minimum-in-rotated-sorted-array/)

**Intuition:** The minimum is the rotation "pivot point" — the one place where `nums[i] > nums[i+1]`. Compare the midpoint to the rightmost element: if `nums[mid] > nums[hi]`, the minimum must be to the right of mid (the rotation point hasn't been passed yet); otherwise it's at or to the left of mid.

**Approach:** Boundary-search style loop narrowing toward the pivot.

```python
def find_min(nums: list[int]) -> int:
    lo, hi = 0, len(nums) - 1
    while lo < hi:
        mid = lo + (hi - lo) // 2
        if nums[mid] > nums[hi]:
            lo = mid + 1
        else:
            hi = mid
    return nums[lo]
```

**Complexity:** Time O(log n), space O(1).

**Common mistakes:**
- Comparing `nums[mid]` to `nums[lo]` instead of `nums[hi]` — breaks when the left half itself is the sorted, non-rotated portion.
- Using `lo <= hi` here instead of `lo < hi`; this template converges to a single index and doesn't need the equality case.

## Search a 2D Matrix

[Search a 2D Matrix (LeetCode 74)](https://leetcode.com/problems/search-a-2d-matrix/)

**Intuition:** If each row is sorted and the first element of each row is greater than the last element of the previous row, the whole matrix is really a single sorted 1D array in disguise — you can binary search over the flattened index space and convert back to `(row, col)`.

**Approach:** Binary search over indices `0` to `rows*cols - 1`; convert a flat index to `(row, col)` with divmod.

```python
def search_matrix(matrix: list[list[int]], target: int) -> bool:
    if not matrix or not matrix[0]:
        return False
    rows, cols = len(matrix), len(matrix[0])
    lo, hi = 0, rows * cols - 1

    while lo <= hi:
        mid = lo + (hi - lo) // 2
        row, col = divmod(mid, cols)
        val = matrix[row][col]
        if val == target:
            return True
        elif val < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return False
```

**Complexity:** Time O(log(rows·cols)), space O(1).

**Common mistakes:**
- Doing two separate binary searches (one to find the row, one within the row) — correct and still O(log n) but more code and more places to get bounds wrong than the flattened-index trick.
- Getting `divmod(mid, cols)` backwards (`col, row` instead of `row, col`).

## Key takeaways

- Binary search requires a monotonic condition over the search space, not necessarily a literally sorted array.
- Keep two templates straight: exact-match (`lo <= hi`, `mid ± 1`) and boundary-search (`lo < hi`, `hi = mid` on the "keep" branch) — mixing their conventions is the top cause of infinite loops.
- Rotated-array search works by identifying which half of the current range is normally sorted, then checking if the target's value falls within that half's range.
- "Search the answer" problems hide a monotonic yes/no predicate over a range of candidate answers — binary search the predicate, not the input array.
- A sorted 2D matrix can often be treated as a flattened 1D array for a single binary search pass.

## Today's checklist

- [ ] Solve Binary Search with the exact-match template from memory
- [ ] Solve Search in Rotated Sorted Array by identifying the sorted half
- [ ] Solve Find Minimum in Rotated Sorted Array
- [ ] Solve Search a 2D Matrix by treating it as 1D
- [ ] Implement lower_bound and upper_bound functions
- [ ] Practice identifying when binary search applies
- [ ] Memorize: binary search is O(log n)
- [ ] Review: common off-by-one errors
