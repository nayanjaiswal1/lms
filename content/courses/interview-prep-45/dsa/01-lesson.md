---
kind: lesson
id_key: interview-prep-45/day-01
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Arrays and Hashing - Fundamentals"
position: 1
estimated_minutes: 90
source:
    - 45-day-interview-roadmap.md
---
Arrays and hash tables are the substrate almost every other pattern in this course builds on. Two pointers, sliding window, even graph adjacency lists: all of them are arrays and hash maps in disguise. Interviewers use these three problems as a calibration check. Fumble a hash-map complement lookup, and they downgrade their expectations for everything harder that follows. Today you get the mental model right once so it stops costing you thinking time later.

## Hash table basics and collision resolution

A hash table maps keys to values by running the key through a hash function to get a bucket index, then storing the entry in that bucket. Two different keys can hash to the same bucket, a **collision**, and how you resolve that determines the table's real-world performance.

Two standard resolution strategies:

- **Chaining**: each bucket holds a list (or small tree, in some production hash maps once a bucket gets large) of all entries that hashed there. Lookup walks the list comparing keys.
- **Open addressing**: on collision, probe another slot in the same array (linear probing, quadratic probing, or double hashing) until you find an empty one.

Python's `dict` uses open addressing internally, but for interview purposes you only need to reason about the contract: average O(1) insert/lookup/delete, degrading to O(n) if the hash function is bad or an attacker can force collisions (hash-flooding).

```python
class HashNode:
    def __init__(self, key, value):
        self.key = key
        self.value = value
        self.next = None  # chaining: next node in this bucket

class ChainingHashMap:
    def __init__(self, capacity=8):
        self.capacity = capacity
        self.size = 0
        self.buckets = [None] * capacity

    def _index(self, key):
        return hash(key) % self.capacity

    def put(self, key, value):
        idx = self._index(key)
        node = self.buckets[idx]
        while node:
            if node.key == key:
                node.value = value  # update existing
                return
            node = node.next
        new_node = HashNode(key, value)
        new_node.next = self.buckets[idx]
        self.buckets[idx] = new_node
        self.size += 1
        if self.size / self.capacity > 0.75:
            self._resize()

    def get(self, key):
        idx = self._index(key)
        node = self.buckets[idx]
        while node:
            if node.key == key:
                return node.value
            node = node.next
        raise KeyError(key)

    def _resize(self):
        old_buckets = self.buckets
        self.capacity *= 2
        self.buckets = [None] * self.capacity
        self.size = 0
        for node in old_buckets:
            while node:
                self.put(node.key, node.value)
                node = node.next
```

**Interview-relevant details:**
- Load factor (`size / capacity`) above ~0.7 is when you resize. Too high, and chains get long, degrading toward O(n).
- Resizing is O(n), but amortized across n inserts it's O(1) per insert, the same argument as dynamic array growth.
- Keys must be hashable and comparable; in Python, that means `__hash__` and `__eq__` must be consistent (equal objects must have equal hashes).

## Time complexity analysis for array operations

| Operation | Complexity | Why |
|---|---|---|
| Index access `arr[i]` | O(1) | Direct memory offset calculation |
| Append at end | O(1) amortized | See dynamic array section below |
| Insert/delete at front or middle | O(n) | Every following element shifts |
| Search (unsorted) | O(n) | Must check every element |
| Search (sorted) | O(log n) | Binary search applies |

The trap interviewers set: candidates say "insert is O(1)" out of habit from thinking about linked lists. For a Python `list` (a dynamic array), inserting at index 0 is O(n) because everything after it must shift right. Only `list.append()` is O(1) amortized.

### Dynamic array from scratch

Python's `list` is a dynamic array: a fixed-capacity C array underneath that reallocates and copies to a bigger array when it fills up. The "amortized O(1) append" claim rests on doubling the capacity each time, not growing by a fixed amount.

```python
import ctypes

class DynamicArray:
    def __init__(self):
        self.count = 0        # number of elements actually stored
        self.capacity = 1     # allocated slots
        self.array = self._make_array(self.capacity)

    def _make_array(self, capacity):
        return (capacity * ctypes.py_object)()

    def __len__(self):
        return self.count

    def __getitem__(self, i):
        if not 0 <= i < self.count:
            raise IndexError("index out of range")
        return self.array[i]

    def append(self, value):
        if self.count == self.capacity:
            self._resize(2 * self.capacity)  # double capacity
        self.array[self.count] = value
        self.count += 1

    def _resize(self, new_capacity):
        new_array = self._make_array(new_capacity)
        for i in range(self.count):
            new_array[i] = self.array[i]
        self.array = new_array
        self.capacity = new_capacity
```

