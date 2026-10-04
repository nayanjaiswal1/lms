---
kind: lesson
id_key: interview-prep-45/lld-11-ticket-booking
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design a Movie Ticket Booking System"
position: 11
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

This is the *concurrency* problem of the section. The class model itself is simple — city, cinema, screen, show, seat, booking — and every interviewer moves within about ten minutes to the one question that actually matters: *two people click the same seat at the exact same instant. What happens?* Get that right, and everything else is just bookkeeping.

## Step 1 — Requirements and the booking lifecycle

**What the system needs to do:**

- Search for shows by city, movie, and date.
- Show a show's seat map, with each seat's current availability.
- Let a user pick one or more seats and **hold** them while they pay.
- Confirm the booking once payment succeeds, or release the hold if it fails or times out.
- Cancel a booking, following a refund policy.

**The question that shapes the entire design**: *how long can a user hold a seat before actually paying for it?* The answer — "a few minutes" — immediately rules out holding a database lock that whole time, and points straight to the **reservation-with-a-TTL** pattern instead. Say this early. It's really the insight this whole problem is built around.

**The other clarifying questions:**

| Question | Answer used here | What it changes |
|---|---|---|
| Does pricing vary? | Yes — by seat class and show time | **Strategy** |
| Can a user book multiple seats at once? | Yes — all or nothing | The hold covers a whole *set* of seats |
| What if payment fails, or the user just disappears? | The hold expires on its own | An expiry timestamp, not a boolean flag |
| Multiple servers? | Yes | The invariant has to live in the database |
| Is overbooking ever allowed? | Never | A hard constraint, not a best-effort guess |

**The lifecycle is a state machine**, and it's worth thirty seconds to draw it:

```
AVAILABLE ──hold()──▶ HELD ──confirm()──▶ BOOKED ──cancel()──▶ AVAILABLE
    ▲                  │                                          ▲
    └──── expire() ◀────┘   (TTL elapsed, or payment failed) ──────┘
```

Two things about that diagram are worth points: **HELD is a genuine state, not a boolean**, and **leaving HELD can happen without anyone calling anything at all** — the expiry is driven purely by time, which is exactly why the hold carries a timestamp rather than a flag.

> **Remember:** a seat hold needs an expiry timestamp, not a flag — a crashed browser tab has to release the seat automatically, with nobody having to clean up after it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-req-q1", "type": "mcq",
      "prompt": "Why does a seat hold need an expiry timestamp rather than a plain `is_locked` boolean?",
      "options": [
        {"id":"a","text":"Timestamps are easier to index"},
        {"id":"b","text":"A boolean set by a client that then crashes or just abandons checkout locks the seat forever; an expiry means the hold releases itself, with no cleanup step required for correctness"},
        {"id":"c","text":"Booleans can't be stored in a database"},
        {"id":"d","text":"So that multiple users could hold the same seat at once"}
      ],
      "correct": "b",
      "explanation": "This is the exact same reasoning behind a TTL on a distributed lock: you can never fully trust the holder to release it themselves. An expiry makes abandonment self-healing, and a sweeper job becomes a nice-to-have instead of a correctness requirement." }
] }
```

## Step 2 — Entities and relationships

| Concept | Kind of thing | Notes |
|---|---|---|
| `City`, `Cinema`, `Screen` | Entities | `Cinema ◆── Screen` is composition |
| `Movie` | Entity | Exists on its own, independent of any specific show |
| `Show` | Entity | A movie playing on one screen at one time — this is the unit you actually book |
| `Seat` | Entity | Belongs to a screen: a physical row, number, and class |
| `ShowSeat` | Entity | **The one people forget**: whether a seat is available *for one specific show* |
| `SeatStatus` | Enum | AVAILABLE / HELD / BOOKED |
| `Booking` | Entity | A user's set of show-seats, with its own lifecycle |
| `PricingStrategy` | Interface | Varies by seat class, show time, day |
| `PaymentProcessor` | Interface | Left out of scope to actually implement |

```
City ◇── Cinema ◆── Screen ◆── Seat              (the physical layout)
                       │
                     Show ──> Movie              (one screening)
                       ◆
                       │ 1..*
                   ShowSeat ──> Seat             (availability, per show)
                       │  - status: SeatStatus
                       │  - held_until: int|None
                       │  - booking_id: str|None
                       ▲
                   Booking ◇── 1..* ShowSeat
