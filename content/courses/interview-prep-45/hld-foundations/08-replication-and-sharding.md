---
kind: lesson
id_key: interview-prep-45/hld-08-replication-sharding
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Replication, Partitioning, and Sharding"
position: 8
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Every single database eventually runs out of something: it can't read fast enough, it can't write fast enough, it can't hold any more data, or it can't stay online through a failure. There are exactly two tools for this, and they solve two different problems. Replication, keeping extra copies of the same data, helps with reads and with staying online. Partitioning, splitting the data itself into pieces, helps with writes and with storage. The two are almost always used together. Mixing up which one solves which problem is the most common mistake candidates make in this part of an interview.

## Replication: copies for reads and for survival

**The leader-follower design**, also called primary-replica, sends every write to one server called the leader. Other servers, called followers or replicas, copy the leader's own log of changes and can serve reads.

```
                 ┌──▶ Replica 1 (reads)
Writes ──▶ Leader├──▶ Replica 2 (reads)
                 └──▶ Replica 3 (reads, standby for promotion)
```

- Reads scale up as you add more replicas. Writes do not scale at all, since they all still go through the one leader.
- It keeps the system available: if the leader dies, you can promote a replica to take its place.
- It introduces **replication lag**, the gap in time between the leader confirming a write and a follower actually applying it. Normally this is milliseconds, but it can stretch to seconds under heavy load, or even minutes during a large background job.

**Whether the leader waits for a replica before confirming a write is a real dial you control, trading safety for speed:**

| | Asynchronous | Synchronous | Semi-synchronous (a quorum) |
|---|---|---|---|
| Leader waits for | Nothing | Every replica | A chosen number, k, out of n replicas |
| Write speed | Fastest | Slowest | In between |
| Can data be lost if the leader crashes? | **Yes, possibly** | No | No, as long as at least one of the k survives |
| Staying available | Best | One slow replica stalls every write | Keeps working even if n minus k replicas are slow or dead |

Semi-synchronous, meaning "wait for at least one replica to confirm it, then reply," is the practical default most systems pick: it bounds how much data you could lose, and it bounds how much extra time each write costs.

**Multi-leader replication** lets more than one region accept writes. This removes the extra delay of always writing to one far-away leader, and it keeps working even if regions can't talk to each other. The price is **write conflicts**, cases where two regions each changed the same thing differently and you have to decide which wins. The options are last-write-wins (simple, but it quietly throws away one of the two changes), a merge rule you write yourself, or CRDTs, special data structures designed to always merge cleanly without any conflict at all; these are the right answer for something like collaborative document editing.

**Leaderless replication**, used by Dynamo and Cassandra, has the client itself write to several servers and read from several servers, with a bit of counting (called quorum arithmetic, covered in the next lesson on CAP and consistency levels) deciding how fresh the data you read back actually is.

**Failover is where the genuinely hard questions live.** Promoting a replica to become the new leader involves detecting the failure without being fooled by a temporary network hiccup, picking whichever replica has the most up-to-date data, redirecting clients to it through DNS, a proxy, or a shared address, and preventing what's called split brain: the old leader coming back online and still accepting writes as if nothing happened. Split brain is prevented through fencing, giving each leadership term a steadily increasing number, and having every write carry that number so storage can reject one that's out of date.

