---
kind: lesson
id_key: interview-prep-45/day-01
course: interview-prep-45
section: dsa
section_title: "Data Structures & Algorithms"
section_position: 2
title: "Arrays and Hashing"
position: 1
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Say you have a phone book with a million names and you need to find one number fast. Flipping page by page is slow. An index that jumps you straight to the right page is fast. A hash table is that index, built into a data structure.

Arrays and hash tables are the base almost every other pattern sits on. Two pointers, sliding window, even a graph's adjacency list: all of them are arrays and hash maps underneath. Interviewers use simple hashing problems as a calibration check. Fumble a basic complement lookup, and they lower their expectations for everything harder you attempt after. Get the mental model right once here, and it stops costing you thinking time later.

## Hash tables: how collisions get resolved

Picture a classroom with 8 coat hooks, numbered 0 to 7. Every student's name gets turned into a hook number by a rule, say, add up the letters and divide by 8. Two students can land on the same hook number. That is a **collision**: two different keys landing in the same slot. A hash table works the same way. It maps keys to values by running the key through a hash function to get a bucket index, then storing the entry in that bucket. How you handle two keys wanting the same bucket decides how fast the table stays as more keys arrive.

There are two standard ways to resolve a collision:

| Strategy | How it works | Trade-off |
|---|---|---|
| Chaining | Each bucket holds a list of every entry that hashed there. A lookup walks the list comparing keys. | Simple, but a long list in one bucket degrades toward O(n). |
| Open addressing | On a collision, probe another slot in the same array until you find an empty one. | No extra list, but the probe sequence itself needs care (see below). |

Python's `dict` uses open addressing internally, but for interview purposes you only need the contract: average O(1) insert, lookup, and delete, degrading to O(n) if the hash function is bad or an attacker can force collisions on purpose (called hash-flooding).

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
```javascript +
class HashNode {
  constructor(key, value) {
    this.key = key;
    this.value = value;
    this.next = null; // chaining: next node in this bucket
  }
}

class ChainingHashMap {
  constructor(capacity = 8) {
    this.capacity = capacity;
    this.size = 0;
    this.buckets = new Array(capacity).fill(null);
  }

  _hash(key) {
    const str = String(key);
    let h = 0;
    for (let i = 0; i < str.length; i++) {
      h = (h * 31 + str.charCodeAt(i)) | 0;
    }
    return Math.abs(h) % this.capacity;
  }

  put(key, value) {
    const idx = this._hash(key);
    let node = this.buckets[idx];
    while (node) {
      if (node.key === key) {
        node.value = value; // update existing
        return;
      }
      node = node.next;
    }
    const newNode = new HashNode(key, value);
    newNode.next = this.buckets[idx];
    this.buckets[idx] = newNode;
    this.size += 1;
    if (this.size / this.capacity > 0.75) {
      this._resize();
    }
  }

  get(key) {
    const idx = this._hash(key);
    let node = this.buckets[idx];
    while (node) {
      if (node.key === key) return node.value;
      node = node.next;
    }
    throw new Error(`key not found: ${key}`);
  }

  _resize() {
    const oldBuckets = this.buckets;
    this.capacity *= 2;
    this.buckets = new Array(this.capacity).fill(null);
    this.size = 0;
    for (let node of oldBuckets) {
      while (node) {
        this.put(node.key, node.value);
        node = node.next;
      }
    }
  }
}
```
```java +
public class Main {
    public static void main(String[] args) {
        ChainingHashMap<String, Integer> map = new ChainingHashMap<>(8);
        map.put("a", 1);
        map.put("b", 2);
        map.put("a", 10);
        System.out.println(map.get("a"));
        System.out.println(map.get("b"));
    }
}

class HashNode<K, V> {
    K key;
    V value;
    HashNode<K, V> next; // chaining: next node in this bucket

    HashNode(K key, V value) {
        this.key = key;
        this.value = value;
        this.next = null;
    }
}

class ChainingHashMap<K, V> {
    private int capacity;
    private int size;
    private HashNode<K, V>[] buckets;

    @SuppressWarnings("unchecked")
    ChainingHashMap(int capacity) {
        this.capacity = capacity;
        this.size = 0;
        this.buckets = new HashNode[capacity];
    }

    private int index(K key) {
        return Math.abs(key.hashCode()) % capacity;
    }

    void put(K key, V value) {
        int idx = index(key);
        HashNode<K, V> node = buckets[idx];
        while (node != null) {
            if (node.key.equals(key)) {
                node.value = value; // update existing
                return;
            }
            node = node.next;
        }
        HashNode<K, V> newNode = new HashNode<>(key, value);
        newNode.next = buckets[idx];
        buckets[idx] = newNode;
        size += 1;
        if ((double) size / capacity > 0.75) {
            resize();
        }
    }

    V get(K key) {
        int idx = index(key);
        HashNode<K, V> node = buckets[idx];
        while (node != null) {
            if (node.key.equals(key)) return node.value;
            node = node.next;
        }
        throw new java.util.NoSuchElementException(String.valueOf(key));
    }

    @SuppressWarnings("unchecked")
    private void resize() {
        HashNode<K, V>[] oldBuckets = buckets;
        capacity *= 2;
        buckets = new HashNode[capacity];
        size = 0;
        for (HashNode<K, V> node : oldBuckets) {
            while (node != null) {
                put(node.key, node.value);
                node = node.next;
            }
        }
    }
}
```

