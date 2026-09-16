---
kind: lesson
id_key: interview-prep-45/lld-01-framework
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "The LLD Interview Framework and UML"
position: 1
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Low-level design is the other half of the design interview: not "how many servers", but "what classes exist, what does each one own, and how do they talk". A typical round is 45–60 minutes — "design a parking lot", "design Splitwise", "design an elevator system" — and it is graded on whether your object model is *clean, extensible, and correct under concurrency*, not on how many patterns you name.

Like HLD, it has a fixed procedure. Learn the procedure once and every problem in this section becomes an instance of it.

> **The six steps** — **R**equirements, **E**ntities, **R**elationships, **I**nterfaces, **C**oncurrency, **E**xtensibility. (Mnemonic: *"Real Engineers Rarely Ignore Corner Errors."*)

## What an LLD interview is really testing

Four signals, in the order interviewers weight them:

| Signal | What "good" looks like | What "bad" looks like |
|---|---|---|
| **Clean object model** | Each class has one clear responsibility and a name a domain expert would recognise | A `Manager` god-class doing everything; classes named `Helper`, `Util`, `Data` |
| **Right relationships** | Composition where the part cannot exist alone; interfaces at the boundaries you expect to vary | Deep inheritance chains; concrete classes wired together everywhere |
| **Extensibility** | "Add a new vehicle type / payment method / notification channel" is a new class, not an edited `if` chain | Every new feature requires editing five existing methods |
| **Correctness under concurrency** | You name the shared mutable state and how it is protected | Two users book the same seat and nobody notices |

Two behaviours that separate strong candidates:

- **They keep the design small and complete rather than large and half-finished.** Ten well-shaped classes with real method signatures beat thirty class names with no bodies.
- **They drive the conversation with the domain, not with pattern names.** "A `ParkingSpot` knows its size and whether it is free" is design. "I'll use the Strategy pattern" without saying what varies is vocabulary.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-signal-q1", "type": "mcq",
      "prompt": "Which is the strongest indicator of a good LLD answer?",
      "options": [
        {"id":"a","text":"Naming as many of the 23 GoF patterns as the design can accommodate"},
        {"id":"b","text":"Adding a new vehicle type or payment method requires adding a class, not editing existing conditionals — the model is open for extension and closed for modification"},
        {"id":"c","text":"Having the largest number of classes"},
        {"id":"d","text":"Using inheritance for every relationship between concepts"}
      ],
      "correct": "b",
      "explanation": "Extensibility under a plausible change is the property interviewers probe (\"now support electric vehicles\"). Pattern name-dropping without a varying axis, class count, and inheritance-by-default all correlate with weaker designs." }
] }
```

## Step 1 — Requirements: actors, use cases, scope

Five minutes, and it works exactly like HLD's first step but at the object level.

**Ask about the actors.** Who uses this? For a parking lot: a driver, an attendant, an admin. Each actor's needs become use cases, and use cases become methods.

**Write the use cases as verbs.** Park a vehicle, retrieve a vehicle, pay, view availability. These map almost one-to-one onto the public methods of your top-level class, which is why they are worth writing down.

**Ask the questions that change the model**, not the ones that don't:

| Question | Why it changes classes |
|---|---|
| How many kinds of X are there, and will more be added? | Decides an enum vs. a class hierarchy vs. a strategy |
| Is there more than one of Y? (floors, branches, currencies) | Decides whether Y is a field or a first-class entity |
| Do we need history, or only current state? | Decides whether events/records exist as entities |
| Who can do what? | Decides where authorisation lives |
| Is this single-process or concurrent? | Decides locks, immutability, atomic operations |
| In-memory or persisted? | Decides repository interfaces |

**Then state the scope cut**: "I'll model parking, unparking, spot allocation and fee calculation in memory; I'll define a `PaymentProcessor` interface but not implement a real gateway."

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-requirements-q1", "type": "mcq",
      "prompt": "In an LLD round, which clarifying question most directly changes the class model?",
      "options": [
        {"id":"a","text":"\"What programming language should I use?\""},
        {"id":"b","text":"\"Will new vehicle types be added over time, and does fee calculation differ per type?\" — the answer decides between an enum, a subclass hierarchy, and a pluggable pricing strategy"},
        {"id":"c","text":"\"How many users will the system have?\""},
        {"id":"d","text":"\"Should I write tests?\""}
      ],
      "correct": "b",
      "explanation": "Questions about what varies and how often decide your extension points. Scale questions belong to HLD; language and tests don't change the model." }
] }
```

## Step 2 — Entities: from nouns to classes

**Noun extraction** is the mechanical starting point: read the requirements and list every noun. "A *driver* parks a *vehicle* in a *spot* on a *floor* of a *parking lot*, gets a *ticket*, and makes a *payment*." That's six candidate classes.

