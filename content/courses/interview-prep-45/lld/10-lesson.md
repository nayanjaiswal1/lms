---
kind: lesson
id_key: interview-prep-45/lld-10-elevator
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Elevator System"
position: 10
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

The elevator is the *scheduling* problem of LLD, the way parking lot is the *allocation* problem. What makes it hard is not the class model — it is that the correct behaviour is an algorithm (which car serves which request, and in what order), and candidates who dive into classes without pinning down the algorithm produce designs that cannot answer "why did car 2 get that request?".

## Step 1 — Requirements and the two kinds of request

**Functional requirements:**

- A person on a floor presses **up** or **down** (an *external* / hall request).
- A person inside a car presses a **destination floor** (an *internal* / car request).
- Cars move between floors, opening doors at stops.
- A dispatcher assigns each external request to a car.
- Emergency stop, door open/close, and out-of-service maintenance mode.

**The distinction that shapes everything**: an **external request** has a floor *and a direction* but no destination; an **internal request** has a destination but no direction of its own. Candidates who model only "a request has a floor" cannot express "this car is going up, so it should not accept a down request from floor 8 yet" — which is the whole of elevator scheduling.

**The clarifying questions:**

| Question | Answer taken here | Effect |
|---|---|---|
| How many cars? | Several, in one bank | A `Dispatcher` is a first-class object |
| Which scheduling rule? | Nearest-suitable car, then SCAN inside the car | **Strategy** — this is the extension point |
| Can a car skip floors? | Yes — express cars, restricted floors | Per-car `serviceable_floors` |
| Capacity limits? | Yes, weight/person limit | Car refuses new internal requests when full |
| Real-time or simulation? | Simulate with a `step()` tick | Testable, no threads needed to demonstrate |

**Scope cut**: "I'll model request types, per-car state and movement, and pluggable dispatching, driven by a discrete `step()` so the behaviour is testable. Door timing, motor control, and the physical safety interlocks are out of scope."

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-req-q1", "type": "mcq",
      "prompt": "Why must external (hall) and internal (car) requests be modelled differently?",
      "options": [
        {"id":"a","text":"External requests are more urgent"},
        {"id":"b","text":"An external request carries a floor plus a desired direction but no destination, while an internal request carries a destination but no direction — the direction is exactly what the dispatcher needs to decide whether a car travelling up should serve it now or on the way back"},
        {"id":"c","text":"Internal requests can be cancelled, external ones cannot"},
        {"id":"d","text":"They are stored in different databases"}
      ],
      "correct": "b",
      "explanation": "Collapsing both into \"a request has a floor\" makes the scheduling rule inexpressible. Direction is the field that lets a car serve a hall call en route instead of reversing." }
] }
```

## Step 2 — Entities and states

| Concept | Kind | Notes |
|---|---|---|
| `Direction` (UP / DOWN / IDLE) | Enum | The car's current travel direction |
| `DoorState` (OPEN / CLOSED) | Enum | |
| `ElevatorState` (MOVING / STOPPED / MAINTENANCE) | Enum | Drives what operations are legal — a **State**-flavoured lifecycle |
| `Request` (external) / `Destination` (internal) | Value objects | Immutable |
| `ElevatorCar` | Entity | Owns its own stop set, position, direction, capacity |
| `DispatchStrategy` | Interface | Nearest-car, least-busy, zoned, energy-optimal |
| `ElevatorSystem` | Service / facade | Holds cars, routes external requests, drives the tick |

```
                    ┌────────────────────┐
                    │  ElevatorSystem    │
                    │ + request(floor,   │◆──1..*── ElevatorCar
                    │     direction)     │             - current_floor
                    │ + step()           │             - direction: Direction
                    └─────────┬──────────┘             - up_stops / down_stops
                              │ 1                      - state: ElevatorState
                       DispatchStrategy                + add_stop(floor)
                         △ (interface)                 + step()
                         │
            NearestCar / LeastBusy / Zoned
