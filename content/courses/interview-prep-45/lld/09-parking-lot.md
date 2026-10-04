---
kind: lesson
id_key: interview-prep-45/lld-09-parking-lot
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design a Parking Lot"
position: 9
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

This is the most-asked LLD question there is, and nearly every other problem in this section is really a variation of it. It's popular for a good reason: it's small enough to finish in about 45 minutes, but rich enough to show whether you can model a real domain, pick the right places to leave room for change, and reason about what happens when two things happen at once.

This lesson runs the full six-step framework from start to finish. Every problem after this one follows the same shape.

## Step 1 — Requirements and scope

**What the system needs to do** (the verbs, coming from the actors: a driver, an attendant, an admin):

- Park a vehicle: find a spot that fits, assign it, hand over a ticket.
- Unpark: look up the ticket, work out the fee, take payment, free the spot.
- Show which spots are free, broken down by vehicle size.
- Support several floors, each with many spots.

**The clarifying questions that actually change the design**, and the answers this lesson assumes:

| Question | Answer used here | What it changes |
|---|---|---|
| What vehicle types exist? | Motorcycle, car, truck — more may be added later | An enum with a size ordering, not separate subclasses |
| Can a small vehicle use a large spot? | Yes, a bigger spot can always take a smaller vehicle | `can_fit` compares sizes by rank, not by exact match |
| How's the fee calculated? | Hourly for now, but the scheme will change (flat rate, rising rate, weekend rate) | **Strategy** — this becomes the main place the design can grow |
| More than one entrance or exit? | Yes | Separate entry/exit objects, sharing one lot |
| Reserved, electric, or accessible spots? | Not yet, but "we might add them" | The spot type has to be easy to extend |
| Payment methods? | Cash and card for now, more later | An interface, left unimplemented here |
| Kept in memory, or saved somewhere? | In memory, for this interview | Repository interfaces named, but not built |

**Say the scope out loud**: "I'll build spot assignment, ticketing, and fee calculation in memory, with pricing that can be swapped out. I'll define a `PaymentProcessor` interface but won't wire up a real payment gateway — I'll show where it would attach."

**Worth naming as out of scope**: this is a single lot. A whole chain of lots across a city, with one shared reservation system, is an HLD problem, not this one.

> **Remember:** when an interviewer says "this might change later," they're handing you your extension point. Notice it and use it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-req-q1", "type": "mcq",
      "prompt": "The interviewer mentions \"the pricing scheme might change — hourly now, maybe progressive or flat later.\" What does that one sentence tell you about the design?",
      "options": [
        {"id":"a","text":"To store the price directly on each spot"},
        {"id":"b","text":"Pricing is a place the design needs to vary, so it belongs behind a `PricingStrategy` interface handed into the lot — a new scheme becomes a new class, not an edit to the fee calculation"},
        {"id":"c","text":"To make the Ticket class unchangeable"},
        {"id":"d","text":"To use a real database instead of memory"}
      ],
      "correct": "b",
      "explanation": "\"This might change\" is the interviewer telling you exactly where to put an extension point. Anything they flag as likely to change should sit behind an interface; anything they call fixed can stay a plain concrete class." }
] }
```

## Step 2 — Entities and the class diagram

Pulling nouns out of the requirements gives: parking lot, floor, spot, vehicle, ticket, payment, pricing, entry and exit panel. Sorting them into the right kind of thing:

| Concept | Kind of thing | Why |
|---|---|---|
| `VehicleType` / `SpotType` | **Enum**, with an ordering | A small, fixed set with a natural ranking |
| `Vehicle` | **Entity** | Identified by its plate number |
| `ParkingSpot` | **Entity** | Has an identity and a lifecycle — free, then occupied |
| `Ticket` | **Entity** | Has an identity, and a lifecycle — issued, then closed |
| `Money` | **Value object** | Never changes, has no identity of its own |
| `ParkingFloor` | **Entity**, owns its spots | A spot can't exist without a floor |
| `SpotAllocationStrategy` | **Interface** | Nearest-first vs. fill-floor-by-floor is likely to change |
| `PricingStrategy` | **Interface** | The requirements said this directly |
| `ParkingLot` | **Service / facade** | Coordinates everything else |

```
                 ┌────────────────────┐
                 │    ParkingLot      │
                 │  + park(vehicle)   │◆──────1..*── ParkingFloor
                 │  + unpark(ticket)  │                   ◆
                 │  + availability()  │                   │ 1..*
                 └─────────┬──────────┘             ParkingSpot
                           │ 1                            │
             ┌─────────────┴──────────────┐               │ 0..1
             │ 1                          │ 1             ▼
   SpotAllocationStrategy         PricingStrategy      Vehicle
        △ (interface)                △ (interface)        △
        │                            │                    │
  NearestFirst / FloorByFloor   PerHour / Flat /     (plate, VehicleType)
                                 Progressive

   Ticket ───> ParkingSpot   Ticket ───> Vehicle    (associations, not ownership)
