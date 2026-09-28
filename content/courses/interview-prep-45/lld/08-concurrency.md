---
kind: lesson
id_key: interview-prep-45/lld-08-concurrency
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Concurrency in Low-Level Design"
position: 8
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

"Two users try to book the last seat at the exact same moment — what happens?" That question shows up as a follow-up in almost every LLD interview, and it's where otherwise solid designs quietly fall apart. This lesson gives you the vocabulary, the three tools you'll actually use, and the specific patterns for the problems coming up later in this section.

Here's the one idea that keeps you out of trouble: **find the piece of data that's shared and changeable, then either stop sharing it, stop letting it change, or protect access to it.** Every correct answer boils down to one of those three moves.

## Race conditions and shared, changeable data

A **race condition** happens whenever the result depends on exactly how two things happening at once get interleaved. The classic shape is **check, then act**:

```python
import threading

class UnsafeCounter:
    def __init__(self): self.count = 0
    def increment(self):
        current = self.count      # read
        self.count = current + 1  # write — another thread might have written in between

class SafeCounter:
    def __init__(self):
        self.count = 0
        self._lock = threading.Lock()
    def increment(self):
        with self._lock:          # read-then-write happens as one atomic step now
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
assert safe == 200_000                      # always exactly right, every time
unsafe = run(UnsafeCounter())
print(f"safe={safe} (always correct), unsafe={unsafe} (may be < 200000)")
```

There are three shapes of race worth being able to name on sight:

| Race | What it looks like | Example |
|---|---|---|
| **Check-then-act** | Test something, then act on it — but it could change in between | `if seat.is_free: seat.book()` |
| **Read-modify-write** | Load a value, do some math, save it back | `count = count + 1`, `balance -= amount` |
| **Publish-before-init** | Another thread sees an object that's only half built | A naive lazy singleton, with no lock at all |

**Two questions to answer out loud in every LLD interview, before anyone even asks:**

1. *What's the shared, changeable data here?* — the set of free spots, the seat map, the inventory count, the account balance.
2. *What's protecting it?* — a lock, an atomic operation, the fact that it never changes, or a database rule.

Say both, unprompted, and you've already answered the concurrency follow-up before it lands.

> **Remember:** thread-safe pieces don't add up to a thread-safe sequence. The whole check-then-act step needs one lock around it, not two separately-safe halves.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-race-q1", "type": "mcq",
      "prompt": "`if seat.is_available: seat.book(user)` runs on two threads at the same moment. What kind of race is this, and why doesn't making `is_available` and `book` each individually thread-safe fix it?",
      "options": [
        {"id":"a","text":"Read-modify-write; it's fixed by marking each method synchronized"},
        {"id":"b","text":"Check-then-act — both threads can pass the check before either one books the seat. The two steps have to be atomic *together*, so the lock has to cover the whole check-and-act, not each method on its own"},
        {"id":"c","text":"Publish-before-initialisation; fixed with a volatile field"},
        {"id":"d","text":"There's no race here, since booking just overwrites the same value"}
      ],
      "correct": "b",
      "explanation": "Thread-safe individual methods give you no guarantee about a sequence of them — this is the classic trap where safe pieces don't add up to a safe whole. The section that needs protecting is the entire check-and-act." }
] }
```

## The three tools

**1. Locks — mutual exclusion.** The general-purpose tool: only one thread is allowed inside the protected section at a time.

```python
import threading

class SeatMap:
    def __init__(self, seats: list[str]):
        self._free = set(seats)
        self._lock = threading.Lock()

    def book(self, seat: str, user: str) -> bool:
        with self._lock:                     # check and act happen as one atomic step
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

assert results.count(True) == 1              # exactly one winner, every single time
assert seats.free_count == 2
print("bookings succeeded:", results.count(True), "of", len(results))
```

Rules for locks, and all of them get asked about:

- **Hold the lock for the shortest time possible** — never across a network call, a disk read, or a callback into code you don't control.
- **Never call unfamiliar code while holding a lock.** It might call back into your code and deadlock against itself.
- **Prefer many small locks over one big one**: one lock per seat, spot, or account, so unrelated operations can run at the same time.
- **Use a read-write lock** when reads vastly outnumber writes — many readers can run together, with just one writer at a time.

**2. Atomic operations.** For a single value, an atomic compare-and-swap beats a lock outright: no blocking, no possibility of deadlock, less overhead. Java's `AtomicInteger.incrementAndGet()`, Go's `atomic.AddInt64`, and Redis's `INCR` are all this same idea. The limit is that atomics only protect **one** variable — the moment two things need to change together, you're back to needing a lock or a transaction.

**3. Making it unchangeable — needs no protection at all.** An object that never changes after it's built is safe to hand to any number of threads, with no lock, no cost, and literally no way for it to go wrong. This is exactly why value objects like `Money`, `TimeSlot`, and `Point` should never change after they're created, and why "just make it unchangeable" is the cheapest concurrency fix you'll ever get to use. When something genuinely has to change, replace the whole object instead of mutating it in place — this is called copy-on-write.

> **Remember:** the three tools, from cheapest to most general: make it unchangeable (free), use an atomic operation (one value), or take a lock (anything else, held as briefly as possible).

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-mechanisms-q1", "type": "mcq",
      "prompt": "Why is one lock per parking spot usually better than one single lock for the whole parking lot?",
      "options": [
        {"id":"a","text":"Smaller locks use less memory"},
        {"id":"b","text":"Operations on different spots don't compete with each other, so throughput scales with how many things run in parallel — one global lock would force everything in the whole system to happen one at a time"},
        {"id":"c","text":"A global lock can never be released"},
        {"id":"d","text":"Smaller locks make deadlock impossible"}
      ],
      "correct": "b",
      "explanation": "Lock size is a throughput decision: one big lock is simpler and safer but forces everything to wait its turn. Worth noting: smaller locks actually *raise* the risk of deadlock when one thread needs two of them at once — which is why lock ordering matters, covered next." }
] }
```

