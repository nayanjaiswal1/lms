---
kind: lesson
id_key: interview-prep-45/lld-19-cheatsheet
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD Cheat Sheet and Recall Drill"
position: 19
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
---

Eighteen lessons of object modelling, principles, patterns, and worked problems only pay off if you can retrieve them in 45 minutes with someone watching. This lesson is the retrieval layer: the framework, the decision tables that map a requirement to a design move, the phrases that earn points, and a drill to run weekly until every answer is automatic.

## The one-page map

```
FRAMEWORK (Lesson 1)   Requirements → Entities → Relationships → Interfaces
                       → Concurrency → Extensibility
                       45 min: 5 / 8 / 8 / 10 / 7 / 5

MODELLING (1,2)        nouns → classes · verbs → methods · closed sets → ENUMS
                       varying behaviour → INTERFACE · values → immutable value objects
                       COMPOSITION over inheritance · low coupling, high cohesion
                       lifecycle test: composition (◆) vs aggregation (◇)

PRINCIPLES (3)         S one reason to change · O add classes not edits
                       L subtypes substitutable · I no forced methods
                       D depend on abstractions the DOMAIN owns

PATTERNS (4–7)         Creational : Singleton · Factory · Abstract Factory · Builder
                                    · Prototype · Object Pool
                       Structural : Adapter · Decorator · Facade · Composite
                                    · Bridge · Proxy · Flyweight
                       Behavioral : Strategy · Observer · Command · State
                                    · Template Method · Chain · Iterator
                                    · Mediator · Memento · Visitor

CONCURRENCY (8)        find SHARED MUTABLE STATE → remove sharing / remove mutability
                                                  / protect access
                       lock · atomic · immutable · lock ORDER for deadlock
                       optimistic (low contention) vs pessimistic (high) vs TTL reservation
                       MULTI-PROCESS ⇒ the DATABASE enforces it, never an in-process lock

PROBLEMS (9–18)        parking lot · elevator · ticket booking · splitwise
                       · vending/ATM · rate limiter/logger · notifications/cache
                       · games · coding-style design problems · database design
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-map-q1", "type": "mcq",
      "prompt": "Which step of the LLD framework do candidates most often skip, and what does skipping it cost?",
      "options": [
        {"id":"a","text":"Drawing the class diagram — without it the interviewer cannot follow"},
        {"id":"b","text":"Concurrency — most candidates present a single-threaded model and then have no answer when asked what happens if two users act at once, which is the follow-up in nearly every LLD round"},
        {"id":"c","text":"Requirements — most candidates spend too long there"},
        {"id":"d","text":"Naming the classes"}
      ],
      "correct": "b",
      "explanation": "Concurrency is both the most commonly skipped step and the most reliably asked follow-up. Volunteering \"the shared mutable state is X, protected by Y\" before being asked is one of the cheapest ways to stand out." }
] }
```

## Requirement → design move

The table to run in your head while the interviewer is still talking.

| What you hear | What it means |
|---|---|
| "…and we might add more types later" | Enum + polymorphism, or a registry factory |
| "…the pricing/rules may change" | **Strategy** interface |
| "…when X happens, also do Y and Z" | **Observer** |
| "…it can be in one of these states" | **State** pattern, or an enum + transition table |
| "…support undo" | **Command** (+ Memento for snapshots) |
| "…process the request through these steps" | **Chain of Responsibility** |
| "…it's a tree / has nested groups" | **Composite** |
| "…integrate with this third-party API" | **Adapter** (+ **Decorator** for retry) |
| "…this is expensive to create" | Lazy **Proxy**, **Object Pool**, or **Flyweight** |
| "…lots of optional parameters" | **Builder** |
| "…exactly one of these should exist" | One instance, **injected** (not a global Singleton) |
| "…two users do this at the same time" | Name the shared state; lock / atomic / conditional DB write |
| "…the user takes minutes to complete this" | **Reservation with a TTL**, never a held lock |
| "…this involves money" | Integer minor units, immutable ledger entries, derived balances |
| "…we run on several servers" | Unique constraint or conditional `UPDATE`; in-process locks are useless |
| "…we need history / an audit trail" | Immutable records; corrections are new entries, never edits |

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-mapping-q1", "type": "mcq",
      "prompt": "The interviewer says: \"a user selects seats, then has five minutes to pay.\" What is the design move?",
      "options": [
        {"id":"a","text":"Hold a database row lock for the five minutes"},
        {"id":"b","text":"A reservation with an expiry timestamp — the seat moves to a HELD state with `held_until`, so an abandoned checkout releases itself and no lock is held across a human-scale delay"},
        {"id":"c","text":"An optimistic version check at payment time only"},
        {"id":"d","text":"A distributed Redis lock with a five-minute TTL"}
      ],
      "correct": "b",
      "explanation": "Human-scale delays rule out held locks — they would serialise the whole system and leak on abandonment. The expiry makes abandonment self-healing, and the actual anti-double-booking guarantee is the conditional write plus the unique constraint." }
] }
```

## The phrases that earn points

Rehearse these verbatim; under pressure you produce what you have said before.

1. "Before I model anything — what varies here, and what's fixed?"
2. "I'll scope to X and Y; I'll define an interface for Z but not implement it."
3. "That's a closed set, so an enum — and an enum rather than a boolean, because a third state is coming."
4. "These two things vary independently, so composition rather than inheritance — otherwise I need a class per combination."
5. "This is composition, not aggregation: destroy the floor and the spots are meaningless."
6. "I'm putting pricing behind an interface because you said the scheme will change."
7. "The shared mutable state here is the free-seat set, and it's protected by a conditional write."
8. "An in-process lock won't survive a second server — the invariant has to live in the database."
9. "Illegal transitions become unwritable, because each state class only defines the moves it permits."
10. "That's a cross-cutting concern, so a decorator around the channel rather than code in every channel."
11. "Money is integer paise, and the split has an explicit remainder rule so the shares sum exactly to the total."
12. "If we add a new type, that's one new class and no edits — here's the walkthrough."

**And the anti-patterns to hear yourself doing**: naming a pattern before naming the problem; a `Manager`/`Helper` god class; getters and setters instead of behaviour; inheritance for code reuse; booleans where an enum belongs; an interface with one implementation and no plausible second; and going silent while thinking.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-phrases-q1", "type": "mcq",
      "prompt": "Which statement would an interviewer most likely count against you?",
      "options": [
        {"id":"a","text":"\"I'll keep this concrete for now; if a second pricing rule appears, this is where the strategy goes.\""},
        {"id":"b","text":"\"I'll add an interface, an abstract factory, and a strategy for this one concrete class so the design is flexible.\""},
        {"id":"c","text":"\"The shared mutable state is the inventory count, protected by a conditional UPDATE.\""},
        {"id":"d","text":"\"This is aggregation, not composition — the songs outlive the playlist.\""}
      ],
      "correct": "b",
      "explanation": "Speculative abstraction with no axis of variation is the most common post-patterns mistake. Deliberately staying concrete while naming where the extension point would go (a) is the stronger, more senior answer." }
] }
```

