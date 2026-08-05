---
kind: lesson
id_key: interview-prep-45/note-consistent-hashing
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Notes: Consistent Hashing"
position: 91
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

Consistent hashing is one of the few system-design building blocks interviewers expect you to derive on the spot, not just name-drop — it's the mechanism behind Dynamo, Cassandra, memcached client sharding, and most CDN/load-balancer request routing. If you can explain *why* plain `hash(key) % N` breaks and *how* the ring fixes it, you've demonstrated the exact kind of first-principles reasoning these interviews are built to test.

## The problem: modulo hashing doesn't survive resizing

The naive way to shard data across `N` servers is `server = hash(key) % N`. It works fine until `N` changes — add or remove a single server and `% N` becomes `% (N±1)`, which reassigns almost **every** key to a different server, not just the keys that belong on the new one. For a cache, that's a near-total cache miss storm; for a database, it's a massive, unnecessary data migration triggered by a single node joining or leaving.

Interviewers ask this to check whether you reason about **failure and scaling as first-class requirements**, not edge cases — servers going up and down is the normal operating condition of a distributed system, not an exception.

## The idea: a hash ring

Consistent hashing maps both **servers** and **keys** onto the same fixed circular space (typically `0` to `2^32 - 1`, using a hash function like MD5 or MurmurHash). A key is owned by the first server encountered walking clockwise from the key's position on the ring.

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

- **Adding a server** only steals the keys between its new ring position and the previous server clockwise from it — every other key stays put. Only `~1/N` of keys move, not nearly all of them.
- **Removing a server** only reassigns that server's keys to the next server clockwise — again, a small, local blast radius instead of a global reshuffle.

This is the entire point: **ring membership changes cause proportional, local key movement instead of global reshuffling.**

## Virtual nodes (the part people forget)

Placing each physical server at a single random ring position causes two problems: uneven load (some servers own a much bigger arc than others by chance) and an all-or-nothing failover (when a server dies, 100% of its keys land on exactly one neighbor, doubling that neighbor's load).

The fix: hash each physical server into **many** points on the ring (100-200 virtual nodes is typical), each labeled `server-A#1`, `server-A#2`, etc. A key still resolves to "the first virtual node clockwise," but that virtual node's physical owner is what actually serves the request.

```
Ring with virtual nodes (letters = physical server owning that point):

  A1  B2  C1  A2  B1  C3  A3  C2  B3  A1 ...

  - Load evens out: each physical server owns many small,
    scattered arcs instead of one large arc.
  - Failover spreads out: when server B dies, its keys
    (B1, B2, B3) land on several different neighbors,
    not one.
```

More virtual nodes → smoother load distribution, at the cost of more ring metadata to store and traverse. Real systems (Cassandra, Dynamo) tune this count based on cluster size.

## System design considerations

- **Ring lookup structure.** Keep virtual node positions in a sorted structure (a balanced tree, or a sorted array with binary search) so "find the first node clockwise from `hash(key)`" is O(log V) where V is the number of virtual nodes — not a linear scan.
- **Replication.** For durability, a key is usually stored on the N *distinct physical* servers encountered walking clockwise from its position (skipping virtual nodes that map back to an already-selected physical server) — this is exactly how Dynamo-style systems place replicas.
- **Heterogeneous capacity.** A server with 2x the RAM/disk of its peers gets 2x the virtual nodes, so it owns proportionally more of the ring — virtual node count is a natural capacity-weighting knob, not just a load-smoothing one.
- **Client-side vs server-side.** memcached clients typically compute the ring locally (every client needs the same server list); Dynamo/Cassandra maintain ring membership via gossip between nodes instead, so clients don't need cluster topology knowledge.

## Common pitfalls

- **Forgetting virtual nodes entirely** — a bare hash ring with one point per server has bad load balance and bad failover blast radius; interviewers listen for whether you bring this up unprompted.
- **Using a weak hash function** — a poor hash clusters keys/servers unevenly on the ring regardless of virtual nodes; a well-distributed hash (MurmurHash, SHA-based) matters as much as the ring structure itself.
- **Conflating consistent hashing with data consistency** — the name is about hashing being *consistent under membership change*, not about strong vs eventual consistency of the stored data; interviewers sometimes probe this distinction directly.

## Key takeaways

- Plain `hash(key) % N` reshuffles almost all keys on every server add/remove — consistent hashing fixes this by mapping servers and keys onto the same ring so only `~1/N` of keys move per membership change.
- Virtual nodes (100-200 per physical server) fix uneven load and concentrated failover blast radius that a single-point-per-server ring suffers from.
- Replicas are placed by walking clockwise to the next N distinct physical servers — the same ring structure that assigns primary ownership also derives replica placement.
- Virtual node count doubles as a capacity-weighting knob for heterogeneous hardware, not just a load-smoothing parameter.
