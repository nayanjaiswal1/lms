---
kind: lesson
id_key: interview-prep-45/hld-12-coordination
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Coordination, Consensus, and Distributed Locks"
position: 12
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Nearly every system eventually needs exactly one of something: one leader accepting writes, one scheduled job actually running, one worker holding a seat, one server owning a piece of data. Getting "exactly one" right, on a network where servers crash and messages get lost or delayed, is what consensus is built for. You won't be asked to build Raft, a well-known consensus algorithm, from scratch in an interview. You do need to know what it guarantees, when you actually need it, and why the distributed lock most people write on their first try is broken.

## Leader election and what a leader is for

A **leader**, sometimes called a coordinator, primary, or master, is the one server temporarily given the right to do something exactly once: accept writes, hand out which server owns which shard, run a scheduled job, or drive a rebalance.

Electing a leader well requires three properties.

1. **Safety**: at most one leader exists at any given moment. Breaking this is called split brain, and it's exactly how systems end up with corrupted data.
2. **Liveness**: if the leader dies, a new one gets elected within a reasonable amount of time.
3. **Fencing**: once the old leader eventually comes back, it must not be able to act as leader anymore. This is the part that quick, naive implementations usually skip.

**Here's exactly why fencing is mandatory.** A leader can still be technically alive, but cut off from the network, or stuck for a while during a long garbage-collection pause, or simply stalled waiting on a slow disk. It still genuinely believes it's the leader the whole time. Meanwhile, the rest of the cluster has already elected a replacement. Now two separate servers both believe they hold the same authority.

The fix is a **steadily increasing number, called an epoch or a fencing token**, handed out along with the leadership itself. Every write carries its own token, and whatever storage receives it **rejects any token lower than the highest one it has already seen**:

```
Leader A holds epoch 7, then pauses for 30 s (GC)
Cluster elects Leader B with epoch 8; B writes with token 8 → accepted
A wakes, writes with token 7 → REJECTED (7 < 8) → A steps down
```

Without that token, A's outdated write would silently overwrite B's newer one. This is the single most valuable detail in the entire topic, and almost nobody brings it up unprompted. Picture two office managers, each convinced they're the current one, because one of them simply never saw the memo saying they'd been replaced. A numbered memo, one that clearly states "this replaces every memo before it," is the only thing that actually stops the old manager's outdated instructions from being followed by mistake.

**Heartbeats and leases.** A leader holds onto its authority through a lease it has to keep renewing every few seconds. Detecting a failure comes down to a timeout, and picking that timeout is a genuine trade-off: a short timeout catches failures quickly but can trigger a needless new election during a brief garbage-collection pause or a temporary network blip; a long timeout is more stable, but leaves the system unable to make progress for longer. Add a small amount of randomness to election timeouts, so that several candidates don't all start campaigning for leadership at exactly the same moment and split the vote between them.

