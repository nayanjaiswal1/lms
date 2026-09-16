---
kind: lesson
id_key: interview-prep-45/lld-11-ticket-booking
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Movie Ticket Booking (BookMyShow)"
position: 11
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

This is the **concurrency** problem of LLD. The class model is straightforward — city, cinema, screen, show, seat, booking — and every interviewer moves within ten minutes to the only question that matters: *two users click the same seat at the same instant; what happens?* Get that right and the rest is bookkeeping.

## Step 1 — Requirements and the booking lifecycle

**Functional requirements:**

- Search shows by city, movie, and date.
- View the seat map of a show, with each seat's current availability.
- Select one or more seats and **hold** them while payment is in progress.
- Confirm the booking on successful payment, or release the hold on failure or timeout.
- Cancel a booking (with a refund policy).

**The question that defines the design**: *how long may a user hold a seat before paying?* The answer — "a few minutes" — rules out holding a database lock for the duration and forces the **reservation-with-TTL** pattern. Say this early; it is the insight the problem is built around.

**The other clarifying questions:**

| Question | Answer taken here | Effect |
|---|---|---|
| Seat pricing? | Varies by seat class and show time | **Strategy** |
| Can a user book multiple seats atomically? | Yes — all or nothing | The hold covers a *set* of seats |
| What if payment fails or the user disappears? | The hold expires automatically | Expiry timestamp, not a boolean flag |
| Multiple servers? | Yes | The invariant must live in the database |
| Overbooking allowed? | Never | Hard constraint, not a best effort |

**The lifecycle is a state machine**, and drawing it is worth 30 seconds:

```
AVAILABLE ──hold()──▶ HELD ──confirm()──▶ BOOKED ──cancel()──▶ AVAILABLE
    ▲                  │                                          ▲
    └──── expire() ◀────┘   (TTL elapsed, or payment failed) ──────┘
```

Two properties of that diagram earn points: **HELD is a real state, not a boolean**, and **the transition out of HELD can happen without anyone calling anything** — expiry is driven by time, which is why the hold carries a timestamp rather than a flag.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-req-q1", "type": "mcq",
      "prompt": "Why must a seat hold carry an expiry timestamp rather than an `is_locked` boolean?",
      "options": [
        {"id":"a","text":"Timestamps are easier to index"},
        {"id":"b","text":"A boolean set by a client that then crashes or abandons checkout locks the seat forever; an expiry means the hold releases itself with no cleanup process required for correctness"},
        {"id":"c","text":"Booleans cannot be stored in a database"},
        {"id":"d","text":"So that multiple users can hold the same seat"}
      ],
      "correct": "b",
      "explanation": "This is the same reasoning as a TTL on a distributed lock: the holder cannot be trusted to release it. An expiry makes abandonment self-healing, and a sweeper job becomes an optimisation rather than a correctness requirement." }
] }
```

## Step 2 — Entities and relationships

| Concept | Kind | Notes |
|---|---|---|
| `City`, `Cinema`, `Screen` | Entities | `Cinema ◆── Screen` is composition |
| `Movie` | Entity | Exists independently of any show |
| `Show` | Entity | A movie on a screen at a time — the booking unit |
| `Seat` | Entity | Belongs to a screen: physical row/number/class |
| `ShowSeat` | Entity | **The one people miss**: a seat's status *for one show* |
| `SeatStatus` | Enum | AVAILABLE / HELD / BOOKED |
| `Booking` | Entity | A user's set of show-seats, with its own lifecycle |
| `PricingStrategy` | Interface | By seat class, show time, day |
| `PaymentProcessor` | Interface | Out of scope to implement |

```
City ◇── Cinema ◆── Screen ◆── Seat              (physical layout)
                       │
                     Show ──> Movie              (a screening)
                       ◆
                       │ 1..*
                   ShowSeat ──> Seat             (per-show availability)
                       │  - status: SeatStatus
                       │  - held_until: int|None
                       │  - booking_id: str|None
                       ▲
                   Booking ◇── 1..* ShowSeat
```

**The `Seat` vs `ShowSeat` split is the modelling insight of this problem.** A seat is a physical object that exists once and never changes; its *availability* is a property of the pair (seat, show). Candidates who put `is_booked` on `Seat` cannot represent the same seat being free for the 6pm show and booked for the 9pm one. Being able to say that sentence is worth more than any pattern name here.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-entities-q1", "type": "mcq",
      "prompt": "Why separate `Seat` from `ShowSeat` rather than putting `is_booked` on `Seat`?",
      "options": [
        {"id":"a","text":"To reduce the number of database rows"},
        {"id":"b","text":"Availability is a property of the (seat, show) pair, not of the physical seat — seat A5 can be booked for the 9pm show and free for the 6pm one, which a flag on Seat cannot express"},
        {"id":"c","text":"Because Seat must be immutable for thread safety"},
        {"id":"d","text":"Because shows and seats are stored in different services"}
      ],
      "correct": "b",
      "explanation": "Physical layout and per-screening state have different lifecycles and different cardinality. The join entity is also exactly where the unique constraint that prevents double-booking lives." }
] }
```

