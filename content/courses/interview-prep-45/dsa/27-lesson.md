---
kind: lesson
id_key: interview-prep-45/day-27
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Day 27 — Design Patterns"
position: 27
estimated_minutes: 150
source:
    - 45-day-interview-roadmap.md
---

"Design" questions blend two skills: knowing the classic OOP patterns well enough to apply them under time pressure, and combining basic data structures to satisfy specific operation-complexity requirements. Today covers the patterns you'll actually be asked to reason about or implement — Singleton, Factory, Observer, Strategy, Repository, Builder — then applies that thinking to four "implement this data structure" problems, ending with LRU Cache, the single most-asked design problem in tech interviews.

## Singleton, Factory, Observer

**Singleton** — ensure a class has exactly one instance, globally accessible. Useful for shared resources (config, connection pools, loggers) — but overused in interviews as an example, since global mutable state is usually an anti-pattern in real systems. Know it, but be ready to critique it too.

```python
class Singleton:
    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

s1 = Singleton()
s2 = Singleton()
assert s1 is s2  # same object
```

**Factory** — centralize object creation logic so callers don't need to know concrete classes, just a category/type string.

```python
class Dog:
    def speak(self): return "Woof"

class Cat:
    def speak(self): return "Meow"

class AnimalFactory:
    @staticmethod
    def create(kind: str):
        return {"dog": Dog, "cat": Cat}[kind]()

animal = AnimalFactory.create("dog")
print(animal.speak())  # Woof
```

**Observer** — objects (observers) subscribe to a subject and get notified automatically when its state changes. This is the pattern behind event systems, pub/sub, and reactive UI updates.

```python
class Subject:
    def __init__(self):
        self._observers = []

    def subscribe(self, observer):
        self._observers.append(observer)

    def notify(self, event):
        for observer in self._observers:
            observer.update(event)

class Logger:
    def update(self, event):
        print(f"Logged: {event}")

subject = Subject()
subject.subscribe(Logger())
subject.notify("user_created")  # Logged: user_created
```

## Strategy, Repository, Builder

**Strategy** — encapsulate interchangeable algorithms behind a common interface, selected at runtime. This is how you avoid a wall of `if/elif` branches for "which algorithm to run."

```python
class SortStrategy:
    def sort(self, data): raise NotImplementedError

class AscendingSort(SortStrategy):
    def sort(self, data): return sorted(data)

class DescendingSort(SortStrategy):
    def sort(self, data): return sorted(data, reverse=True)

class Sorter:
    def __init__(self, strategy: SortStrategy):
        self.strategy = strategy

    def execute(self, data):
        return self.strategy.sort(data)

print(Sorter(DescendingSort()).execute([3, 1, 2]))  # [3, 2, 1]
```

**Repository** — abstract data access behind an interface, so business logic doesn't depend on whether data comes from a DB, an API, or memory. This is what lets you swap Postgres for a mock in tests without touching business logic.

```python
class UserRepository:
    def get(self, user_id): raise NotImplementedError
    def save(self, user): raise NotImplementedError

class InMemoryUserRepository(UserRepository):
    def __init__(self):
        self._users = {}

    def get(self, user_id):
        return self._users.get(user_id)

    def save(self, user):
        self._users[user["id"]] = user
```

**Builder** — construct a complex object step by step, instead of a constructor with a dozen optional parameters.

```python
class Pizza:
    def __init__(self):
        self.toppings = []

    def __repr__(self):
        return f"Pizza({', '.join(self.toppings)})"

class PizzaBuilder:
    def __init__(self):
        self.pizza = Pizza()

    def add_topping(self, topping):
        self.pizza.toppings.append(topping)
        return self  # enables fluent chaining

    def build(self):
        return self.pizza

pizza = PizzaBuilder().add_topping("cheese").add_topping("basil").build()
```

| Pattern | Solves | Interview signal it addresses |
|---|---|---|
| Singleton | One shared instance | "How do you avoid duplicate expensive resources?" |
| Factory | Decouple creation from usage | "How do you add a new type without touching callers?" |
| Observer | React to state changes | "How do multiple parts of a system stay in sync?" |
| Strategy | Swap algorithms at runtime | "How do you avoid a giant if/elif chain?" |
| Repository | Decouple business logic from storage | "How do you test this without a real database?" |
| Builder | Construct complex objects incrementally | "How do you avoid a 10-argument constructor?" |

