---
kind: lesson
id_key: interview-prep-45/day-02
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Two Pointers"
position: 2
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Picture a sorted row of 1,000 people lined up by height, shortest to tallest. You need to find two people whose heights add up to exactly 300 cm. Put one finger on the shortest person and one on the tallest. Too small a total? Move the left finger one person to the right. Too big? Move the right finger one person to the left. You never check the same pair twice, so you cover the whole row in at most 1,000 steps: O(n), where a nested loop checking every pair would take close to 500,000 checks, O(n²). That is two pointers: the win is not a smarter data structure, it is a smarter scan order, using structure already in the input, usually that it is sorted. Interviewers use it to see whether you reach for hashing out of habit, or actually look at the shape of the problem first.

## Two pointers vs hash maps

Both patterns often solve "find a pair or triple with some property," but they use different things about the input.

| | Hash map | Two pointers |
|---|---|---|
| Needs sorted input | No | Usually yes |
| Extra space | O(n) | O(1) |
| Keeps original indices | Yes | No, unless tracked separately |
| Typical time | O(n) | O(n), after an O(n log n) sort if needed |

Rule of thumb: if the array is already sorted, or you can sort it without needing the original order or indices, reach for two pointers to save space. If you need the original indices (like Two Sum) or the input cannot be reordered, use a hash map instead.

Two pointers works because in a sorted array, moving the left pointer right only increases the value there, and moving the right pointer left only decreases it. This one-directional behavior lets you throw away half the remaining search space at each step, instead of trying every pair.

For 3Sum-style problems: fix one element, then run two pointers on the remaining sorted subarray to find pairs that sum to the value you need. That is why sorting first turns an O(n³) triple-nested loop into O(n²).

> **Remember:** hash map when you need original indices or the input can't be reordered. Two pointers when the input is sorted (or free to sort) and you can trade indices for O(1) space.

```knowledge-check
{ "questions": [
    { "id": "dsa-two-pointers-vs-hashmap-q1", "type": "mcq",
      "prompt": "When should you reach for two pointers instead of a hash map?",
      "options": [
        {"id": "a", "text": "When the array is sorted (or free to sort) and you don't need to preserve original indices"},
        {"id": "b", "text": "Whenever the array has duplicate values"},
        {"id": "c", "text": "Only when the array has fewer than 10 elements"},
        {"id": "d", "text": "Whenever you need to return indices, not values"}
      ],
      "correct": "a",
      "explanation": "Two pointers exploits sortedness to save space (O(1) instead of O(n)), but it loses the original index order. Use a hash map instead when you need indices or can't reorder the input." }
] }
```

## Moving elements in place

Picture tidying a shelf of 20 books where some titles repeat, without taking any books off the shelf or using a second shelf. One hand marks the next empty spot for a book you want to keep. The other hand scans ahead, looking for the next book worth keeping and sliding it back to that spot. Many two-pointer problems work exactly like this: removing duplicates, moving zeroes, partitioning, all using O(1) extra space, no second array. One pointer (`write` or `slow`) tracks where the next valid element should go. Another pointer (`read` or `fast`) scans ahead looking for valid elements to bring back.

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
```javascript +
function removeDuplicates(nums) {
  // Removes duplicates from a sorted array in place, returns new length.
  if (nums.length === 0) return 0;
  let write = 1;
  for (let read = 1; read < nums.length; read++) {
    if (nums[read] !== nums[write - 1]) {
      nums[write] = nums[read];
      write += 1;
    }
  }
  return write;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {1, 1, 2, 2, 3};
        int newLength = removeDuplicates(nums);
        System.out.println("new length: " + newLength);
    }

    // Removes duplicates from a sorted array in place, returns new length.
    static int removeDuplicates(int[] nums) {
        if (nums.length == 0) return 0;
        int write = 1;
        for (int read = 1; read < nums.length; read++) {
            if (nums[read] != nums[write - 1]) {
                nums[write] = nums[read];
                write += 1;
            }
        }
        return write;
    }
}
```

In-place two-pointer solutions are easy to get subtly wrong around the boundary condition (`!=` vs `<`, starting `write` at 0 vs 1). Always trace through a small 2-3 element example by hand before calling it correct.