A load factor (`size / capacity`) above about 0.7 is when you resize. Go higher, and chains get long, dragging lookups toward O(n). Resizing itself is O(n), but spread across n inserts it costs O(1) per insert on average, the same argument that makes dynamic-array growth cheap.

### Open addressing: three ways to probe

Open addressing skips the linked lists. Every entry lives directly in the array, and a collision makes you probe other slots until you find an empty one.

- **Linear probing:** try `(hash(key) + i) % size` for `i = 0, 1, 2, ...`. Simple, and cache-friendly since the probes are sequential memory addresses. The downside is **primary clustering**: once a run of filled slots forms, every new collision makes the run longer, so long runs snowball toward O(n) lookups.
- **Quadratic probing:** try `(hash(key) + i²) % size`. Spreads probes out faster, so it avoids primary clustering. Its downside is **secondary clustering**: two keys that hash to the same first slot always follow the exact same probe path, so they keep colliding with each other.
- **Double hashing:** try `(hash1(key) + i * hash2(key)) % size`, where `hash2` is a second, independent hash function. The step size depends on the key, so two colliding keys almost never share a probe path. Best spread of the three, at the cost of computing two hash functions per lookup.

```python
class OpenAddressingMap:
    def __init__(self, capacity=8):
        self.capacity = capacity
        self.size = 0
        self.keys = [None] * capacity
        self.values = [None] * capacity

    def _probe(self, key):
        # linear probing — swap the +i step for quadratic (+i*i) or double hashing
        i = 0
        idx = hash(key) % self.capacity
        while self.keys[idx] is not None and self.keys[idx] != key:
            i += 1
            idx = (hash(key) + i) % self.capacity
        return idx

    def put(self, key, value):
        idx = self._probe(key)
        if self.keys[idx] is None:
            self.size += 1
        self.keys[idx] = key
        self.values[idx] = value
```

Trace it by hand with `capacity = 8` and linear probing. A key with hash `11` gives `idx = 11 % 8 = 3`: it lands in slot 3. A second key also hashing to `3` finds slot 3 taken, so it checks `(3 + 1) % 8 = 4`, which is empty, and lands there. A third key hashing to `19` (`19 % 8 = 3`) tries slot 3 (taken), slot 4 (taken), then slot 5 (empty). Three different keys packed into three consecutive slots: that is primary clustering happening in real time.