> **Remember:** replicas are copies for reading and for surviving a crash. They do nothing for your write rate; that's what partitioning is for.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-replication-q1", "type": "mcq",
      "prompt": "A user posts a comment and is immediately sent to a page that reads from a replica, but their comment is missing. What is happening, and what is the standard fix?",
      "options": [
        {"id":"a","text":"A cache stampede; add a lock around the read"},
        {"id":"b","text":"Replication lag is breaking the \"see your own writes\" guarantee; send that user's reads to the leader, or to a replica known to have caught up, for a short window after they write"},
        {"id":"c","text":"A lost update; use a row lock before updating"},
        {"id":"d","text":"A phantom read; raise the isolation level to Serializable"}
      ],
      "correct": "b",
      "explanation": "Because replication happens asynchronously, a follower can genuinely be behind for a moment. The fix is to briefly pin that one user's reads to the leader, or to wait until a replica has caught up to the exact point their write happened at." }
] }
```

## Partitioning: splitting the data itself

Picture a library so large that one building can't hold every book, so the city splits its collection into five branch libraries, sorted by street address. Partitioning, also called sharding, does the exact same thing to data: it splits one logical set of data across many machines, so each one holds only a slice. This is what scales **writes** and **storage**, the two things replication alone cannot do.

**Vertical partitioning** splits data by column or by feature: the users table lives on one cluster, and analytics events live on another. This is really "split the service into two," and it's often the right first move, because it doesn't require rewriting how your application routes queries.

**Horizontal partitioning** splits data by row instead, and the big decision here is choosing the **partition key**, the value that decides which shard a given row lives on.

| Strategy | How it works | Good | Bad |
|---|---|---|---|
| **Range** | Split by ranges, like A through F, or by date | Range queries stay inside one shard | Whatever's newest, like today's date, gets all the writes |
| **Hash** | `hash(key) % N` | Spreads data evenly | Range queries have to hit every shard; adding a shard moves almost everything |
| **Consistent hashing** | Keys and servers placed on a shared ring, using many points per server | Adding a server only moves about 1 out of N keys | More moving parts; still needs many points per server to stay even |
| **Directory / lookup** | A separate service maps each key to its shard | Very flexible, easy to rebalance | That lookup service is now a dependency, and a possible single point of failure |
| **Geographic** | Split by region | Good for latency and legal data-location rules | Queries spanning regions become expensive |

**Here is exactly why `hash(key) % N` is a trap.** Say you have 4 servers, and a key like `"user:42"` hashes to the number 17. `17 % 4 = 1`, so that key lives on server 1. Now add a 5th server. The key's hash hasn't changed, but `17 % 5 = 2`, so the key suddenly moves to server 2, a server that didn't even just join. Multiply that across every single key whose answer changes between dividing by 4 and dividing by 5, which turns out to be most of them, and you can see why adding just one server to a cache fleet can wipe out almost the entire cache at once.

### Consistent hashing: the ring that fixes the modulo trap

Picture a circular clock face instead of a plain numbered list of servers. Consistent hashing places both servers and keys onto that same circle, called a ring, usually numbered from 0 up to a very large number using a hash function like MurmurHash. A key belongs to whichever server you reach first walking clockwise from that key's own position on the ring.

```
                    hash space: a ring, 0 .. 2^32-1

                            0 / 2^32
                              |
                    Server D  *
                         .        .
                    .                .
              key "session:42"          Server A
              hash -> lands here   *          *
                    .          walk CW    .
                       .        |      .
                    Server C *--+---* Server B
                              |
                        (owns everything
                         clockwise back
                         to Server A)
```

With the ring, adding or removing a server only disturbs a small stretch of it, not the whole thing.

- **Adding a server** only takes over the keys that sit between its new spot on the ring and the previous server clockwise from it. Every other key stays exactly where it was. Only about 1 out of every N keys moves, not nearly all of them.
- **Removing a server** only hands its keys to the next server clockwise. Every other server's keys are left untouched.

**Here's the part people forget: virtual nodes.** If each physical server only gets one single, randomly placed point on the ring, two problems show up. Some servers end up owning a much bigger stretch of the ring than others, purely by chance. And when a server dies, every single one of its keys lands on exactly one neighbour, doubling that neighbour's load overnight. The fix is to give each physical server 100 to 200 separate points on the ring instead of just one, labelled something like `server-A#1`, `server-A#2`, and so on. A key still resolves to "the first point clockwise," but now each physical server owns many small, scattered stretches instead of one big one. Load evens out, and when a server fails, its load spreads across several neighbours instead of dumping onto just one. Using more virtual points per server smooths the distribution further, at the cost of more data to keep track of. A server with twice the memory of its peers can simply be given twice the virtual points, which makes this count a knob for weighting capacity as well as for smoothing load.

**Placing replica copies reuses this same ring.** For a replication factor of 3, a key gets stored on the first 3 *distinct physical servers* you reach walking clockwise past its position. This is exactly how Dynamo-style systems, including Cassandra and DynamoDB, decide where to place replicas, with no extra machinery needed.

Two mistakes worth naming before you're asked about them: forgetting virtual nodes entirely, which leaves you with uneven load and a large blast radius when one server fails, and confusing "consistent hashing" with "the data itself is always up to date." The name only refers to the hashing staying stable as servers join and leave; it says nothing about how fresh a read is.