## Step 3 — The concurrency design

This is the section the interview is really about. Build the answer in three layers.

**Layer 1 — the hold is an atomic conditional write.** Not "check availability, then mark held". One statement that both tests and takes:

```sql
UPDATE show_seats
   SET status = 'HELD', held_by = $1, held_until = now() + interval '5 minutes'
 WHERE show_id = $2
   AND seat_id = ANY($3)
   AND (status = 'AVAILABLE'
        OR (status = 'HELD' AND held_until < now()));   -- expired holds are reclaimable
-- affected rows < requested count  ⇒  someone else won  ⇒  roll back, tell the user
```

The `AND` clause is the entire concurrency mechanism: the database evaluates the condition and performs the write in one atomic step, so two concurrent attempts cannot both succeed. Row count is how you learn whether you won.

**Layer 2 — all-or-nothing for a multi-seat booking.** Wrap the update in a transaction and require the affected-row count to equal the number of seats requested; otherwise roll back. Half a booking is worse than none.

Two seats acquired in different orders by two users is the deadlock case from the concurrency lesson — **sort the seat ids before locking** so every transaction acquires them in the same global order.

**Layer 3 — a unique constraint as the last line of defence.** Even with perfect application code, add:

```sql
CREATE UNIQUE INDEX one_booking_per_seat_per_show
    ON show_seats (show_id, seat_id) WHERE status = 'BOOKED';
```

Application logic can have bugs; a constraint cannot be bypassed. Volunteering this is the mark of someone who has shipped a booking system.

**Why not a distributed (Redis) lock?** You can use one as an *optimisation* to reduce contention on the database, but it cannot be the guarantee — a GC pause or a slow network can outlive any TTL, and the holder cannot know it was evicted. Say: *"a Redis lock reduces contention; the unique constraint is what makes it correct."*

