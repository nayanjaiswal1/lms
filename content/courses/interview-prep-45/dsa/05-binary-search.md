---
kind: lesson
id_key: interview-prep-45/day-04
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Binary Search"
position: 5
estimated_minutes: 105
source:
    - 45-day-interview-roadmap.md
---
Picture a guessing game: someone picks a whole number from 1 to 100, and after each guess they only say "higher" or "lower," never the number itself. Guess 50. Told "higher," guess 75. Told "lower," guess 62. Keep splitting whatever range is left in half, and you land on the exact number within 7 guesses, out of 100 possibilities. That is binary search: throw away half of what is left at every single step. It looks simple on paper, but small mistakes in exactly where the two boundaries sit cause an infinite loop the moment you write it live. Get the pattern right once, and it stops being just "search a sorted array." It also handles rotated arrays, 2D grids, and "find the best possible answer" optimization problems.

## Search space reduction

In the guessing game above, the answer to "is the number higher than my guess?" flips from true to false exactly once as your guesses climb from 1 to 100. That one-way flip is what let you throw away half the range with full confidence every time. The technical name for that shape is **monotonic**: false for a run of values, then true for the rest (or the other way around), with exactly one flip point in between. Binary search works whenever you can define a monotonic yes/no rule over the search space. At each step you check the rule at the midpoint and throw away the half that cannot contain the answer. That guarantees the remaining space halves every step, which is what gives O(log n): a range of 100 shrinks to 50, then 25, then 12, then 6, then 3, then 1, about 7 steps, not 100 one-by-one guesses.

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
```javascript +
function binarySearch(nums, target) {
  let lo = 0;
  let hi = nums.length - 1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (nums[mid] === target) {
      return mid;
    } else if (nums[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {1, 3, 5, 7, 9, 11};
        System.out.println(binarySearch(nums, 7));
    }

    static int binarySearch(int[] nums, int target) {
        int lo = 0;
        int hi = nums.length - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2; // avoids overflow, standard habit
            if (nums[mid] == target) {
                return mid;
            } else if (nums[mid] < target) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return -1;
    }
}
```

`lo + (hi - lo) // 2` instead of `(lo + hi) // 2` is a habit worth keeping even in Python, where integers never overflow. It shows you understand why the naive version breaks in languages with fixed-width integers.