> **Remember:** plain `hash(key) % N` reshuffles almost every key when a server joins or leaves. A ring with virtual nodes moves only about 1 out of N keys, and spreads a failure's load across many neighbours instead of dumping it on one.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-consistent-hash-q1", "type": "mcq",
      "prompt": "Why does a hash ring use 100 to 200 virtual points per physical server, instead of just one point per server?",
      "options": [
        {"id": "a", "text": "One point per server gives uneven load and dumps a dead server's entire load onto a single neighbour; many scattered points even out the load and spread a failure across several neighbours"},
        {"id": "b", "text": "Virtual nodes make the hash function itself run faster"},
        {"id": "c", "text": "Virtual nodes are required for the ring to support more than 4 servers"},
        {"id": "d", "text": "Virtual nodes remove the need to choose a replication factor"}
      ],
      "correct": "a",
      "explanation": "With one point per server, where it lands on the ring is pure luck: some servers get a big stretch, some get a small one, and a dead server's entire stretch lands on one neighbour. Many small points spread across each server smooths out both the load and the size of a failure's impact." }
] }
```

**Choosing the partition key is the decision that matters most, and it should pass three tests.**

1. **High cardinality**, meaning enough distinct values to spread the data across many shards. Using `country` as the key is a bad choice, since all of India's data would land on one single shard. Using `user_id` is a good choice.
2. **Even access**, meaning no single value gets a disproportionate share of traffic. A celebrity's own `user_id` breaks this badly, which is exactly why handling a celebrity account is such a recurring design topic.
3. **Query alignment**, meaning your single most common query should be answerable from one shard alone. If you shard tweets by `tweet_id` but almost always query by `author_id`, every read now has to fan out and gather results across every single shard.

**Sharding has real costs, and you should say them out loud, since they're exactly why you shouldn't shard before you need to:**

- **You lose cross-shard joins.** You either copy data across shards to avoid needing a join, join the data yourself inside your application code, or keep a small reference table copied onto every shard.
- **You lose cross-shard transactions**, unless you bring in two-phase commit or a saga, both covered in a later lesson.
- **Queries that fan out and gather results from every shard** are only as fast as the single slowest shard, and their worst-case response time is far worse than what a single machine would give you.
- **Staying globally unique and correctly ordered needs help.** Use a Snowflake-style ID, combining a timestamp, a machine number, and a counter, or a UUIDv7, instead of a simple auto-incrementing number.
- **Rebalancing data across shards is a long, careful process**: write to both the old and new location at once, copy over the existing data in the background, double-check it matches, switch reads over, and only then stop writing to the old location.

> **Remember:** a good partition key has many distinct values, spreads traffic evenly, and matches your most common query. Get any one of those wrong, and sharding creates new problems instead of solving the old one.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-partition-q1", "type": "mcq",
      "prompt": "You shard an orders table by hashing `order_id`, but 90% of queries ask \"all orders for customer X.\" What goes wrong?",
      "options": [
        {"id":"a","text":"Nothing; hash partitioning spreads data evenly, and that's all that matters"},
        {"id":"b","text":"Almost every common query has to fan out and gather results across every single shard, so its speed tracks the slowest shard and overall throughput collapses; the key should instead match the dominant query, such as customer id"},
        {"id":"c","text":"Orders lose their guarantee of being unique"},
        {"id":"d","text":"Replication lag increases"}
      ],
      "correct": "b",
      "explanation": "Spreading data evenly is only half of what a good partition key needs to do. The other half is making sure your most common query can be answered from a single shard. Sharding by customer id keeps one customer's orders together, at the cost of a possible hot shard for one very large customer." }
] }
```

## Hot spots, celebrities, and skew

Picture five identical checkout counters in a supermarket, each meant to serve an equal share of shoppers. Then a celebrity walks in, and every other shopper drifts over to that one counter just to look. One counter is now swamped while the other four sit nearly empty. That's a hot shard: **traffic can be badly uneven even when the keys themselves are spread out evenly.** Every real system has some version of this: a celebrity account, a viral product, a huge sale-day item, or one customer that alone makes up 40% of your database's traffic.

**Here is the order of fixes to offer, cheapest first:**

1. **Cache the hot key in front of the shard.** This is usually the cheapest fix, and it's often enough on its own; a single Redis key can absorb a million reads the shard would otherwise have had to serve.
2. **Split the key up, sometimes called salting.** Turn one hot key into ten, like `celebrity_id:0` through `celebrity_id:9`, and spread reads across all ten. Writes now spread out naturally; reads have to merge the ten results back together.
3. **Give the hot case a different path entirely.** The classic example: build each normal user's feed at write time, but build a celebrity's followers' feeds at read time instead, then merge the two approaches.
4. **Give it a dedicated shard, fully isolated.** Move one giant customer onto its own database. This is completely standard practice for multi-tenant systems, and it's easy to justify.
5. **Rate limit or shed load** for the extreme case, so that one troublesome key can't drag down everyone else's experience.

**Spotting the problem matters as much as fixing it.** Track metrics per key and per shard, use a small structure called a count-min sketch to spot the busiest keys cheaply, and alert whenever one shard is carrying an unfair share of the load. Saying something like "I'd track requests per shard and their slowest 1%, and alert when one shard is more than twice the median" is a strong, concrete thing to say in an interview.