```

**Splitting `Seat` from `ShowSeat` is the real modelling insight in this problem.** A physical seat exists exactly once and never changes. Its *availability* is a property of the pair (seat, show), not of the seat by itself. If you put `is_booked` directly on `Seat`, you can't express the same seat being booked for the 9pm show while still free for the 6pm one — and being able to say that sentence out loud is worth more here than any pattern name.

> **Remember:** availability belongs to the (seat, show) pair — never to the seat alone.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-entities-q1", "type": "mcq",
      "prompt": "Why separate `Seat` from `ShowSeat` instead of just putting `is_booked` directly on `Seat`?",
      "options": [
        {"id":"a","text":"To cut down the number of database rows"},
        {"id":"b","text":"Availability belongs to the (seat, show) pair, not to the physical seat — seat A5 can be booked for the 9pm show and free for the 6pm one, which a single flag on Seat could never express"},
        {"id":"c","text":"Because Seat has to be unchangeable for thread safety"},
        {"id":"d","text":"Because shows and seats live in different services"}
      ],
      "correct": "b",
      "explanation": "Physical layout and per-screening availability have completely different lifecycles and cardinality. The join entity — ShowSeat — is also exactly where the unique constraint that stops double-booking has to live." }
] }
```

## Step 3 — The concurrency design

This is what the whole interview is actually about. Build the answer up in three layers.

**Layer 1 — the hold is one atomic conditional write.** Not "check availability, then separately mark it held." One single statement that both checks and takes at the same time:

```sql
UPDATE show_seats
   SET status = 'HELD', held_by = $1, held_until = now() + interval '5 minutes'
 WHERE show_id = $2
   AND seat_id = ANY($3)
   AND (status = 'AVAILABLE'
        OR (status = 'HELD' AND held_until < now()));   -- an expired hold can be reclaimed
-- affected rows < requested count  ⇒  someone else already won  ⇒  roll back, tell the user
```

That `AND` clause *is* the entire concurrency mechanism. The database checks the condition and performs the write as one atomic step, so two concurrent attempts genuinely cannot both succeed. Counting the affected rows is how you find out whether you actually won.

**Layer 2 — a multi-seat booking is all-or-nothing.** Wrap the update in a transaction, and require the number of affected rows to exactly equal the number of seats requested, or roll everything back. Half a booking is worse than none at all.

Two seats grabbed in a different order by two different users is exactly the deadlock case from the concurrency lesson — **sort the seat ids before locking**, so every transaction acquires locks in the same fixed order.

**Layer 3 — a unique constraint as the final backstop.** Even with flawless application code, add this:

```sql
CREATE UNIQUE INDEX one_booking_per_seat_per_show
    ON show_seats (show_id, seat_id) WHERE status = 'BOOKED';
```

Application code can always have bugs. A database constraint cannot be bypassed. Bringing this up yourself is exactly the sign of someone who's actually shipped a booking system before.

**Why not just use a Redis lock?** You can, but only as an *optimisation* to cut down contention hitting the database — it can never be the actual guarantee. A garbage-collection pause or a slow network can outlast any TTL, and the lock holder has no way to know it was evicted early. The sentence to say: *"a Redis lock reduces contention; the unique constraint is what actually makes it correct."*

**Expiry**: a background sweeper flips expired holds back to AVAILABLE, mostly to keep the seat map tidy — but the `held_until < now()` clause already built into the hold query means correctness never actually depends on that sweeper running at all.

