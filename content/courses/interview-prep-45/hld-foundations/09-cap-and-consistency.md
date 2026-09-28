---
kind: lesson
id_key: interview-prep-45/hld-09-cap-consistency
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "CAP, PACELC, and Levels of Consistency"
position: 9
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

CAP is probably the most repeated, and least understood, idea in system design. People often say "we'll just pick AP" as if it were a simple setting to flip on, then quietly go on to design something that actually needs perfectly up-to-date data everywhere. This lesson makes the theorem precise, adds a second idea called PACELC that describes your system almost all of the time, and gives you the actual list of consistency levels to choose from.

## What CAP actually says

Picture two branches of the same bank, in two different cities, whose phone line to each other has just gone dead. A customer walks into Branch A and withdraws the last 500 rupees from a shared account. At the very same moment, someone tries to withdraw from Branch B, which has no way to check with Branch A right now. Branch B has two choices. It can refuse the withdrawal until the phone line comes back, which is safe but turns the customer away. Or it can allow it anyway, risking paying out money that no longer exists. That exact choice is what CAP is about.

**The theorem says this:** when a **network partition** happens, meaning two parts of a distributed system can no longer talk to each other, that system must choose between staying **consistent** and staying **available**. It cannot have both at the same time.

Let's be precise about each word.

- **C, for Consistency**, here specifically means linearizability: every read returns the most recently completed write, as if there were only one single copy of the data anywhere. This is a different meaning from the "C" in ACID, covered in the previous lesson.
- **A, for Availability**, means every server that hasn't actually failed still returns a real answer, not an error.
- **P, for Partition tolerance**, means the system keeps working even when messages between its own servers get lost or delayed.

Here's the important correction most people miss: **P isn't something you get to choose.** Networks partition in real life: cables get cut, network switches reboot, a link between data centers gets overloaded. Any system spread across more than one machine has to deal with partitions sooner or later, so the only real decision is what to do *while* one is happening.

- **CP** means refusing to answer rather than risking a stale or wrong answer. Whichever side of the split is in the minority returns errors instead of guessing. Choose this for money, inventory counts, unique constraints, and locks.
- **AP** means both sides keep answering, accepting that they might now disagree, and sorting it out once they can talk again. Choose this for feeds, like counts, "who's online" indicators, product catalogues, and DNS.

"CA," meaning consistent and available with no partition tolerance at all, isn't a meaningful category for a system spread across multiple machines. A database running on a single machine is trivially "CA" simply because it has no other machine to lose contact with in the first place.

Two more points that score well in an interview.

**This choice is made per operation, not once for the whole system.** The very same online shop can be CP for "place the order and reduce stock" while being AP for "show the product page and its review count." Saying this out loud is one of the single highest-value sentences in this whole topic.

**The choice only actually applies while a partition is happening.** The rest of the time, which is nearly all of the time, you're making a completely different trade-off, which is exactly what PACELC, covered next, describes.

> **Remember:** during a partition you pick consistency (refuse rather than risk a wrong answer) or availability (answer anyway, and fix it up later). Networks partition whether you plan for it or not.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-cap-q1", "type": "mcq",
      "prompt": "Why is \"we'll build a CA system\" not a meaningful answer for a distributed database?",
      "options": [
        {"id":"a","text":"Because consistency and availability are actually the same property"},
        {"id":"b","text":"Because partitions are a fact of how networks behave, not something you can opt out of; any system spread across multiple machines must deal with them, so the only real choice is what to do during one: stay consistent (CP) or stay available (AP)"},
        {"id":"c","text":"Because CA systems are simply too slow to be practical"},
        {"id":"d","text":"Because CAP theory only applies to NoSQL databases"}
      ],
      "correct": "b",
      "explanation": "Partition tolerance isn't a design choice; it's forced on you by physical networks. Only a system running on a single machine escapes this, and it only escapes by not being distributed at all, which comes with its own cost to availability." }
] }
```

## PACELC: the trade-off you make every day

CAP only describes what happens in the rare moment a partition occurs. **PACELC** describes both that rare moment and every single ordinary day:

> **If** there is a **P**artition, choose **A**vailability or **C**onsistency. **E**lse, during normal operation, choose **L**atency or **C**onsistency.

That second half, the "else," is the part quietly governing your system's response times every single day. Getting perfectly up-to-date data across several replicas requires coordination between them, such as waiting for a quorum of servers to agree, or waiting on the one designated leader, and that coordination always costs time. Accepting slightly less-fresh data buys that time back.

| System | How it's classified | What that means |
|---|---|---|
| Postgres / MySQL with one main server | Consistent during a partition, consistent normally | Chooses correctness both during and outside a partition |
| DynamoDB, with its default reads | Available during a partition, fast normally | Chooses speed and availability both during and outside a partition |
| DynamoDB, with strongly-consistent reads turned on | Consistent during a partition, consistent normally | You can opt into stronger guarantees per request; this makes the "per operation, not per system" point very concrete |
| Cassandra, tunable | Available during a partition, fast normally, by default | Asking for `QUORUM` reads and writes shifts it toward the consistent side |
| MongoDB, with majority write concern | Consistent during a partition, consistent normally | Configurable per operation |
| DNS | Available during a partition, fast normally | Extremely available, and often quite stale |

A strong sentence to use in an interview: **"Even when the network is completely healthy, staying perfectly consistent still costs a round trip of coordination. So I'm only using strong reads for the account balance check, and accepting slightly stale reads for the transaction history."**

> **Remember:** CAP only describes the rare moment the network breaks. PACELC's second half describes every normal day: stronger consistency always costs latency.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-pacelc-q1", "type": "mcq",
      "prompt": "What does the second half of PACELC describe that CAP leaves out entirely?",
      "options": [
        {"id":"a","text":"How the system behaves during a network partition"},
        {"id":"b","text":"That even during ordinary, non-partitioned operation there is still a trade-off between speed and consistency, because staying perfectly consistent requires coordination between servers"},
        {"id":"c","text":"How data is encrypted while stored on disk"},
        {"id":"d","text":"How many replicas a system needs"}
      ],
      "correct": "b",
      "explanation": "CAP only has something to say about the rare, partitioned case. PACELC's real contribution is naming the everyday cost: staying consistent is paid for in extra response time, whether or not the network is actually broken." }
] }
```

