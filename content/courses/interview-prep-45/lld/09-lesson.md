---
kind: lesson
id_key: interview-prep-45/lld-09-parking-lot
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Parking Lot"
position: 9
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

The most-asked LLD question in existence, and the one every other problem in this section is a variation of. It is popular because it is small enough to finish in 45 minutes and rich enough to expose whether you can model a domain, pick extension points, and reason about concurrency.

This lesson runs the six-step framework end to end. Follow the same shape for every problem that follows.

## Step 1 — Requirements and scope

**Functional requirements** (the verbs, from the actors — driver, attendant, admin):

- Park a vehicle: find a suitable free spot, assign it, issue a ticket.
- Unpark: look up the ticket, compute the fee, take payment, free the spot.
- Query availability by vehicle size.
- Support multiple floors, each with many spots.

**The clarifying questions that change the model**, and typical answers:

| Question | Answer taken here | Effect on the design |
|---|---|---|
| What vehicle types? | Motorcycle, car, truck — more may be added | Enum with a size ordering, not subclasses |
| Can a small vehicle use a large spot? | Yes, a bigger spot fits a smaller vehicle | `can_fit` compares ranks, not equality |
| How is the fee calculated? | Hourly, but the scheme will change (flat, progressive, weekend) | **Strategy** — this is the main extension point |
| Multiple entrances/exits? | Yes | Entry/exit panels as separate objects, one shared lot |
| Reserved / EV / handicapped spots? | Not now, but "we may add them" | Spot type must be extensible |
| Payment methods? | Cash and card, more later | Interface, not implemented here |
| In-memory or persisted? | In-memory for the interview | Repository interfaces named, not implemented |

**Scope cut, stated out loud**: "I'll model spot allocation, ticketing, and fee calculation in memory with pluggable pricing. Payment gateways, persistence, and the admin UI are out of scope, though I'll show where they attach."

**Non-goals worth naming**: this is a single-lot design; a multi-city chain with a central reservation system is an HLD problem, not this one.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-req-q1", "type": "mcq",
      "prompt": "The interviewer says \"the pricing scheme may change — hourly now, maybe progressive or flat later\". What does that single sentence tell you about the design?",
      "options": [
        {"id":"a","text":"To store the price on each spot"},
        {"id":"b","text":"Pricing is an axis of variation, so it belongs behind a `PricingStrategy` interface injected into the lot — new schemes become new classes rather than edits to fee calculation"},
        {"id":"c","text":"To make the Ticket class immutable"},
        {"id":"d","text":"To use a database instead of memory"}
      ],
      "correct": "b",
      "explanation": "\"This may change\" is the interviewer naming your extension point. Anything they say will vary should end up behind an interface; anything they say is fixed should stay concrete." }
] }
```

## Step 2 — Entities and the class diagram

Noun extraction gives: parking lot, floor, spot, vehicle, ticket, payment, pricing, entry/exit panel. Refined into the right kind of thing:

| Concept | Kind | Why |
|---|---|---|
| `VehicleType` / `SpotType` | **Enum** with a rank | Small closed set with an ordering |
| `Vehicle` | **Entity** | Identified by its plate |
| `ParkingSpot` | **Entity** | Has identity and a lifecycle (free ↔ occupied) |
| `Ticket` | **Entity** | Identity, issued/closed lifecycle |
| `Money` | **Value object** | Immutable, no identity |
| `ParkingFloor` | **Entity**, composes spots | A spot cannot exist without a floor |
| `SpotAllocationStrategy` | **Interface** | Nearest-first vs. fill-floor-by-floor will vary |
| `PricingStrategy` | **Interface** | Named as varying in requirements |
| `ParkingLot` | **Service / facade** | Orchestrates the rest |

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

Two relationship calls to justify out loud: `ParkingFloor ◆── ParkingSpot` is **composition** (destroy the floor, the spots are meaningless), while `Ticket ──> Vehicle` is **association** (the vehicle exists before and after the ticket).

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-entities-q1", "type": "mcq",
      "prompt": "Why is `ParkingFloor` → `ParkingSpot` composition, while `Ticket` → `Vehicle` is only an association?",
      "options": [
        {"id":"a","text":"Because a floor has more spots than a ticket has vehicles"},
        {"id":"b","text":"Lifecycle: a spot has no meaning without its floor and is destroyed with it, whereas a vehicle exists independently of any ticket and outlives it"},
        {"id":"c","text":"Because ParkingSpot is an enum"},
        {"id":"d","text":"Because tickets are immutable"}
      ],
      "correct": "b",
      "explanation": "The lifecycle test — \"if the whole is destroyed, does the part still make sense?\" — is what separates composition (filled diamond) from aggregation/association." }
] }
```