Then refine, because not every noun is a class:

| Noun is… | Model it as |
|---|---|
| A thing with identity and lifecycle | **Entity class** (`Vehicle`, `Ticket`, `User`) |
| A value with no identity | **Value object**, ideally immutable (`Money`, `TimeSlot`, `Address`) |
| A fixed, small, closed set | **Enum** (`VehicleSize`, `SpotStatus`, `PaymentStatus`) |
| A behaviour that varies | **Interface + implementations** (`PricingStrategy`, `NotificationChannel`) |
| A property of another thing | **A field**, not a class (`colour`, `licencePlate`) |
| An orchestration of several entities | **Service** (`ParkingLotService`, `BookingService`) |
| A collection with lookup rules | **Repository** (`SpotRepository`, `TicketRepository`) |

Two habits worth adopting immediately:

- **Prefer enums over booleans and magic strings.** `SpotStatus.OCCUPIED` beats `is_taken = True`, because tomorrow there is a `RESERVED` and an `OUT_OF_SERVICE` state and the boolean cannot grow.
- **Make value objects immutable.** `Money`, `Point`, `TimeRange` never change after construction; that removes a whole class of aliasing bugs and makes them safe to share across threads.

Here is the noun list turned into skeleton code — small, complete, and runnable, which is exactly the level of detail an interviewer wants at this stage:

```python
from dataclasses import dataclass
from enum import Enum


class VehicleSize(Enum):
    MOTORCYCLE = 1
    COMPACT = 2
    LARGE = 3


class SpotStatus(Enum):
    FREE = "free"
    OCCUPIED = "occupied"
    OUT_OF_SERVICE = "out_of_service"


@dataclass(frozen=True)          # value object: immutable, no identity
class Money:
    paise: int

    def __add__(self, other: "Money") -> "Money":
        return Money(self.paise + other.paise)

    def __str__(self) -> str:
        return f"Rs {self.paise / 100:.2f}"


@dataclass
class Vehicle:                    # entity: identified by its plate
    plate: str
    size: VehicleSize


class ParkingSpot:                # entity with lifecycle and state
    def __init__(self, spot_id: str, size: VehicleSize):
        self.spot_id = spot_id
        self.size = size
        self.status = SpotStatus.FREE
        self.vehicle: Vehicle | None = None

    def can_fit(self, vehicle: Vehicle) -> bool:
        return self.status == SpotStatus.FREE and self.size.value >= vehicle.size.value

    def occupy(self, vehicle: Vehicle) -> None:
        if not self.can_fit(vehicle):
            raise ValueError(f"spot {self.spot_id} cannot take {vehicle.plate}")
        self.vehicle, self.status = vehicle, SpotStatus.OCCUPIED

    def release(self) -> None:
        self.vehicle, self.status = None, SpotStatus.FREE


spot = ParkingSpot("A-01", VehicleSize.COMPACT)
bike = Vehicle("KA-01-1234", VehicleSize.MOTORCYCLE)
truck = Vehicle("KA-05-9999", VehicleSize.LARGE)

assert spot.can_fit(bike) and not spot.can_fit(truck)   # a compact spot fits a bike, not a truck
spot.occupy(bike)
assert spot.status is SpotStatus.OCCUPIED and not spot.can_fit(bike)
spot.release()
assert spot.status is SpotStatus.FREE
print("entity model behaves:", Money(4990) + Money(1010))
```