Deleting is the classic open-addressing trap. You cannot just set a slot back to empty, because that breaks the probe path for any key that probed past it. In the trace above, clearing slot 3 would make a lookup for the key in slot 4 stop early at the now-empty slot 3 and wrongly report "not found." Real implementations write a tombstone marker instead. Probing continues through tombstones, and a new insert is free to reuse them.

**Python's `dict` uses a variation on this.** It does open addressing, but with a pseudo-random probe sequence built from the full hash value, not plain linear or quadratic steps. This scrambles the probe order using hash bits a simple `mod size` would throw away, which keeps `dict` fast even when many keys collide on their low bits. Since Python 3.3, string and bytes hashing is randomized per process specifically to block **hash-flooding attacks**, where an attacker submits keys engineered to all collide and drag a service's hash map down to O(n) per operation.

> **Remember:** chaining stores a list per bucket; open addressing stores everything in the array and probes on collision. Say "average O(1), worst case O(n) on bad hashing" and you have covered the interview-relevant part.

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-hash-collisions-q1", "type": "mcq",
      "prompt": "Why does linear probing tend to get slower over time as a hash table fills up?",
      "options": [
        {"id": "a", "text": "Primary clustering: filled runs of slots keep growing, so more keys have to probe further"},
        {"id": "b", "text": "It recomputes the hash function on every probe"},
        {"id": "c", "text": "It always resizes the array on the first collision"},
        {"id": "d", "text": "It stores a linked list per slot, like chaining does"}
      ],
      "correct": "a",
      "explanation": "Linear probing checks consecutive slots. Once a run of filled slots forms, every new collision lands at the end of that run and extends it, so runs snowball and lookups get slower." }
] }
```

## Keeping custom objects hashable

Picture a coat-check counter with 100 numbered pegs. Two coats that look identical, same size, same color, must always be hung on the same peg, or the counter loses track of one when it goes searching for it later. If you want your own class to work as a dict key or set member, `__hash__` and `__eq__` (Python's "are these two equal" and "which bucket does this go in" methods) must agree with each other the same way.

**The rule: if `a == b`, then `hash(a) == hash(b)`.** The reverse is not required. Different objects can share a hash; that is just an ordinary collision, handled the normal way. But two objects that compare equal must never disagree on their hash, or a dict/set stores them as separate entries it can never look up consistently: a lookup hashes to bucket A, finds nothing, even though an "equal" object sits in bucket B.

```python
class Student:
    def __init__(self, student_id, name):
        self.student_id = student_id
        self.name = name  # not part of identity — two records can share a name

    def __eq__(self, other):
        return isinstance(other, Student) and self.student_id == other.student_id

    def __hash__(self):
        return hash(self.student_id)  # must derive from the same fields __eq__ uses
```

A common bug is defining `__eq__` without `__hash__`. Python then sets `__hash__` to `None` automatically, making the class unhashable. That is on purpose: a custom `__eq__` without a matching `__hash__` would silently break the rule above. If you override `__eq__`, you must also define `__hash__` (or explicitly keep the default identity-based one, if that is really what you want).

> **Remember:** equal objects must hash equal. If you write `__eq__`, write `__hash__` right next to it, using the same fields.

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-hash-eq-contract-q1", "type": "mcq",
      "prompt": "A class defines a custom `__eq__` but no `__hash__`. What happens in Python?",
      "options": [
        {"id": "a", "text": "Python sets `__hash__` to `None`, making instances unhashable"},
        {"id": "b", "text": "Python keeps the default identity-based `__hash__` automatically"},
        {"id": "c", "text": "Python raises a syntax error at class definition time"},
        {"id": "d", "text": "Python derives `__hash__` from `__eq__` automatically"}
      ],
      "correct": "a",
      "explanation": "Defining __eq__ without __hash__ sets __hash__ to None, so instances can't be used as dict keys or set members. This stops you from silently breaking the equal-objects-must-hash-equal rule." }
] }
```

## Time complexity of array operations

