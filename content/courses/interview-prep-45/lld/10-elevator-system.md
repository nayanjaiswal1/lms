---
kind: lesson
id_key: interview-prep-45/lld-10-elevator
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design an Elevator System"
position: 10
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

If the parking lot was about *allocation*, the elevator is about *scheduling*. The hard part isn't the classes — it's that correct behaviour is really an algorithm: which car answers which request, and in what order. Candidates who jump straight into writing classes, without first pinning down that algorithm, end up with a design that can't answer a simple question like "why did car 2 get sent there?"

## Step 1 — Requirements and the two kinds of request

**What the system needs to do:**

- A person standing on a floor presses **up** or **down** — this is called an *external* or *hall* request.
- A person already inside a car presses a **destination floor** — this is an *internal* or *car* request.
- Cars move between floors and open their doors at each stop.
- A dispatcher decides which car answers each hall request.
- There's an emergency stop, manual door controls, and a maintenance mode.

**The one distinction that shapes everything else**: an **external request** carries a floor *and a desired direction*, but no destination. An **internal request** carries a destination, but no direction of its own. If you model every request as "just a floor," you can't express something as basic as "this car is already heading up, so it shouldn't grab a down request from floor 8 just yet" — and that idea is really the entire job of elevator scheduling.

**The clarifying questions:**

| Question | Answer used here | What it changes |
|---|---|---|
| How many cars? | Several, sharing one bank | A `Dispatcher` becomes its own object |
| Which scheduling rule? | Send the nearest suitable car, then sweep inside each car | **Strategy** — this is the extension point |
| Can a car skip floors? | Yes — express cars, restricted floors | Each car gets its own `serviceable_floors` |
| Is there a capacity limit? | Yes, a weight or headcount limit | A full car refuses new internal requests |
| Real hardware, or a simulation? | Simulated with a `step()` tick | Testable, with no real threads needed |

**Say the scope**: "I'll model both kinds of requests, how each car moves and holds state, and a pluggable dispatcher, all driven by a discrete `step()` so the behaviour is fully testable. Door timing, the actual motor control, and physical safety interlocks are out of scope."

> **Remember:** an external request carries a direction. An internal one carries a destination. Mixing them into one shape loses the exact information the dispatcher needs.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-req-q1", "type": "mcq",
      "prompt": "Why do external (hall) and internal (car) requests need to be modelled differently?",
      "options": [
        {"id":"a","text":"External requests are simply more urgent"},
        {"id":"b","text":"An external request carries a floor plus a desired direction but no destination, while an internal request carries a destination but no direction — that direction is exactly what tells the dispatcher whether a car already heading up should grab this request on the way, or ignore it for now"},
        {"id":"c","text":"Internal requests can be cancelled and external ones can't"},
        {"id":"d","text":"They're stored in different databases"}
      ],
      "correct": "b",
      "explanation": "Collapsing both into \"just a floor\" makes the whole scheduling rule impossible to express. Direction is the exact field that lets a passing car pick up a hall call instead of turning around for it." }
] }
```

## Step 2 — Entities and states

| Concept | Kind of thing | Notes |
|---|---|---|
| `Direction` (UP / DOWN / IDLE) | Enum | The car's current direction of travel |
| `DoorState` (OPEN / CLOSED) | Enum | |
| `ElevatorState` (MOVING / STOPPED / MAINTENANCE) | Enum | Decides which operations are even legal — this is really a small State machine |
| `Request` (external) / `Destination` (internal) | Value objects | Never change once created |
| `ElevatorCar` | Entity | Owns its own stops, position, direction, and capacity |
| `DispatchStrategy` | Interface | Nearest car, least busy, zoned, energy-aware — these will vary |
| `ElevatorSystem` | Service / facade | Holds every car, routes hall requests, drives the tick forward |

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

**Why each car keeps two separate ordered sets of stops** (`up_stops`, `down_stops`) instead of one plain queue: a real elevator doesn't serve requests in the order they arrived — it sweeps in one direction, then the other. Keeping "stops I'll hit going up" separate from "stops I'll hit coming down" is what makes that sweep trivial to write and even easier to explain out loud.

> **Remember:** an elevator sweeps, it doesn't queue. Two direction-based sets, not one FIFO list.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-entities-q1", "type": "mcq",
      "prompt": "Why does each car keep separate sorted sets of up-stops and down-stops instead of one plain FIFO queue of requests?",
      "options": [
        {"id":"a","text":"To use less memory"},
        {"id":"b","text":"An elevator sweeps rather than serving requests in the order they arrived — the two sets directly express \"floors to stop at going up\" versus \"going down\", so the next stop is just a quick lookup in the current direction"},
        {"id":"c","text":"FIFO queues can't store integers"},
        {"id":"d","text":"To allow requests to be cancelled"}
      ],
      "correct": "b",
      "explanation": "A plain FIFO order would make an elevator bounce between distant floors pointlessly. The two directional sets encode the sweeping behaviour real elevators use, and turn \"where do I go next?\" into a one-line lookup." }
] }
```