```

**Why each car keeps two ordered stop sets** (`up_stops`, `down_stops`) rather than one queue: an elevator does not serve requests in arrival order — it sweeps. Holding the stops it will serve *while going up* separately from those *while coming down* is what makes the sweep trivial to implement and to explain.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-entities-q1", "type": "mcq",
      "prompt": "Why does each car keep separate sorted sets of up-stops and down-stops instead of one FIFO queue of requests?",
      "options": [
        {"id":"a","text":"To reduce memory usage"},
        {"id":"b","text":"Because an elevator sweeps rather than serving in arrival order — the two sets directly express \"floors I'll stop at going up\" and \"going down\", so the next stop is just the nearest one in the current direction"},
        {"id":"c","text":"Because FIFO queues cannot store integers"},
        {"id":"d","text":"To allow requests to be cancelled"}
      ],
      "correct": "b",
      "explanation": "FIFO order makes an elevator oscillate: floor 10, then floor 2, then floor 9. The two directional sets encode the SCAN behaviour that real elevators use, and make \"where do I go next?\" a one-line lookup." }
] }
```

## Step 3 — The scheduling algorithm

This is the heart of the problem, and there are three named answers to have ready:

| Algorithm | Rule | Behaviour |
|---|---|---|
| **FCFS** | Serve in arrival order | Simple, terrible — the car oscillates |
| **SCAN (elevator algorithm)** | Keep going in one direction, serving every stop on the way; reverse at the last stop | What real elevators do; bounded waiting |
| **LOOK** | Like SCAN but reverse at the *last request*, not the physical end | SCAN without pointless travel — the practical choice |

Inside one car: **LOOK**. Across cars: a **dispatch strategy** scoring each car for a hall call. The scoring rule to state:

```
For each car:
  if car is IDLE                                  → cost = |car.floor - request.floor|
  if car moving TOWARD the request AND same direction
                                                  → cost = |car.floor - request.floor|
  otherwise (moving away, or opposite direction)  → cost = |distance| + a large penalty
Pick the lowest cost; break ties by fewest pending stops.
```

That single rule captures the behaviour people expect from a lift bank: a car already heading your way and passing your floor picks you up; a car heading the other way does not turn around for you.