Picture 1,000 people standing shoulder to shoulder in a numbered line, position 0 to 999. Calling out "person 500, step forward" gets an instant answer: you know exactly where to look. Squeezing a new person into the front of that line means all 1,000 people already there have to shuffle back one spot to make room. That difference, jump straight to a spot versus shift everyone over, is the whole story of array time complexity.

| Operation | Complexity | Why |
|---|---|---|
| Index access `arr[i]` | O(1) | Direct memory offset calculation |
| Append at end | O(1) amortized | See below |
| Insert or delete at front or middle | O(n) | Every following element shifts |
| Search (unsorted) | O(n) | Must check every element |
| Search (sorted) | O(log n) | Binary search applies |

The common mix-up: candidates say "insert is O(1)" out of habit, thinking of linked lists. For a Python `list`, which is a dynamic array, inserting at index 0 is O(n) because everything after it has to shift right. Only `list.append()` is O(1) amortized.

### Dynamic array from scratch

Python's `list` is a dynamic array: a fixed-capacity array underneath that reallocates and copies into a bigger array once it fills up. The "amortized O(1) append" claim rests on doubling the capacity each time, not growing by a fixed amount.

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
```javascript +
class DynamicArray {
  constructor() {
    this.count = 0;    // number of elements actually stored
    this.capacity = 1; // allocated slots
    this.array = new Array(this.capacity);
  }

  get length() {
    return this.count;
  }

  get(i) {
    if (i < 0 || i >= this.count) {
      throw new RangeError("index out of range");
    }
    return this.array[i];
  }

  append(value) {
    if (this.count === this.capacity) {
      this._resize(2 * this.capacity); // double capacity
    }
    this.array[this.count] = value;
    this.count += 1;
  }

  _resize(newCapacity) {
    const newArray = new Array(newCapacity);
    for (let i = 0; i < this.count; i++) {
      newArray[i] = this.array[i];
    }
    this.array = newArray;
    this.capacity = newCapacity;
  }
}
```
```java +
public class Main {
    public static void main(String[] args) {
        DynamicArray arr = new DynamicArray();
        for (int i = 0; i < 5; i++) {
            arr.append(i * 10);
        }
        System.out.println("length: " + arr.length());
        System.out.println("arr[3]: " + arr.get(3));
    }
}

class DynamicArray {
    private int count;      // number of elements actually stored
    private int capacity;   // allocated slots
    private Object[] array;

    DynamicArray() {
        this.count = 0;
        this.capacity = 1;
        this.array = new Object[capacity];
    }

    int length() {
        return count;
    }

    @SuppressWarnings("unchecked")
    <T> T get(int i) {
        if (i < 0 || i >= count) {
            throw new IndexOutOfBoundsException("index out of range");
        }
        return (T) array[i];
    }

    void append(Object value) {
        if (count == capacity) {
            resize(2 * capacity); // double capacity
        }
        array[count] = value;
        count += 1;
    }

    private void resize(int newCapacity) {
        Object[] newArray = new Object[newCapacity];
        for (int i = 0; i < count; i++) {
            newArray[i] = array[i];
        }
        array = newArray;
        capacity = newCapacity;
    }
}
```

Why is append amortized O(1)? A resize costs O(n) to copy, but doubling means resizes happen at sizes 1, 2, 4, 8, ... 2^k. Add up the copy costs (1 + 2 + 4 + ... + n ≈ 2n) and divide by n appends, and you get O(1) average cost per append. Growing by a fixed amount instead of doubling makes append O(n) amortized, which is the detail interviewers probe for.