```java +
import java.util.Objects;

public class Main {
    enum VehicleSize { MOTORCYCLE(1), COMPACT(2), LARGE(3);
        final int rank;
        VehicleSize(int rank) { this.rank = rank; }
    }

    enum SpotStatus { FREE, OCCUPIED, OUT_OF_SERVICE }

    // Value object: final fields, no identity, value-based equality.
    static final class Money {
        private final long paise;
        Money(long paise) { this.paise = paise; }
        Money plus(Money other) { return new Money(this.paise + other.paise); }
        @Override public boolean equals(Object o) {
            return o instanceof Money m && m.paise == paise;
        }
        @Override public int hashCode() { return Objects.hash(paise); }
        @Override public String toString() { return String.format("Rs%.2f", paise / 100.0); }
    }

    record Vehicle(String plate, VehicleSize size) {}

    static class ParkingSpot {
        private final String spotId;
        private final VehicleSize size;
        private SpotStatus status = SpotStatus.FREE;
        private Vehicle vehicle;

        ParkingSpot(String spotId, VehicleSize size) { this.spotId = spotId; this.size = size; }

        boolean canFit(Vehicle v) {
            return status == SpotStatus.FREE && size.rank >= v.size().rank;
        }

        // Idiomatic Java: signal the violated precondition with an exception type
        // callers can catch, rather than returning a boolean nobody checks.
        void occupy(Vehicle v) {
            if (!canFit(v)) throw new IllegalStateException("spot " + spotId + " cannot take " + v.plate());
            this.vehicle = v;
            this.status = SpotStatus.OCCUPIED;
        }

        void release() { this.vehicle = null; this.status = SpotStatus.FREE; }
        SpotStatus status() { return status; }
    }

    public static void main(String[] args) {
        ParkingSpot spot = new ParkingSpot("A-01", VehicleSize.COMPACT);
        Vehicle bike = new Vehicle("KA-01-1234", VehicleSize.MOTORCYCLE);
        Vehicle truck = new Vehicle("KA-05-9999", VehicleSize.LARGE);

        assert spot.canFit(bike) && !spot.canFit(truck);
        spot.occupy(bike);
        assert spot.status() == SpotStatus.OCCUPIED;
        spot.release();
        assert spot.status() == SpotStatus.FREE;
        System.out.println("entity model behaves: " + new Money(4990).plus(new Money(1010)));
    }
}
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-entities-q1", "type": "mcq",
      "prompt": "You are modelling a parking spot's state. Why is `SpotStatus` (an enum) better than an `isOccupied` boolean?",
      "options": [
        {"id":"a","text":"Enums use less memory than booleans"},
        {"id":"b","text":"The set of states is genuinely open — RESERVED, OUT_OF_SERVICE, CLEANING will appear — and a boolean forces you to add parallel flags with impossible combinations, while an enum grows by one case"},
        {"id":"c","text":"Booleans cannot be compared"},
        {"id":"d","text":"Enums are required for the State pattern"}
      ],
      "correct": "b",
      "explanation": "Two booleans allow four combinations, two of which are nonsense. An enum makes illegal states unrepresentable and extends cleanly, which is why \"prefer enums over boolean flags\" is a standard LLD habit." }
] }
```

## Step 3 — Relationships and the UML you actually need

You will draw a class diagram. You need five arrows, not the whole UML specification.

```
 ┌──────────────────┐
 │   ParkingLot     │   class box: name / fields / methods
 ├──────────────────┤
 │ - name: str      │   -  private
 │ + floors: List   │   +  public
 ├──────────────────┤
 │ + park(v): Ticket│
 └──────────────────┘

RELATIONSHIPS

  A ──────▷ B     inheritance      "A IS-A B"          Car ──▷ Vehicle
  A ┈┈┈┈┈▷ B      implements       "A fulfils B"       CreditCard ┈▷ PaymentMethod
  A ◆────── B     composition      "A OWNS B, B dies with A"   Floor ◆── Spot
  A ◇────── B     aggregation      "A HAS B, B lives on"       Team ◇── Player
  A ───────> B    association      "A uses/knows B"    Order ──> Customer
  A ┈┈┈┈┈┈> B     dependency       "A mentions B briefly (a parameter)"
```

**Multiplicity** goes on the ends: `1`, `0..1`, `1..*`, `*`. `ParkingLot 1 ◆── 1..* Floor` reads "one lot owns at least one floor".

The distinction interviewers actually check is **composition vs aggregation**:

- **Composition** — the part cannot exist without the whole and is created/destroyed with it. Deleting a `Floor` deletes its `ParkingSpot`s. A `House` composes its `Room`s.
- **Aggregation** — the part exists independently and can be shared. Deleting a `Team` does not delete its `Player`s. A `Playlist` aggregates `Song`s.

Ask yourself: *"if the whole is destroyed, does this part still make sense?"* Yes → aggregation. No → composition.

A sequence diagram is worth sketching once, for the main use case, because it forces you to commit to who calls whom:

```
Driver        ParkingLotService     SpotAllocator     TicketRepo
  │  park(vehicle)  │                     │                │
  ├────────────────>│                     │                │
  │                 │  findSpot(vehicle)  │                │
  │                 ├────────────────────>│                │
  │                 │<─── spot ───────────┤                │
  │                 │  spot.occupy(vehicle)                │
  │                 │  save(ticket)       │                │
  │                 ├─────────────────────────────────────>│
  │<──── ticket ────┤                     │                │
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-uml-q1", "type": "mcq",
      "prompt": "A `Playlist` contains `Song` objects that also appear in other playlists and exist independently in the library. Which relationship is it?",
      "options": [
        {"id":"a","text":"Composition — the playlist owns the songs"},
        {"id":"b","text":"Aggregation — the songs exist independently of any playlist and are shared, so deleting the playlist must not delete them"},
        {"id":"c","text":"Inheritance — a playlist is a kind of song collection"},
        {"id":"d","text":"Dependency — the playlist only mentions songs as parameters"}
      ],
      "correct": "b",
      "explanation": "The lifecycle test settles it: destroy the whole and ask whether the part still makes sense. Songs outlive playlists, so it is aggregation (a hollow diamond); rooms do not outlive their house, so that is composition." }
] }
```