```

Two relationship calls worth defending out loud: `ParkingFloor ◆── ParkingSpot` is **composition** — destroy the floor, and its spots have no meaning left. `Ticket ──> Vehicle` is just an **association** — the vehicle existed before the ticket, and still exists after it.

> **Remember:** ask "does this part survive the whole being destroyed?" A spot doesn't survive its floor. A vehicle survives its ticket easily.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-entities-q1", "type": "mcq",
      "prompt": "Why is `ParkingFloor` to `ParkingSpot` composition, while `Ticket` to `Vehicle` is only an association?",
      "options": [
        {"id":"a","text":"Because a floor has more spots than a ticket has vehicles"},
        {"id":"b","text":"Lifecycle: a spot means nothing without its floor and is destroyed along with it, while a vehicle exists on its own and keeps existing long after any one ticket closes"},
        {"id":"c","text":"Because ParkingSpot is an enum"},
        {"id":"d","text":"Because tickets never change once created"}
      ],
      "correct": "b",
      "explanation": "The lifecycle test — \"does the part still make sense if you destroy the whole?\" — is exactly what separates composition (a filled-in diamond) from aggregation or association." }
] }
```

## Step 3 — The decisions that actually matter here

Three decisions carry this whole design. Everything else is just bookkeeping.

**1. Whether a spot fits a vehicle is a rank comparison, not an exact match.** `VehicleType` and `SpotType` both carry a rank, and a spot fits a vehicle whenever `spot.rank >= vehicle.rank`. This is exactly what lets a motorcycle park in a car-sized spot, and it means adding an `ELECTRIC` or `ACCESSIBLE` spot type never touches the allocator at all.

**2. Which spot to assign is a strategy.** "Which free spot does this vehicle get?" has several reasonable answers — the first one found, the one nearest the entrance, spread evenly across floors, the cheapest one — and that answer is very likely to change. Behind an interface, swapping between them costs nothing.

**3. The price is a strategy too.** The requirements said so directly. Notice that pricing only needs *duration and vehicle type*, and returns `Money` — it never touches the spot or the ticket directly, which is exactly what keeps it trivially easy to test on its own.

There's a fourth decision here that's really a warning: **don't let `ParkingLot` do everything itself.** The single most common way this design goes wrong is a god class that finds spots, prices tickets, takes payments, and tracks availability, all in one place. `ParkingLot` should coordinate and hand work off — allocation to the strategy, fees to the strategy, and spot state to the spot itself.