> **Remember:** doubling capacity is what makes append amortized O(1). A fixed growth step would make it O(n).

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-array-time-complexity-q1", "type": "mcq",
      "prompt": "Why is inserting at the front of a Python list O(n) instead of O(1)?",
      "options": [
        {"id": "a", "text": "Every element after the insertion point has to shift one slot to the right"},
        {"id": "b", "text": "Python lists are actually linked lists internally"},
        {"id": "c", "text": "It triggers a resize every single time"},
        {"id": "d", "text": "Front insertion always re-sorts the list"}
      ],
      "correct": "a",
      "explanation": "A Python list is a dynamic array, a contiguous block of memory. Inserting at the front means shifting every existing element one slot over to make room, which is O(n)." }
] }
```

## Space complexity trade-offs

Picture packing for a trip. You can travel light and dig through one bag every time you need something, slow, but no extra weight. Or you can spend a little extra suitcase space on a labeled pouch for each item, so your hand finds it instantly. Space complexity is that second cost: how much extra memory an algorithm uses, not counting the input itself, as the input grows. The trade-off worth knowing cold: a hash set turns an O(n) "does this exist" scan (checking up to all 1,000 items one by one) into an O(1) lookup (one step, every time), at the cost of O(n) extra memory, roughly one labeled pouch per item, to store the set.

Say this trade-off out loud whenever you propose a hash-map solution: "I can get O(n) time using O(n) extra space for a hash set. Is that trade-off fine here, or is memory tight?" That one sentence signals you think about trade-offs, not just the fastest possible time complexity.

> **Remember:** hashing usually trades O(n) space for O(1) lookup. Say the trade-off out loud before an interviewer has to ask.

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-space-tradeoffs-q1", "type": "mcq",
      "prompt": "A hash-set solution turns an O(n) linear scan into an O(1) lookup. What does it cost to get that speed-up?",
      "options": [
        {"id": "a", "text": "O(n) extra space to store the set"},
        {"id": "b", "text": "Nothing, hash sets are free in both time and space"},
        {"id": "c", "text": "O(log n) extra space"},
        {"id": "d", "text": "It requires the input array to be sorted first"}
      ],
      "correct": "a",
      "explanation": "The hash set has to store roughly one entry per input element, so the memory cost is O(n). Time and space are trading against each other here, not both improving for free." }
] }
```

## Two Sum

[Two Sum (LeetCode 1)](https://leetcode.com/problems/two-sum/)

You have an array of numbers and a target. Find two numbers that add up to it, and return their positions.

**Intuition:** Checking every pair is O(n²). But for each number `x`, all you need to know is whether its complement `target - x` showed up already. That is an existence check, and a hash map answers existence in O(1).

**Approach:** Walk the array once. For each element, compute the complement. If the complement is already in the map, you found your pair: return the stored index and the current index. Otherwise, store the current value mapped to its index and keep going.

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
```javascript +
function twoSum(nums, target) {
  const seen = new Map(); // value -> index
  for (let i = 0; i < nums.length; i++) {
    const complement = target - nums[i];
    if (seen.has(complement)) {
      return [seen.get(complement), i];
    }
    seen.set(nums[i], i);
  }
  throw new Error("no two sum solution");
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {2, 7, 11, 15};
        int[] result = twoSum(nums, 9);
        System.out.println(result[0] + ", " + result[1]);
    }

    static int[] twoSum(int[] nums, int target) {
        java.util.Map<Integer, Integer> seen = new java.util.HashMap<>();
        for (int i = 0; i < nums.length; i++) {
            int complement = target - nums[i];
            if (seen.containsKey(complement)) {
                return new int[] { seen.get(complement), i };
            }
            seen.put(nums[i], i);
        }
        throw new IllegalArgumentException("no two sum solution");
    }
}
```

**Complexity:** Time O(n), one pass with O(1) map operations. Space O(n) for the map.

**Common mistakes:**
- Checking `if num in seen` before applying the complement logic. That answers "did I see this number," not "did I see its complement."
- Building the map first and scanning separately, which breaks on duplicate values (an element would match itself).
- Forgetting the problem asks for indices, not values.

> **Remember:** for every number, ask "have I seen its complement," not "have I seen this number."

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-two-sum-q1", "type": "mcq",
      "prompt": "In the standard hash-map solution to Two Sum, what should you check on each element?",
      "options": [
        {"id": "a", "text": "Whether target minus the current number is already in the map"},
        {"id": "b", "text": "Whether the current number is already in the map"},
        {"id": "c", "text": "Whether the current number is negative"},
        {"id": "d", "text": "Whether the array is sorted"}
      ],
      "correct": "a",
      "explanation": "You need the complement (target - current number) to already exist in the map. Checking whether the current number itself was seen answers a different question and breaks the solution." }
] }
```

## Valid Anagram

[Valid Anagram (LeetCode 242)](https://leetcode.com/problems/valid-anagram/)

**Intuition:** Two strings are anagrams when they hold the same characters with the same counts. Counting frequencies turns this into a comparison, instead of generating every permutation.

**Approach:** Count character frequencies in both strings and compare. A length check first is a free O(1) shortcut for the common non-anagram case.

```python
from collections import Counter

