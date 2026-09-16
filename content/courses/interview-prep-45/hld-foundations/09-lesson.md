---
kind: lesson
id_key: interview-prep-45/hld-09-cap-consistency
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "CAP, PACELC, and Consistency Models"
position: 9
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

CAP is the most quoted and least understood idea in system design. Candidates say "we'll pick AP" as if it were a configuration setting, then design something that quietly requires linearizability. This lesson makes the theorem precise, extends it with PACELC (which describes your system 99.9% of the time), and gives you the consistency ladder you actually choose from.

## What CAP actually says

**The theorem:** when a **network partition** occurs, a distributed system must choose between **consistency** and **availability**. It cannot have both.

Precisely:

- **C — Consistency** here means *linearizability*: every read sees the most recent completed write, as if there were one copy. This is **not** the C in ACID.
- **A — Availability** means every non-failing node returns a non-error response.
- **P — Partition tolerance** means the system keeps operating when messages between nodes are lost or delayed.

The crucial correction: **P is not a choice.** Networks partition — cables get cut, switches reboot, a datacenter link saturates. Any system spanning more than one machine must tolerate partitions, so the real question is only what to do *during* one:

- **CP** — refuse to serve rather than serve possibly-stale or divergent data. The minority side of the partition returns errors. Choose for money, inventory, unique constraints, locks.
- **AP** — keep serving on both sides, accept divergence, reconcile afterwards. Choose for feeds, likes, presence, product catalogues, DNS.

"CA" is not a meaningful category for a distributed system. A single-node database is trivially CA and simply has no partitions to tolerate.

Two more things that score:

- **It is a per-operation choice, not a per-system one.** The same e-commerce system can be CP for "place order / decrement stock" and AP for "show product page and review count". Saying this is one of the highest-yield sentences in the whole topic.
- **The choice only binds during a partition.** The rest of the time — which is nearly all of the time — you are making a different trade-off entirely, which is what PACELC describes.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-cap-q1", "type": "mcq",
      "prompt": "Why is \"we'll build a CA system\" not a meaningful answer for a distributed database?",
      "options": [
        {"id":"a","text":"Because consistency and availability are the same property"},
        {"id":"b","text":"Because partitions are a fact of networks, not an option — any multi-node system must tolerate them, so the only real choice is what to do during one: stay consistent (CP) or stay available (AP)"},
        {"id":"c","text":"Because CA systems are too slow"},
        {"id":"d","text":"Because CAP only applies to NoSQL databases"}
      ],
      "correct": "b",
      "explanation": "P is imposed by physics and operations, not chosen. Only a single-node system escapes it — and it escapes by not being distributed, which costs you availability in a different way." }
] }
```

## PACELC: the trade-off you make every day

CAP describes the rare case. **PACELC** describes both:

> **If** there is a **P**artition, choose **A**vailability or **C**onsistency; **E**lse (normal operation), choose **L**atency or **C**onsistency.

The "else" half is the one that governs your p99 every single day. Strong consistency across replicas requires coordination — a quorum round trip, or a wait for the leader — and coordination costs latency. Weakening consistency buys latency back.

| System | Classification | Reading |
|---|---|---|
| Postgres / MySQL (single primary) | PC/EC | Consistent during partitions, consistent normally |
| DynamoDB (default eventually-consistent reads) | PA/EL | Available during partitions, low latency normally |
| DynamoDB (strongly-consistent read flag) | PC/EC | Per-request opt-in — the point about per-operation choice, made concrete |
| Cassandra (tunable) | PA/EL by default | `QUORUM` reads/writes move it toward PC/EC |
| MongoDB (majority write concern) | PC/EC | Configurable per operation |
| DNS | PA/EL | Extremely available, extremely stale |

The sentence to deploy in an interview: **"Even when the network is healthy, strong consistency costs a coordination round trip — so I'm using strong reads only for the balance check and eventual reads for the transaction history."**

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-pacelc-q1", "type": "mcq",
      "prompt": "What does the \"ELC\" half of PACELC describe that CAP omits?",
      "options": [
        {"id":"a","text":"How the system behaves during a partition"},
        {"id":"b","text":"That in normal (non-partitioned) operation there is still a trade-off between latency and consistency, because strong consistency requires coordination round trips"},
        {"id":"c","text":"How data is encrypted at rest"},
        {"id":"d","text":"How many replicas are required"}
      ],
      "correct": "b",
      "explanation": "CAP only says anything about the partitioned case, which is rare. PACELC's contribution is naming the everyday cost: consistency is paid for in latency whether or not the network is broken." }
] }
```

## The consistency ladder

Not a binary — a spectrum. Pick the weakest level that satisfies the requirement, because each step up costs latency and availability.

| Level | Guarantee | Cost | Use for |
|---|---|---|---|
| **Linearizable (strong)** | Reads see the latest committed write; system behaves as one copy | Coordination on every op; unavailable in a partition minority | Locks, uniqueness, balances, seat allocation |
| **Sequential** | All nodes see operations in the same order (not necessarily real-time) | High | Replicated state machines |
| **Causal** | Operations that are causally related are seen in order by everyone | Moderate — track causality (vector clocks) | Comment threads, chat message ordering |
| **Read-your-own-writes** | A user always sees their own writes | Cheap — route that user to the leader briefly | Post-then-view, profile edits |
| **Monotonic reads** | You never see time go backwards | Cheap — pin a user to one replica | Any paginated/refreshing view |
| **Eventual** | Replicas converge if writes stop | Cheapest, always available | Likes, view counts, feeds, catalogues, DNS |

