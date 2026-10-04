---
kind: quiz
id_key: interview-prep-45/test-lld
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Practice Test: Low-Level Design"
position: 19
estimated_minutes: 30
pass_percentage: 70
duration_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - checkpoints/04-quiz-week-4.md
questions:
  - id_key: interview-prep-45/quiz-week-4/q5
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Which design pattern lets you swap algorithms at runtime behind one interface — for example, several payment providers behind one checkout method?"
    options:
      - text: "Strategy"
        correct: true
      - text: "Singleton"
      - text: "Decorator"
      - text: "Observer"
    explanation: "Strategy wraps interchangeable behaviours behind one common interface, chosen at runtime. Decorator adds responsibilities, Observer broadcasts events to listeners, and Singleton restricts a class to exactly one instance."

  - id_key: interview-prep-45/test-lld/composition-vs-inheritance
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A design has `ElectricCar`, `PetrolCar`, `ElectricTruck`, and `PetrolTruck`, and now needs hybrid engines too. What's the underlying problem, and the fix?"
    options:
      - text: "Two things vary independently — power source and body type — through single-axis inheritance, so classes multiply; model each axis as a field instead"
        correct: true
      - text: "There aren't enough subclasses yet; add HybridCar and HybridTruck"
      - text: "The base Vehicle class needs more abstract methods"
      - text: "These should all become interfaces instead of classes"
    explanation: "A class tree can only cleanly express one axis of change. Every extra independent axis multiplies the class count — the fix is composition: give Vehicle an Engine field instead of a subclass per combination."

  - id_key: interview-prep-45/test-lld/interface-vs-abstract
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "A `Dog` and a `Boat` both need a `swim()` method, but a `Boat` is clearly not an `Animal`. What does this call for?"
    options:
      - text: "An abstract class, since both types share behaviour"
      - text: "An interface (or a Python Protocol) — this is a CAN-DO relationship between unrelated types, with no shared implementation"
        correct: true
      - text: "Multiple inheritance from a shared Animal base"
      - text: "A Singleton that both types depend on"
    explanation: "Abstract class means IS-A, sharing both a type relationship and some implementation. Interface means CAN-DO — unrelated types promising the same capability with no shared code, which is exactly the Dog/Boat situation."

  - id_key: interview-prep-45/test-lld/srp-test
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What's the sharpest test for whether a class violates the Single Responsibility Principle?"
    options:
      - text: "Whether the class has more than 200 lines of code"
      - text: "Whether more than one group of people could each independently ask for a change to it"
        correct: true
      - text: "Whether it has more than five public methods"
      - text: "Whether it implements more than one interface"
    explanation: "SRP is about how many distinct reasons a class has to change, not about size. A large class that only ever changes for one reason is fine; a small class three different teams keep editing is not."

  - id_key: interview-prep-45/test-lld/lsp-violation
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A `ReadOnlyCollection` extends `Collection` and throws an exception from `add()`. Which principle does this break?"
    options:
      - text: "Single Responsibility"
      - text: "Liskov Substitution — code holding a plain Collection can no longer safely call add(), breaking the substitution guarantee"
        correct: true
      - text: "Open/Closed"
      - text: "Dependency Inversion"
    explanation: "Throwing from a method the parent type promised would work breaks Liskov Substitution. The usual fix is splitting the interface into a read-only base and a separate mutable one."

  - id_key: interview-prep-45/test-lld/dip-ownership
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In Dependency Inversion, which layer should own and define the `OrderRepository` interface?"
    options:
      - text: "The database layer, since it's the one that implements it"
      - text: "The high-level business layer — the interface is written in business language, and the low-level adapter implements it"
        correct: true
      - text: "A shared utility package that neither layer owns"
      - text: "Whichever layer happens to have fewer classes"
    explanation: "If the persistence layer owns the interface, the business layer still points at persistence and nothing has actually inverted. The business layer owning the interface is what lets the adapter be swapped freely."

  - id_key: interview-prep-45/test-lld/singleton-lock
    type: mcq
    difficulty: advanced
    points: 15
    prompt: "Why does a thread-safe Singleton use double-checked locking instead of locking on every single access?"
    options:
      - text: "To make the singleton object immutable"
      - text: "So the lock is only ever taken during the first, racing construction — later accesses skip locking entirely, while the inner check stops two threads that both passed the outer check from building two instances"
        correct: true
      - text: "To allow more than one instance to exist when needed"
      - text: "Because constructors cannot be synchronized in most languages"
    explanation: "A single check alone races; locking on every access works but pays a permanent cost on a read-mostly path. Check, lock, check again gives correctness while paying the synchronisation cost only once."

  - id_key: interview-prep-45/test-lld/proxy-vs-decorator
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Proxy and Decorator have nearly identical class diagrams. What actually tells them apart?"
    options:
      - text: "Proxy can only wrap one object; Decorator can wrap several"
      - text: "Intent: Decorator adds new behaviour and the caller deliberately stacks it; Proxy controls access to the same behaviour and is usually invisible to the caller"
        correct: true
      - text: "Decorators run at compile time, proxies at runtime"
      - text: "Proxies never implement the same interface as the object they wrap"
    explanation: "These patterns are classified by intent, not by shape. Decorator deliberately adds behaviour; Proxy controls access — lazy loading, permission checks, caching, or a remote stand-in — usually without the caller even knowing." 

  - id_key: interview-prep-45/test-lld/observer-leak
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What's the most common memory bug in an Observer implementation?"
    options:
      - text: "The subject stores too many past events"
      - text: "Observers are never unsubscribed, so the subject's strong references keep them alive indefinitely"
        correct: true
      - text: "Observers get notified in the wrong order"
      - text: "The observer interface has too many methods"
    explanation: "A long-lived subject holding references to short-lived observers stops garbage collection from ever cleaning them up. Every subscribe needs a matching unsubscribe, or weak references instead."

  - id_key: interview-prep-45/test-lld/state-vs-strategy
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "What's the clearest way to tell Strategy and State apart?"
    options:
      - text: "Strategy uses interfaces; State uses enums"
      - text: "With Strategy, whoever's using the object picks an independent algorithm; with State, the object's own states drive transitions between each other, modelling a lifecycle"
        correct: true
      - text: "Strategy is a creational pattern, State is a structural one"
      - text: "State can only ever have exactly two possible values"
    explanation: "Strategy and State have nearly identical class diagrams, so intent separates them. Strategies are picked from outside and stand alone; states know their own successors and drive transitions from within."

  - id_key: interview-prep-45/test-lld/multiserver-lock
    type: mcq
    difficulty: advanced
    points: 15
    prompt: "A booking service runs on five separate servers. Which mechanism actually stops a seat from being double-booked?"
    options:
      - text: "A synchronized method or a threading.Lock inside the booking service"
      - text: "A conditional database write, checked and applied atomically, with a unique constraint as a backstop — an in-process lock only synchronises threads within one single process"
        correct: true
      - text: "Making the Seat class immutable"
      - text: "Ordering in-process locks by seat id"
    explanation: "In-process locks are invisible to a different process entirely. Only the database, which every server shares, can arbitrate between them — through a conditional write and a unique constraint."

  - id_key: interview-prep-45/test-lld/deadlock-ordering
    type: mcq
    difficulty: advanced
    points: 15
    prompt: "Two threads transfer money in opposite directions between accounts A and B, each locking the source account and then the destination. What's the standard fix?"
    options:
      - text: "Use one single global lock for every transfer in the system"
      - text: "Lock the two accounts in a fixed global order — by account id, for instance — which breaks the circular-wait condition while still allowing unrelated transfers to run in parallel"
        correct: true
      - text: "Make the Account class immutable"
      - text: "Retry the transfer automatically if it seems to be taking too long"
    explanation: "A single global lock works but forces every transfer in the system to wait its turn. Locking in a consistent order removes the circular wait with no loss of parallelism."

  - id_key: interview-prep-45/test-lld/lru-structures
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why does an O(1) LRU cache need both a hash map and a doubly linked list?"
    options:
      - text: "The list stores the values and the map stores the keys"
      - text: "The map gives O(1) key lookup but no ordering; the doubly linked list gives O(1) removal and re-insertion for tracking recency, but only O(n) search on its own — each one supplies exactly what the other is missing"
        correct: true
      - text: "The list is only needed for iterating over the cache"
      - text: "A singly linked list would work exactly as well"
    explanation: "The map holds key to node so any node can be found instantly. The doubly linked structure lets that node be unlinked in O(1), which a singly linked list can't do, since it has no back-pointer to the previous node."

  - id_key: interview-prep-45/test-lld/seat-hold-ttl
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Why does a seat hold in a ticket-booking system need an expiry timestamp instead of a plain `is_locked` boolean?"
    options:
      - text: "Timestamps are easier for a database to index"
      - text: "A boolean set by a client that then crashes or abandons checkout locks the seat forever; an expiry means the hold releases itself, with no cleanup step required for correctness"
        correct: true
      - text: "Booleans can't be stored in a relational database"
      - text: "So that multiple users could hold the same seat at once"
    explanation: "This is the same reasoning as a TTL on any distributed lock — the holder can never fully be trusted to release it. An expiry makes an abandoned checkout self-healing." 

  - id_key: interview-prep-45/test-lld/junction-table
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "You're modelling posts and tags, where a post can have many tags and a tag can apply to many posts. What's the right schema shape?"
    options:
      - text: "A `tag_ids` array column directly on the posts table"
      - text: "A separate junction table holding a post_id and a tag_id together as its primary key"
        correct: true
      - text: "A post_id column added directly onto the tags table"
      - text: "Duplicate each tag's data into every post row that references it"
    explanation: "Any genuine many-to-many relationship needs a junction table with a foreign key pointing each way. An array column on one side is the classic shortcut, and it also breaks first normal form."
---

The seventeen lessons before this one covered the framework, the OOP foundations, SOLID, every major design pattern, concurrency, and ten worked problems. This test checks whether that knowledge is actually retrievable under a clock — the same condition a real interview puts you in.