def is_anagram(s: str, t: str) -> bool:
    if len(s) != len(t):
        return False
    return Counter(s) == Counter(t)
```
```javascript +
function isAnagram(s, t) {
  if (s.length !== t.length) return false;
  const counts = new Map();
  for (const ch of s) counts.set(ch, (counts.get(ch) || 0) + 1);
  for (const ch of t) {
    if (!counts.has(ch)) return false;
    counts.set(ch, counts.get(ch) - 1);
  }
  return [...counts.values()].every((c) => c === 0);
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(isAnagram("anagram", "nagaram"));
        System.out.println(isAnagram("rat", "car"));
    }

    static boolean isAnagram(String s, String t) {
        if (s.length() != t.length()) return false;
        java.util.Map<Character, Integer> counts = new java.util.HashMap<>();
        for (char ch : s.toCharArray()) {
            counts.merge(ch, 1, Integer::sum);
        }
        for (char ch : t.toCharArray()) {
            counts.merge(ch, -1, Integer::sum);
        }
        for (int count : counts.values()) {
            if (count != 0) return false;
        }
        return true;
    }
}
```

You can also write it without the library, to show you understand the mechanism underneath:

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
```javascript +
function isAnagramManual(s, t) {
  if (s.length !== t.length) return false;
  const counts = new Map();
  for (const ch of s) counts.set(ch, (counts.get(ch) || 0) + 1);
  for (const ch of t) {
    if (!counts.has(ch)) return false;
    const next = counts.get(ch) - 1;
    if (next === 0) counts.delete(ch);
    else counts.set(ch, next);
  }
  return counts.size === 0;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        System.out.println(isAnagramManual("anagram", "nagaram"));
        System.out.println(isAnagramManual("rat", "car"));
    }

    static boolean isAnagramManual(String s, String t) {
        if (s.length() != t.length()) return false;
        java.util.Map<Character, Integer> counts = new java.util.HashMap<>();
        for (char ch : s.toCharArray()) {
            counts.merge(ch, 1, Integer::sum);
        }
        for (char ch : t.toCharArray()) {
            if (!counts.containsKey(ch)) return false;
            int next = counts.get(ch) - 1;
            if (next == 0) counts.remove(ch);
            else counts.put(ch, next);
        }
        return counts.isEmpty();
    }
}
```

**Complexity:** Time O(n) where n is string length. Space O(k) where k is the alphabet size (O(1) if you assume a fixed alphabet like lowercase ASCII).

**Common mistakes:**
- Sorting both strings and comparing. This works at O(n log n), but it is strictly worse than counting, and interviewers will ask if you can do better.
- Skipping the early length check, a cheap and easy win.
- Not handling non-ASCII characters if the problem implies them.

> **Remember:** anagram means same character counts, not same sorted order. Counting beats sorting.

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-valid-anagram-q1", "type": "mcq",
      "prompt": "Why is counting character frequencies a better anagram check than sorting both strings?",
      "options": [
        {"id": "a", "text": "Counting is O(n) while sorting is O(n log n)"},
        {"id": "b", "text": "Sorting cannot detect anagrams at all"},
        {"id": "c", "text": "Counting uses no extra memory while sorting does"},
        {"id": "d", "text": "Sorting only works on numbers, not strings"}
      ],
      "correct": "a",
      "explanation": "Both approaches are correct, but frequency counting runs in O(n) while sorting costs O(n log n). An interviewer will usually push you from the sorting answer to the counting one." }
] }
```