> **Remember:** a god class is the most common way this exact problem goes wrong. `ParkingLot` coordinates; it should never compute anything itself.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-decisions-q1", "type": "mcq",
      "prompt": "Why compare spot and vehicle by a numeric rank instead of requiring `spot.type == vehicle.type` exactly?",
      "options": [
        {"id":"a","text":"Comparing integers is faster than comparing enums"},
        {"id":"b","text":"It captures the real rule — a bigger spot can always hold a smaller vehicle — in one place, which keeps utilisation higher, and new spot types just slot into the ordering without the allocator needing any changes"},
        {"id":"c","text":"Enums can't be compared for equality"},
        {"id":"d","text":"It lets a vehicle occupy two spots at once"}
      ],
      "correct": "b",
      "explanation": "Requiring an exact match leaves large spots sitting empty while small vehicles get turned away. The rank comparison expresses the real domain rule once, and the allocation strategy only ever needs to ask `can_fit`." }
] }
```

## Step 4 — The implementation

This is complete and runnable, and it's roughly what you should be able to produce on a whiteboard in about 20 minutes:

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
import itertools
import threading


class VehicleType(Enum):
    MOTORCYCLE = 1
    CAR = 2
    TRUCK = 3


class SpotType(Enum):
    SMALL = 1
    MEDIUM = 2
    LARGE = 3


@dataclass(frozen=True)
class Vehicle:
    plate: str
    kind: VehicleType


@dataclass(frozen=True)
class Money:
    paise: int
    def __str__(self) -> str: return f"Rs {self.paise / 100:.2f}"


class ParkingSpot:
    def __init__(self, spot_id: str, kind: SpotType):
        self.spot_id, self.kind = spot_id, kind
        self.vehicle: Vehicle | None = None

    @property
    def is_free(self) -> bool: return self.vehicle is None

    def can_fit(self, vehicle: Vehicle) -> bool:
        return self.is_free and self.kind.value >= vehicle.kind.value

    def occupy(self, vehicle: Vehicle) -> None:
        if not self.can_fit(vehicle):
            raise ValueError(f"{self.spot_id} cannot take {vehicle.plate}")
        self.vehicle = vehicle

    def release(self) -> None: self.vehicle = None


class ParkingFloor:
    def __init__(self, number: int, spots: list[ParkingSpot]):
        self.number, self.spots = number, spots       # composition

    def free_spots(self, vehicle: Vehicle) -> list[ParkingSpot]:
        return [s for s in self.spots if s.can_fit(vehicle)]


@dataclass
class Ticket:
    ticket_id: str
    vehicle: Vehicle
    spot: ParkingSpot
    entry_minute: int
    exit_minute: int | None = None


# ---- extension point 1: where to put the vehicle ----------------------------
class SpotAllocationStrategy(ABC):
    @abstractmethod
    def allocate(self, floors: list[ParkingFloor], vehicle: Vehicle) -> ParkingSpot | None: ...

class FirstFit(SpotAllocationStrategy):
    def allocate(self, floors, vehicle):
        for floor in floors:
            free = floor.free_spots(vehicle)
            if free:
                return free[0]
        return None

class BestFit(SpotAllocationStrategy):
    """The smallest spot that still fits — keeps large spots free for large vehicles."""
    def allocate(self, floors, vehicle):
        candidates = [s for f in floors for s in f.free_spots(vehicle)]
        return min(candidates, key=lambda s: s.kind.value, default=None)


# ---- extension point 2: what to charge --------------------------------------
class PricingStrategy(ABC):
    @abstractmethod
    def price(self, minutes: int, kind: VehicleType) -> Money: ...

class PerHourPricing(PricingStrategy):
    RATES = {VehicleType.MOTORCYCLE: 2_000, VehicleType.CAR: 4_000, VehicleType.TRUCK: 8_000}
    def price(self, minutes, kind):
        hours = max(1, -(-minutes // 60))              # round part-hours up, minimum 1
        return Money(hours * self.RATES[kind])

class ProgressivePricing(PricingStrategy):
    """Cheap for the first hour, pricier each hour after — discourages long stays."""
    def price(self, minutes, kind):
        hours, total, rate = max(1, -(-minutes // 60)), 0, 2_000
        for _ in range(hours):
            total += rate
            rate += 1_000
        return Money(total)


class ParkingLot:
    """A facade: coordinates everything, hands every decision off to a collaborator."""

    def __init__(self, floors: list[ParkingFloor],
                 allocator: SpotAllocationStrategy,
                 pricing: PricingStrategy):
        self._floors, self._allocator, self._pricing = floors, allocator, pricing
        self._tickets: dict[str, Ticket] = {}
        self._ids = itertools.count(1)
        self._lock = threading.Lock()                  # guards allocation + the ticket book

    def park(self, vehicle: Vehicle, now_minute: int) -> Ticket:
        with self._lock:                               # find-and-occupy has to be one atomic step
            spot = self._allocator.allocate(self._floors, vehicle)
            if spot is None:
                raise RuntimeError(f"lot full for {vehicle.kind.name}")
            spot.occupy(vehicle)
            ticket = Ticket(f"T{next(self._ids)}", vehicle, spot, now_minute)
            self._tickets[ticket.ticket_id] = ticket
            return ticket

    def unpark(self, ticket_id: str, now_minute: int) -> Money:
        with self._lock:
            ticket = self._tickets.get(ticket_id)
            if ticket is None:
                raise ValueError("unknown ticket")
            if ticket.exit_minute is not None:
                raise ValueError("ticket already closed")   # stops charging someone twice
            ticket.exit_minute = now_minute
            ticket.spot.release()
            return self._pricing.price(now_minute - ticket.entry_minute, ticket.vehicle.kind)

    def availability(self) -> dict[SpotType, int]:
        with self._lock:
            counts = {t: 0 for t in SpotType}
            for floor in self._floors:
                for spot in floor.spots:
                    if spot.is_free:
                        counts[spot.kind] += 1
            return counts


def build_lot(allocator=None, pricing=None) -> ParkingLot:
    floors = [
        ParkingFloor(1, [ParkingSpot("1-S1", SpotType.SMALL),
                         ParkingSpot("1-M1", SpotType.MEDIUM),
                         ParkingSpot("1-L1", SpotType.LARGE)]),
        ParkingFloor(2, [ParkingSpot("2-M1", SpotType.MEDIUM)]),
    ]
    return ParkingLot(floors, allocator or BestFit(), pricing or PerHourPricing())


lot = build_lot()
bike = Vehicle("KA-01-1234", VehicleType.MOTORCYCLE)
car = Vehicle("KA-05-9999", VehicleType.CAR)
truck = Vehicle("KA-09-0001", VehicleType.TRUCK)

t_bike = lot.park(bike, now_minute=0)
assert t_bike.spot.spot_id == "1-S1"          # BestFit gives the bike the small spot

t_car = lot.park(car, now_minute=0)
assert t_car.spot.kind is SpotType.MEDIUM     # ...leaving the large spot free for the truck
t_truck = lot.park(truck, now_minute=0)
assert t_truck.spot.spot_id == "1-L1"

assert lot.unpark(t_bike.ticket_id, now_minute=90) == Money(4_000)   # 2 hours at Rs 20
try:
    lot.unpark(t_bike.ticket_id, now_minute=95)
    raise AssertionError("double exit allowed")
except ValueError:
    pass

progressive = build_lot(pricing=ProgressivePricing())
t = progressive.park(car, now_minute=0)
assert progressive.unpark(t.ticket_id, now_minute=180) == Money(2_000 + 3_000 + 4_000)

print("availability:", {k.name: v for k, v in lot.availability().items()})
print("bike fee:", Money(4_000), "| progressive 3h car:", Money(9_000))
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-impl-q1", "type": "mcq",
      "prompt": "Why does `park()` hold the lock across BOTH finding a spot and calling `spot.occupy()`?",
      "options": [
        {"id":"a","text":"To keep ticket ids in sequential order"},
        {"id":"b","text":"Find-then-occupy is a check-then-act sequence: without one lock spanning both steps, two threads could get handed the exact same free spot, and the second `occupy` call would either fail or double-book it"},
        {"id":"c","text":"Because the pricing strategy isn't thread-safe"},
        {"id":"d","text":"To stop the availability count from being read while parking happens"}
      ],
      "correct": "b",
      "explanation": "Individually safe operations don't add up to a safe sequence. The lock has to cover the entire find-and-take step — the exact same reason a seat booking has to lock the check and the write together." }
] }
```

