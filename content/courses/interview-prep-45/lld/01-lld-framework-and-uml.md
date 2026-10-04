---
kind: lesson
id_key: interview-prep-45/lld-01-framework
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "The LLD Interview Framework and UML"
position: 1
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

High-level design asks "how many servers do you need?" Low-level design asks a completely different question: "what classes exist, what does each one own, and how do they talk to each other?"

Picture being asked to design a parking lot, or an elevator, or a movie-ticket app, in about 45 minutes. The interviewer is not counting how many design patterns you can name. They are watching whether your classes are clean, whether you could add a new feature without rewriting everything, and whether you know what breaks when two people use the system at the exact same moment.

Like HLD, this has a fixed order of steps. Learn the order once, and every problem in this section becomes the same six steps with different nouns.

> **The six steps** — **R**equirements, **E**ntities, **R**elationships, **I**nterfaces, **C**oncurrency, **E**xtensibility. Say it as *"Real Engineers Rarely Ignore Corner Errors."*

## What the interviewer is actually grading

Picture the interviewer holding a scorecard. It has four rows, and they matter in this order.

| They're checking | Good looks like | Bad looks like |
|---|---|---|
| **A clean object model** | Each class does one clear job, with a name a normal person would recognise | One giant `Manager` class doing everything; classes named `Helper`, `Util`, `Data` |
| **Sensible relationships** | Parts that can't exist without their whole are owned by it; the pieces likely to change sit behind an interface | Long inheritance chains; everything wired directly to everything else |
| **Room to grow** | "Add a new vehicle type" or "add a new payment method" means writing one new class | Adding anything means editing five old files and hoping nothing breaks |
| **Correctness when two things happen at once** | You can say out loud which piece of shared data is at risk and how it's protected | Two users book the same seat and the bug ships to production |

Two habits separate people who pass from people who don't:

- **They build small and finished, not big and half-done.** Ten classes with real methods beat thirty class names with nothing inside them.
- **They talk about the actual problem, not about pattern names.** "A `ParkingSpot` knows its size and whether it's free" is design. Saying "I'll use the Strategy pattern" without saying what actually varies is just vocabulary.

> **Remember:** the strongest signal in an LLD interview is that a plausible new requirement fits in as one new class, not five edited ones.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-signal-q1", "type": "mcq",
      "prompt": "Which of these is the strongest sign of a good LLD answer?",
      "options": [
        {"id":"a","text":"Naming as many of the 23 classic design patterns as will fit"},
        {"id":"b","text":"Adding a new vehicle type or payment method means adding one class, not editing an existing if/else chain"},
        {"id":"c","text":"Having the largest possible number of classes"},
        {"id":"d","text":"Using inheritance for every relationship in the design"}
      ],
      "correct": "b",
      "explanation": "Interviewers test what happens when they add a plausible new requirement mid-interview. Name-dropping patterns, piling up classes, and reaching for inheritance by default are all things weaker designs tend to do." }
] }
```

## Step 1 — Requirements: who uses this, and what do they do

Spend about five minutes here. It works the same way HLD's first step does, just one level closer to the code.

**Ask who the actors are.** For a parking lot: a driver, an attendant, an admin. Each actor's needs turn into use cases, and use cases turn into the public methods on your main class.

**Write the use cases as verbs.** Park a vehicle. Retrieve a vehicle. Pay. Check availability. These map almost directly onto the methods you'll write later, which is exactly why writing them down first is worth the minute it takes.

**Ask questions that actually change the design**, and skip the ones that don't:

| Question | Why it matters |
|---|---|
| How many kinds of X are there, and will more show up later? | Decides between an enum, a family of classes, or a pluggable strategy |
| Is there more than one Y? (floors, branches, currencies) | Decides whether Y is just a field, or its own class |
| Do we need history, or only the current state? | Decides whether "events" need to exist as their own objects |
| Who is allowed to do what? | Decides where permission checks live |
| Is this one process, or many at once? | Decides whether you need locks, or immutable data, or database-level checks |
| Does this live in memory, or get saved somewhere? | Decides whether you need a repository interface |

**Then say the scope out loud**: "I'll build parking, un-parking, spot assignment, and fee calculation in memory. I'll define a `PaymentProcessor` interface, but I won't wire up a real payment gateway."

> **Remember:** a question like "will this change later?" is the interviewer handing you your extension point. Use it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-requirements-q1", "type": "mcq",
      "prompt": "Which clarifying question most directly changes your class design?",
      "options": [
        {"id":"a","text":"\"What programming language should I use?\""},
        {"id":"b","text":"\"Will new vehicle types get added later, and does the fee change per type?\" — the answer decides between an enum, a family of subclasses, and a pluggable pricing strategy"},
        {"id":"c","text":"\"How many users will the system have?\""},
        {"id":"d","text":"\"Should I write tests?\""}
      ],
      "correct": "b",
      "explanation": "Questions about what might change and how often decide where your extension points go. Scale questions belong in an HLD interview; language and testing habits don't reshape the class model." }
] }
```

