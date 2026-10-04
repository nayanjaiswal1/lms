---
kind: lesson
id_key: interview-prep-45/lld-19-cheatsheet
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "LLD Cheat Sheet and Recall Drill"
position: 18
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
---

Seventeen lessons of object modelling, principles, patterns, and worked problems only actually pay off if you can pull them back out of your head in 45 minutes, with someone watching. This lesson is the retrieval layer: the framework, tables that map a requirement straight to a design move, the exact phrases that earn points, and a drill worth running regularly until every answer feels automatic.

## The one-page map

```
FRAMEWORK (Lesson 1)   Requirements → Entities → Relationships → Interfaces
                       → Concurrency → Extensibility
                       45 min: 5 / 8 / 8 / 10 / 7 / 5

MODELLING (1,2)        nouns → classes · verbs → methods · closed sets → ENUMS
                       varying behaviour → INTERFACE · values → unchangeable value objects
                       COMPOSITION over inheritance · low coupling, high cohesion
                       the lifecycle test: composition (◆) vs aggregation (◇)

PRINCIPLES (3)         S one reason to change · O add classes, don't edit
                       L subtypes must be substitutable · I no forced methods
                       D depend on abstractions the DOMAIN owns

PATTERNS (4–7)         Creational : Singleton · Factory · Abstract Factory · Builder
                                    · Prototype · Object Pool
                       Structural : Adapter · Decorator · Facade · Composite
                                    · Bridge · Proxy · Flyweight
                       Behavioral : Strategy · Observer · Command · State
                                    · Template Method · Chain · Iterator
                                    · Mediator · Memento · Visitor

CONCURRENCY (8)        find the SHARED, CHANGEABLE data → stop sharing it / stop letting it change
                                                         / protect access to it
                       lock · atomic · immutable · lock ORDER for deadlock
                       optimistic (low contention) vs pessimistic (high) vs a TTL reservation
                       MULTI-PROCESS ⇒ the DATABASE enforces it, never an in-process lock

PROBLEMS (9–17)        parking lot · elevator · ticket booking · splitwise
                       · vending machine/ATM · rate limiter/logger · notifications/cache/hashmap
                       · games · database design
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-map-q1", "type": "mcq",
      "prompt": "Which step of the LLD framework do people skip most often, and what does skipping it actually cost them?",
      "options": [
        {"id":"a","text":"Drawing the class diagram — without it, the interviewer can't follow along"},
        {"id":"b","text":"Concurrency — most candidates present a single-threaded design and then have nothing to say when asked what happens if two users act at the exact same time, which is the follow-up in nearly every LLD round"},
        {"id":"c","text":"Requirements — most candidates spend far too long there"},
        {"id":"d","text":"Naming the classes"}
      ],
      "correct": "b",
      "explanation": "Concurrency is both the step people skip the most and the follow-up interviewers ask the most reliably. Volunteering \"the shared, changeable data here is X, and it's protected by Y\" before anyone even asks is one of the cheapest ways to stand out." }
] }
```

## Requirement → design move

Run this table in your head while the interviewer is still talking.