**Trade-offs worth naming aloud**: optimising for *average* wait time can starve a floor at the end of the building, so real systems add an age penalty so a long-waiting request eventually wins. Zoning (cars assigned to floor ranges) reduces travel in tall buildings at the cost of flexibility during a rush.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-algo-q1", "type": "mcq",
      "prompt": "Car A is at floor 3 moving UP; car B is idle at floor 8. A hall call arrives at floor 5, direction UP. Which car should be dispatched under the standard scoring rule, and why?",
      "options": [
        {"id":"a","text":"Car B — it is idle so it is free to respond immediately"},
        {"id":"b","text":"Car A — it is already moving toward floor 5 in the requested direction, so it serves the call en route at no extra travel, whereas car B would have to travel down against its position"},
        {"id":"c","text":"Whichever car has served fewer requests today"},
        {"id":"d","text":"Both, and the first to arrive wins"}
      ],
      "correct": "b",
      "explanation": "\"Moving toward the request in the same direction\" is the cheapest case — the stop is free. Dispatching the idle car adds travel that the passing car would have done anyway, which is why an en-route car outscores an idle one." }
] }
```

## Step 4 — The implementation

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum


class Direction(Enum):
    UP = 1
    DOWN = -1
    IDLE = 0


class ElevatorState(Enum):
    STOPPED = "stopped"
    MOVING = "moving"
    MAINTENANCE = "maintenance"


@dataclass(frozen=True)
class HallRequest:                       # external: floor + desired direction
    floor: int
    direction: Direction


class ElevatorCar:
    def __init__(self, car_id: int, floor: int = 0, capacity: int = 8):
        self.car_id, self.current_floor, self.capacity = car_id, floor, capacity
        self.direction = Direction.IDLE
        self.state = ElevatorState.STOPPED
        self.occupants = 0
        self.up_stops: set[int] = set()      # floors to serve while ascending
        self.down_stops: set[int] = set()    # floors to serve while descending
        self.log: list[str] = []

    # ---- requests -------------------------------------------------------
    def add_stop(self, floor: int) -> None:
        if self.state is ElevatorState.MAINTENANCE:
            raise RuntimeError(f"car {self.car_id} is out of service")
        if floor == self.current_floor and self.direction is Direction.IDLE:
            return                                    # already here, doors open
        (self.up_stops if floor > self.current_floor else self.down_stops).add(floor)
        if self.direction is Direction.IDLE:
            self.direction = Direction.UP if floor > self.current_floor else Direction.DOWN
            self.state = ElevatorState.MOVING

    @property
    def pending(self) -> int:
        return len(self.up_stops) + len(self.down_stops)

    def is_full(self) -> bool:
        return self.occupants >= self.capacity

    # ---- movement (LOOK) ------------------------------------------------
    def _next_stop(self) -> int | None:
        if self.direction is Direction.UP:
            ahead = [f for f in self.up_stops if f > self.current_floor]
            if ahead:
                return min(ahead)
            return max(self.down_stops) if self.down_stops else None   # reverse
        if self.direction is Direction.DOWN:
            below = [f for f in self.down_stops if f < self.current_floor]
            if below:
                return max(below)
            return min(self.up_stops) if self.up_stops else None       # reverse
        return None

    def step(self) -> None:
        """Advance one floor, or stop and open doors if this floor is a stop."""
        if self.state is ElevatorState.MAINTENANCE:
            return
        target = self._next_stop()
        if target is None:
            self.direction, self.state = Direction.IDLE, ElevatorState.STOPPED
            return

        if target == self.current_floor:
            self.up_stops.discard(target)
            self.down_stops.discard(target)
            self.log.append(f"car{self.car_id}: doors open at {target}")
            if self.pending == 0:
                self.direction, self.state = Direction.IDLE, ElevatorState.STOPPED
            return

        step = 1 if target > self.current_floor else -1
        self.current_floor += step
        self.direction = Direction.UP if step == 1 else Direction.DOWN
        self.state = ElevatorState.MOVING
        if self.current_floor in self.up_stops or self.current_floor in self.down_stops:
            self.up_stops.discard(self.current_floor)
            self.down_stops.discard(self.current_floor)
            self.log.append(f"car{self.car_id}: doors open at {self.current_floor}")


class DispatchStrategy(ABC):
    @abstractmethod
    def choose(self, cars: list[ElevatorCar], req: HallRequest) -> ElevatorCar | None: ...


class NearestSuitableCar(DispatchStrategy):
    PENALTY = 1_000

    def _cost(self, car: ElevatorCar, req: HallRequest) -> int:
        distance = abs(car.current_floor - req.floor)
        if car.direction is Direction.IDLE:
            return distance
        moving_toward = (
            (car.direction is Direction.UP and req.floor >= car.current_floor) or
            (car.direction is Direction.DOWN and req.floor <= car.current_floor)
        )
        if moving_toward and car.direction is req.direction:
            return distance                       # free: served en route
        return distance + self.PENALTY            # would have to come back

    def choose(self, cars, req):
        eligible = [c for c in cars
                    if c.state is not ElevatorState.MAINTENANCE and not c.is_full()]
        if not eligible:
            return None
        return min(eligible, key=lambda c: (self._cost(c, req), c.pending, c.car_id))


class ElevatorSystem:
    def __init__(self, cars: list[ElevatorCar], strategy: DispatchStrategy):
        self.cars, self.strategy = cars, strategy

    def hall_request(self, floor: int, direction: Direction) -> ElevatorCar:
        car = self.strategy.choose(self.cars, HallRequest(floor, direction))
        if car is None:
            raise RuntimeError("no car available")
        car.add_stop(floor)
        return car

    def step(self, ticks: int = 1) -> None:
        for _ in range(ticks):
            for car in self.cars:
                car.step()


# --- an en-route car beats an idle one --------------------------------------
a = ElevatorCar(1, floor=3); a.add_stop(10)          # car 1: at 3, heading UP to 10
b = ElevatorCar(2, floor=8)                          # car 2: idle at 8
system = ElevatorSystem([a, b], NearestSuitableCar())

chosen = system.hall_request(5, Direction.UP)
assert chosen is a                                    # picked up on the way, not by the idle car

# --- the car sweeps: 5 then 10, not 10 then back ----------------------------
system.step(12)
assert "car1: doors open at 5" in a.log
assert a.log.index("car1: doors open at 5") < a.log.index("car1: doors open at 10")

# --- a car in maintenance is never dispatched -------------------------------
a.state = ElevatorState.MAINTENANCE
assert system.hall_request(2, Direction.DOWN) is b

print(a.log)
print("car2 sent to floor 2:", sorted(b.down_stops))
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-impl-q1", "type": "mcq",
      "prompt": "In `_next_stop`, when a car moving UP has no stops above it, it returns `max(down_stops)`. What behaviour is that implementing?",
      "options": [
        {"id":"a","text":"FCFS — serving whichever request came first"},
        {"id":"b","text":"The LOOK reversal: having exhausted every stop in the current direction, the car reverses at the highest pending down-stop rather than continuing to the top of the building"},
        {"id":"c","text":"An emergency stop"},
        {"id":"d","text":"Load balancing between cars"}
      ],
      "correct": "b",
      "explanation": "SCAN would travel to the physical top floor before reversing; LOOK reverses at the furthest actual request. Returning the maximum down-stop is exactly that turnaround point." }
] }
```