## Step 2 — Entities: turning nouns into classes

**Start by listing every noun.** "A *driver* parks a *vehicle* in a *spot* on a *floor* of a *parking lot*, gets a *ticket*, and makes a *payment*." That sentence alone hands you six candidate classes.

Not every noun deserves to be a class, though. Sort them:

| If the noun is… | Model it as… |
|---|---|
| Something with an identity that changes over time | An **entity** (`Vehicle`, `Ticket`, `User`) |
| A value with no identity of its own | A **value object**, ideally one that never changes (`Money`, `TimeSlot`, `Address`) |
| A small, fixed set of options | An **enum** (`VehicleSize`, `SpotStatus`, `PaymentStatus`) |
| Behaviour that might vary | An **interface** with several implementations (`PricingStrategy`, `NotificationChannel`) |
| Just a detail of something else | A plain **field**, not a class (`colour`, `licencePlate`) |
| Something that coordinates several other things | A **service** (`ParkingLotService`, `BookingService`) |
| A collection you need to search | A **repository** (`SpotRepository`, `TicketRepository`) |

Two habits worth picking up right away:

- **Reach for an enum before a boolean or a bare string.** `SpotStatus.OCCUPIED` beats `is_taken = True`, because tomorrow there's a `RESERVED` status and an `OUT_OF_SERVICE` status, and a boolean has nowhere to put them.
- **Make value objects unchangeable.** `Money`, `Point`, `TimeRange` should never change after they're built. That removes a whole category of bugs where two things secretly share the same mutable object, and it makes those objects safe to hand to another thread.

Here's the noun list turned into small, runnable code — about the level of detail an interviewer wants to see on the whiteboard:

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


@dataclass(frozen=True)          # value object: never changes, has no identity of its own
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


class ParkingSpot:                # entity: has a lifecycle
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

    // Value object: final fields, no identity, equality based on the value itself.
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

        // Idiomatic Java: throw an exception the caller can catch, instead of
        // returning a boolean that's easy to ignore.
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

> **Remember:** if a "thing" in your design is really just two booleans pretending to be a state, turn it into one enum before you write another line.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-entities-q1", "type": "mcq",
      "prompt": "You're modelling whether a parking spot is free. Why pick an enum like `SpotStatus` over a plain `isOccupied` boolean?",
      "options": [
        {"id":"a","text":"Enums use less memory than booleans"},
        {"id":"b","text":"More statuses are coming — RESERVED, OUT_OF_SERVICE, CLEANING — and a boolean would force you to bolt on extra flags that can combine into nonsense, while an enum just grows by one case"},
        {"id":"c","text":"Booleans cannot be compared to each other"},
        {"id":"d","text":"Enums are required by the State pattern"}
      ],
      "correct": "b",
      "explanation": "Two booleans give you four combinations, and at least one of them makes no sense. An enum only ever allows real states, and it grows cleanly — that's why \"reach for an enum, not a boolean\" is a habit worth having." }
] }
```

## Step 3 — Relationships and the UML you'll actually use

You will draw a class diagram at some point. You need five arrows for it, not the full UML spec.

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

Put **multiplicity** on each end of an arrow: `1`, `0..1`, `1..*`, `*`. `ParkingLot 1 ◆── 1..* Floor` reads as "one lot owns at least one floor."

The one distinction interviewers actually check for is **composition vs. aggregation**. Picture it this way:

- **Composition** — think of a house and its rooms. A room without its house makes no sense. Delete the `Floor`, and its `ParkingSpot`s go with it.
- **Aggregation** — think of a sports team and its players. Delete the `Team`, and the `Player`s are still real people who play elsewhere. A `Playlist` works the same way with its `Song`s.

Ask yourself one question to tell them apart: *if I destroy the whole thing, does the part still make sense on its own?* Yes → aggregation. No → composition.

Sketching a sequence diagram for the main use case is also worth thirty seconds, because it forces you to decide who calls whom:

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

> **Remember:** ask "does the part still make sense if the whole is gone?" A room doesn't survive its house; a song survives its playlist.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-uml-q1", "type": "mcq",
      "prompt": "A `Playlist` holds `Song` objects that also appear in other playlists and exist in the music library on their own. What relationship is that?",
      "options": [
        {"id":"a","text":"Composition — the playlist owns the songs"},
        {"id":"b","text":"Aggregation — the songs exist on their own and are shared across playlists, so deleting one playlist must never delete the songs"},
        {"id":"c","text":"Inheritance — a playlist is a kind of song collection"},
        {"id":"d","text":"Dependency — the playlist only mentions songs briefly, as a parameter"}
      ],
      "correct": "b",
      "explanation": "Ask the lifecycle question: destroy the whole, and does the part still make sense? Songs outlive playlists, so this is aggregation (a hollow diamond). Rooms don't outlive a house, so that's composition." }
] }
```