| What you hear | What it actually means |
|---|---|
| "...and we might add more types later" | An enum plus polymorphism, or a registry-backed factory |
| "...the pricing or rules might change" | A **Strategy** interface |
| "...when X happens, also do Y and Z" | **Observer** |
| "...it can be in one of these states" | The **State** pattern, or just an enum plus a transition table |
| "...support undo" | **Command** (plus Memento for snapshots) |
| "...run the request through these steps" | **Chain of Responsibility** |
| "...it's a tree, or has nested groups" | **Composite** |
| "...integrate with this third-party API" | **Adapter** (plus **Decorator** for retry) |
| "...this is expensive to build" | A lazy **Proxy**, an **Object Pool**, or **Flyweight** |
| "...lots of optional parameters" | **Builder** |
| "...exactly one of these should ever exist" | One instance, **injected** — not a global Singleton |
| "...two users do this at the same moment" | Name the shared data; a lock, an atomic operation, or a conditional database write |
| "...the user takes minutes to finish this" | A **reservation with a TTL**, never a held lock |
| "...this involves money" | Whole minor units, unchangeable ledger entries, calculated balances |
| "...we run on several servers" | A unique constraint or a conditional `UPDATE` — in-process locks are useless here |
| "...we need history or an audit trail" | Unchangeable records; corrections are new entries, never edits |

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-mapping-q1", "type": "mcq",
      "prompt": "The interviewer says: \"a user selects seats, then has five minutes to pay.\" What's the design move here?",
      "options": [
        {"id":"a","text":"Hold a database row lock for the whole five minutes"},
        {"id":"b","text":"A reservation with an expiry timestamp — the seat moves into a HELD state with a `held_until` field, so an abandoned checkout releases itself automatically, and no lock is held across a delay that long"},
        {"id":"c","text":"An optimistic version check, done only at payment time"},
        {"id":"d","text":"A distributed Redis lock with a five-minute TTL"}
      ],
      "correct": "b",
      "explanation": "Delays measured in human time rule out held locks — they'd serialise the whole system and leak whenever someone abandons checkout. The expiry makes abandonment self-healing, and the actual anti-double-booking guarantee still comes from the conditional write plus the unique constraint." }
] }
```

## The phrases that earn points

Rehearse these until they're automatic — under pressure, you tend to say whatever you've already practiced saying.

1. "Before I model anything — what varies here, and what's fixed?"
2. "I'll scope to X and Y. I'll define an interface for Z, but I won't implement it."
3. "That's a closed set, so it's an enum — and specifically an enum instead of a boolean, because a third state is coming."
4. "These two things vary independently, so composition instead of inheritance — otherwise I'd need a class per combination."
5. "This is composition, not aggregation: destroy the floor, and the spots stop meaning anything."
6. "I'm putting pricing behind an interface, because you said the scheme is going to change."
7. "The shared, changeable data here is the free-seat set, and it's protected by a conditional write."
8. "An in-process lock won't survive a second server — the invariant has to live in the database."
9. "Illegal transitions become impossible to write by accident, because each state class only defines the moves it actually allows."
10. "That's a cross-cutting concern, so a decorator around the channel, rather than code copy-pasted into every channel."
11. "Money is stored as whole paise, and the split has an explicit rule for leftover remainders, so the shares always add up exactly to the total."
12. "If we add a new type, that's one new class with zero edits — here's the walkthrough."

**And the anti-patterns worth catching yourself doing**: naming a pattern before naming the actual problem, a `Manager`/`Helper` god class, getters and setters standing in for real behaviour, inheritance used purely for code reuse, booleans where an enum belongs, an interface with one implementation and no realistic second one, and going silent while you think instead of narrating out loud.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-phrases-q1", "type": "mcq",
      "prompt": "Which of these statements would most likely count against you in an interview?",
      "options": [
        {"id":"a","text":"\"I'll keep this concrete for now — if a second pricing rule shows up, this is exactly where the strategy would go.\""},
        {"id":"b","text":"\"I'll add an interface, an abstract factory, and a strategy for this one concrete class, just to keep the design flexible.\""},
        {"id":"c","text":"\"The shared, changeable data here is the inventory count, and it's protected by a conditional UPDATE.\""},
        {"id":"d","text":"\"This is aggregation, not composition — the songs outlive the playlist.\""}
      ],
      "correct": "b",
      "explanation": "Adding abstraction with no real axis of variation is the most common mistake people make right after learning these patterns. Deliberately staying concrete while naming exactly where the extension point would go, like option (a), is the stronger, more senior answer." }
] }
```

## The weekly recall drill

Answer these out loud, from memory, in under five seconds each. The number in brackets is the lesson to check yourself against.

**Round 1 — framework and modelling**
1. The six steps of an LLD interview, and roughly how many minutes each gets. [1]
2. The four things a noun can turn into. [1]
3. The lifecycle test for telling composition from aggregation. [1]
4. Why prefer an enum over a boolean flag. [1]
5. Encapsulation versus abstraction, in one sentence each. [2]
6. Two reasons composition beats inheritance. [2]
7. Name three design smells and their fixes. [2]
8. Interface versus abstract class — when to use each. [2]