## Contains Duplicate

[Contains Duplicate (LeetCode 217)](https://leetcode.com/problems/contains-duplicate/)

**Intuition:** This is the plainest form of "have I seen this before": a hash set existence check.

**Approach:** Insert elements into a set one at a time. If an element is already there, return `True` right away.

```python
def contains_duplicate(nums: list[int]) -> bool:
    seen = set()
    for num in nums:
        if num in seen:
            return True
        seen.add(num)
    return False
```
```javascript +
function containsDuplicate(nums) {
  const seen = new Set();
  for (const num of nums) {
    if (seen.has(num)) return true;
    seen.add(num);
  }
  return false;
}
```
```java +
public class Main {
    public static void main(String[] args) {
        int[] nums = {1, 2, 3, 1};
        System.out.println(containsDuplicate(nums));
    }

    static boolean containsDuplicate(int[] nums) {
        java.util.Set<Integer> seen = new java.util.HashSet<>();
        for (int num : nums) {
            if (!seen.add(num)) return true;
        }
        return false;
    }
}
```

A one-line alternative trades the early exit for brevity: `return len(nums) != len(set(nums))`. It is correct, but it always scans the full list even when a duplicate shows up early, so mention that trade-off if you use it.

**Complexity:** Time O(n). Space O(n) worst case (all values unique).

**Common mistakes:**
- Using nested loops (O(n²)) as the final answer instead of a starting point to optimize from.
- Sorting first (O(n log n)): correct and space-efficient, but slower than hashing. Worth mentioning both if asked to compare.

> **Remember:** "have I seen this before" is almost always a hash set, one insert-and-check per element.

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-contains-duplicate-q1", "type": "mcq",
      "prompt": "What is the time complexity of the hash-set solution to Contains Duplicate?",
      "options": [
        {"id": "a", "text": "O(n)"},
        {"id": "b", "text": "O(n log n)"},
        {"id": "c", "text": "O(n²)"},
        {"id": "d", "text": "O(1)"}
      ],
      "correct": "a",
      "explanation": "Each element is inserted and checked against the set once, and both operations are O(1) on average, giving O(n) total." }
] }
```

## Sorting algorithms: a complexity cheatsheet

Picture 1,000 exam papers in a random pile that need ordering by score. Comparing every pair to place each paper is slow: about 500,000 comparisons. Splitting the pile in half, sorting each half, then merging the two sorted halves needs only about 10 rounds of splitting (since 2 to the 10th power is roughly 1,000), each doing at most 1,000 comparisons: about 10,000 total instead of 500,000. That gap, `n²` versus `n log n`, is why sorting algorithm choice matters, even though sorting rarely stands alone: it shows up as a supporting tool, calling `nums.sort()` before a two-pointer sweep, or reaching for a heap in a top-k problem. This section is the reference for when an interviewer asks about sorting directly.

### Comparison-based sorts

| Algorithm | Best | Average | Worst | Space | Stable? |
|---|---|---|---|---|---|
| Bubble Sort | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Selection Sort | O(n²) | O(n²) | O(n²) | O(1) | No |
| Insertion Sort | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Merge Sort | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes |
| Quick Sort | O(n log n) | O(n log n) | O(n²) | O(log n) | No |
| Heap Sort | O(n log n) | O(n log n) | O(n log n) | O(1) | No |

### Non-comparison sorts

| Algorithm | Best / Average / Worst | Space | Constraint |
|---|---|---|---|
| Counting Sort | O(n + k) | O(k) | Integers in a known, bounded range `k` |
| Radix Sort | O(nk) | O(n + k) | Fixed-width integers or strings, sorted digit by digit |
| Bucket Sort | O(n + k) best/avg, O(n²) worst | O(n + k) | Input spread out evenly |

These beat the O(n log n) comparison-sort lower bound because they never compare elements pairwise. They exploit structure in the values themselves, a bounded range or a fixed digit count, which is exactly why they do not generalize to arbitrary comparable objects.

### Why Quick Sort's worst case is O(n²)

Quick Sort partitions around a pivot. If the pivot always lands on the min or max of the current slice (always picking the first element on already-sorted input, say), one side of the partition is empty and the other holds everything else. Recursion depth becomes O(n) instead of O(log n), giving O(n²) total.

Trace it on the already-sorted array `[1, 2, 3, 4, 5]` with "always pick the first element" as the pivot rule: pivot `1` splits into `[]` and `[2, 3, 4, 5]`, pivot `2` splits into `[]` and `[3, 4, 5]`, and so on. Every partition peels off one element instead of splitting the array in half, so recursion goes 5 levels deep instead of the 2-3 levels a balanced split would give. On an array of size n, that becomes n levels deep, each doing O(n) partition work: O(n²) total. The fix is to randomize the pivot (or use median-of-three), which makes this worst case astronomically unlikely instead of triggered by a common shape like "already sorted."

### Choosing a sort in an interview

- **Merge Sort** is the only stable O(n log n) option here. It needs O(n) extra space for the merge step. Reach for it when stability matters (sorting by a secondary key after a primary one) or for linked lists, where merging costs O(1) extra space instead of the shifting an array-based sort would need.
- **Quick Sort** is in-place, needing only O(log n) space for the recursion stack. It is typically fastest in practice thanks to cache locality, but it is not stable and carries the O(n²) worst case traced above.
- **Heap Sort** uses O(1) space with no worst-case blowup, but poor cache locality makes it slower in practice than Quick Sort despite the same O(n log n) bound. It is the classic "same Big-O, different real-world speed" example.

Python's built-in `arr.sort()` and `sorted(arr)` use Timsort, a hybrid of Merge Sort and Insertion Sort. It finds already-sorted runs in the input, uses Insertion Sort to extend or build small runs, then merges those runs the way Merge Sort does. It is stable and O(n log n) worst case. Insertion Sort's fast O(n) best case on nearly-sorted data is exactly why it handles the small-run part.

Binary search is O(log n) because it halves the search space each step. The general pattern worth stating out loud:

- **O(log n):** the algorithm halves the problem each step. Binary search, BST lookup, a single heap push or pop.
- **O(n log n):** an O(log n) operation repeated for all n elements. Merge Sort does O(log n) merge levels, each processing all n elements, giving n times log n, not log n alone. Heap Sort has the same shape: n heap operations, each O(log n).

| n | log n | n log n |
|---|---|---|
| 8 | 3 | 24 |
| 1,000 | ~10 | ~10,000 |
| 1,000,000 | ~20 | ~20,000,000 |

One line to keep: O(log n) means divide and ignore half; O(n log n) means divide, and do O(log n) work for every one of the n elements.

> **Remember:** Merge Sort is the stable one, Quick Sort is usually the fastest, Heap Sort has no bad case but poor cache behavior. Timsort is what Python actually runs.

```knowledge-check
{ "questions": [
    { "id": "dsa-arrays-and-hashing-sorting-cheatsheet-q1", "type": "mcq",
      "prompt": "Which sorting algorithm is stable AND guarantees O(n log n) even in the worst case?",
      "options": [
        {"id": "a", "text": "Merge Sort"},
        {"id": "b", "text": "Quick Sort"},
        {"id": "c", "text": "Heap Sort"},
        {"id": "d", "text": "Selection Sort"}
      ],
      "correct": "a",
      "explanation": "Merge Sort is O(n log n) in every case and stable. Quick Sort is not stable and has an O(n²) worst case; Heap Sort is O(n log n) worst case but not stable." }
] }
```
