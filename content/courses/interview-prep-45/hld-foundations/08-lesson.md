---
kind: lesson
id_key: interview-prep-45/hld-08-replication-sharding
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Databases II — Replication, Partitioning, and Sharding"
position: 8
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

One database eventually runs out of something: reads, writes, storage, or availability. There are exactly three moves, and they solve different problems — replication scales **reads** and buys **availability**, partitioning scales **storage and writes**, and the two are almost always used together. Confusing which problem you are solving is the most common mistake in this part of an interview.

## Replication: copies for reads and for survival

**Leader–follower (primary–replica).** All writes go to one leader; followers stream the leader's change log and serve reads.

```
                 ┌──▶ Replica 1 (reads)
Writes ──▶ Leader├──▶ Replica 2 (reads)
                 └──▶ Replica 3 (reads, standby for promotion)
```

- Scales reads linearly with replicas; scales writes **not at all**.
- Buys availability: promote a replica when the leader dies.
- Introduces **replication lag** — the gap between the leader's commit and a follower's apply. Milliseconds normally, seconds under load, minutes during a large batch job.

**Synchronous vs asynchronous** is the durability/latency knob:

| | Async | Sync | Semi-sync (quorum) |
|---|---|---|---|
| Leader waits for | Nothing | All replicas | k of n replicas |
| Write latency | Lowest | Highest | Middle |
| Data loss on leader crash | **Possible** | None | None (if k ≥ 1 survives) |
| Availability | Highest | A slow replica stalls all writes | Tolerates n−k slow/dead replicas |

Semi-synchronous — "wait for one replica to acknowledge, then return" — is the pragmatic default: bounded data loss with a bounded latency cost.

**Multi-leader** (writes accepted in several regions) removes the cross-region write latency and keeps working during a partition, at the price of **write conflicts** you must resolve: last-write-wins (simple, silently loses data), application-defined merge, or CRDTs (conflict-free by construction, the right answer for collaborative editing).

**Leaderless** (Dynamo, Cassandra): the client writes to several nodes and reads from several nodes, and quorum arithmetic gives you the consistency you need — covered in the next lesson.