## Deadlock, livelock, and starvation

**Deadlock** needs all four of the Coffman conditions to hold at once — break just one of them, and it can't happen:

| Condition | What it means | How to break it |
|---|---|---|
| Mutual exclusion | Something can only be held by one thread at a time | Make it unchangeable, or use a lock-free structure |
| Hold and wait | A thread holds one lock while waiting on another | Grab every lock you need at once, or none at all |
| No pre-emption | A lock can't be taken away from whoever's holding it | Use timeouts (`tryLock`) |
| **Circular wait** | Thread A waits on B, and B waits on A | **A fixed global lock order** — the usual fix |

```python
import threading

class Account:
    def __init__(self, aid: int, paise: int):
        self.id, self.balance = aid, paise
        self.lock = threading.Lock()

def transfer(src: Account, dst: Account, paise: int) -> bool:
    # ALWAYS lock in a fixed order (by id) — this is exactly what removes the circular wait.
    first, second = (src, dst) if src.id < dst.id else (dst, src)
    with first.lock:
        with second.lock:
            if src.balance < paise:
                return False
            src.balance -= paise
            dst.balance += paise
            return True


a, b = Account(1, 100_000), Account(2, 50_000)
# Concurrent transfers in OPPOSITE directions — the classic setup for a deadlock.
t1 = threading.Thread(target=lambda: [transfer(a, b, 100) for _ in range(1_000)])
t2 = threading.Thread(target=lambda: [transfer(b, a, 100) for _ in range(1_000)])
t1.start(); t2.start(); t1.join(); t2.join()

assert a.balance + b.balance == 150_000       # the money is all still there, and nothing froze
print("balances:", a.balance, b.balance)
```

The bank-transfer deadlock gets asked about by name, and **locking accounts in a fixed order by id** is exactly the answer interviewers are listening for. The fallback, when no stable ordering exists, is `tryLock` with a timeout plus a randomised retry — that breaks the "no pre-emption" condition instead. Mention it as a backup option.

Two related problems worth telling apart from deadlock:

- **Livelock**: two threads keep reacting to each other and changing state, but neither one ever makes progress — like two people stepping side to side in a hallway, both trying to let the other pass. Fixed with random backoff before retrying.
- **Starvation**: one thread never gets its turn because others keep winning first. Fixed with fair locks or a proper queue.

> **Remember:** lock accounts (or any pair of things) in a fixed order by id, and the circular-wait condition simply can't happen.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-deadlock-q1", "type": "mcq",
      "prompt": "Two threads transfer money in opposite directions between accounts A and B, each one locking the source account then the destination. What's the standard fix?",
      "options": [
        {"id":"a","text":"Use one single global lock for every transfer"},
        {"id":"b","text":"Lock the two accounts in a fixed global order — by account id, for instance — which breaks the circular-wait condition while still letting unrelated transfers run in parallel"},
        {"id":"c","text":"Make the accounts unchangeable"},
        {"id":"d","text":"Retry the transfer if it's taking too long"}
      ],
      "correct": "b",
      "explanation": "A single global lock works, but it forces every transfer in the system to wait its turn. Locking in a consistent order removes the cycle with no loss of parallelism; tryLock with a timeout plus randomised retry is the fallback when no stable ordering exists." }
] }
```

## The patterns you'll actually use

**Producer-consumer with a bounded queue.** This is the standard shape whenever requests arrive faster than they can be handled — and the "bounded" part is what gives you backpressure instead of memory growing without limit.

```python
import queue, threading

def worker(jobs: "queue.Queue", done: list, lock: threading.Lock):
    while True:
        job = jobs.get()
        if job is None:                      # a signal to shut down cleanly
            jobs.task_done()
            return
        with lock:
            done.append(job * 2)
        jobs.task_done()