## Step 3 — The design decisions that matter

Three decisions carry this design; everything else is bookkeeping.

**1. Spot fitting is a rank comparison, not equality.** `VehicleType` and `SpotType` both carry a rank, and a spot fits a vehicle when `spot.rank >= vehicle.rank`. This is what lets a motorcycle park in a car spot, and it means adding an `ELECTRIC` or `HANDICAPPED` spot type does not touch the allocator.

**2. Allocation is a strategy.** "Which free spot do I give this vehicle?" has several plausible answers — first fit, nearest to the entrance, spread across floors, cheapest — and they will change. Behind an interface, they cost nothing to swap.

**3. Pricing is a strategy.** The requirement said so explicitly. Note that pricing takes *duration and vehicle type* and returns `Money` — it never touches the spot or the ticket, so it stays trivially testable.

A fourth decision that is really a warning: **do not put everything on `ParkingLot`.** The single most common failure in this problem is a god class that finds spots, prices tickets, takes payments, and tracks availability. `ParkingLot` should orchestrate and delegate — allocation to the strategy, fee to the strategy, spot state to the spot.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-decisions-q1", "type": "mcq",
      "prompt": "Why compare spot and vehicle by a numeric rank rather than requiring `spot.type == vehicle.type`?",
      "options": [
        {"id":"a","text":"Integer comparison is faster than enum comparison"},
        {"id":"b","text":"It encodes the real rule — a larger spot accommodates a smaller vehicle — in one place, so utilisation is higher and new spot types slot into the ordering without changing the allocator"},
        {"id":"c","text":"Enums cannot be compared for equality"},
        {"id":"d","text":"It allows a vehicle to occupy two spots"}
      ],
      "correct": "b",
      "explanation": "Exact-match allocation leaves large spots idle while small vehicles are turned away. The rank comparison expresses the domain rule once, and the allocation strategy is written against `can_fit` rather than against a list of types." }
] }
```

## Step 4 — The implementation

Complete, runnable, and roughly what you should be able to produce on a whiteboard in 20 minutes:

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


# ---- extension point 1: where to put the car -------------------------------
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
    """Smallest spot that still fits — keeps large spots free for large vehicles."""
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
        hours = max(1, -(-minutes // 60))              # part-hours round up, minimum 1
        return Money(hours * self.RATES[kind])

class ProgressivePricing(PricingStrategy):
    """First hour cheap, each subsequent hour dearer — discourages long stays."""
    def price(self, minutes, kind):
        hours, total, rate = max(1, -(-minutes // 60)), 0, 2_000
        for _ in range(hours):
            total += rate
            rate += 1_000
        return Money(total)


class ParkingLot:
    """Facade: orchestrates, delegates every decision to a collaborator."""

    def __init__(self, floors: list[ParkingFloor],
                 allocator: SpotAllocationStrategy,
                 pricing: PricingStrategy):
        self._floors, self._allocator, self._pricing = floors, allocator, pricing
        self._tickets: dict[str, Ticket] = {}
        self._ids = itertools.count(1)
        self._lock = threading.Lock()                  # guards allocation + ticket book

    def park(self, vehicle: Vehicle, now_minute: int) -> Ticket:
        with self._lock:                               # find-and-occupy must be atomic
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
                raise ValueError("ticket already closed")   # no double-charging
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
assert t_car.spot.kind is SpotType.MEDIUM     # ...leaving LARGE free for the truck
t_truck = lot.park(truck, now_minute=0)
assert t_truck.spot.spot_id == "1-L1"

assert lot.unpark(t_bike.ticket_id, now_minute=90) == Money(4_000)   # 2 h x Rs20
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
      "prompt": "Why does `park()` hold the lock across BOTH the allocation and `spot.occupy()`?",
      "options": [
        {"id":"a","text":"To make ticket ids sequential"},
        {"id":"b","text":"Because allocate-then-occupy is a check-then-act sequence: without one critical section spanning both, two threads can be handed the same free spot and the second `occupy` either fails or double-books"},
        {"id":"c","text":"Because the pricing strategy is not thread-safe"},
        {"id":"d","text":"To prevent the availability count from being read during parking"}
      ],
      "correct": "b",
      "explanation": "Individually atomic operations do not compose. The critical section must cover the whole find-and-take sequence — the same reason a seat booking locks the check and the write together." }
] }
```