## Step 3 — The scheduling algorithm

This is the real heart of the problem, and there are three named answers worth having ready:

| Algorithm | The rule | What it does |
|---|---|---|
| **FCFS** | Serve requests in the order they arrived | Simple, and genuinely terrible — the car bounces back and forth |
| **SCAN** (the "elevator algorithm") | Keep going one direction, stopping at everything along the way, then reverse at the very last floor | What real elevators actually do; wait times stay bounded |
| **LOOK** | Like SCAN, but reverse at the last *requested* floor, not the physical top or bottom | SCAN without the wasted travel — this is the practical choice |

Inside one car: **LOOK**. Across several cars: a **dispatch strategy** that scores every car against a given hall call. Here's the scoring rule worth stating:

```
For each car:
  if car is IDLE                                  → cost = |car.floor - request.floor|
  if car moving TOWARD the request AND same direction
                                                  → cost = |car.floor - request.floor|
  otherwise (moving away, or the opposite direction)  → cost = |distance| + a large penalty
Pick the lowest cost; break ties by fewest pending stops.
```

That single rule captures exactly the behaviour people expect from a real elevator bank: a car already heading your way, passing your floor, picks you up along the way. A car heading the other direction doesn't turn around just for you.

**Trade-offs worth mentioning out loud**: optimising purely for *average* wait time can leave one floor at the far end of the building waiting forever, so real systems add a small penalty that grows with how long a request has waited, so it eventually wins regardless of distance. Zoning — assigning cars to specific floor ranges — cuts down travel in tall buildings, at the cost of flexibility whenever there's an unusual rush.

> **Remember:** a car already moving toward a request in the same direction costs nothing extra to serve. That's the cheapest case, and it should almost always win.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-algo-q1", "type": "mcq",
      "prompt": "Car A is at floor 3 moving UP. Car B is idle at floor 8. A hall call arrives at floor 5, wanting to go UP. Which car should be dispatched, and why?",
      "options": [
        {"id":"a","text":"Car B — it's idle, so it's free to respond right away"},
        {"id":"b","text":"Car A — it's already heading toward floor 5 in the requested direction, so it serves the call along the way for free, while car B would have to travel all the way down against its current position"},
        {"id":"c","text":"Whichever car has served fewer requests so far today"},
        {"id":"d","text":"Both, and whichever arrives first wins"}
      ],
      "correct": "b",
      "explanation": "\"Already moving toward the request, same direction\" is the cheapest possible case — the stop is essentially free. Sending the idle car instead adds travel that the passing car would have done anyway, which is exactly why an en-route car should outscore an idle one." }
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
class HallRequest:                       # external: a floor plus the desired direction
    floor: int
    direction: Direction


class ElevatorCar:
    def __init__(self, car_id: int, floor: int = 0, capacity: int = 8):
        self.car_id, self.current_floor, self.capacity = car_id, floor, capacity
        self.direction = Direction.IDLE
        self.state = ElevatorState.STOPPED
        self.occupants = 0
        self.up_stops: set[int] = set()      # floors to serve while going up
        self.down_stops: set[int] = set()    # floors to serve while going down
        self.log: list[str] = []

    # ---- requests -------------------------------------------------------
    def add_stop(self, floor: int) -> None:
        if self.state is ElevatorState.MAINTENANCE:
            raise RuntimeError(f"car {self.car_id} is out of service")
        if floor == self.current_floor and self.direction is Direction.IDLE:
            return                                    # already here, doors will just open
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
            return max(self.down_stops) if self.down_stops else None   # time to reverse
        if self.direction is Direction.DOWN:
            below = [f for f in self.down_stops if f < self.current_floor]
            if below:
                return max(below)
            return min(self.up_stops) if self.up_stops else None       # time to reverse
        return None

    def step(self) -> None:
        """Move one floor, or stop and open the doors if this floor is a stop."""
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
            return distance                       # free: served along the way
        return distance + self.PENALTY            # would need to turn around

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


# --- an en-route car beats an idle one ---------------------------------------
a = ElevatorCar(1, floor=3); a.add_stop(10)          # car 1: at floor 3, heading UP to 10
b = ElevatorCar(2, floor=8)                          # car 2: idle at floor 8
system = ElevatorSystem([a, b], NearestSuitableCar())

chosen = system.hall_request(5, Direction.UP)
assert chosen is a                                    # picked up on the way, not the idle car

# --- the car sweeps: floor 5, then floor 10, never 10 then back --------------
system.step(12)
assert "car1: doors open at 5" in a.log
assert a.log.index("car1: doors open at 5") < a.log.index("car1: doors open at 10")