## The consistency ladder

Consistency isn't a single switch you flip on or off. It's a ladder of levels, and you should pick the weakest one that still meets your actual requirement, because every rung higher costs you extra time or availability.

| Level | What it guarantees | What it costs | Use it for |
|---|---|---|---|
| **Linearizable (strong)** | Every read sees the latest confirmed write, as if there's only one copy anywhere | Coordination on every single operation; can become unavailable on the smaller side of a partition | Locks, uniqueness checks, account balances, seat allocation |
| **Sequential** | Every server sees operations happen in the same order, though not necessarily in real time | High | Systems that replicate a state machine across servers |
| **Causal** | Operations that are actually related to each other are seen in that same order by everyone | Moderate; requires tracking cause and effect using something like vector clocks | Comment threads, chat message ordering |
| **See your own writes** | A user always sees the effect of their own recent action | Cheap; briefly route that one user's reads to the leader | Posting something, then viewing it right after; editing a profile |
| **Never see time go backwards** (monotonic reads) | A user's reads never appear to move backward in time | Cheap; pin that one user's session to one replica | Any view that refreshes or pages through results |
| **Eventual** | Replicas will agree, eventually, once writes stop coming in | Cheapest, and stays available the whole time | Like counts, view counts, feeds, catalogues, DNS |

The two cheap guarantees in the middle, "see your own writes" and "never see time go backwards," deserve special attention, because they fix the exact symptoms users actually notice from eventual consistency, without paying the full cost of true linearizability.

- **See your own writes**: right after posting, read from the leader itself, or from a replica confirmed to have caught up, for the next few seconds.
- **Never see time go backwards**: keep a session pinned to one single replica, so a page refresh can never land on a more out-of-date replica and make something that was there a moment ago disappear.

Together, these two cover most of what users actually complain about, which is why "eventual consistency, plus these two cheap guarantees" is such a common answer in real production systems.