## Steps 5 and 6 — Concurrency and extensions

**The shared, changeable data** is the set of free spots. There are three levels of answer here, and you should give whichever one fits how the interviewer framed the problem:

| Setting | What protects it |
|---|---|
| One process, moderate traffic | One lock around find-and-occupy, exactly as built above |
| One process, heavy traffic | A lock per floor, or a lock-free free-list per spot type, so different floors don't wait on each other |
| Many servers | The database enforces it: `UPDATE spots SET vehicle_id=$1 WHERE id=$2 AND vehicle_id IS NULL` — zero rows affected means someone else already won |

That third row is worth saying out loud even if the problem was framed as purely in-memory: an in-process lock protects nothing the moment there are two entry-panel servers running.

**Extensions, and how cleanly the design absorbs each one** — walking through one or two of these out loud is a good way to close:

| New requirement | What actually changes |
|---|---|
| Electric vehicles with charging spots | Add `ELECTRIC` to `SpotType`; a `ChargingSpot` subclass adds `start_charging()`. The allocator is untouched — it only ever asks `can_fit` |
| Reserved or accessible spots | A `SpotAllocationStrategy` that filters by eligibility — no changes to any entity |
| Weekend or festival pricing | A new `PricingStrategy`; nothing else moves |
| Monthly pass holders | A `PricingStrategy` that returns `Money(0)` for pass holders, chosen per ticket |
| Several entrances with displays | `EntryPanel` / `ExitPanel` objects watching the lot; the display is an **Observer** of changes in availability |
| A lost ticket | A `LostTicketPolicy` — a flat penalty — as another pricing path |
| Saving data permanently | `SpotRepository` / `TicketRepository` interfaces; `ParkingLot` depends on them, never on raw SQL |