The two cheap "session guarantees" in the middle deserve special attention, because they fix the *user-visible* symptoms of eventual consistency without paying for linearizability:

- **Read-your-own-writes**: after posting, read from the leader (or from a replica confirmed to have caught up) for the next few seconds.
- **Monotonic reads**: pin a session to one replica so a refresh cannot land on a more-lagged node and make a comment disappear.

Together they cover most of what users actually notice, which is why "eventual consistency plus session guarantees" is such a common production answer.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-ladder-q1", "type": "mcq",
      "prompt": "Users complain that refreshing a page sometimes makes a just-loaded comment disappear and reappear. Which guarantee fixes this most cheaply?",
      "options": [
        {"id":"a","text":"Linearizability for all reads"},
        {"id":"b","text":"Monotonic reads — pin the session to one replica so successive reads never move backwards in the replication log"},
        {"id":"c","text":"Serializable transaction isolation"},
        {"id":"d","text":"Two-phase commit across replicas"}
      ],
      "correct": "b",
      "explanation": "The symptom is reads bouncing between replicas at different lag positions. Session stickiness to one replica costs essentially nothing and removes the time-travel effect, without paying for global coordination." }
] }
```

## Quorums and conflict resolution

**Quorum arithmetic** is how leaderless stores (Dynamo, Cassandra) let you dial consistency per request. With `N` replicas, `W` acknowledgements required on write, and `R` on read:

> **If `W + R > N`, the read set and write set must overlap**, so a read is guaranteed to see the latest acknowledged write.

| Setting | Behaviour |
|---|---|
| N=3, W=3, R=1 | Fast reads, slow writes, no write availability if any replica is down |
| N=3, W=1, R=1 | Fastest, W+R ≤ N → **eventually consistent** |
| **N=3, W=2, R=2** | The balanced default: overlap guaranteed, tolerates one node down for both reads and writes |
| N=3, W=2, R=1 | Fast reads, no overlap guarantee — may read stale |

Cassandra exposes exactly this as `ONE` / `QUORUM` / `ALL` per query, and `LOCAL_QUORUM` per datacenter for multi-region.

Two repair mechanisms keep replicas converging: **read repair** (a read that finds divergent replicas writes the newest value back) and **anti-entropy** (a background process comparing Merkle trees of key ranges and syncing the differences). **Hinted handoff** covers short outages: a coordinator holds writes destined for a down node and replays them when it returns.

**When two replicas disagree, something must decide:**

| Strategy | How it works | Cost |
|---|---|---|
| **Last-write-wins** | Highest timestamp wins | Simple; **silently discards** the loser, and clock skew makes "latest" unreliable |
| **Vector clocks / version vectors** | Detect concurrent versions and hand both to the application | Correct detection; someone must write the merge |
| **CRDTs** | Data types that merge deterministically by construction (counters, sets, sequences) | No conflicts possible; limited to types that can be expressed this way |
| **Application merge** | Domain logic decides (e.g. union both shopping carts) | Best user outcome; the most work |

The canonical illustration is Amazon's shopping cart: LWW would drop an item a user added on their phone; the union merge keeps both, and the worst case is a deleted item reappearing — which Amazon judged better than losing a sale.

**Clocks deserve one warning.** Wall-clock timestamps across machines are not ordered — NTP skew is milliseconds at best, and clocks jump. Use **logical clocks** (Lamport timestamps, vector clocks) for causality. Google's Spanner achieves linearizable global transactions only by using GPS and atomic clocks to bound uncertainty (TrueTime) and *waiting out* that uncertainty on commit — which is precisely how expensive real global consistency is.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-09-quorum-q1", "type": "mcq",
      "prompt": "With N=5 replicas, which (W, R) pair guarantees a read sees the latest acknowledged write while tolerating two nodes being down?",
      "options": [
        {"id":"a","text":"W=1, R=1"},
        {"id":"b","text":"W=3, R=3 — W+R=6 > 5 so the sets overlap, and each quorum of 3 is reachable with 2 of 5 nodes down"},
        {"id":"c","text":"W=5, R=1"},
        {"id":"d","text":"W=2, R=2"}
      ],
      "correct": "b",
      "explanation": "Overlap requires W+R > N: 3+3=6 > 5. Requiring 3 of 5 still succeeds with two nodes unavailable, whereas W=5 needs every node alive and W=R=2 (4 ≤ 5) gives no overlap guarantee." }
] }
```

## Key takeaways

**The recall card:**

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

- **Never say "we'll be AP" about a whole system.** Say which operations are CP and which are AP, and why. That single move separates a memorised answer from an engineered one.
- **PACELC is the more useful model** because partitions are rare and coordination latency is constant.
- **Pick the weakest consistency that meets the requirement**, then add the cheap session guarantees on top — that is what production systems actually do.
- **Conflict resolution is a product decision**, not just a technical one: LWW quietly loses data, and whether that is acceptable depends on whether the data is a like count or a shopping cart.