> **Remember:** every real system has a hot key somewhere. The order of fixes is: cache it, split it, give it a separate path, then finally give it its own dedicated shard.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-hotspot-q1", "type": "mcq",
      "prompt": "One customer on a multi-tenant system generates 40% of all queries and is overwhelming its shard. Which response is most standard?",
      "options": [
        {"id":"a","text":"Re-shard the entire system with more shards"},
        {"id":"b","text":"Move that one customer to its own dedicated database, and cache their most-read data, isolating their load from everyone else"},
        {"id":"c","text":"Switch from hash-based partitioning to range-based partitioning"},
        {"id":"d","text":"Add read replicas of every single shard"}
      ],
      "correct": "b",
      "explanation": "Adding more shards doesn't help here, since that one customer still lands on a single shard regardless of how many shards exist. Giving them their own dedicated database, plus caching, is the standard multi-tenant fix, and it also gives that customer more predictable performance." }
] }
```

## Denormalisation, derived data, and multi-region

Once your data is sharded, you lose the ability to join across shards, so the shape of your schema has to change to cope.

**Denormalising on purpose, and being able to explain why, is a legitimate design choice.** Copying an author's display name directly onto each of their posts means rendering a feed needs no join at all, but it also means a name change has to be pushed out everywhere it was copied. Say the trade-off out loud: you're buying faster reads and keeping related data on one shard, at the cost of extra writes and the risk of the copies drifting apart over time. Add a background job that checks for and fixes drift for anything that truly must never drift.

**Derived data stores** are the general version of this same idea: the relational database holds the real, authoritative data, and things like search indexes, caches, running totals, and analytics tables are all *derived* from a stream of its changes, either by reading its internal change log directly or through events your application publishes. Two properties make this pattern actually safe to use.

- **It must be rebuildable.** If the derived store gets corrupted, or its schema needs to change, you should be able to simply replay the source data and regenerate it. Never let a derived store quietly become the only copy of something important.
- **Its lag must be bounded and known.** Saying "the search index can be up to two seconds behind" is a real requirement you should state clearly, monitor, and set an alert on.

**Operating in more than one region raises three questions, and interviewers will expect answers to all three.**

| Question | Options |
|---|---|
| Where do writes happen? | One region writes for everyone (simple, but far-away users pay extra delay) · every region can write (fast locally, but creates conflicts) · each region owns its own users' data (splits by geography) |
| How does data get copied between regions? | Asynchronously across regions (the normal choice) · synchronously (only for small, critical data, since the delay is severe) |
| What happens if regions can't talk to each other? | Fail over to one side, risking split brain · fall back to read-only · accept the two sides drifting apart and reconcile them later |

**Where data is legally allowed to live is a real constraint too.** Laws like GDPR can require that data belonging to EU users physically stays within the EU, which forces you to split data by geography no matter what your latency numbers suggest.

**Running active in only one region at a time (active-passive) versus active everywhere (active-active)** is a real trade-off. Active-passive is far simpler: one region serves traffic, another sits ready as a standby, and failover is just promoting the standby, though it wastes the standby's capacity while idle. Active-active serves traffic from everywhere at once, giving lower latency, but makes keeping data correct and in sync much harder. State clearly which one you're choosing, and why.

> **Remember:** a derived store, like a search index, a cache, or an analytics table, is only safe if you could throw it away and fully rebuild it from the source of truth. If you can't, it has quietly become a second source of truth.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-08-derived-q1", "type": "mcq",
      "prompt": "You keep Postgres as the real data and Elasticsearch as a search index fed from a stream of Postgres's own changes. Which property must you preserve?",
      "options": [
        {"id":"a","text":"Elasticsearch must be written to at the exact same time as Postgres, so it never lags behind"},
        {"id":"b","text":"The index must be fully rebuildable by replaying Postgres's data from scratch, and its lag must be bounded, monitored, and clearly stated as a requirement"},
        {"id":"c","text":"Writes must always go to Elasticsearch first, and Postgres second"},
        {"id":"d","text":"Both stores must be split using the exact same partition key"}
      ],
      "correct": "b",
      "explanation": "A derived store is really a cache of the real data. Being rebuildable is what lets you survive a schema change or corruption; a bounded, monitored lag is what turns eventual consistency into a stated requirement, rather than a surprise bug someone discovers later." }
] }
```

## Quick recap

```
Replication scales READS + availability.  Partitioning scales WRITES + storage.
Async replication → replication lag → breaks read-your-own-writes
                    fix: read from leader briefly, or wait for a log position
Sync/semi-sync    → no data loss, higher latency. Semi-sync (k of n) is the sane default.
Failover: detect → elect most-current → redirect → FENCE the old leader (epoch numbers)

Partition key must be: high cardinality · evenly accessed · aligned with the top query
hash % N is a trap → consistent hashing ring + virtual nodes moves only ~1/N of keys
Sharding costs: no cross-shard joins/transactions, scatter-gather tails,
                global IDs (Snowflake/UUIDv7), painful rebalancing

Hot key fixes: cache it → salt it → separate path (celebrity) → dedicated shard → shed
Derived stores (search, analytics, cache) must be rebuildable from the source of truth
Multi-region: where do writes go · how does data replicate · what happens in a partition
```