## Steps 5 and 6 — Concurrency and extensions

**The shared mutable state** is the set of free spots. Three levels of answer, and you should give whichever matches the interviewer's framing:

| Setting | Mechanism |
|---|---|
| Single process, modest traffic | One lock around find-and-occupy (as implemented) |
| Single process, high traffic | Per-floor locks, or a lock-free free-list per spot type, so different floors don't contend |
| Multiple servers | The database enforces it: `UPDATE spots SET vehicle_id=$1 WHERE id=$2 AND vehicle_id IS NULL` — zero rows affected means someone else won |

That third row is the one to say out loud even if the interviewer framed the problem as in-memory: an in-process lock protects nothing once there are two entry-panel servers.

**Extensions, and how the design absorbs them** — walk through one or two out loud to close:

| New requirement | Change required |
|---|---|
| Electric vehicles with charging spots | Add `ELECTRIC` to `SpotType`; a `ChargingSpot` subclass adds `start_charging()`. The allocator is unchanged — it only asks `can_fit`. |
| Reserved / handicapped spots | A `SpotAllocationStrategy` that filters by an eligibility predicate; no entity changes |
| Weekend and festival pricing | A new `PricingStrategy`; nothing else moves |
| Monthly pass holders | A `PricingStrategy` returning `Money(0)` for pass holders, chosen per ticket |
| Multiple entrances with displays | `EntryPanel` / `ExitPanel` objects observing the lot; the display is an **Observer** of availability changes |
| Lost ticket | A `LostTicketPolicy` — flat penalty — as another pricing path |
| Persistence | `SpotRepository` / `TicketRepository` interfaces; `ParkingLot` depends on them, not on SQL |

Notice what the table demonstrates: five of the seven extensions are **new classes, zero edits**. That is the Open/Closed evidence the interviewer is looking for, and pointing it out explicitly is worth doing.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-09-extend-q1", "type": "mcq",
      "prompt": "The interviewer adds: \"now support electric vehicles that need charging spots.\" What should your answer be?",
      "options": [
        {"id":"a","text":"Rewrite the allocator to special-case electric vehicles"},
        {"id":"b","text":"Add an ELECTRIC spot type and a ChargingSpot subclass with charging behaviour; the allocation strategy is untouched because it only asks `can_fit`, and an eligibility-filtering strategy handles \"EVs only\" if required"},
        {"id":"c","text":"Add an `is_electric` boolean to ParkingSpot and branch on it in every method"},
        {"id":"d","text":"Create a separate ElectricParkingLot class"}
      ],
      "correct": "b",
      "explanation": "A well-placed extension point means the new requirement is additive. Branching on a boolean in every method is the Open/Closed violation this design exists to avoid, and a parallel lot class duplicates everything." }
] }
```

## Key takeaways

- **This problem is the template.** Requirements → entities → relationships → interfaces → concurrency → extensibility, with pricing and allocation as the two strategies. Every other problem in this section is this shape with different nouns.
- **The two extension points are allocation and pricing.** Interviewers add requirements along exactly those axes, which is why they belong behind interfaces before you are asked.
- **Rank-based fitting, not exact matching**, is the domain insight that separates a considered model from a mechanical one.
- **`ParkingLot` orchestrates; it does not compute.** The god-class version of this answer is the most common failure mode.
- **Say the multi-server sentence**: an in-process lock does not survive a second server, and the conditional `UPDATE` is what actually enforces the invariant.