**Expiry**: a background sweeper flips expired holds back to AVAILABLE for a tidy seat map, but the `held_until < now()` clause in the hold query means correctness does not depend on the sweeper ever running.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-concurrency-q1", "type": "mcq",
      "prompt": "Two users on different servers submit a hold for seat A5 at the same instant. What actually guarantees only one succeeds?",
      "options": [
        {"id":"a","text":"An in-process lock in the booking service"},
        {"id":"b","text":"A conditional UPDATE — `SET status='HELD' WHERE seat_id=$1 AND status='AVAILABLE'` — evaluated and applied atomically by the database, with the affected-row count telling each server whether it won, backed by a unique index on booked seats"},
        {"id":"c","text":"A Redis lock with a 5-minute TTL"},
        {"id":"d","text":"Checking availability immediately before writing"}
      ],
      "correct": "b",
      "explanation": "Only the shared component — the database — can arbitrate between servers. The Redis lock is a contention optimisation whose TTL can be outlived by a pause; check-then-write is the race itself; an in-process lock is invisible to the other server." }
] }
```

## Step 4 — The implementation

An in-memory model that reproduces the same semantics, with the conditional-write behaviour made explicit so it maps directly onto the SQL above:

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
import itertools
import threading


class SeatClass(Enum):
    REGULAR = 1
    PREMIUM = 2
    RECLINER = 3


class SeatStatus(Enum):
    AVAILABLE = "available"
    HELD = "held"
    BOOKED = "booked"


class BookingStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


@dataclass(frozen=True)
class Seat:                                   # physical, immutable
    seat_id: str
    row: str
    number: int
    seat_class: SeatClass


@dataclass
class ShowSeat:                               # per-show availability
    seat: Seat
    status: SeatStatus = SeatStatus.AVAILABLE
    held_until: int | None = None
    booking_id: str | None = None

    def is_takeable(self, now: int) -> bool:
        """AVAILABLE, or a HELD whose hold has expired — mirrors the SQL WHERE clause."""
        if self.status is SeatStatus.AVAILABLE:
            return True
        return self.status is SeatStatus.HELD and self.held_until is not None \
            and self.held_until <= now


class PricingStrategy(ABC):
    @abstractmethod
    def price_paise(self, seat: Seat, show: "Show") -> int: ...


class ClassAndTimePricing(PricingStrategy):
    BASE = {SeatClass.REGULAR: 20_000, SeatClass.PREMIUM: 35_000, SeatClass.RECLINER: 60_000}

    def price_paise(self, seat, show):
        price = self.BASE[seat.seat_class]
        if show.start_hour >= 18:             # evening surcharge
            price = int(price * 1.2)
        return price


@dataclass
class Show:
    show_id: str
    movie: str
    screen_id: str
    start_hour: int
    seats: dict[str, ShowSeat] = field(default_factory=dict)


@dataclass
class Booking:
    booking_id: str
    user: str
    show_id: str
    seat_ids: list[str]
    total_paise: int
    status: BookingStatus = BookingStatus.PENDING


class BookingService:
    HOLD_SECONDS = 300

    def __init__(self, pricing: PricingStrategy):
        self._pricing = pricing
        self._shows: dict[str, Show] = {}
        self._bookings: dict[str, Booking] = {}
        self._ids = itertools.count(1)
        self._lock = threading.Lock()     # stands in for the DB's atomicity

    def add_show(self, show: Show) -> None:
        self._shows[show.show_id] = show

    def available_seats(self, show_id: str, now: int) -> list[str]:
        show = self._shows[show_id]
        return sorted(sid for sid, ss in show.seats.items() if ss.is_takeable(now))

    def hold(self, show_id: str, seat_ids: list[str], user: str, now: int) -> Booking:
        show = self._shows[show_id]
        ordered = sorted(seat_ids)            # global ordering → no deadlock on multi-seat
        with self._lock:
            targets = [show.seats[sid] for sid in ordered]
            if not all(ss.is_takeable(now) for ss in targets):
                taken = [ss.seat.seat_id for ss in targets if not ss.is_takeable(now)]
                raise RuntimeError(f"seats no longer available: {taken}")   # all or nothing

            booking = Booking(
                booking_id=f"B{next(self._ids)}", user=user, show_id=show_id,
                seat_ids=ordered,
                total_paise=sum(self._pricing.price_paise(ss.seat, show) for ss in targets),
            )
            for ss in targets:                # commit the hold
                ss.status = SeatStatus.HELD
                ss.held_until = now + self.HOLD_SECONDS
                ss.booking_id = booking.booking_id
            self._bookings[booking.booking_id] = booking
            return booking

    def confirm(self, booking_id: str, now: int) -> Booking:
        with self._lock:
            booking = self._bookings[booking_id]
            if booking.status is not BookingStatus.PENDING:
                raise ValueError(f"booking is {booking.status.value}")
            show = self._shows[booking.show_id]
            for sid in booking.seat_ids:
                ss = show.seats[sid]
                if ss.booking_id != booking_id or (ss.held_until or 0) <= now:
                    booking.status = BookingStatus.EXPIRED     # hold lapsed before payment
                    raise RuntimeError("hold expired; seats released")
            for sid in booking.seat_ids:      # payment succeeded → make it permanent
                ss = show.seats[sid]
                ss.status, ss.held_until = SeatStatus.BOOKED, None
            booking.status = BookingStatus.CONFIRMED
            return booking

    def cancel(self, booking_id: str) -> None:
        with self._lock:
            booking = self._bookings[booking_id]
            show = self._shows[booking.show_id]
            for sid in booking.seat_ids:
                ss = show.seats[sid]
                ss.status, ss.held_until, ss.booking_id = SeatStatus.AVAILABLE, None, None
            booking.status = BookingStatus.CANCELLED


def build_show() -> tuple[BookingService, Show]:
    seats = {f"A{i}": ShowSeat(Seat(f"A{i}", "A", i, SeatClass.PREMIUM)) for i in range(1, 5)}
    show = Show("S1", "Dune", "SCR1", start_hour=19, seats=seats)
    svc = BookingService(ClassAndTimePricing())
    svc.add_show(show)
    return svc, show


svc, show = build_show()

# --- happy path: hold then confirm ------------------------------------------
b1 = svc.hold("S1", ["A2", "A1"], user="asha", now=0)
assert b1.seat_ids == ["A1", "A2"]                     # sorted for consistent ordering
assert b1.total_paise == 2 * int(35_000 * 1.2)         # premium, evening surcharge
assert svc.available_seats("S1", now=0) == ["A3", "A4"]

# --- a second user cannot take a held seat ----------------------------------
try:
    svc.hold("S1", ["A1"], user="ravi", now=10)
    raise AssertionError("double hold allowed")
except RuntimeError as e:
    print("rejected:", e)

svc.confirm(b1.booking_id, now=60)
assert show.seats["A1"].status is SeatStatus.BOOKED

# --- all-or-nothing: A3 free, A1 booked → the whole request fails ------------
try:
    svc.hold("S1", ["A3", "A1"], user="ravi", now=70)
    raise AssertionError("partial booking allowed")
except RuntimeError:
    pass
assert show.seats["A3"].status is SeatStatus.AVAILABLE   # A3 was NOT taken

# --- an abandoned hold expires and the seat becomes takeable again ----------
b2 = svc.hold("S1", ["A3"], user="meera", now=100)
assert svc.available_seats("S1", now=200) == ["A4"]              # still held
assert svc.available_seats("S1", now=100 + 301) == ["A3", "A4"]  # hold lapsed
try:
    svc.confirm(b2.booking_id, now=100 + 301)
    raise AssertionError("expired hold confirmed")
except RuntimeError as e:
    print("expiry enforced:", e)

print("final statuses:", {sid: ss.status.value for sid, ss in show.seats.items()})
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-impl-q1", "type": "mcq",
      "prompt": "`hold()` sorts the seat ids before taking them. What problem does that prevent?",
      "options": [
        {"id":"a","text":"It makes the booking id deterministic"},
        {"id":"b","text":"Deadlock: with per-seat locks, one user taking A1 then A2 while another takes A2 then A1 forms a circular wait — a fixed global ordering breaks the cycle"},
        {"id":"c","text":"It prevents the seats from being priced twice"},
        {"id":"d","text":"It ensures the seat map is displayed in order"}
      ],
      "correct": "b",
      "explanation": "This is the bank-transfer deadlock in a different costume. Any time a transaction takes more than one lock, acquiring them in a consistent global order is the standard prevention." }
] }
```