> **Remember:** a paused leader cannot know it's been replaced, so it can't police itself. Only a fencing token checked at the resource itself, meaning "reject anything older than the highest epoch I've seen," actually prevents split brain.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-election-q1", "type": "mcq",
      "prompt": "A leader pauses for 30 seconds during a garbage collection cycle. The cluster elects a new leader. The old leader wakes up and tries to write. What prevents corruption?",
      "options": [
        {"id":"a","text":"The old leader notices it was replaced and stops on its own"},
        {"id":"b","text":"A fencing token: each term of leadership has a steadily increasing epoch number, and storage rejects any write carrying an epoch lower than the highest one it has already seen"},
        {"id":"c","text":"The lease timeout by itself guarantees the old leader cannot write"},
        {"id":"d","text":"The new leader locks the entire database"}
      ],
      "correct": "b",
      "explanation": "A paused server learns absolutely nothing while it's paused, so it has no way to police itself, and a lease timeout is only a promise that the paused node has already, unknowingly, broken. Only a check made right where the write actually lands, rejecting any outdated epoch, is genuinely safe." }
] }
```

## Consensus: Raft in the amount you need

Picture five friends in different cities trying to agree where the whole group will meet, over a group call where anyone's connection might drop at any moment. They need a rule that still produces one single agreed answer, even if two of them briefly lose signal. Consensus is exactly this: agreement on a value, or a whole sequence of values, among servers that can crash and whose network can drop or delay messages between them. In practice, almost every real use of consensus is really a **replicated state machine**: agree on one ordered list of commands, apply that same list in the same order everywhere, and every copy ends up in the identical state.

**Here is Raft, a specific consensus algorithm, explained in five points, which is enough to answer any system design question about it:**

1. Every server is a **follower**, a **candidate**, or **the leader**. Time is split into numbered periods called **terms**, which act as the epoch number described above.
2. A follower that hasn't heard from a leader in a while becomes a candidate and asks the others for their vote. Each server grants exactly one vote per term. **A candidate that wins a majority of votes becomes the leader.** Requiring a majority is exactly what makes it impossible for two leaders to exist in the same term.
3. Every write goes to the leader, which appends it to its own log and copies it out to the followers.
4. An entry counts as **committed** only once a majority of servers have stored it; only then is it actually applied and confirmed back to the client. A committed entry is guaranteed to survive even if a minority of servers fail.
5. A server is only allowed to vote for a candidate whose log is at least as up to date as its own, which guarantees a new leader can never be missing an entry that was already committed.

**The maths behind how many servers you need, worth being able to state instantly:**

| Servers | Majority needed | Failures it survives | Note |
|---|---|---|---|
| 3 | 2 | 1 | The common default |
| 5 | 3 | 2 | Better durability, but slower to commit |
| 7 | 4 | 3 | Rarely worth the extra delay |
| 4 | 3 | 1 | **No better than 3 servers**; always use an odd number |

**Where you'll actually run into this in real systems**: etcd and ZooKeeper (built on Raft or a similar algorithm called ZAB) sit underneath Kubernetes, service discovery, and configuration management; Kafka's own controller uses a form of Raft; CockroachDB, TiDB, and Spanner all replicate each piece of their data using Raft or Paxos; and Consul uses it for its service catalogue and its locks.

**The rule to follow in interviews is simple: use an existing, battle-tested consensus system, never build your own.** Saying "I'd store leadership information and cluster metadata in etcd, which gives me a perfectly consistent key-value store with leases and atomic compare-and-swap operations" is exactly the right depth of answer, and it also tells the interviewer you understand that consensus is expensive and belongs in a small control layer, not sitting directly in your main data path.

> **Remember:** use a battle-tested consensus system like etcd or ZooKeeper. Building your own Raft implementation is a red flag, not a strength.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-raft-q1", "type": "mcq",
      "prompt": "Why is a 5-server Raft cluster generally preferred over a 4-server one?",
      "options": [
        {"id":"a","text":"5 servers commit changes faster than 4 do"},
        {"id":"b","text":"Both need a majority of 3, so 4 servers only tolerate 1 failure while 5 tolerate 2; the fourth server adds cost and extra delay without adding any fault tolerance"},
        {"id":"c","text":"Raft strictly requires the number of servers to be a prime number"},
        {"id":"d","text":"A 4-server cluster simply cannot elect a leader at all"}
      ],
      "correct": "b",
      "explanation": "A majority of 4 servers is 3, and a majority of 5 servers is also 3, so an even-sized cluster is effectively wasting one server. This is exactly why every production consensus cluster you'll see is sized at 3, 5, or 7." }
] }
```

## Distributed locks, and why the naive one is broken

The actual requirement here is mutual exclusion across separate processes: only one worker should run this particular job, only one request should hold this particular seat.

**Here is the naive Redis lock most people write first, and its two bugs:**

```
# BROKEN in two ways
if redis.setnx("lock:job", "1"):     # bug 1: no expiry → a crashed holder locks forever
    do_work()
    redis.delete("lock:job")          # bug 2: deletes ANY holder's lock, not just mine
```

**Here is the corrected, single-instance version:**

```
token = str(uuid.uuid4())
# Atomic acquire with an expiry: NX = only if absent, EX = auto-release on crash.
if redis.set("lock:job", token, nx=True, ex=30):
    try:
        do_work()
    finally:
        # Release only if we still hold it — compare-and-delete, atomically, in Lua.
        redis.eval(
            "if redis.call('get', KEYS[1]) == ARGV[1] "
            "then return redis.call('del', KEYS[1]) else return 0 end",
            1, "lock:job", token,
        )
```

Both fixes matter for a distinct reason: the **expiry** means a worker that crashes while holding the lock can't leave the whole system permanently deadlocked, and the **matching token before deleting** means a slow worker whose lock has already expired can't accidentally delete the lock a completely different worker is now legitimately holding.

**There is still one problem left here that cannot be fixed.** Suppose the actual work takes longer than the lock's expiry time, because of a garbage-collection pause, a slow disk, or a stalled network call. The lock expires, a second worker picks it up, and now **two workers are running the same protected section of code at the same time**. No amount of clever Redis engineering removes this, because the original lock holder has no way of knowing it's already been evicted.

So the rule to follow is:

- **For efficiency**, meaning you just want to avoid doing the same work twice, and a duplicate is merely wasteful, a Redis lock is perfectly fine.
- **For correctness**, meaning a duplicate would actually corrupt data or charge someone twice, a lock alone is **not** enough. You need a fencing token checked right at the resource itself, or you need to make the protected operation itself safe to repeat, or you need the resource to enforce the rule directly, such as a unique constraint or a conditional update like `UPDATE ... WHERE version = ?`.

Redlock, a multi-server version of this same Redis locking idea, is controversial precisely because it doesn't solve this pause problem either; the exact same argument applies to it. When you genuinely need correctness under contention, **push the actual rule you need enforced into a system built to enforce it**: a database's unique constraint, a conditional update, or a lease from a consensus store like etcd or ZooKeeper, which hands out steadily increasing revision numbers you can fence against.