> **Remember:** only the database can arbitrate between two different servers. A Redis lock helps with load; the unique constraint is what makes it actually correct.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-concurrency-q1", "type": "mcq",
      "prompt": "Two users on two different servers both submit a hold on seat A5 at the exact same instant. What actually guarantees only one of them succeeds?",
      "options": [
        {"id":"a","text":"An in-process lock inside the booking service"},
        {"id":"b","text":"A conditional UPDATE — `SET status='HELD' WHERE seat_id=$1 AND status='AVAILABLE'` — checked and applied atomically by the database, with the affected-row count telling each server whether it won, backed by a unique index on booked seats"},
        {"id":"c","text":"A Redis lock with a 5-minute TTL"},
        {"id":"d","text":"Checking availability right before writing"}
      ],
      "correct": "b",
      "explanation": "Only the piece of the system every server actually shares — the database — can arbitrate between them. A Redis lock is a contention optimisation with a TTL that a pause can outlast; check-then-write on its own is the race itself; an in-process lock is simply invisible to the other server." }
] }
```

## Step 4 — The implementation

An in-memory model that reproduces the exact same behaviour, with the conditional-write logic made explicit so it maps directly onto the SQL above:

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
class Seat:                                   # physical, never changes
    seat_id: str
    row: str
    number: int
    seat_class: SeatClass


@dataclass
class ShowSeat:                               # availability, specific to one show
    seat: Seat
    status: SeatStatus = SeatStatus.AVAILABLE
    held_until: int | None = None
    booking_id: str | None = None

    def is_takeable(self, now: int) -> bool:
        """AVAILABLE, or a HELD seat whose hold has expired — mirrors the SQL WHERE clause."""
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
        if show.start_hour >= 18:             # an evening surcharge
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
        self._lock = threading.Lock()     # stands in for what the database's atomicity gives us

    def add_show(self, show: Show) -> None:
        self._shows[show.show_id] = show

    def available_seats(self, show_id: str, now: int) -> list[str]:
        show = self._shows[show_id]
        return sorted(sid for sid, ss in show.seats.items() if ss.is_takeable(now))

    def hold(self, show_id: str, seat_ids: list[str], user: str, now: int) -> Booking:
        show = self._shows[show_id]
        ordered = sorted(seat_ids)            # a fixed order avoids deadlock on multi-seat holds
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
                    booking.status = BookingStatus.EXPIRED     # the hold lapsed before payment
                    raise RuntimeError("hold expired; seats released")
            for sid in booking.seat_ids:      # payment succeeded — make it permanent
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

# --- the happy path: hold, then confirm --------------------------------------
b1 = svc.hold("S1", ["A2", "A1"], user="asha", now=0)
assert b1.seat_ids == ["A1", "A2"]                     # sorted, so ordering is always consistent
assert b1.total_paise == 2 * int(35_000 * 1.2)         # premium seats, evening surcharge
assert svc.available_seats("S1", now=0) == ["A3", "A4"]

# --- a second user can't take a seat that's already held ---------------------
try:
    svc.hold("S1", ["A1"], user="ravi", now=10)
    raise AssertionError("double hold allowed")
except RuntimeError as e:
    print("rejected:", e)

svc.confirm(b1.booking_id, now=60)
assert show.seats["A1"].status is SeatStatus.BOOKED

# --- all-or-nothing: A3 is free but A1 is booked, so the whole request fails --
try:
    svc.hold("S1", ["A3", "A1"], user="ravi", now=70)
    raise AssertionError("partial booking allowed")
except RuntimeError:
    pass
assert show.seats["A3"].status is SeatStatus.AVAILABLE   # A3 was NOT taken either

# --- an abandoned hold expires, and the seat becomes takeable again ----------
b2 = svc.hold("S1", ["A3"], user="meera", now=100)
assert svc.available_seats("S1", now=200) == ["A4"]              # still held
assert svc.available_seats("S1", now=100 + 301) == ["A3", "A4"]  # the hold lapsed
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
      "prompt": "`hold()` sorts the seat ids before taking them. What problem does that actually prevent?",
      "options": [
        {"id":"a","text":"It makes the booking id predictable"},
        {"id":"b","text":"Deadlock: with a lock per seat, one user grabbing A1 then A2 while another grabs A2 then A1 forms a circular wait — a fixed global ordering breaks that cycle before it can even start"},
        {"id":"c","text":"It stops a seat from being priced twice"},
        {"id":"d","text":"It makes the seat map display in order"}
      ],
      "correct": "b",
      "explanation": "This is the exact same bank-transfer deadlock from the concurrency lesson, wearing a different costume. Any time a transaction takes more than one lock, acquiring them in a fixed, consistent order is the standard fix." }
] }
```