## Steps 5 and 6 — Concurrency, edge cases, and extensions

**Shared mutable state**: each car's stop sets, and the dispatcher's view of car positions. Two threads pressing buttons concurrently can both mutate a car's stop set.

| Setting | Mechanism |
|---|---|
| One controller process | A lock per car around `add_stop`/`step`; sets are per-car, so no global lock is needed |
| Real hardware | Each car is its own actor/thread with a **command queue** — the dispatcher posts messages, the car owns its state entirely. This is the cleaner model: no shared mutable state at all |
| Dispatcher decisions | Recompute from a consistent snapshot; a stale position at worst costs an efficiency, not correctness |

The actor/queue answer is the strong one here: **remove the sharing rather than lock it.**

**Edge cases interviewers raise** — have answers ready:

| Case | Handling |
|---|---|
| Car full | Skip it in dispatch (`is_full`), and the car does not accept the hall call — the passenger re-presses |
| Request for the current floor | Open doors, do not enqueue a stop |
| All cars in maintenance | Dispatcher returns `None`; the system surfaces "no service" rather than silently dropping |
| Emergency stop | Transition to a state that clears stops and refuses new ones — a **State** transition, not a boolean |
| Power failure / reset | Cars home to the nearest floor and open doors |
| Starvation of a far floor | Add an age term to the cost function so waiting eventually outweighs distance |
| Two cars arrive for one call | Cancel the duplicate stop when a car opens doors for that hall request |

**Extensions and how the design absorbs them:**

- **Express elevators / restricted floors** → a `serviceable_floors` set per car, filtered in `choose`. No new classes.
- **Zoning (low-rise / high-rise banks)** → a `ZonedDispatch` strategy. One new class.
- **Peak-hour modes** (morning up-peak: park idle cars at the lobby) → another strategy, plus an idle-parking rule.
- **Energy optimisation** → a strategy that weights travel distance and door cycles.
- **Displays showing car position** → **Observer**s on each car's floor change.

Every one of those is a new strategy or a new observer — which is the point to make when you close: *the scheduling rule was the thing most likely to change, so it is the thing behind an interface.*

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-concurrency-q1", "type": "mcq",
      "prompt": "What is the cleanest concurrency model for a real multi-car elevator controller?",
      "options": [
        {"id":"a","text":"One global lock around the entire elevator system"},
        {"id":"b","text":"Each car is an independent actor owning its own state, receiving commands through a queue — the dispatcher posts messages instead of mutating car state, so there is no shared mutable state to protect at all"},
        {"id":"c","text":"Optimistic locking with version numbers on each car"},
        {"id":"d","text":"No synchronisation, since each car moves independently"}
      ],
      "correct": "b",
      "explanation": "The best concurrency answer removes sharing rather than guarding it. A per-car command queue serialises all mutations of that car's state by construction, and cars remain fully parallel with respect to each other." }
] }
```

## Key takeaways

- **Pin down the algorithm before the classes.** Elevator is a scheduling problem; a design that cannot explain *why* a particular car was chosen has missed the question.
- **Two request types, not one.** External (floor + direction) and internal (destination) are different things, and the direction field is what makes en-route service expressible.
- **LOOK inside a car, cost-based dispatch across cars**, with the "moving toward it in the same direction is free" rule stated explicitly.
- **Two directional stop sets** make the sweep trivial and are much easier to defend than a single queue.
- **Prefer actors with command queues** over locks when every unit of state has a natural owner — it is the concurrency answer that removes the problem instead of guarding it.
