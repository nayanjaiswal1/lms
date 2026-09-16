---
kind: lesson
id_key: interview-prep-45/lld-08-concurrency
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "Concurrency in Low-Level Design"
position: 8
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

"Two users try to book the last seat at the same time — what happens?" is the follow-up question in almost every LLD interview, and it is where otherwise-good designs fall apart. This lesson gives you the vocabulary, the three mechanisms you will actually use, and the specific patterns for the problems in the rest of this section.

The framing that keeps you out of trouble: **find the shared mutable state, then either remove the sharing, remove the mutability, or protect the access.** Every correct answer is one of those three.

## Race conditions and the shared mutable state

A **race condition** is any situation where the result depends on the interleaving of concurrent operations. The canonical shape is **check-then-act**:

```python
import threading

class UnsafeCounter:
    def __init__(self): self.count = 0
    def increment(self):
        current = self.count      # read
        self.count = current + 1  # write — another thread may have written between these

class SafeCounter:
    def __init__(self):
        self.count = 0
        self._lock = threading.Lock()
    def increment(self):
        with self._lock:          # read-modify-write is now atomic
            self.count += 1


def hammer(counter, times=50_000):
    for _ in range(times):
        counter.increment()

def run(counter):
    threads = [threading.Thread(target=hammer, args=(counter,)) for _ in range(4)]
    for t in threads: t.start()
    for t in threads: t.join()
    return counter.count

safe = run(SafeCounter())
assert safe == 200_000                      # always exactly right
unsafe = run(UnsafeCounter())
print(f"safe={safe} (always correct), unsafe={unsafe} (may be < 200000)")
```

Three shapes to be able to name:

| Race | Shape | Example |
|---|---|---|
| **Check-then-act** | Test a condition, then act on it — the state changed in between | `if seat.is_free: seat.book()` |
| **Read-modify-write** | Load, compute, store | `count = count + 1`, `balance -= amount` |
| **Publish-before-init** | Another thread sees a half-constructed object | Naive lazy singleton without a lock |

**The two questions to answer out loud in every LLD interview:**

1. *What is the shared mutable state here?* — the free-spot set, the seat map, the inventory count, the account balance.
2. *What protects it?* — a lock, an atomic operation, immutability, or a database constraint.

Say both, unprompted, and the concurrency follow-up is already answered.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-race-q1", "type": "mcq",
      "prompt": "`if seat.is_available: seat.book(user)` is run by two threads at once. Which race is this, and why doesn't making `is_available` and `book` individually thread-safe fix it?",
      "options": [
        {"id":"a","text":"Read-modify-write; it is fixed by making each method synchronized"},
        {"id":"b","text":"Check-then-act — both threads can pass the check before either books. The two operations must be atomic *together*, so the lock has to span the whole check-and-act, not each method separately"},
        {"id":"c","text":"Publish-before-initialisation; fix with a volatile field"},
        {"id":"d","text":"There is no race, since booking overwrites the same value"}
      ],
      "correct": "b",
      "explanation": "Thread-safe individual methods give no guarantee about a sequence of them — this is the classic \"composition of atomic operations is not atomic\" trap. The critical section is the whole check-and-act." }
] }
```

## The three mechanisms

**1. Locks (mutual exclusion).** The general tool: only one thread inside the critical section.

```python
import threading

class SeatMap:
    def __init__(self, seats: list[str]):
        self._free = set(seats)
        self._lock = threading.Lock()

    def book(self, seat: str, user: str) -> bool:
        with self._lock:                     # check and act, atomically
            if seat not in self._free:
                return False
            self._free.remove(seat)
            return True

    @property
    def free_count(self) -> int:
        with self._lock:
            return len(self._free)


seats = SeatMap([f"A{i}" for i in range(3)])
results = []
threads = [threading.Thread(target=lambda: results.append(seats.book("A1", "u")))
           for _ in range(10)]
for t in threads: t.start()
for t in threads: t.join()