## Steps 5 and 6 — Edge cases and extensions

**Edge cases worth raising before anyone asks:**

| Case | How it's handled |
|---|---|
| Payment succeeds, but the hold already expired by then | Never book over someone else's seat. Refund automatically and tell the user. Even better: extend the hold the moment payment starts, and make confirmation idempotent on a payment id |
| A user pays twice by double-clicking | An idempotency key on the booking request — the second attempt just returns the first result |
| The seat map looks stale in the browser | Show an optimistic update in the UI, but let the server's conditional write make the real decision |
| The cinema cancels the show | Bulk-cancel bookings and trigger refunds through an **Observer**, or an event — never a loop inside the show object itself |
| A group wants seats next to each other | A `SeatAllocationStrategy` that's aware of adjacency — the exact same extension point the parking lot's allocator used |
| Refund amount depends on how early someone cancels | A `CancellationPolicy` strategy that returns the refundable amount |
| A hugely popular show, thousands of holds at once | A virtual waiting room plus per-user rate limits; the conditional write is still what guarantees correctness — it just gets rejected more often |

**Extensions, and how they fit in:**

- **Coupons and offers** → a `DiscountPolicy` combined with pricing (or a decorator layered on top of `PricingStrategy`).
- **Food and drink add-ons** → line items on the `Booking`; pricing itself is unchanged.
- **Loyalty points** → an observer on `booking.confirmed`.
- **Multiplex chains, multiple cities** → new entities added above `Cinema`; the booking core itself doesn't change.
- **Rendering the seat map** → a read-only view built from `ShowSeat`, never a second source of truth.

The closing line worth having ready: *"The core of this design is a per-show seat table, a hold with an expiry, and one conditional write. Everything else — pricing, discounts, refunds, notifications — hangs off that as either a strategy or an observer."*

> **Remember:** never let a lapsed hold win against a correctly-timed one, even when the customer already paid. Refund automatically, and fix the root cause: align the hold window with the payment window.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-11-edge-q1", "type": "mcq",
      "prompt": "Payment succeeds, but by then the user's 5-minute hold has already expired and someone else has booked the seat. What's the correct behaviour?",
      "options": [
        {"id":"a","text":"Book it for the first user anyway, since they paid"},
        {"id":"b","text":"Never double-book: fail the confirmation, refund automatically, and let the user know — and prevent it happening again by extending the hold the moment payment starts, and making confirmation idempotent on the payment id"},
        {"id":"c","text":"Cancel the other user's booking, since the first user paid first"},
        {"id":"d","text":"Keep the money and quietly issue a credit note"}
      ],
      "correct": "b",
      "explanation": "Overbooking is a hard constraint, so a lapsed hold has to lose, no matter what. The correct response is an automatic refund plus a clear notification, and the real fix is aligning the hold window with how long payment actually takes, rather than weakening the constraint." }
] }
```

## Quick recap

- **This problem is about concurrency, not classes.** Bring up the seat-contention question yourself, rather than waiting for the interviewer to ask.
- **`Seat` vs. `ShowSeat`** is the real modelling insight — availability belongs to the (seat, show) pair.
- **A hold with an expiry, not a lock**: a real person takes minutes to pay, and no lock should ever be held that long. The expiry is what makes abandonment heal itself.
- **One conditional write is the whole mechanism**, backed up by a unique index. In-process locks and Redis locks are optimisations; the database constraint is the actual guarantee.
- **All-or-nothing bookings for multiple seats** need both a transaction and a consistent seat ordering, to avoid deadlock.
- **This same skeleton solves every inventory problem you'll ever meet** — flight seats, hotel rooms, event tickets, e-commerce stock, appointment slots. Learn it once, right here.