> **Remember:** binary search needs a monotonic yes/no rule: false, then true, with one flip point. Halving only works because of that.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-search-space-q1", "type": "mcq",
      "prompt": "What property must a search space have for binary search to work on it?",
      "options": [
        {"id": "a", "text": "A monotonic condition: false for a prefix, then true for the rest (or the reverse)"},
        {"id": "b", "text": "It must contain only positive numbers"},
        {"id": "c", "text": "It must have an even number of elements"},
        {"id": "d", "text": "It must be a linked list, not an array"}
      ],
      "correct": "a",
      "explanation": "Binary search discards half the space at each step by evaluating a condition at the midpoint. That only works if the condition flips exactly once across the space, from false to true or true to false." }
] }
```

## Finding boundaries (lower bound, upper bound)

Picture a shelf of 1,000 books sorted by page count, with several books tied at exactly 300 pages. You want the position of the first 300-page book on the shelf, not just whether one exists. Many real problems ask exactly that: not "does target exist" but "where would target go" or "what is the first or last position satisfying a condition." That is a boundary search, and it needs a variant template that never lets `lo` and `hi` cross too early:

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
```javascript +
function lowerBound(nums, target) {
  // First index where nums[index] >= target.
  let lo = 0;
  let hi = nums.length;
  while (lo < hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (nums[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

function upperBound(nums, target) {
  // First index where nums[index] > target.
  let lo = 0;
  let hi = nums.length;
  while (lo < hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (nums[mid] <= target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {1, 2, 2, 2, 3, 5};
        System.out.println(lowerBound(nums, 2));
        System.out.println(upperBound(nums, 2));
    }

    // First index where nums[index] >= target.
    static int lowerBound(int[] nums, int target) {
        int lo = 0;
        int hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] < target) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return lo;
    }

    // First index where nums[index] > target.
    static int upperBound(int[] nums, int target) {
        int lo = 0;
        int hi = nums.length;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] <= target) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return lo;
    }
}
```

The key differences from the exact-match template: `hi` starts at `len(nums)` (one past the end, meaning "not found, insert here"), the loop condition is `lo < hi` (not `<=`), and there is no early return, since the loop converges with `lo == hi` landing on the answer. Mixing one template's conventions with the other's is the number one source of infinite loops.

> **Remember:** exact match uses `lo <= hi` and `mid ± 1`. Boundary search uses `lo < hi` and `hi = mid`. Never mix them.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-boundaries-q1", "type": "mcq",
      "prompt": "What is the most common cause of an infinite loop when writing a boundary-search binary search?",
      "options": [
        {"id": "a", "text": "Mixing the exact-match template's loop condition or update rule with the boundary-search template's"},
        {"id": "b", "text": "Starting lo at 1 instead of 0"},
        {"id": "c", "text": "Using recursion instead of a loop"},
        {"id": "d", "text": "Forgetting to sort the array first"}
      ],
      "correct": "a",
      "explanation": "The exact-match template uses lo <= hi with mid ± 1 updates; boundary search uses lo < hi with hi = mid. Borrowing one template's loop condition while using the other's update rule is what causes lo and hi to never converge." }
] }
```

## Monotonic functions and searching the answer

Picture 10 packages that need to ship within 5 days on trucks of some capacity `C`. With `C = 1`, the trucks crawl and shipping takes 20 days: too slow. With `C = 1000`, everything fits on one truck and ships in 1 day: done. Somewhere between 1 and 1000, the answer to "can we finish within 5 days?" flips from no to yes and stays yes. "Search the answer" problems like this one are not phrased as array search at all, but they hide that same monotonic rule. Binary search over the answer space itself, capacities from 1 to the total weight, applying the boundary-search template to find the smallest `C` where the rule flips to true.

Recognizing this shape, a yes/no question that flips one-directionally as some parameter increases, is what separates candidates who only know "binary search on a sorted array" from those who can apply it broadly.

> **Remember:** if a yes/no question flips exactly once as a parameter grows, you can binary search that parameter, even if there's no array in sight.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-monotonic-functions-q1", "type": "mcq",
      "prompt": "What lets you binary search a problem like \"minimum capacity to ship packages within D days\", which has no array to search?",
      "options": [
        {"id": "a", "text": "The yes/no question \"can we ship within D days with capacity C?\" is monotonic in C"},
        {"id": "b", "text": "The packages must already be sorted by weight"},
        {"id": "c", "text": "Binary search always applies to any optimization problem"},
        {"id": "d", "text": "D must be a power of two"}
      ],
      "correct": "a",
      "explanation": "As capacity C increases, \"can we ship within D days?\" goes from false to true and stays true. That one-directional flip is exactly the property binary search needs, letting you search over capacities instead of array indices." }
] }
```

## Binary Search

[Binary Search (LeetCode 704)](https://leetcode.com/problems/binary-search/)

**Intuition:** The baseline exact-match template. Confirm you can write it cold, with correct bounds, in under a minute.

**Approach:** Standard `lo <= hi` loop, compare the midpoint to target, narrow to the half that cannot contain it.

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
```javascript +
function search(nums, target) {
  let lo = 0;
  let hi = nums.length - 1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (nums[mid] === target) {
      return mid;
    } else if (nums[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {-1, 0, 3, 5, 9, 12};
        System.out.println(search(nums, 9));
    }

    static int search(int[] nums, int target) {
        int lo = 0;
        int hi = nums.length - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] == target) {
                return mid;
            } else if (nums[mid] < target) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return -1;
    }
}
```

**Complexity:** Time O(log n), space O(1).

**Common mistakes:**
- Using `hi = len(nums)` together with `lo <= hi` (mixing template conventions): causes an out-of-range access at `nums[hi]` when `hi == len(nums)`.
- Forgetting `mid + 1` / `mid - 1` and instead setting `lo = mid` / `hi = mid`, which can infinite-loop when `lo` and `hi` are adjacent.

> **Remember:** the exact-match template narrows with `mid + 1` / `mid - 1`, never plain `mid`.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-basic-search-q1", "type": "mcq",
      "prompt": "What bug does setting `lo = mid` instead of `lo = mid + 1` in the exact-match template usually cause?",
      "options": [
        {"id": "a", "text": "An infinite loop when lo and hi become adjacent"},
        {"id": "b", "text": "It makes the search run in O(n) instead of O(log n)"},
        {"id": "c", "text": "It skips half the array unnecessarily"},
        {"id": "d", "text": "It only affects arrays with duplicate values"}
      ],
      "correct": "a",
      "explanation": "If nums[mid] < target and you set lo = mid, and mid happens to equal lo, the loop never makes progress, and lo/hi keep circling the same value forever." }
] }
```