assert results.count(True) == 1              # exactly one winner, always
assert seats.free_count == 2
print("bookings succeeded:", results.count(True), "of", len(results))
```

Rules for locks, all of which get asked about:

- **Hold the lock for as little as possible** — never across I/O, a network call, or a callback into unknown code.
- **Never call out to unknown code while holding a lock** — it can call back in and deadlock.
- **Prefer fine-grained locks**: one lock per spot/seat/account, not one global lock, so unrelated operations proceed in parallel.
- **Read-write locks** when reads vastly outnumber writes: many concurrent readers, one exclusive writer.

**2. Atomic operations.** For a single variable, an atomic compare-and-swap beats a lock: no blocking, no deadlock, less overhead. Java's `AtomicInteger.incrementAndGet()`, Go's `atomic.AddInt64`, and Redis's `INCR` are all this. The limitation is that atomics protect **one** variable — the moment two must change together, you need a lock or a transaction.

**3. Immutability — the mechanism that needs no protection at all.** An object that never changes after construction is safe to share across any number of threads, with no lock, no cost, and no possible race. This is why value objects (`Money`, `TimeSlot`, `Point`) should be immutable, and why "make it immutable" is the cheapest concurrency answer available. When state must change, replace the whole object (copy-on-write) instead of mutating it in place.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-mechanisms-q1", "type": "mcq",
      "prompt": "Why is one lock per parking spot usually better than one lock for the whole parking lot?",
      "options": [
        {"id":"a","text":"Fine-grained locks use less memory"},
        {"id":"b","text":"Operations on different spots don't contend with each other, so throughput scales with parallelism — a single global lock serialises every operation in the system"},
        {"id":"c","text":"A global lock cannot be released"},
        {"id":"d","text":"Per-spot locks eliminate the possibility of deadlock"}
      ],
      "correct": "b",
      "explanation": "Lock granularity is a throughput decision: coarse locks are simpler and safer but serialise everything. Note that fine-grained locks *increase* deadlock risk when a thread needs two of them — which is why lock ordering matters." }
] }
```

## Deadlock, livelock, and starvation

**Deadlock** needs all four Coffman conditions simultaneously — break any one and it cannot occur:

| Condition | Meaning | Break it by |
|---|---|---|
| Mutual exclusion | A resource is held exclusively | Immutability, lock-free structures |
| Hold and wait | Hold one lock, request another | Acquire all locks at once, or none |
| No pre-emption | Locks can't be taken away | Timeouts (`tryLock`) |
| **Circular wait** | A waits for B, B waits for A | **Global lock ordering** — the usual fix |

```python
import threading

class Account:
    def __init__(self, aid: int, paise: int):
        self.id, self.balance = aid, paise
        self.lock = threading.Lock()

def transfer(src: Account, dst: Account, paise: int) -> bool:
    # ALWAYS acquire in a fixed global order (by id) — this is what removes circular wait.
    first, second = (src, dst) if src.id < dst.id else (dst, src)
    with first.lock:
        with second.lock:
            if src.balance < paise:
                return False
            src.balance -= paise
            dst.balance += paise
            return True


a, b = Account(1, 100_000), Account(2, 50_000)
# Concurrent transfers in OPPOSITE directions: the classic deadlock setup.
t1 = threading.Thread(target=lambda: [transfer(a, b, 100) for _ in range(1_000)])
t2 = threading.Thread(target=lambda: [transfer(b, a, 100) for _ in range(1_000)])
t1.start(); t2.start(); t1.join(); t2.join()

assert a.balance + b.balance == 150_000       # money is conserved, and nothing deadlocked
print("balances:", a.balance, b.balance)
```

The bank-transfer deadlock is asked by name, and **ordering locks by a stable identifier** is the expected answer. The alternative, `tryLock` with a timeout and a randomised retry, breaks the no-pre-emption condition instead — mention it as the fallback when a global order is not available.

Two related failures worth distinguishing:

- **Livelock**: threads keep changing state in response to each other but make no progress — two people stepping aside in a corridor. Fixed with randomised backoff.
- **Starvation**: a thread never gets the resource because others keep winning. Fixed with fair locks or queueing.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-deadlock-q1", "type": "mcq",
      "prompt": "Two threads transfer money in opposite directions between accounts A and B, each locking the source then the destination. What is the standard fix?",
      "options": [
        {"id":"a","text":"Use a single global lock for all transfers"},
        {"id":"b","text":"Acquire the two account locks in a fixed global order (e.g. by account id), which breaks the circular-wait condition while still allowing unrelated transfers to run in parallel"},
        {"id":"c","text":"Make the accounts immutable"},
        {"id":"d","text":"Retry the transfer if it takes too long"}
      ],
      "correct": "b",
      "explanation": "A global lock works but serialises all transfers. Consistent lock ordering removes the cycle with no loss of parallelism; tryLock-with-timeout plus randomised retry is the fallback where no stable ordering exists." }
] }
```

## The patterns you will actually use in LLD problems

**Producer–consumer with a bounded queue.** The standard shape for "requests arrive faster than they can be processed" — and the bound is what gives you backpressure rather than unbounded memory growth.

```python
import queue, threading

def worker(jobs: "queue.Queue", done: list, lock: threading.Lock):
    while True:
        job = jobs.get()
        if job is None:                      # sentinel: shut down cleanly
            jobs.task_done()
            return
        with lock:
            done.append(job * 2)
        jobs.task_done()