# --- a car in maintenance is never dispatched ---------------------------------
a.state = ElevatorState.MAINTENANCE
assert system.hall_request(2, Direction.DOWN) is b

print(a.log)
print("car2 sent to floor 2:", sorted(b.down_stops))
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-impl-q1", "type": "mcq",
      "prompt": "In `_next_stop`, a car moving UP with no more stops above it returns `max(down_stops)`. What behaviour is that?",
      "options": [
        {"id":"a","text":"FCFS — serving whichever request arrived first"},
        {"id":"b","text":"The LOOK reversal: having run out of stops in the current direction, the car turns around at the highest pending down-stop instead of continuing all the way to the top of the building"},
        {"id":"c","text":"An emergency stop"},
        {"id":"d","text":"Balancing load between different cars"}
      ],
      "correct": "b",
      "explanation": "Plain SCAN would travel all the way to the physical top floor before turning around. LOOK reverses right at the furthest actual request instead. Returning the highest pending down-stop is exactly that turnaround point." }
] }
```

## Steps 5 and 6 — Concurrency, edge cases, and extensions

**The shared, changeable data**: each car's set of stops, and the dispatcher's view of where every car currently is. Two people pressing buttons at the same instant can both try to change one car's stops at once.

| Setting | What protects it |
|---|---|
| One controller process | A lock per car around `add_stop`/`step` — each car's stops are its own, so no single global lock is needed |
| Real hardware | Each car acts as its own independent actor or thread, with a **command queue** — the dispatcher just posts messages, and the car fully owns its own state. This removes shared state entirely, rather than just protecting it |
| Dispatcher decisions | Work from a consistent snapshot; a slightly stale position only costs a little efficiency, never correctness |

The actor-with-a-queue answer is the stronger one here: **get rid of the sharing, don't just guard it.**

**Edge cases worth raising yourself:**

| Case | How it's handled |
|---|---|
| Car is full | Skip it in dispatch (`is_full`), and it won't accept a new hall call either — the passenger presses the button again |
| Request for the floor the car is already on | Just open the doors, no new stop needed |
| Every car is in maintenance | Dispatch returns nothing; the system should show "no service" instead of silently doing nothing |
| Emergency stop | A state transition that clears all pending stops and refuses new ones — a real state change, not a boolean flag |
| Power failure or reboot | Cars return to the nearest floor and open their doors |
| A far floor keeps getting skipped | Add a term to the cost function that grows with wait time, so waiting eventually beats distance |
| Two cars arrive for one call | Cancel the duplicate stop the moment either car opens its doors for that hall request |

**Extensions, and how the design absorbs each one:**

- **Express elevators, or restricted floors** — a `serviceable_floors` set per car, checked inside `choose`. No new classes needed.
- **Zoning** (low-rise and high-rise banks) — a `ZonedDispatch` strategy. One new class.
- **Peak-hour behaviour** (morning rush: park idle cars near the lobby) — another strategy, plus a rule for where idle cars wait.
- **Energy-aware routing** — a strategy that weights both travel distance and how often doors open and close.
- **Displays showing car position** — **Observers** watching each car's floor change.

Every single one of those is a new strategy or a new observer — which is exactly the point to make when you wrap up: *the scheduling rule was the thing most likely to change, so it went behind an interface from the start.*

> **Remember:** the best concurrency answer here removes the shared state entirely — give each car its own actor and a command queue, instead of guarding a lock.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-10-concurrency-q1", "type": "mcq",
      "prompt": "What's the cleanest concurrency model for a real multi-car elevator controller?",
      "options": [
        {"id":"a","text":"One single global lock around the entire elevator system"},
        {"id":"b","text":"Each car acts as an independent actor owning its own state, receiving commands through a queue — the dispatcher posts messages instead of directly mutating a car's state, so there's no shared, changeable data left to protect at all"},
        {"id":"c","text":"Optimistic locking with version numbers on each car"},
        {"id":"d","text":"No synchronisation at all, since each car moves on its own"}
      ],
      "correct": "b",
      "explanation": "The strongest concurrency answer removes the sharing rather than just guarding it. A per-car command queue naturally serialises every change to that car's state, while different cars stay fully independent of each other." }
] }
```

## Quick recap

- **Pin down the algorithm before you write a single class.** The elevator is a scheduling problem, and a design that can't explain *why* a specific car got chosen has missed the actual question.
- **There are two kinds of request, not one.** External requests carry a floor plus a direction; internal ones carry a destination — and that direction field is exactly what makes serving a request along the way possible.
- **LOOK inside one car, cost-based scoring across cars**, and say the "already moving toward it in the same direction is free" rule out loud.
- **Two direction-based sets of stops** make the sweeping behaviour trivial to write, and much easier to defend than a single plain queue.
- **Prefer actors with command queues** over locks whenever every piece of state has a natural, single owner — it's the concurrency answer that removes the problem instead of just guarding against it.