> **Remember:** in a write/read pair, `write` marks where the next good value goes; `read` scans ahead to find it. Trace 2-3 elements by hand before you trust it.

```knowledge-check
{ "questions": [
    { "id": "dsa-two-pointers-inplace-q1", "type": "mcq",
      "prompt": "In the write/read two-pointer pattern for removing duplicates from a sorted array, what does the `write` pointer track?",
      "options": [
        {"id": "a", "text": "The position where the next unique value should be placed"},
        {"id": "b", "text": "The current element being scanned"},
        {"id": "c", "text": "The number of duplicates removed so far"},
        {"id": "d", "text": "The midpoint of the array"}
      ],
      "correct": "a",
      "explanation": "`write` always points at the next slot to fill with a valid (non-duplicate) value. `read` is the pointer that scans ahead looking for the next value worth writing." }
] }
```

## Valid Palindrome

[Valid Palindrome (LeetCode 125)](https://leetcode.com/problems/valid-palindrome/)

A palindrome reads the same forwards and backwards. Instead of building a cleaned string and reversing it, which costs extra space, walk from both ends toward the middle and compare characters directly.

**Approach:** Use `left` and `right` pointers starting at the two ends. Skip non-alphanumeric characters on either side. Compare lowercase versions of the characters; a mismatch means it is not a palindrome. Pointers crossing means success.

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
```javascript +
function isPalindrome(s) {
  const isAlnum = (ch) => /[a-z0-9]/i.test(ch);
  let left = 0;
  let right = s.length - 1;
  while (left < right) {
    while (left < right && !isAlnum(s[left])) left += 1;
    while (left < right && !isAlnum(s[right])) right -= 1;
    if (s[left].toLowerCase() !== s[right].toLowerCase()) return false;
    left += 1;
    right -= 1;
  }
  return true;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(isPalindrome("A man, a plan, a canal: Panama"));
        System.out.println(isPalindrome("race a car"));
    }

    static boolean isPalindrome(String s) {
        int left = 0;
        int right = s.length() - 1;
        while (left < right) {
            while (left < right && !Character.isLetterOrDigit(s.charAt(left))) left += 1;
            while (left < right && !Character.isLetterOrDigit(s.charAt(right))) right -= 1;
            if (Character.toLowerCase(s.charAt(left)) != Character.toLowerCase(s.charAt(right))) {
                return false;
            }
            left += 1;
            right -= 1;
        }
        return true;
    }
}
```

**Complexity:** Time O(n), space O(1). No extra string built.

**Common mistakes:**
- Building a cleaned, lowercased copy of the string first. Correct, but O(n) extra space when O(1) is possible.
- Inner `while` loops missing the `left < right` bound, which causes an out-of-range index when the string is all punctuation.
- Forgetting `.isalnum()` covers both letters and digits, not just letters.

> **Remember:** two pointers walking inward, skipping non-alphanumeric characters as they go, no extra string needed.

```knowledge-check
{ "questions": [
    { "id": "dsa-two-pointers-valid-palindrome-q1", "type": "mcq",
      "prompt": "What is the space complexity of the two-pointer Valid Palindrome solution that skips non-alphanumeric characters in place?",
      "options": [
        {"id": "a", "text": "O(1)"},
        {"id": "b", "text": "O(n)"},
        {"id": "c", "text": "O(log n)"},
        {"id": "d", "text": "O(n²)"}
      ],
      "correct": "a",
      "explanation": "No cleaned copy of the string is built. Two pointers scan the original string directly, so extra space stays constant." }
] }
```

## 3Sum

[3Sum (LeetCode 15)](https://leetcode.com/problems/3sum/)

Extending Two Sum's hash-map trick to three numbers gets messy fast because of duplicate handling. Sorting first and fixing one number turns this into a Two Sum variant you can solve with two pointers, and sorted order makes skipping duplicates mechanical.

**Approach:** Sort the array. For each index `i` (skipping duplicate values of `nums[i]`), run two pointers (`left = i+1`, `right = n-1`) across the rest of the array looking for pairs that sum to `-nums[i]`. Skip duplicate values at `left` and `right` after finding a match, so you do not record the same triplet twice.

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
```javascript +
function threeSum(nums) {
  nums.sort((a, b) => a - b);
  const result = [];
  const n = nums.length;
  for (let i = 0; i < n - 2; i++) {
    if (i > 0 && nums[i] === nums[i - 1]) continue; // skip duplicate anchors
    if (nums[i] > 0) break; // smallest remaining value is positive, no triplet can sum to 0
    let left = i + 1;
    let right = n - 1;
    while (left < right) {
      const total = nums[i] + nums[left] + nums[right];
      if (total < 0) {
        left += 1;
      } else if (total > 0) {
        right -= 1;
      } else {
        result.push([nums[i], nums[left], nums[right]]);
        left += 1;
        right -= 1;
        while (left < right && nums[left] === nums[left - 1]) left += 1;
        while (left < right && nums[right] === nums[right + 1]) right -= 1;
      }
    }
  }
  return result;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {-1, 0, 1, 2, -1, -4};
        java.util.List<java.util.List<Integer>> result = threeSum(nums);
        System.out.println(result);
    }

    static java.util.List<java.util.List<Integer>> threeSum(int[] nums) {
        java.util.Arrays.sort(nums);
        java.util.List<java.util.List<Integer>> result = new java.util.ArrayList<>();
        int n = nums.length;
        for (int i = 0; i < n - 2; i++) {
            if (i > 0 && nums[i] == nums[i - 1]) continue; // skip duplicate anchors
            if (nums[i] > 0) break; // smallest remaining value is positive, no triplet can sum to 0
            int left = i + 1;
            int right = n - 1;
            while (left < right) {
                int total = nums[i] + nums[left] + nums[right];
                if (total < 0) {
                    left += 1;
                } else if (total > 0) {
                    right -= 1;
                } else {
                    result.add(java.util.Arrays.asList(nums[i], nums[left], nums[right]));
                    left += 1;
                    right -= 1;
                    while (left < right && nums[left] == nums[left - 1]) left += 1;
                    while (left < right && nums[right] == nums[right + 1]) right -= 1;
                }
            }
        }
        return result;
    }
}
```

**Complexity:** Time O(n²): O(n log n) to sort plus an O(n) outer loop times an O(n) two-pointer scan. Space O(1) extra, not counting the sort and output.

**Common mistakes:**
- Forgetting to skip duplicate anchors, which produces duplicate triplets in the result.
- Skipping duplicates for `left`/`right` before recording the match instead of after.
- Deduplicating the output with a hash set as a patch, instead of the sorted-skip technique. It works, but it is slower and messier.

> **Remember:** sort first, fix one number, then two-pointer the rest. Skip duplicates right after recording a match, not before.

```knowledge-check
{ "questions": [
    { "id": "dsa-two-pointers-3sum-q1", "type": "mcq",
      "prompt": "What is the overall time complexity of the sort-then-two-pointer solution to 3Sum?",
      "options": [
        {"id": "a", "text": "O(n²)"},
        {"id": "b", "text": "O(n log n)"},
        {"id": "c", "text": "O(n³)"},
        {"id": "d", "text": "O(n)"}
      ],
      "correct": "a",
      "explanation": "Sorting costs O(n log n). The outer loop runs n times, and for each anchor the two-pointer scan is O(n), giving O(n²) total, which dominates the sort." }
] }
```

## Container With Most Water

[Container With Most Water (LeetCode 11)](https://leetcode.com/problems/container-with-most-water/)

**Intuition:** The area between two lines is `min(height[left], height[right]) * (right - left)`. Starting pointers at both ends maximizes the width term first. The key insight: moving the pointer at the taller line inward can never increase the area, since the width shrinks and the height is still capped by the shorter line either way. So you always move the shorter line's pointer.

**Approach:** Start `left = 0`, `right = n - 1`. Track the max area seen. Move whichever pointer points to the shorter line inward. Repeat until the pointers meet.

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
```javascript +
function maxArea(height) {
  let left = 0;
  let right = height.length - 1;
  let best = 0;
  while (left < right) {
    const h = Math.min(height[left], height[right]);
    best = Math.max(best, h * (right - left));
    if (height[left] < height[right]) {
      left += 1;
    } else {
      right -= 1;
    }
  }
  return best;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] height = {1, 8, 6, 2, 5, 4, 8, 3, 7};
        System.out.println(maxArea(height));
    }

    static int maxArea(int[] height) {
        int left = 0;
        int right = height.length - 1;
        int best = 0;
        while (left < right) {
            int h = Math.min(height[left], height[right]);
            best = Math.max(best, h * (right - left));
            if (height[left] < height[right]) {
                left += 1;
            } else {
                right -= 1;
            }
        }
        return best;
    }
}
```

**Complexity:** Time O(n), a single pass with each pointer moving at most n times total. Space O(1).

**Common mistakes:**
- Trying every pair (O(n²)) instead of recognizing the "move the shorter side" argument.
- Moving the taller pointer, or moving both pointers every step. Both break the correctness proof.
- Forgetting the area formula uses `min`, not `max`, of the two heights, since water cannot rise above the shorter wall.

> **Remember:** always move the pointer at the shorter line. Moving the taller one can only ever shrink the area.

```knowledge-check
{ "questions": [
    { "id": "dsa-two-pointers-container-water-q1", "type": "mcq",
      "prompt": "In Container With Most Water, when the left line is shorter than the right line, which pointer should you move?",
      "options": [
        {"id": "a", "text": "The left pointer, since the shorter line is what caps the area"},
        {"id": "b", "text": "The right pointer, since it's taller and safer to move"},
        {"id": "c", "text": "Both pointers together"},
        {"id": "d", "text": "Neither; stop once you see the shorter line"}
      ],
      "correct": "a",
      "explanation": "The shorter line caps the area no matter what. Moving it is the only move that has a chance of finding a taller line and a bigger area; moving the taller pointer can only shrink the width while keeping the same cap." }
] }
```

## A reusable linked list node

Linked list and tree problems reuse a minimal node class like this one. Get this boilerplate right once so it is not a distraction later.

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
```javascript +
class ListNode {
  constructor(val = 0, next = null) {
    this.val = val;
    this.next = next;
  }
}

function buildLinkedList(values) {
  const dummy = new ListNode();
  let tail = dummy;
  for (const v of values) {
    tail.next = new ListNode(v);
    tail = tail.next;
  }
  return dummy.next;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        ListNode head = buildLinkedList(new int[] {1, 2, 3});
        StringBuilder sb = new StringBuilder();
        while (head != null) {
            sb.append(head.val).append(" -> ");
            head = head.next;
        }
        sb.append("null");
        System.out.println(sb);
    }

    static ListNode buildLinkedList(int[] values) {
        ListNode dummy = new ListNode();
        ListNode tail = dummy;
        for (int v : values) {
            tail.next = new ListNode(v);
            tail = tail.next;
        }
        return dummy.next;
    }
}

class ListNode {
    int val;
    ListNode next;

    ListNode() {
        this(0, null);
    }

    ListNode(int val) {
        this(val, null);
    }

    ListNode(int val, ListNode next) {
        this.val = val;
        this.next = next;
    }
}
```

The `dummy` head node is the trick worth remembering: it removes the special case of "is this the first node?" from insertion logic, since `dummy.next` always points at the real head.

> **Remember:** a dummy head node turns "is this the first insert?" into a non-question. `dummy.next` is always the real head.

```knowledge-check
{ "questions": [
    { "id": "dsa-two-pointers-linked-list-node-q1", "type": "mcq",
      "prompt": "Why do linked-list building functions often start with a dummy head node?",
      "options": [
        {"id": "a", "text": "It removes the special case of handling the first insertion separately"},
        {"id": "b", "text": "It makes the list doubly linked"},
        {"id": "c", "text": "It is required for the list to be mutable"},
        {"id": "d", "text": "It reduces the time complexity of insertion"}
      ],
      "correct": "a",
      "explanation": "Without a dummy head, inserting the very first real node needs special-case code (there's no previous node to attach to). With a dummy head, dummy.next always points to the real head, so every insertion follows the same code path." }
] }
```