> **Remember:** pick the weakest consistency level that still meets the requirement. Every step stronger costs latency or availability, so don't pay for more than you need.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-ladder-q1", "type": "mcq",
      "prompt": "Users complain that refreshing a page sometimes makes a comment they just loaded disappear, and then reappear later. Which guarantee fixes this most cheaply?",
      "options": [
        {"id":"a","text":"Making every single read linearizable"},
        {"id":"b","text":"Never seeing time go backwards: pin that user's session to one replica, so consecutive reads never move backward through the replication log"},
        {"id":"c","text":"The strictest transaction isolation level"},
        {"id":"d","text":"Coordinating every write across all replicas before confirming it"}
      ],
      "correct": "b",
      "explanation": "The symptom here is reads bouncing between replicas that are at different points in catching up. Pinning a session to one replica costs almost nothing and removes that time-travel effect entirely, without paying for coordination across the whole system." }
] }
```

## Quorums and conflict resolution

Picture a jury of 5 people. A verdict only counts once at least 3 of them agree; that's a majority. A quorum works the same way for replicas: as long as enough copies of the data agree, you can trust the answer, even if some copies are currently unreachable.

**Quorum arithmetic is how leaderless stores, like Dynamo and Cassandra, let you dial consistency up or down for each individual request.** With `N` total replicas, `W` of them required to confirm a write, and `R` of them consulted on a read:

> **If `W + R` is greater than `N`, the group of replicas you write to and the group you read from are guaranteed to overlap**, so a read is guaranteed to see the latest confirmed write.

| Setting | What happens |
|---|---|
| N=3, W=3, R=1 | Fast reads, slow writes, and no writes at all can succeed if even one replica is down |
| N=3, W=1, R=1 | Fastest possible, but W+R is not greater than N, so this is only **eventually consistent** |
| **N=3, W=2, R=2** | The balanced default: overlap is guaranteed, and it tolerates one server being down for both reads and writes |
| N=3, W=2, R=1 | Fast reads, but no overlap is guaranteed, so a read might return a stale value |

Cassandra exposes exactly this idea as settings called `ONE`, `QUORUM`, and `ALL` on each query, plus a `LOCAL_QUORUM` option that keeps the quorum within one data center, useful across regions.

Two mechanisms keep replicas converging back toward agreement over time. **Read repair** happens when a read notices replicas disagree and writes the newest value back to the ones that were behind. **Anti-entropy** is a background process that compares a compact summary (called a Merkle tree) of each range of keys across replicas and syncs up any differences it finds. **Hinted handoff** covers short outages: if a server is briefly down, another server holds onto the writes meant for it and delivers them once it's back.

**When two replicas genuinely disagree, something has to decide which value wins:**

| Strategy | How it works | Cost |
|---|---|---|
| **Last-write-wins** | Whichever value has the newest timestamp wins | Simple, but it **silently throws away** the other value, and clocks on different machines aren't perfectly in sync, so "newest" isn't always reliable |
| **Vector clocks / version vectors** | Detects that two versions happened at the same time and hands both to the application | Correctly detects the conflict, but someone still has to write the code that merges the two |
| **CRDTs** | Special data types, like certain counters, sets, and sequences, that merge cleanly by design | No conflict is even possible, but only certain kinds of data can be expressed this way |
| **Application-level merge** | Your own business logic decides, such as combining both versions of a shopping cart | Usually the best outcome for the user, but also the most work to build |

The classic example is Amazon's own shopping cart. Last-write-wins would quietly drop an item a user added from their phone if a different update landed after it. Merging the two carts together instead keeps both items; the worst case is a deleted item reappearing, which Amazon decided was a far better trade-off than losing a sale.

**One warning about clocks.** The clocks on different machines are not reliably in sync with each other; even with time-syncing services, the drift can be milliseconds, and clocks can occasionally jump forward or backward. Use logical clocks, like Lamport timestamps or vector clocks, to determine which event happened before another. Google's Spanner achieves perfectly consistent transactions across the whole globe only by using GPS and atomic clocks to measure exactly how uncertain its own clock might be, and then deliberately waiting out that uncertainty before confirming each commit. That's a real measure of just how expensive true global consistency actually is.

> **Remember:** `W + R > N` guarantees a read overlaps with the latest write. Conflict resolution is as much a product decision as a technical one: last-write-wins quietly deletes data, and that might not be acceptable.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-quorum-q1", "type": "mcq",
      "prompt": "With N=5 replicas, which (W, R) pair guarantees a read sees the latest confirmed write while still tolerating two servers being down?",
      "options": [
        {"id":"a","text":"W=1, R=1"},
        {"id":"b","text":"W=3, R=3, since W+R=6 is greater than 5, so the two groups must overlap, and each group of 3 is still reachable with 2 of 5 servers down"},
        {"id":"c","text":"W=5, R=1"},
        {"id":"d","text":"W=2, R=2"}
      ],
      "correct": "b",
      "explanation": "Guaranteed overlap needs W+R greater than N: 3+3=6, which is greater than 5. Requiring 3 out of 5 still succeeds even with two servers unavailable, while W=5 needs every single server alive, and W=R=2 gives 4, which is not greater than 5, so there's no overlap guarantee at all." }
] }
```

## Quick recap

```
CAP: during a PARTITION, choose C or A. P is not optional. "CA" isn't a distributed system.
     CP = refuse rather than diverge (money, inventory, locks)
     AP = serve and reconcile (feeds, likes, presence, catalogue)
     → the choice is PER OPERATION, not per system
PACELC: if Partition → A or C;  Else → Latency or Consistency  (the everyday trade-off)
CAP's C = linearizability ≠ ACID's C = constraint validity

Ladder (weakest that works wins):
  eventual < monotonic reads < read-your-own-writes < causal < sequential < linearizable
  The two cheap session guarantees fix most user-visible symptoms.

Quorum: W + R > N ⇒ overlap ⇒ read sees latest.  N=3,W=2,R=2 is the default.
Repair: read repair · anti-entropy (Merkle trees) · hinted handoff
Conflicts: LWW (lossy) · vector clocks (detect) · CRDTs (merge by design) · app merge
Clocks: wall-clock ordering across machines is unreliable — use logical clocks.
```