## Steps 4–6 — Interfaces, concurrency, extensibility

**Step 4 — write the public surface of each class.** What does it accept, and what does it return? Design mistakes usually surface right here, the moment you write it down.

```
from abc import ABC, abstractmethod

class PricingStrategy(ABC):                       # something that varies → an interface
    @abstractmethod
    def price(self, hours: float, size: "VehicleSize") -> int: ...

class ParkingLotService:                          # something that coordinates → a service
    def park(self, vehicle: "Vehicle") -> "Ticket": ...
    def unpark(self, ticket_id: str) -> int: ...   # returns the fee, in paise
    def availability(self) -> dict["VehicleSize", int]: ...
```

Three rules for this step:

- **Only put an interface where you genuinely expect change** — pricing, payment, notifications, storage — and use plain concrete classes everywhere else. An interface with exactly one implementation and no realistic second one is just extra work with no payoff.
- **Return real objects, not raw primitives**, whenever a primitive could be misread. `Money` is clearer than a bare `int`; a `TicketId` is clearer than a `str` when a plate number is also a string.
- **Check for valid input in the constructor**, so an object can never exist in a broken state in the first place.

**Step 5 — concurrency.** Say out loud: *"the shared mutable state here is the set of free spots"* — or seats, or inventory, whatever fits the problem — then say what protects it. The full treatment lives in the Concurrency lesson later in this section, but at interview speed, your answer is always one of these:

| Situation | What protects it |
|---|---|
| Two threads might grab the same slot or seat | A lock around "check, then take," or an atomic compare-and-swap |
| A number shared across threads | An atomic counter, never a plain `count += 1` |
| Data that's shared but never changed | Nothing needed — it can't go wrong if it never changes |
| Independent items | A lock per item, not one giant lock for everything |
| Multiple processes or servers | The database enforces it: a unique constraint, or a conditional `UPDATE` |

**Step 6 — extensibility.** Close by walking a plausible new requirement through your design out loud: *"if we add electric vehicles with charging spots, I add an `ELECTRIC` size and a `ChargingSpot` subclass. The allocator doesn't change, because it only ever asks `can_fit`."* If that walkthrough means editing five existing classes, redesign before the interviewer points it out.

Three shapes of change to prepare for: *a new type* should mean a new class, *a new rule* should mean a new strategy, and *a new listener for an event* should mean a new observer.

> **Remember:** an interface with one implementation and no plausible second one is a cost with no benefit. Only add one where change is actually expected.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-01-interfaces-q1", "type": "mcq",
      "prompt": "When should you reach for an interface instead of a plain concrete class?",
      "options": [
        {"id":"a","text":"For every class, so the design stays as flexible as possible"},
        {"id":"b","text":"At the exact points you genuinely expect to change — pricing rules, payment methods, notification channels, storage — where a second implementation is likely or already needed"},
        {"id":"c","text":"Only for classes that will be unit tested"},
        {"id":"d","text":"Never; interfaces belong to HLD, not LLD"}
      ],
      "correct": "b",
      "explanation": "Interfaces pay off wherever behaviour genuinely varies, and cost you extra layers everywhere else. An interface with one implementation and no realistic second one is exactly the kind of over-design reviewers mark down." }
] }
```

## Quick recap

**The six steps and roughly how long each takes:**

| Step | Minutes | What you produce |
|---|---|---|
| 1. Requirements | 5 | Actors, use-case verbs, the questions that matter, a stated scope |
| 2. Entities | 8 | Nouns sorted into entities, value objects, enums, services, repositories |
| 3. Relationships | 8 | A class diagram with the five arrows and multiplicities |
| 4. Interfaces | 10 | Real method signatures on the core classes; interfaces where things vary |
| 5. Concurrency | 7 | The shared mutable state, named, plus how it's protected |
| 6. Extensibility | 5 | One new requirement, walked through the design out loud |

- Nouns become classes, verbs become methods, small fixed sets become enums, changing behaviour becomes an interface.
- Prefer enums over booleans, prefer unchangeable value objects over mutable bags of fields, and validate inside the constructor.
- Prefer composition over inheritance, and use "does the part survive the whole?" to tell composition from aggregation.
- One job per class. No class named `Manager`, `Helper`, or `Util`.
- Say out loud which piece of state is shared and mutable, and how it's protected — before anyone asks.
- Finish by walking a plausible new requirement through your design.

**What's next**: the OOP and SOLID lessons make steps 2 through 4 much sharper. The pattern lessons give you ready answers to "what varies here." The concurrency lesson covers step 5 properly. And from lesson 9 onward, you'll run this whole framework end to end on the problems you're most likely to be asked.