> **Remember:** a Redis lock stops most double-work, but a paused worker can still outlive its own expiry time. Use a lock for efficiency; use a database constraint for correctness.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-lock-q1", "type": "mcq",
      "prompt": "A worker holds a 30-second Redis lock, then stalls unexpectedly for 40 seconds. A second worker acquires the lock and starts running. What is the correct conclusion?",
      "options": [
        {"id":"a","text":"Use a much longer expiry time; setting it to 5 minutes will make this impossible"},
        {"id":"b","text":"A lock based on an expiry time cannot guarantee mutual exclusion, because the original holder has no way of knowing it was evicted. For correctness, enforce the actual rule at the resource itself, such as with a fencing token, a unique constraint, or a conditional update, rather than relying on the lock alone"},
        {"id":"c","text":"Use Redlock across five separate Redis servers, which removes the problem entirely"},
        {"id":"d","text":"Remove the expiry time entirely, so the lock never expires"}
      ],
      "correct": "b",
      "explanation": "Any expiry time, no matter how generous, can still be exceeded by an unexpected pause, and removing the expiry entirely just trades this failure for a lock that deadlocks forever if a worker crashes. Redlock doesn't solve the pause problem either. A lock is an optimisation; real correctness has to live at the resource itself." }
] }
```

## Coordination in practice: what to actually use

Most systems need far less coordination than people first assume. **The cheapest form of coordination is none at all:**

| Instead of coordinating | Do this |
|---|---|
| A lock so only one worker processes an item | **Partition** the work by key, so only one specific worker ever owns that particular key |
| A lock to prevent processing something twice | Make the operation itself **safe to repeat**, and let duplicates be harmless |
| A single global counter | Keep a separate counter per server and add them up when you read, or use a probabilistic structure built for counting |
| A lock around a read-then-write sequence | A single **atomic or conditional statement** run directly by the database |
| A distributed lock for "run this scheduled job exactly once" | A **lease** held in etcd, or an insert with a unique key on the job's name and its scheduled time that simply does nothing if it already exists |

That last row is genuinely worth remembering: a scheduled job protected by a unique constraint on its name and its run time gives you exactly-once scheduling, using nothing more than the database you're already running.

**Here is where a real, dedicated coordination service is actually the right answer:**

- Keeping track of which servers exist, and shared configuration (using etcd, ZooKeeper, or Consul)
- Electing a leader for a control layer
- Assigning and rebalancing which server owns which shard or partition
- Service discovery, and knowing which servers are currently healthy
- Feature flags and configuration that needs to notify listeners the moment it changes

**Demand two properties from any of these tools**: leases that expire automatically, so a client that dies quietly releases its claim, and a way to atomically compare-and-swap using revision numbers, so you can build fencing on top of it.

**One last warning, about time itself. Never coordinate using wall-clock time.** Clocks on different machines drift apart from each other by at least a few milliseconds even with time-syncing services running, they can occasionally jump backward, and a virtual machine can simply pause for a while. Use **monotonic clocks** for measuring how much time has actually elapsed, **logical clocks**, like Lamport timestamps or vector clocks, for figuring out which event happened before another, and consensus-issued revision numbers for fencing. Google Spanner's TrueTime, which needs actual GPS receivers and atomic clocks just to bound how uncertain its own clock might be, and then deliberately *waits out* that uncertainty on every single commit, is an honest measure of just how hard perfectly ordered global time really is to achieve.

> **Remember:** the cheapest coordination is none. Partition the work so only one worker ever sees a given key, and most locks disappear on their own.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-12-practice-q1", "type": "mcq",
      "prompt": "You must guarantee a nightly job runs exactly once, across 10 identical application instances. Which is the simplest mechanism that actually works?",
      "options": [
        {"id":"a","text":"A Redis lock with a 1-hour expiry time"},
        {"id":"b","text":"A unique constraint on the job's name and its scheduled time, combined with an insert that does nothing if a matching row already exists; whichever instance's insert succeeds is the one that runs the job, using only the database you already run"},
        {"id":"c","text":"Designate instance number 1 as the runner directly in configuration"},
        {"id":"d","text":"Have every single instance run it, and remove the duplicates afterward"}
      ],
      "correct": "b",
      "explanation": "A database's own unique index gives you an atomic, durable way to guarantee only one winner, which is exactly what \"exactly once\" actually needs, without introducing any extra system at all. A hardcoded instance has no failover if it goes down, and an expiry-based lock has both the eviction problem described above and one more system to depend on." }
] }
```

## Quick recap

```
Need exactly one of something? → leader election, and FENCING is not optional.
  Fencing token = monotonically increasing epoch, checked and rejected AT THE RESOURCE.
  A paused (GC'd) leader cannot police itself — only the resource can.

Raft: terms · majority vote · leader-only writes · commit on majority · up-to-date-log rule
  Cluster sizes: 3 (tolerate 1) · 5 (tolerate 2) · always ODD
  Use etcd / ZooKeeper / Consul. Do not implement consensus.

Distributed lock (Redis): SET key token NX EX ttl  +  Lua compare-and-delete on release
  Locks give EFFICIENCY, never CORRECTNESS — a pause can exceed any TTL.
  Correctness lives at the resource: unique constraint · conditional UPDATE · fencing token

Cheapest coordination is none: partition the work · make it idempotent · one atomic statement
Time: monotonic clocks for elapsed, logical clocks for order, never wall clocks for ordering.
```