Notice what that table actually shows: five of the seven extensions are **brand-new classes, with zero edits anywhere else**. That's exactly the kind of evidence an interviewer is looking for, and pointing it out explicitly is worth doing.

> **Remember:** an in-process lock never survives a second server. The database's conditional write is what actually enforces the rule everywhere.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-extend-q1", "type": "mcq",
      "prompt": "The interviewer adds: \"now support electric vehicles that need charging spots.\" What should your answer be?",
      "options": [
        {"id":"a","text":"Rewrite the allocator to special-case electric vehicles"},
        {"id":"b","text":"Add an ELECTRIC spot type and a ChargingSpot subclass with charging behaviour; the allocation strategy stays untouched because it only ever asks `can_fit`, and an eligibility-filtering strategy handles \"EVs only\" if that's needed"},
        {"id":"c","text":"Add an `is_electric` boolean to ParkingSpot and check it in every method"},
        {"id":"d","text":"Create a whole separate ElectricParkingLot class"}
      ],
      "correct": "b",
      "explanation": "A well-placed extension point means the new requirement is purely additive. Checking a boolean everywhere is exactly the Open/Closed violation this design exists to avoid, and a parallel lot class just duplicates everything." }
] }
```

## Quick recap

- **This problem is the template for the rest of the section.** Requirements, then entities, then relationships, then interfaces, then concurrency, then extensibility — with pricing and allocation as the two strategies. Every other problem coming up is this same shape with different nouns.
- **The two extension points are allocation and pricing.** Interviewers tend to add new requirements right along those two axes, which is exactly why they belong behind interfaces before you're even asked.
- **Comparing by rank, not by exact match**, is the domain insight that separates a thoughtful model from a purely mechanical one.
- **`ParkingLot` coordinates; it doesn't compute.** The god-class version of this answer is the single most common way this problem goes wrong.
- **Say the multi-server sentence out loud.** An in-process lock doesn't survive a second server, and the conditional `UPDATE` is what actually enforces the rule.