## Implement Singleton (coding interview)

**Intuition:** The interview version usually wants you to demonstrate the mechanism (lazy initialization, thread-safety awareness) rather than just describe the pattern.

**Approach:** Override `__new__` to intercept instance creation; use a class-level attribute to hold the single instance.

```python
import threading

class ThreadSafeSingleton:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            with cls._lock:               # double-checked locking
                if cls._instance is None:  # re-check inside the lock
                    cls._instance = super().__new__(cls)
        return cls._instance
```

**Complexity:** O(1) instance access after first creation. The double-checked lock avoids taking the lock on every access (only the first, racing creation needs it).

**Common mistakes:** Forgetting thread-safety when asked about concurrent access — a naive `if cls._instance is None: cls._instance = ...` has a race condition where two threads can both pass the check before either assigns; over-using Singleton for things that don't need global uniqueness (mention this critique if asked "when would you *not* use this").

## Design Tic-Tac-Toe

[LeetCode 348](https://leetcode.com/problems/design-tic-tac-toe/) — Design

**Intuition:** Naively checking the whole board for a win after every move is O(n²) per move. Instead, track running sums per row, column, and both diagonals — a move only ever affects one row, one column, and possibly the diagonals, so update and check in O(1).

**Approach:** Maintain `rows[n]`, `cols[n]`, and two diagonal counters. Player 1 adds +1, player 2 adds -1 to each relevant counter. A win is detected the instant any counter reaches `±n`.

```python
class TicTacToe:
    def __init__(self, n: int):
        self.n = n
        self.rows = [0] * n
        self.cols = [0] * n
        self.diagonal = 0
        self.anti_diagonal = 0

    def move(self, row: int, col: int, player: int) -> int:
        delta = 1 if player == 1 else -1

        self.rows[row] += delta
        self.cols[col] += delta
        if row == col:
            self.diagonal += delta
        if row + col == self.n - 1:
            self.anti_diagonal += delta

        if abs(self.rows[row]) == self.n or abs(self.cols[col]) == self.n \
                or abs(self.diagonal) == self.n or abs(self.anti_diagonal) == self.n:
            return player

        return 0
```

**Complexity:** Time O(1) per move, space O(n) — a massive improvement over rescanning the full board (O(n²)) on every move.

**Common mistakes:** Actually storing the full board and re-scanning for a winner each move — works but fails the implicit "can you do better" bar this problem is designed to test; forgetting a move can be on a diagonal *and* the anti-diagonal simultaneously only when `n` is odd and the move is at the center — the `if` checks above handle this correctly without an `elif`.

## Design HashMap

[LeetCode 706](https://leetcode.com/problems/design-hashmap/) — Design

**Intuition:** Implement a hash map without using the language's built-in dict — this tests whether you understand what a hash map actually does under the hood: bucket by hash, handle collisions via chaining.

**Approach:** Fixed-size array of buckets; each bucket is a list of `(key, value)` pairs. Hash the key to pick a bucket; search/replace/remove within that bucket's list.

```python
class MyHashMap:
    def __init__(self):
        self.size = 1000
        self.buckets = [[] for _ in range(self.size)]

    def _hash(self, key: int) -> int:
        return key % self.size

    def put(self, key: int, value: int) -> None:
        bucket = self.buckets[self._hash(key)]
        for i, (k, v) in enumerate(bucket):
            if k == key:
                bucket[i] = (key, value)
                return
        bucket.append((key, value))

    def get(self, key: int) -> int:
        bucket = self.buckets[self._hash(key)]
        for k, v in bucket:
            if k == key:
                return v
        return -1

    def remove(self, key: int) -> None:
        bucket = self.buckets[self._hash(key)]
        for i, (k, v) in enumerate(bucket):
            if k == key:
                bucket.pop(i)
                return
```

**Complexity:** Average O(1) per operation if the bucket count keeps chains short (this implementation uses a fixed 1000 buckets, so worst case degrades to O(n/1000) per bucket — a production hash map would resize dynamically when load factor grows too high). Space O(n).

**Common mistakes:** Forgetting to handle key updates (`put` on an existing key should overwrite, not append a duplicate); using a bucket count that's too small for the problem's key range, causing long chains and effectively O(n) operations.

## LRU Cache

[LeetCode 146](https://leetcode.com/problems/lru-cache/) — Design

**Intuition:** You need O(1) get and put, while evicting the *least recently used* entry when capacity is exceeded. A hash map alone gives O(1) lookup but no ordering; a linked list alone gives ordering but O(n) lookup. Combine them: hash map for O(1) node lookup, doubly linked list for O(1) reordering (move-to-front on access, evict-from-back on overflow).

**Approach:** Doubly linked list with sentinel head/tail nodes (avoids null-checking edge cases at the boundaries). Hash map from key to its node in the list. On `get`, move the accessed node to the front (most recently used side). On `put`, insert at the front; if over capacity, remove the node just before the tail sentinel (least recently used).

```python
class DLLNode:
    def __init__(self, key=0, value=0):
        self.key = key
        self.value = value
        self.prev = None
        self.next = None

class LRUCache:
    def __init__(self, capacity: int):
        self.capacity = capacity
        self.cache = {}  # key -> DLLNode

        self.head = DLLNode()  # sentinel, most-recently-used side
        self.tail = DLLNode()  # sentinel, least-recently-used side
        self.head.next = self.tail
        self.tail.prev = self.head

    def _remove(self, node):
        node.prev.next = node.next
        node.next.prev = node.prev

    def _insert_at_front(self, node):
        node.next = self.head.next
        node.prev = self.head
        self.head.next.prev = node
        self.head.next = node

    def get(self, key: int) -> int:
        if key not in self.cache:
            return -1
        node = self.cache[key]
        self._remove(node)
        self._insert_at_front(node)  # mark as most recently used
        return node.value

    def put(self, key: int, value: int) -> None:
        if key in self.cache:
            self._remove(self.cache[key])

        node = DLLNode(key, value)
        self.cache[key] = node
        self._insert_at_front(node)

        if len(self.cache) > self.capacity:
            lru = self.tail.prev
            self._remove(lru)
            del self.cache[lru.key]
```

**Complexity:** O(1) time for both `get` and `put`, O(capacity) space.

**Common mistakes:** Using `OrderedDict` (which does solve this in a few lines via `move_to_end` and `popitem(last=False)`) without being able to explain or implement the underlying doubly-linked-list + hash-map mechanism — interviewers almost always want the from-scratch version for this specific problem, since it's the whole point of the exercise; forgetting sentinel head/tail nodes and instead null-checking `prev`/`next` at every boundary, which is a frequent source of bugs; not removing the old node before re-inserting on `put` for an existing key, which leaves stale links.

## Key takeaways

- Singleton, Factory, Observer, Strategy, Repository, and Builder each solve one specific structural problem — know the problem each solves, not just the code shape, since "when would you use this" is asked as often as "implement this."
- Design questions on LeetCode (Tic-Tac-Toe, HashMap, LRU) are really "which combination of basic data structures gives the required operation complexity" — identify the complexity target first, then pick structures that satisfy it.
- O(1) win detection in Tic-Tac-Toe comes from maintaining running row/column/diagonal counters instead of rescanning the board.
- A hash map from scratch is buckets (array) + chaining (list of pairs per bucket) + a hash function — the same idea as language-builtin dicts, just without dynamic resizing unless you implement it.
- LRU Cache's O(1) get/put requires combining a hash map (O(1) lookup) with a doubly linked list (O(1) reordering) — sentinel head/tail nodes eliminate edge-case null checks and are worth using by default in linked-list-heavy design problems.

## Today's checklist

- [ ] Explain what problem each pattern solves: Singleton, Factory, Observer, Strategy, Repository, Builder
- [ ] Implement Singleton (thread-safe version) as a coding exercise
- [ ] Solve Design Tic-Tac-Toe (LeetCode 348)
- [ ] Solve Design HashMap (LeetCode 706)
- [ ] Solve LRU Cache (LeetCode 146)
- [ ] Implement LRU cache with hash map + doubly linked list, from memory, no `OrderedDict`
- [ ] Practice explaining design choices and trade-offs out loud, not just describing the code