jobs: "queue.Queue" = queue.Queue(maxsize=10)     # bounded → producers wait once it's full
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

**Optimistic locking (a version check).** No lock held during the operation at all: read a version number, and only allow the write if that version hasn't changed since. This is right for **low contention** — like a user editing their own profile, where clashes are rare.

```python
class VersionedRecord:
    def __init__(self, value: str):
        self.value, self.version = value, 0

    def update(self, new_value: str, expected_version: int) -> bool:
        if self.version != expected_version:
            return False                     # someone else wrote first — caller should retry
        self.value, self.version = new_value, self.version + 1
        return True


rec = VersionedRecord("draft")
v = rec.version
assert rec.update("edited by A", v) is True
assert rec.update("edited by B", v) is False     # B's outdated write gets rejected
assert rec.value == "edited by A" and rec.version == 1
print("optimistic lock rejected the stale write; value =", rec.value)
```

**Pessimistic locking.** Take the lock (or run `SELECT ... FOR UPDATE`) before you even read. This is right for **high contention** — the very last seat of a sold-out show, where optimistic retries would mostly just fail over and over.

**Reservation with a TTL.** This is the pattern behind every seat-booking flow you've ever used: hold the resource for a limited time, then either confirm it or let it expire. It avoids holding a database lock for the several minutes a real human spends typing in their card details, and it's exactly why an expiry timestamp beats a plain `is_locked` boolean — a crashed browser tab releases the seat back automatically.

**And here's the rule that matters the most in an interview**: in a **multi-process or multi-server** system, an in-process lock protects absolutely nothing. Whatever invariant you need has to be enforced wherever the actual data lives:

```
UPDATE seats SET status = 'booked', booked_by = $1
WHERE seat_id = $2 AND status = 'available';     -- 0 rows affected = someone else already won
```

A conditional `UPDATE`, or a unique constraint, is atomic across every server at once. A `threading.Lock` is atomic across exactly one process, full stop. Saying that sentence out loud is what separates a design that works on your laptop from one that survives production — and it connects directly to the fencing-token discussion in the HLD coordination lesson.

> **Remember:** in-process locks are invisible across servers. Only the database — through a conditional write or a unique constraint — actually enforces anything across all of them.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-08-patterns-q1", "type": "mcq",
      "prompt": "Your booking service runs on five separate servers. Which mechanism actually stops a seat from being double-booked?",
      "options": [
        {"id":"a","text":"A synchronized method or a threading.Lock in the booking service"},
        {"id":"b","text":"A conditional database write — `UPDATE seats SET status='booked' WHERE seat_id=? AND status='available'` — where zero affected rows tells you another server already won. An in-process lock only synchronises threads inside one single process"},
        {"id":"c","text":"Making the Seat class unchangeable"},
        {"id":"d","text":"Ordering the locks by seat id"}
      ],
      "correct": "b",
      "explanation": "In-process locks simply don't exist from the point of view of a different process. The one thing every server shares is the database, so that's where the invariant has to be enforced — through a conditional write or a unique constraint." }
] }
```

## Quick recap

```
Find the SHARED, CHANGEABLE data → stop sharing it, stop letting it change, or protect access.
Races: check-then-act · read-modify-write · publish-before-init
  Thread-safe methods do NOT add up: the whole sequence needs one lock, not each half.

Tools, cheapest first:
  Immutability — no protection needed at all. Value objects should never change.
  Atomic       — one variable, no blocking (AtomicInteger, INCR, compare-and-swap)
  Lock         — general purpose; hold briefly, never across I/O or callbacks; small > big

Deadlock = all 4 Coffman conditions at once; break circular wait with a GLOBAL LOCK ORDER (by id).
  Fallback: tryLock + timeout + randomised retry.  Livelock → backoff.  Starvation → fair locks.

Patterns:
  Producer-consumer with a BOUNDED queue (backpressure) + a shutdown signal
  Optimistic (version check + retry) → LOW contention
  Pessimistic (lock / SELECT FOR UPDATE) → HIGH contention
  Reservation with a TTL → long, human-paced flows (seat holds, checkout)

MULTI-PROCESS: an in-process lock protects nothing.
  Enforce it at the shared resource instead: conditional UPDATE ... WHERE status='available',
  or a UNIQUE constraint. Zero rows affected means you lost the race.
```

- **Say the concurrency answer before you're asked for it.** Naming the shared, changeable data and how it's protected, unprompted, is one of the highest-value moves in an LLD interview.
- **Match your locking strategy to how much contention there really is**: optimistic for rare conflicts, pessimistic for the very last seat, reservations for anything a human takes several minutes to finish.
- **Lock ordering is the deadlock answer**, and the bank-transfer example is the one worth having ready.
- **The database is the only lock that works across every server.** Every problem later in this section — seat booking, inventory, wallets — comes down to a conditional write or a unique constraint at the storage layer.