**Why append is amortized O(1):** a resize costs O(n) to copy, but doubling means resizes happen at sizes 1, 2, 4, 8, ... 2^k. Sum the copy costs (1 + 2 + 4 + ... + n ≈ 2n) and divide by n appends, and you get O(1) average cost per append. Growing by a *fixed* increment instead of doubling makes append O(n) amortized, which is the detail interviewers probe for.

## Space complexity trade-offs

Space complexity analysis asks how auxiliary memory (not counting the input) grows with input size n. The classic trade-off in this unit is **time vs. space via hashing**: a hash set turns an O(n) "does this exist" scan into O(1) lookup, at the cost of O(n) extra memory to store the set.

When you propose a hash-map solution in an interview, always state this trade-off out loud: "I can get O(n) time by using O(n) extra space for a hash set. Is that an acceptable trade here, or is memory constrained?" That sentence signals seniority.

## Two Sum

[Two Sum (LeetCode 1)](https://leetcode.com/problems/two-sum/)

**Intuition:** Brute force checks every pair, O(n²). But for each number `x`, you only need to know whether its complement `target - x` has appeared already. That's an existence-and-lookup question, exactly what a hash map answers in O(1).

**Approach:** Walk the array once. For each element, compute the complement. If the complement is already in the map, you've found your pair: return the stored index and the current index. Otherwise, store the current element's value mapped to its index and keep going.

```python
def two_sum(nums: list[int], target: int) -> list[int]:
    seen = {}  # value -> index
    for i, num in enumerate(nums):
        complement = target - num
        if complement in seen:
            return [seen[complement], i]
        seen[num] = i
    raise ValueError("no two sum solution")
```

**Complexity:** Time O(n), one pass with O(1) map operations. Space O(n) for the map.

**Common mistakes:**
- Checking `if num in seen` before inserting the complement logic. That answers "did I see this number," not "did I see its complement."
- Storing the map first and then scanning separately, which breaks on duplicate values (you'd match an element with itself).
- Forgetting that the problem asks for indices, not values.

## Valid Anagram

[Valid Anagram (LeetCode 242)](https://leetcode.com/problems/valid-anagram/)

**Intuition:** Two strings are anagrams if they contain exactly the same characters with the same frequencies. Frequency counting turns this into a comparison problem instead of a permutation-generation problem.

**Approach:** Count character frequencies in both strings and compare the counts. A quick length check first is a free O(1) short-circuit for the common non-anagram case.

```python
from collections import Counter

def is_anagram(s: str, t: str) -> bool:
    if len(s) != len(t):
        return False
    return Counter(s) == Counter(t)
```

Or without the library, to show you understand the mechanism:

```python
def is_anagram_manual(s: str, t: str) -> bool:
    if len(s) != len(t):
        return False
    counts = {}
    for ch in s:
        counts[ch] = counts.get(ch, 0) + 1
    for ch in t:
        if ch not in counts:
            return False
        counts[ch] -= 1
        if counts[ch] == 0:
            del counts[ch]
    return len(counts) == 0
```

**Complexity:** Time O(n) where n is string length. Space O(k) where k is the alphabet size (O(1) if you assume a fixed alphabet like lowercase ASCII).

**Common mistakes:**
- Sorting both strings and comparing: this works (O(n log n)) but is strictly worse than counting, and interviewers will ask "can you do better?"
- Forgetting the early length check, a cheap win.
- Not handling Unicode/multi-byte characters if the prompt implies non-ASCII input.

## Contains Duplicate

[Contains Duplicate (LeetCode 217)](https://leetcode.com/problems/contains-duplicate/)

**Intuition:** This is the purest form of "have I seen this before," a hash set existence check.

**Approach:** Insert elements into a set one at a time; if an element is already present, return `True` immediately.

```python
def contains_duplicate(nums: list[int]) -> bool:
    seen = set()
    for num in nums:
        if num in seen:
            return True
        seen.add(num)
    return False
```

A one-liner alternative trades early exit for brevity: `return len(nums) != len(set(nums))`. It's correct but always scans the full list even when a duplicate shows up early, so mention the trade-off if you use it.

**Complexity:** Time O(n). Space O(n) worst case (all unique).

**Common mistakes:**
- Using nested loops (O(n²)) as the final answer instead of a starting point to optimize from.
- Sorting first (O(n log n)): valid and space-efficient (O(1) extra if sorting in place) but slower than hashing. Worth mentioning both when asked to compare.