jobs: "queue.Queue" = queue.Queue(maxsize=10)     # bounded → producers block when full
done, lock = [], threading.Lock()
workers = [threading.Thread(target=worker, args=(jobs, done, lock)) for _ in range(3)]
for w in workers: w.start()

for i in range(20):
    jobs.put(i)
for _ in workers:
    jobs.put(None)
jobs.join()
for w in workers: w.join()

assert sorted(done) == [i * 2 for i in range(20)]
print("processed", len(done), "jobs across", len(workers), "workers")
```

**Optimistic locking (version check).** No lock held across the operation: read a version, and make the write conditional on that version being unchanged. Right for **low contention** — a user editing their own profile.

```python
class VersionedRecord:
    def __init__(self, value: str):
        self.value, self.version = value, 0

    def update(self, new_value: str, expected_version: int) -> bool:
        if self.version != expected_version:
            return False                     # someone else wrote first → caller retries
        self.value, self.version = new_value, self.version + 1
        return True


rec = VersionedRecord("draft")
v = rec.version
assert rec.update("edited by A", v) is True
assert rec.update("edited by B", v) is False     # B's stale write is rejected
assert rec.value == "edited by A" and rec.version == 1
print("optimistic lock rejected the stale write; value =", rec.value)
```

**Pessimistic locking.** Take the lock (or `SELECT … FOR UPDATE`) before reading. Right for **high contention** — the last seat of a sold-out show, where optimistic retries would mostly fail.

**Reservation with a TTL.** The pattern behind every seat-booking flow: hold the resource for a bounded time, confirm or expire. It avoids holding a database lock for the minutes a user spends entering card details, and it is why an expiry timestamp beats a boolean `is_locked` — a crashed client releases the seat automatically.

**And the rule that matters most in an interview**: in a **multi-process or multi-server** system, an in-process lock protects nothing. The invariant must be enforced where the state lives:

```
UPDATE seats SET status = 'booked', booked_by = $1
WHERE seat_id = $2 AND status = 'available';     -- 0 rows affected ⇒ someone else won
```

A conditional `UPDATE` or a unique constraint is atomic across every server; a `threading.Lock` is atomic across exactly one process. Saying this sentence is what separates a design that works on a laptop from one that works in production — and it connects directly to the fencing-token discussion in the HLD coordination lesson.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-patterns-q1", "type": "mcq",
      "prompt": "Your booking service runs on five servers. Which mechanism actually prevents double-booking a seat?",
      "options": [
        {"id":"a","text":"A synchronized method or threading.Lock in the booking service"},
        {"id":"b","text":"A conditional database write — `UPDATE seats SET status='booked' WHERE seat_id=? AND status='available'` — where zero affected rows means another server won; an in-process lock only serialises threads within one process"},
        {"id":"c","text":"Making the Seat class immutable"},
        {"id":"d","text":"Ordering the locks by seat id"}
      ],
      "correct": "b",
      "explanation": "In-process locks are invisible to other processes. The invariant must be enforced by the one component all servers share — the database — via a conditional update or a unique constraint." }
] }
```

## Key takeaways

**The recall card:**

```
Find the SHARED MUTABLE STATE → remove sharing, remove mutability, or protect access.
Races: check-then-act · read-modify-write · publish-before-init
  Thread-safe methods do NOT compose: the critical section is the whole sequence.

Mechanisms:
  Lock        — general; hold briefly, never across I/O or callbacks; fine-grained > global
  Atomic      — one variable, no blocking (AtomicInteger, INCR, CAS)
  Immutability— no protection needed at all. Value objects should be immutable.

Deadlock = 4 Coffman conditions; break circular wait with a GLOBAL LOCK ORDER (by id).
  Fallback: tryLock + timeout + randomised retry.  Livelock → backoff.  Starvation → fair locks.

Patterns:
  Producer–consumer with a BOUNDED queue (backpressure) + sentinel shutdown
  Optimistic (version check + retry) → LOW contention
  Pessimistic (lock / SELECT FOR UPDATE) → HIGH contention
  Reservation with a TTL → long user-driven flows (seat holds, checkout)

MULTI-PROCESS: an in-process lock protects nothing.
  Enforce at the shared resource: conditional UPDATE ... WHERE status='available',
  or a UNIQUE constraint. Zero rows affected = you lost the race.
```

- **Volunteer the concurrency answer.** Naming the shared mutable state and its protection before being asked is one of the highest-value moves in an LLD round.
- **Match the locking strategy to contention**: optimistic for rare conflicts, pessimistic for the last seat, reservations for anything a human takes minutes to complete.
- **Lock ordering is the deadlock answer**, and the bank-transfer example is the one to have ready.
- **The database is the only lock that spans servers.** Every problem later in this section — seat booking, inventory, wallets — resolves to a conditional write or a unique constraint at the storage layer.