**Failover is where the hard questions live.** Promoting a replica means: detecting the failure without being fooled by a network blip, choosing the most up-to-date follower, redirecting clients (DNS, a proxy, or a virtual IP), and preventing **split brain** — the old leader coming back and accepting writes. Split brain is prevented by fencing: a monotonically increasing epoch/term number that storage and clients reject if it is stale.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-replication-q1", "type": "mcq",
      "prompt": "A user posts a comment and is immediately redirected to a page that reads from a replica — their comment is missing. What is happening and what is the standard fix?",
      "options": [
        {"id":"a","text":"A cache stampede; add a lock around the read"},
        {"id":"b","text":"Replication lag breaking read-your-own-writes; route a user's reads to the leader (or to a replica known to have caught up) for a short window after they write"},
        {"id":"c","text":"A lost update; use SELECT FOR UPDATE"},
        {"id":"d","text":"A phantom read; raise the isolation level to Serializable"}
      ],
      "correct": "b",
      "explanation": "Async replication means a follower can be behind. Read-your-own-writes is restored by pinning that user's reads to the leader briefly, or by passing the write's log position and waiting for a replica to reach it." }
] }
```

## Partitioning: splitting the data itself

Partitioning (sharding) splits one logical dataset across many nodes so that each holds a slice. This is what scales **writes** and **storage** — the thing replication cannot do.

**Vertical partitioning** splits by column or by feature: the users table on one cluster, the analytics events on another. It is really "split the service", and it is often the correct first move because it needs no application rewrite of query routing.

**Horizontal partitioning** splits by row, and the choice is the **partition key**:

| Strategy | How | Good | Bad |
|---|---|---|---|
| **Range** | `A–F`, `G–M`, … or by date | Range scans stay on one shard | Hot spots: today's date shard takes all writes |
| **Hash** | `hash(key) % N` | Even distribution | Range scans hit every shard; resharding moves nearly everything |
| **Consistent hashing** | Keys and nodes on a ring, virtual nodes | Adding a node moves only ~1/N of keys | More machinery; still needs virtual nodes to be even |
| **Directory / lookup** | A service maps key → shard | Total flexibility, easy rebalancing | The directory is a dependency and a potential SPOF |
| **Geographic** | By region | Latency and data residency | Cross-region queries are expensive |

**Why `hash(key) % N` is a trap**: change N from 4 to 5 and almost every key moves. Consistent hashing exists to make adding a node move ~1/N of the keys instead of ~all of them — the section's dedicated *Notes: Consistent Hashing* lesson works through the ring, virtual nodes, and the replication walk in detail.

**Choosing the partition key is the decision that matters.** Three tests:

1. **High cardinality** — enough distinct values to spread across shards. `country` is a bad key (India is one shard); `user_id` is a good one.
2. **Even access** — no single value takes a large share of traffic. `celebrity_user_id` breaks this, which is why celebrity handling is a recurring design theme.
3. **Query alignment** — your most common query should be answerable from one shard. If you shard tweets by `tweet_id` but always query by `author_id`, every read becomes a scatter-gather across all shards.

**What sharding costs** — say these out loud, because they are the reason not to shard prematurely:

- **No cross-shard joins.** You denormalise, or you join in the application, or you keep a small reference table replicated everywhere.
- **No cross-shard transactions** without two-phase commit or a saga (next lessons).
- **Scatter-gather queries** are as slow as the slowest shard, and their tail latency is dramatically worse than a single node's.
- **Global uniqueness and ordering** need help: Snowflake-style IDs (timestamp + machine + sequence) or a UUIDv7, not an auto-increment column.
- **Rebalancing** is a long, careful operation: double-write to old and new, backfill, verify, cut reads over, stop the old write.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-partition-q1", "type": "mcq",
      "prompt": "You shard an orders table by `order_id` hash, but 90% of queries are \"all orders for customer X\". What goes wrong?",
      "options": [
        {"id":"a","text":"Nothing — hash partitioning distributes evenly, which is all that matters"},
        {"id":"b","text":"Every common query becomes a scatter-gather across all shards, so latency tracks the slowest shard and throughput collapses — the key should align with the dominant access pattern (customer_id)"},
        {"id":"c","text":"Orders lose their uniqueness guarantee"},
        {"id":"d","text":"Replication lag increases"}
      ],
      "correct": "b",
      "explanation": "Even distribution is only half the requirement; the other half is that your dominant query should be answerable from one shard. Sharding by customer_id keeps a customer's orders together, at the cost of a hot shard for a very large customer." }
] }
```

## Hot spots, celebrities, and skew

Perfect hashing still produces hot shards, because **traffic is not uniform even when keys are**. Every real system has a celebrity, a viral product, a Black Friday SKU, or a `tenant_id` that is 40% of your database.

Fixes, in the order you should offer them:

1. **Cache the hot key in front of the shard.** The cheapest fix and often sufficient — a single Redis key absorbs a million reads the shard would have served.
2. **Key salting / sub-partitioning.** Split the hot key into `celebrity_id:0` … `celebrity_id:9` and fan reads across the ten. Writes distribute; reads must merge ten results.
3. **A different path for the hot case.** The canonical example: fan-out on write for normal users, fan-out on read for celebrities, merged at read time.
4. **Dedicated shard / isolation.** Give the giant tenant its own database. This is standard multi-tenant practice and easy to justify.
5. **Rate limit or shed** the pathological case, so one key cannot degrade everyone else.