## Steps 4–6 — Interfaces, concurrency, extensibility

**Step 4 — Interfaces and method signatures.** Now write the *public* surface of each class: what it accepts and returns. This is where design errors surface.

```
from abc import ABC, abstractmethod

class PricingStrategy(ABC):                       # what varies → an interface
    @abstractmethod
    def price(self, hours: float, size: "VehicleSize") -> int: ...

class ParkingLotService:                          # orchestration → a service
    def park(self, vehicle: "Vehicle") -> "Ticket": ...
    def unpark(self, ticket_id: str) -> int: ...   # returns fee in paise
    def availability(self) -> dict["VehicleSize", int]: ...
```

Three rules for this step:

- **Program to interfaces at the axes you expect to vary** — pricing, payment, notification, storage — and to concrete classes everywhere else. An interface with exactly one implementation and no plausible second one is speculative complexity.
- **Return domain objects, not primitives**, when the primitive would be ambiguous. `Money` beats `int`; `TicketId` beats `str` when both a ticket id and a plate are strings.
- **Push validation into constructors** so an object cannot exist in an invalid state.

**Step 5 — Concurrency.** Say out loud: *"the shared mutable state here is the set of free spots"* (or seats, or inventory), then say how it is protected. The full treatment is the Concurrency lesson in this section, but the interview-level answer is always one of:

| Situation | Mechanism |
|---|---|
| Two threads may take the same slot/seat | A lock around check-and-take, or an atomic compare-and-set |
| A counter shared across threads | An atomic integer, not `count += 1` |
| Data shared but never mutated | Immutability — no lock needed at all |
| Independent items | A lock per item, not one global lock |
| Multi-process / multi-server | The database enforces it: unique constraint or conditional `UPDATE` |

**Step 6 — Extensibility.** Close by walking one change through your design out loud: *"if we add electric vehicles with charging spots, I add an `ELECTRIC` size and a `ChargingSpot` subclass; the allocator is unchanged because it only asks `can_fit`."* If the walk-through requires editing five existing classes, redesign before the interviewer asks.

The three questions to pre-empt: *add a new type* (should be a new class), *add a new rule* (should be a new strategy), *add a new consumer of an event* (should be a new observer).

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-interfaces-q1", "type": "mcq",
      "prompt": "When should you introduce an interface rather than a concrete class in an LLD design?",
      "options": [
        {"id":"a","text":"For every class, so the design is maximally flexible"},
        {"id":"b","text":"At the axes you genuinely expect to vary — pricing rules, payment methods, notification channels, storage — where a second implementation is plausible or already required"},
        {"id":"c","text":"Only for classes that will be tested"},
        {"id":"d","text":"Never; interfaces belong in HLD"}
      ],
      "correct": "b",
      "explanation": "Interfaces buy substitutability where behaviour varies, and cost indirection everywhere else. An interface with one implementation and no plausible second is exactly the speculative abstraction reviewers mark down." }
] }
```

## Key takeaways

**The six steps and their outputs:**

| Step | Minutes | Output |
|---|---|---|
| 1. Requirements | 5 | Actors, use-case verbs, the questions that change the model, scope cut |
| 2. Entities | 8 | Nouns → entities / value objects / enums / services / repositories |
| 3. Relationships | 8 | Class diagram with the five arrows and multiplicities |
| 4. Interfaces | 10 | Real method signatures on the core classes; interfaces at varying axes |
| 5. Concurrency | 7 | Named shared mutable state + the mechanism protecting it |
| 6. Extensibility | 5 | One change walked through the design out loud |

**The habits, in one list:**

- Nouns become classes, verbs become methods, closed sets become enums, varying behaviour becomes an interface.
- Enums over booleans; immutable value objects over mutable bags of fields; validation in the constructor.
- Composition over inheritance, and use the lifecycle test to tell composition from aggregation.
- One responsibility per class, and no class named `Manager`, `Helper`, or `Util`.
- Name the shared mutable state and how it's protected — unprompted.
- Finish by walking a plausible new requirement through the design.

**What's next**: the OOP foundations and SOLID lessons make steps 2–4 rigorous, the pattern lessons give you the standard answers to "what varies here", the concurrency lesson covers step 5 properly, and lessons 9 onward run the whole framework end to end on the eight problems you are most likely to be asked.