## The weekly recall drill

Answer out loud, from memory, in under five seconds each. The bracketed number is the lesson to check yourself against.

**Round 1 — framework and modelling**
1. The six steps of an LLD interview, and the minutes for each. [1]
2. Four kinds of thing a noun can become. [1]
3. The lifecycle test for composition vs aggregation. [1]
4. Why prefer an enum to a boolean flag. [1]
5. Encapsulation vs abstraction, in one sentence each. [2]
6. Two reasons composition beats inheritance. [2]
7. Name three design smells and their fixes. [2]
8. Interface vs abstract class — when each. [2]

**Round 2 — principles**
9. State each SOLID letter and the smell that reveals its violation. [3]
10. Why does `Square extends Rectangle` break LSP? [3]
11. The practical signal of an ISP violation. [3]
12. Which layer should own the repository interface, and why? [3]

**Round 3 — patterns**
13. Adapter vs Facade. [5]
14. Decorator vs Proxy. [5]
15. Strategy vs State. [6]
16. Strategy vs Template Method. [6]
17. When is Visitor right, and what does it cost? [7]
18. Two capabilities Command unlocks besides undo. [6]
19. Why is Singleton criticised, and what is preferred? [4]
20. What must be true for Flyweight to be safe? [5]

**Round 4 — concurrency**
21. The three race shapes. [8]
22. Why thread-safe methods do not compose. [8]
23. The four Coffman conditions, and which one you break in practice. [8]
24. Optimistic vs pessimistic — pick by what? [8]
25. What actually prevents double-booking across five servers? [8]

**Round 5 — problems**
26. Parking lot: the two extension points. [9]
27. Elevator: why two directional stop sets, and what LOOK does. [10]
28. Booking: why `Seat` and `ShowSeat` are different classes. [11]
29. Splitwise: the three money rules, and the settlement algorithm's bound. [12]
30. Vending machine: what happens when exact change is impossible. [13]
31. ATM: when is greedy note selection wrong? [13]
32. Rate limiter: the four algorithms and the default choice. [14]
33. Logger: why check the level before formatting? [14]
34. LRU: which two structures, and why each is needed. [15]
35. Chess: which layer owns en passant, and why. [16]

**Round 6 — apply it.** Pick a problem you have not yet designed — food delivery, a car rental system, a library, a hotel booking system, a coffee machine, an online judge, a chat application, a URL shortener at class level — and give yourself **fifteen minutes**: requirements and scope, entities with their kind, a class diagram, real method signatures on the core classes, the shared mutable state and its protection, and one extension walked through. Out loud, no notes. Do one a week.

Every one of those is a recombination of what is already in this section: an allocator (parking lot), a lifecycle (vending machine), a reservation (booking), a pricing strategy, a notification observer, and a repository interface.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-19-drill-q1", "type": "mcq",
      "prompt": "You are asked to design a food-delivery system's classes and have never prepared that specific problem. What is the most reliable approach?",
      "options": [
        {"id":"a","text":"Recall the closest problem you memorised and reproduce its classes"},
        {"id":"b","text":"Run the six-step framework and recombine known building blocks: order lifecycle (State), rider assignment (allocation Strategy), pricing/surge (Strategy), status updates (Observer), inventory holds (reservation with TTL), and persistence behind repository interfaces"},
        {"id":"c","text":"Start by listing every design pattern that might apply"},
        {"id":"d","text":"Ask the interviewer to pick a problem you have prepared"}
      ],
      "correct": "b",
      "explanation": "Every new LLD problem is a recombination of the same primitives. The framework guarantees you cover requirements, entities, relationships, interfaces, concurrency, and extensibility regardless of the domain — which is why procedure beats memorisation." }
] }
```

## Key takeaways

- **Procedure beats memorisation.** The six steps and the requirement→design-move table are what let you handle a problem you have never seen.
- **Every design decision comes with a cost — say it.** "Composition here, because these axes vary independently; the cost is one more object to wire" is what a design review sounds like.
- **Concurrency is the most-skipped, most-asked step.** Name the shared mutable state and its protection before you are asked, and remember that only the database enforces anything across servers.
- **Restraint is a senior signal.** After a full pattern catalogue, deliberately staying concrete and naming where the extension point *would* go beats abstracting everything.
- **Practise out loud, on a clock, weekly.** Fifteen minutes on an unfamiliar problem, using nothing but the framework and the building blocks from lessons 9–18.