**Detection matters as much as the fix**: per-key and per-shard metrics, a top-N heavy-hitter sketch (count-min sketch), and alerting on shard imbalance. "I'd measure per-shard QPS and p99 and alert when one shard exceeds 2× the median" is a strong, concrete thing to say.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-hotspot-q1", "type": "mcq",
      "prompt": "One multi-tenant SaaS customer generates 40% of all queries and is saturating its shard. Which response is most standard?",
      "options": [
        {"id":"a","text":"Re-shard the whole system with more shards"},
        {"id":"b","text":"Move that tenant to its own dedicated database (and cache their hottest reads), isolating their load from everyone else"},
        {"id":"c","text":"Switch from hash to range partitioning"},
        {"id":"d","text":"Add read replicas of every shard"}
      ],
      "correct": "b",
      "explanation": "More shards does not help when a single key is the hot spot — the tenant still lands on one. Isolation (a dedicated shard/cluster) plus caching is the normal multi-tenant answer, and it also gives that customer predictable performance." }
] }
```

## Denormalisation, derived data, and multi-region

Once data is sharded, joins are gone — so the schema changes shape.

**Denormalise deliberately, and say why.** Copy the author's display name onto each post so rendering a feed needs no join, and accept that a rename must fan out. State the trade explicitly: **read speed and shard-locality bought with write amplification and the risk of drift**. Add a reconciliation job for anything that must not drift.

**Derived data stores** are the general version of this: the relational database is the source of truth, and search indexes, caches, aggregates, and analytics tables are all *derived* from its change stream (CDC via the write-ahead log, or events published by the application). Two properties make this pattern work:

- **Rebuildable**: if the derived store is corrupted or the schema changes, you replay from the source. Never let a derived store become the only copy of something.
- **Eventually consistent, and bounded**: "the search index lags by up to two seconds" is a requirement to state, monitor, and alert on.

**Multi-region** adds three questions, and interviewers expect all three:

| Question | Options |
|---|---|
| Where do writes happen? | Single-region writes (simple, far users pay latency) · multi-leader (fast local writes, conflicts) · partition by geography (each region owns its users' data) |
| How is data replicated? | Async cross-region (normal) · synchronous (only for small critical datasets — the latency is brutal) |
| What happens in a partition? | Fail over (and risk split brain) · degrade to read-only · accept divergence and reconcile |

**Data residency** is a real constraint worth naming: GDPR and similar laws can require EU users' data to stay in the EU, which forces geographic partitioning regardless of what your latency numbers say.

**Active-active vs active-passive**: active-passive is far simpler (one region serves, one stands by, failover is a promotion) and wastes capacity; active-active serves from everywhere with lower latency and much harder consistency. Say which you are choosing and why.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-derived-q1", "type": "mcq",
      "prompt": "You keep Postgres as the source of truth and Elasticsearch as a search index fed by change-data-capture. Which property must you preserve?",
      "options": [
        {"id":"a","text":"Elasticsearch must be written to synchronously so it never lags"},
        {"id":"b","text":"The index must be fully rebuildable by replaying from Postgres, and its lag must be bounded, monitored, and stated as a requirement"},
        {"id":"c","text":"Writes must go to Elasticsearch first, then Postgres"},
        {"id":"d","text":"Both stores must use the same partition key"}
      ],
      "correct": "b",
      "explanation": "Derived stores are caches of a source of truth. Rebuildability is what makes schema changes and corruption survivable; bounded, monitored lag is what makes the eventual consistency a stated requirement rather than a surprise bug." }
] }
```

## Key takeaways

**The recall card:**

```
Replication scales READS + availability.  Partitioning scales WRITES + storage.
Async replication → replication lag → breaks read-your-own-writes
                    fix: read from leader briefly, or wait for a log position
Sync/semi-sync    → no data loss, higher latency. Semi-sync (k of n) is the sane default.
Failover: detect → elect most-current → redirect → FENCE the old leader (epoch numbers)

Partition key must be: high cardinality · evenly accessed · aligned with the top query
hash % N is a trap → consistent hashing + virtual nodes
Sharding costs: no cross-shard joins/transactions, scatter-gather tails,
                global IDs (Snowflake/UUIDv7), painful rebalancing

Hot key fixes: cache it → salt it → separate path (celebrity) → dedicated shard → shed
Derived stores (search, analytics, cache) must be rebuildable from the source of truth
Multi-region: where do writes go · how does data replicate · what happens in a partition
```

- **Say which problem you are solving.** "I'm adding replicas for read scale and failover; they do nothing for my write rate, so if writes grow I shard on `user_id`."
- **The partition key is the design decision**, and the three tests (cardinality, even access, query alignment) are the way to defend it.
- **Every real system has a hot key.** Bringing it up before the interviewer does is a top-quartile signal.
- **Don't shard early.** A single well-indexed primary with replicas covers a very large range of systems; sharding buys scale with joins, transactions, and operational simplicity.