## Steps 5 and 6 — Edge cases and extensions

**Edge cases to raise before you are asked:**

| Case | Handling |
|---|---|
| Payment succeeds but the hold already expired | Do **not** book over someone else's seat. Refund automatically and tell the user. Better: extend the hold when payment starts, and make confirmation idempotent on a payment id |
| User pays twice (double-click) | Idempotency key on the booking request; the second attempt returns the first result |
| Seat map is stale in the browser | Optimistic UI plus a definitive server-side check; the conditional write is what actually decides |
| Show cancelled by the cinema | Bulk-cancel bookings and trigger refunds — an **Observer**/event, not a loop inside the show object |
| Group booking wanting adjacent seats | A `SeatAllocationStrategy` (contiguity-aware) — the same extension point as the parking lot's allocator |
| Refund policy varies by how early you cancel | A `CancellationPolicy` strategy returning the refundable amount |
| Very popular show, thousands of concurrent holds | A virtual waiting room and per-user rate limits; the conditional write still guarantees correctness, it just rejects more often |

**Extensions and how they land:**

- **Coupons and offers** → a `DiscountPolicy` composed with pricing (or a decorator chain over `PricingStrategy`).
- **Food and beverage add-ons** → line items on the `Booking`; pricing unchanged.
- **Loyalty points** → an observer on `booking.confirmed`.
- **Multiplex chains and cities** → new entities above `Cinema`; the booking core is untouched.
- **Seat-map rendering** → a read model derived from `ShowSeat`; never a second source of truth.

The closing sentence to have ready: *"The design's core is a per-show seat table, a hold with an expiry, and one conditional write — everything else, pricing, discounts, refunds, notifications, hangs off that as a strategy or an observer."*

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-edge-q1", "type": "mcq",
      "prompt": "Payment succeeds, but by then the user's 5-minute hold has expired and another user has booked the seat. What is the correct behaviour?",
      "options": [
        {"id":"a","text":"Book it anyway for the first user, since they paid"},
        {"id":"b","text":"Never double-book: fail the confirmation, refund automatically, and notify the user — and prevent recurrence by extending the hold when payment starts and making confirmation idempotent on the payment id"},
        {"id":"c","text":"Cancel the other user's booking, since the first user paid first"},
        {"id":"d","text":"Keep the money and issue a credit note without telling the user"}
      ],
      "correct": "b",
      "explanation": "Overbooking is a hard constraint, so a lapsed hold must lose. The correct handling is an automatic refund plus notification, and the design fix is to align the hold window with the payment window rather than to weaken the constraint." }
] }
```

## Key takeaways

- **This problem is about concurrency, not classes.** Get to the seat-contention question yourself rather than waiting to be asked.
- **`Seat` vs `ShowSeat`** is the modelling insight — availability belongs to the (seat, show) pair.
- **Hold with an expiry, not a lock**: a human takes minutes to pay, and no lock should be held that long. The expiry makes abandonment self-healing.
- **One conditional write is the whole mechanism**, backed by a unique index. In-process locks and Redis locks are optimisations; the database constraint is the guarantee.
- **All-or-nothing multi-seat bookings** need a transaction and a consistent seat ordering to avoid deadlock.
- **The same skeleton solves every inventory problem** — flight seats, hotel rooms, event tickets, e-commerce stock, appointment slots. Learn it once here.