**Round 2 — principles**
9. Each SOLID letter, plus the warning sign that reveals its violation. [3]
10. Why does `Square extends Rectangle` break Liskov Substitution? [3]
11. The practical tell for an Interface Segregation violation. [3]
12. Which layer should own the repository interface, and why? [3]

**Round 3 — patterns**
13. Adapter versus Facade. [5]
14. Decorator versus Proxy. [5]
15. Strategy versus State. [6]
16. Strategy versus Template Method. [6]
17. When is Visitor the right call, and what does it cost you? [7]
18. Two things Command makes possible, besides undo. [6]
19. Why does Singleton get criticised, and what's preferred instead? [4]
20. What has to be true for Flyweight to actually be safe? [5]

**Round 4 — concurrency**
21. The three shapes a race condition can take. [8]
22. Why thread-safe methods don't add up to a thread-safe sequence. [8]
23. The four Coffman conditions, and which one you actually break in practice. [8]
24. Optimistic versus pessimistic locking — decided by what? [8]
25. What actually prevents double-booking across five servers? [8]

**Round 5 — problems**
26. Parking lot: the two extension points. [9]
27. Elevator: why two direction-based sets of stops, and what LOOK does. [10]
28. Booking: why `Seat` and `ShowSeat` are separate classes. [11]
29. Splitwise: the three money rules, and the bound on the settlement algorithm. [12]
30. Vending machine: what happens when exact change isn't possible. [13]
31. ATM: when is greedy note selection actually wrong? [13]
32. Rate limiter: the four algorithms, and which one is the default. [14]
33. Logger: why check the level before formatting the message? [14]
34. LRU: which two data structures, and why each one is needed. [15]
35. Chess: which layer owns en passant, and why? [16]

**Round 6 — apply it.** Pick a problem you haven't designed before — food delivery, a car rental system, a library system, a hotel booking system, a coffee machine, an online judge, a chat app, a URL shortener at the class level — and give yourself **fifteen minutes**: requirements and scope, entities with their kind, a class diagram, real method signatures on the core classes, the shared changeable data and how it's protected, and one extension walked through out loud. No notes. Do one of these a week.

Every single one of those is really just a recombination of what's already in this section: an allocator (the parking lot), a lifecycle (the vending machine), a reservation (booking), a pricing strategy, a notification observer, and a repository interface.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-drill-q1", "type": "mcq",
      "prompt": "You're asked to design a food-delivery system's classes, and you've never specifically prepared for that exact problem. What's the most reliable way to approach it?",
      "options": [
        {"id":"a","text":"Recall the closest problem you've memorised and just reuse its classes"},
        {"id":"b","text":"Run the six-step framework and recombine building blocks you already know: an order lifecycle (State), rider assignment (an allocation Strategy), surge pricing (Strategy), status updates (Observer), inventory holds (a reservation with a TTL), and persistence behind repository interfaces"},
        {"id":"c","text":"Start by listing every design pattern that might possibly apply"},
        {"id":"d","text":"Ask the interviewer to switch to a problem you've already prepared"}
      ],
      "correct": "b",
      "explanation": "Every new LLD problem is really a recombination of the same handful of building blocks. The framework guarantees you cover requirements, entities, relationships, interfaces, concurrency, and extensibility no matter what the domain is — which is exactly why the procedure beats memorising specific answers." }
] }
```

## Quick recap

- **Procedure beats memorisation.** The six steps, and the requirement-to-design-move table, are exactly what let you handle a problem you've genuinely never seen before.
- **Every design decision comes with a cost — say it out loud.** "Composition here, because these two things vary independently — the cost is one more object to wire together" is what a real design review actually sounds like.
- **Concurrency is the step people skip the most, and the one asked about the most.** Name the shared, changeable data and how it's protected before anyone asks, and remember that only the database enforces anything across separate servers.
- **Restraint is itself a senior-level signal.** After going through a whole pattern catalogue, deliberately staying concrete and naming exactly where the extension point *would* go beats abstracting everything on reflex.
- **Practice out loud, on a timer, every week.** Fifteen minutes on an unfamiliar problem, using nothing but the framework and the building blocks from lessons 9 through 16.