## Search in Rotated Sorted Array

[Search in Rotated Sorted Array (LeetCode 33)](https://leetcode.com/problems/search-in-rotated-sorted-array/)

**Intuition:** The array is not fully sorted, but at any midpoint, at least one half (left-of-mid or mid-to-right) is guaranteed to be normally sorted. Figure out which half is sorted, then check whether the target lies in that half's range. If so, recurse there; if not, recurse into the other half.

**Approach:** Standard binary search loop, but before narrowing, check whether `nums[lo..mid]` is sorted by comparing `nums[lo]` and `nums[mid]`.

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
```javascript +
function searchRotated(nums, target) {
  let lo = 0;
  let hi = nums.length - 1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (nums[mid] === target) return mid;

    if (nums[lo] <= nums[mid]) {
      // left half is sorted
      if (nums[lo] <= target && target < nums[mid]) {
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    } else {
      // right half is sorted
      if (nums[mid] < target && target <= nums[hi]) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
  }
  return -1;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {4, 5, 6, 7, 0, 1, 2};
        System.out.println(searchRotated(nums, 0));
    }

    static int searchRotated(int[] nums, int target) {
        int lo = 0;
        int hi = nums.length - 1;
        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] == target) return mid;

            if (nums[lo] <= nums[mid]) { // left half is sorted
                if (nums[lo] <= target && target < nums[mid]) {
                    hi = mid - 1;
                } else {
                    lo = mid + 1;
                }
            } else { // right half is sorted
                if (nums[mid] < target && target <= nums[hi]) {
                    lo = mid + 1;
                } else {
                    hi = mid - 1;
                }
            }
        }
        return -1;
    }
}
```

**Complexity:** Time O(log n), space O(1).

**Common mistakes:**
- Using `<` instead of `<=` when checking `nums[lo] <= nums[mid]`. With only one element, or two equal boundary values, this misclassifies which half is sorted.
- Getting the boundary comparisons wrong (`nums[lo] <= target < nums[mid]`), missing a target that sits exactly at a boundary.

> **Remember:** one half of a rotated array is always fully sorted. Find which one, then check if the target's range fits inside it.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-rotated-array-q1", "type": "mcq",
      "prompt": "In Search in Rotated Sorted Array, how do you decide which half of the array to search next?",
      "options": [
        {"id": "a", "text": "Determine which half is fully sorted, then check if the target's value falls within that half's range"},
        {"id": "b", "text": "Always search the left half first"},
        {"id": "c", "text": "Re-sort the whole array before searching"},
        {"id": "d", "text": "Search whichever half is shorter"}
      ],
      "correct": "a",
      "explanation": "At least one half around any midpoint is guaranteed normally sorted. Once you know which one, you can check with plain range comparisons whether the target could be in it, and recurse into the correct half." }
] }
```

## Find Minimum in Rotated Sorted Array

[Find Minimum in Rotated Sorted Array (LeetCode 153)](https://leetcode.com/problems/find-minimum-in-rotated-sorted-array/)

**Intuition:** The minimum is the rotation's "pivot point," the one place where `nums[i] > nums[i+1]`. Compare the midpoint to the rightmost element: if `nums[mid] > nums[hi]`, the minimum must be to the right of mid, since the rotation point has not been passed yet. Otherwise it is at or to the left of mid.

**Approach:** A boundary-search style loop narrowing toward the pivot.

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
```javascript +
function findMin(nums) {
  let lo = 0;
  let hi = nums.length - 1;
  while (lo < hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (nums[mid] > nums[hi]) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return nums[lo];
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {4, 5, 6, 7, 0, 1, 2};
        System.out.println(findMin(nums));
    }

    static int findMin(int[] nums) {
        int lo = 0;
        int hi = nums.length - 1;
        while (lo < hi) {
            int mid = lo + (hi - lo) / 2;
            if (nums[mid] > nums[hi]) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        return nums[lo];
    }
}
```

**Complexity:** Time O(log n), space O(1).

**Common mistakes:**
- Comparing `nums[mid]` to `nums[lo]` instead of `nums[hi]`. This breaks when the left half itself is the sorted, non-rotated portion.
- Using `lo <= hi` here instead of `lo < hi`. This template converges to a single index and does not need the equality case.

> **Remember:** compare `nums[mid]` against `nums[hi]`, not `nums[lo]`, to find which side the rotation pivot is on.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-find-min-rotated-q1", "type": "mcq",
      "prompt": "Why does Find Minimum in Rotated Sorted Array compare `nums[mid]` to `nums[hi]` instead of `nums[lo]`?",
      "options": [
        {"id": "a", "text": "Comparing to nums[hi] correctly identifies which side of the pivot mid is on, even when the left half is the sorted, non-rotated part"},
        {"id": "b", "text": "Comparing to nums[lo] would be faster"},
        {"id": "c", "text": "It doesn't matter which one you compare to"},
        {"id": "d", "text": "nums[hi] is always the minimum value"}
      ],
      "correct": "a",
      "explanation": "If nums[mid] > nums[hi], the rotation point (and the minimum) must be to the right of mid. Comparing against nums[lo] instead gives the wrong answer when the array's left half happens to be the unrotated, sorted side." }
] }
```

## Search a 2D Matrix

[Search a 2D Matrix (LeetCode 74)](https://leetcode.com/problems/search-a-2d-matrix/)

**Intuition:** If each row is sorted and the first element of each row is greater than the last element of the previous row, the whole matrix is really a single sorted 1D array wearing a 2D shape. You can binary search over the flattened index space and convert back to `(row, col)`.

**Approach:** Binary search over indices `0` to `rows*cols - 1`, converting a flat index to `(row, col)` with divmod.

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
```javascript +
function searchMatrix(matrix, target) {
  if (!matrix.length || !matrix[0].length) return false;
  const rows = matrix.length;
  const cols = matrix[0].length;
  let lo = 0;
  let hi = rows * cols - 1;

  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    const row = Math.floor(mid / cols);
    const col = mid % cols;
    const val = matrix[row][col];
    if (val === target) {
      return true;
    } else if (val < target) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return false;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[][] matrix = {{1, 3, 5, 7}, {10, 11, 16, 20}, {23, 30, 34, 60}};
        System.out.println(searchMatrix(matrix, 3));
    }

    static boolean searchMatrix(int[][] matrix, int target) {
        if (matrix.length == 0 || matrix[0].length == 0) return false;
        int rows = matrix.length;
        int cols = matrix[0].length;
        int lo = 0;
        int hi = rows * cols - 1;

        while (lo <= hi) {
            int mid = lo + (hi - lo) / 2;
            int row = mid / cols;
            int col = mid % cols;
            int val = matrix[row][col];
            if (val == target) {
                return true;
            } else if (val < target) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return false;
    }
}
```

**Complexity:** Time O(log(rows·cols)), space O(1).

**Common mistakes:**
- Running two separate binary searches, one to find the row and one within it. Correct and still O(log n), but more code and more places to get bounds wrong than the flattened-index trick.
- Getting `divmod(mid, cols)` backwards (`col, row` instead of `row, col`).

Every problem in this lesson is one of two templates wearing a different costume: exact-match (`lo <= hi`, `mid ± 1`) or boundary-search (`lo < hi`, `hi = mid` on the "keep" branch). The rotated-array and matrix problems still narrow to an exact target, so they use the exact-match shape. Finding a boundary or a pivot uses the converging shape instead. Pick the template from what the problem asks (exact value vs. a boundary), then apply it mechanically. Most binary search bugs come from borrowing one template's loop condition with the other's update rule.

> **Remember:** a sorted-rows matrix with each row starting above the previous row's end is one flat sorted array in disguise. Binary search the flat index.

```knowledge-check
{ "questions": [
    { "id": "dsa-binary-search-2d-matrix-q1", "type": "mcq",
      "prompt": "What makes it possible to binary search a 2D matrix as if it were a single sorted array?",
      "options": [
        {"id": "a", "text": "Each row is sorted, and each row's first element is greater than the previous row's last element"},
        {"id": "b", "text": "The matrix must be square (same number of rows and columns)"},
        {"id": "c", "text": "Every value in the matrix must be unique"},
        {"id": "d", "text": "The matrix must contain only positive integers"}
      ],
      "correct": "a",
      "explanation": "Those two conditions together mean reading the matrix row by row produces one fully sorted sequence, so a flat index from 0 to rows*cols-1 behaves exactly like an index into a normal sorted array." }
] }
```
