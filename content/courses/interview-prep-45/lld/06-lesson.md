---
kind: lesson
id_key: interview-prep-45/lld-06-behavioral-patterns-1
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "Behavioral Patterns I — Strategy, Observer, Command, State, Template Method"
position: 6
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Behavioral patterns describe **how objects communicate and how responsibility is distributed**. These five are the ones that appear in real LLD answers over and over: almost every problem in this section uses Strategy for pricing, Observer for notifications, and State for lifecycle. Learn these properly and you can design most of the classic problems.

## Strategy — swap an algorithm at runtime

**Intent: define a family of interchangeable algorithms and select one at runtime.** It is the direct cure for a growing `if/elif` chain of *behaviours* (as opposed to types).

```python
from abc import ABC, abstractmethod

class PricingStrategy(ABC):
    @abstractmethod
    def price_paise(self, minutes: int) -> int: ...

class FlatRate(PricingStrategy):
    def price_paise(self, minutes: int) -> int: return 5_000

class PerHour(PricingStrategy):
    def __init__(self, rate_paise: int): self.rate = rate_paise
    def price_paise(self, minutes: int) -> int:
        hours = -(-minutes // 60)                 # ceiling division: part-hours round up
        return hours * self.rate

class Progressive(PricingStrategy):
    """First hour cheap, then increasingly expensive — real parking pricing."""
    def price_paise(self, minutes: int) -> int:
        hours, total, rate = -(-minutes // 60), 0, 2_000
        for _ in range(hours):
            total += rate
            rate += 1_000
        return total

class ParkingTicket:
    def __init__(self, strategy: PricingStrategy):
        self.strategy = strategy                   # the context holds a strategy
    def fee(self, minutes: int) -> int:
        return self.strategy.price_paise(minutes)


assert ParkingTicket(FlatRate()).fee(300) == 5_000
assert ParkingTicket(PerHour(3_000)).fee(90) == 6_000        # 1.5 h → 2 h billed
assert ParkingTicket(Progressive()).fee(180) == 2_000 + 3_000 + 4_000

ticket = ParkingTicket(FlatRate())
ticket.strategy = Progressive()                    # swapped at runtime
print("progressive 3h:", ticket.fee(180))
```

**Where it shows up in this section's problems**: parking fees, ride surge pricing, seat allocation rules, split algorithms in Splitwise, eviction policies in a cache, rate-limiting algorithms, sorting/matching rules.

**Strategy vs State** — asked constantly, and the answer is about *who decides*:

| | Strategy | State |
|---|---|---|
| Chosen by | The client, before/while using the context | The states themselves, as the object transitions |
| Alternatives know each other | No — independent algorithms | Yes — each state knows its successors |
| Represents | *How* to do something | *What* the object currently is |

**The lightweight version**: in Python, a strategy can be a plain function. `ParkingTicket(lambda m: 5000)` is a perfectly good strategy, and a dictionary of named functions is often the whole pattern. Say this — knowing when a class is unnecessary ceremony is a senior signal.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-strategy-q1", "type": "mcq",
      "prompt": "What is the clearest difference between Strategy and State?",
      "options": [
        {"id":"a","text":"Strategy uses interfaces, State uses enums"},
        {"id":"b","text":"With Strategy the client chooses which independent algorithm to use; with State the object's own states drive the transitions between one another, encoding a lifecycle rather than an interchangeable algorithm"},
        {"id":"c","text":"Strategy is a creational pattern, State is behavioral"},
        {"id":"d","text":"State can only have two alternatives"}
      ],
      "correct": "b",
      "explanation": "Their class diagrams are nearly identical, so intent separates them. Strategies are independent and externally selected; states know their successors and change the context as the object moves through its lifecycle." }
] }
```

## Observer — publish state changes to interested parties

**Intent: when one object changes, notify everyone who registered, without the subject knowing who they are.** This is pub/sub at the object level, and it is what makes "add a new consumer of this event" a zero-edit change.

```python
from abc import ABC, abstractmethod

class OrderObserver(ABC):
    @abstractmethod
    def on_order_placed(self, order_id: str, total_paise: int) -> None: ...

class Order:                                   # the subject
    def __init__(self):
        self._observers: list[OrderObserver] = []

    def subscribe(self, o: OrderObserver) -> None: self._observers.append(o)
    def unsubscribe(self, o: OrderObserver) -> None: self._observers.remove(o)

    def place(self, order_id: str, total_paise: int) -> None:
        # ... persist the order ...
        for o in list(self._observers):        # copy: a handler may unsubscribe
            try:
                o.on_order_placed(order_id, total_paise)
            except Exception as exc:            # one bad observer must not break the rest
                print(f"  observer {type(o).__name__} failed: {exc}")

class EmailReceipt(OrderObserver):
    def __init__(self): self.sent: list[str] = []
    def on_order_placed(self, order_id, total_paise): self.sent.append(order_id)

class InventoryUpdater(OrderObserver):
    def __init__(self): self.updates = 0
    def on_order_placed(self, order_id, total_paise): self.updates += 1

class BrokenAnalytics(OrderObserver):
    def on_order_placed(self, order_id, total_paise): raise RuntimeError("analytics down")


order = Order()
email, inventory = EmailReceipt(), InventoryUpdater()
for observer in (email, inventory, BrokenAnalytics()):
    order.subscribe(observer)

order.place("ord_1", 49_900)
assert email.sent == ["ord_1"] and inventory.updates == 1   # unaffected by the failure
print("observers notified; email queue:", email.sent)
```

Four production details that turn a textbook answer into a strong one:

1. **Isolate failures** — one throwing observer must not prevent the others, as above.
2. **Decide sync vs async.** Synchronous notification makes the subject as slow as its slowest observer; pushing to a queue is the same pattern at system scale (and connects directly to the HLD messaging lesson).
3. **Unsubscribe, or leak.** A subject holding strong references to observers keeps them alive forever — the classic listener memory leak. Weak references or explicit lifecycle management fix it.
4. **Do not mutate the observer list while iterating it** — copy first, as above.

You have used this everywhere: DOM event listeners, React state subscriptions, Kafka consumer groups, database triggers, and every `on_change` callback you have ever written.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-observer-q1", "type": "mcq",
      "prompt": "What is the most common memory bug in an Observer implementation?",
      "options": [
        {"id":"a","text":"The subject stores too many events"},
        {"id":"b","text":"Observers are never unsubscribed, so the subject's strong references keep them alive indefinitely — the classic listener leak, fixed by explicit unsubscription or weak references"},
        {"id":"c","text":"Observers are notified in the wrong order"},
        {"id":"d","text":"The interface has too many methods"}
      ],
      "correct": "b",
      "explanation": "A long-lived subject holding references to short-lived observers (dialogs, request-scoped handlers, components) prevents garbage collection of the observers and everything they reference. It is the reason UI frameworks pair every subscribe with a teardown." }
] }
```

## Command — turn a request into an object

**Intent: encapsulate a request as an object**, so it can be parameterised, queued, logged, and — the reason it matters most — **undone**.

```python
from abc import ABC, abstractmethod

class Command(ABC):
    @abstractmethod
    def execute(self) -> None: ...
    @abstractmethod
    def undo(self) -> None: ...

class Document:
    def __init__(self): self.text = ""

class AppendText(Command):
    def __init__(self, doc: Document, text: str):
        self.doc, self.text = doc, text
    def execute(self) -> None: self.doc.text += self.text
    def undo(self) -> None: self.doc.text = self.doc.text[: -len(self.text)]

class UpperCase(Command):
    def __init__(self, doc: Document):
        self.doc, self._before = doc, None
    def execute(self) -> None:
        self._before = self.doc.text                 # memento: remember to undo
        self.doc.text = self.doc.text.upper()
    def undo(self) -> None: self.doc.text = self._before

class Editor:                                        # the invoker
    def __init__(self): self.history: list[Command] = []
    def run(self, cmd: Command) -> None:
        cmd.execute()
        self.history.append(cmd)
    def undo(self) -> None:
        if self.history:
            self.history.pop().undo()


doc, editor = Document(), Editor()
editor.run(AppendText(doc, "hello "))
editor.run(AppendText(doc, "world"))
editor.run(UpperCase(doc))
assert doc.text == "HELLO WORLD"

editor.undo(); assert doc.text == "hello world"
editor.undo(); assert doc.text == "hello "
print("after undos:", repr(doc.text))
```

The four capabilities Command unlocks, and why it appears in so many LLD problems:

| Capability | How | Where it shows up |
|---|---|---|
| **Undo/redo** | Each command knows how to reverse itself | Text editors, drawing apps, transactions |
| **Queueing** | Commands are objects, so they can wait in a list | Job queues, thread pools, task schedulers |
| **Logging / replay** | Persist the command stream | Event sourcing, audit trails, crash recovery |
| **Decoupling** | The invoker knows only `execute()` | Buttons, menu items, keyboard shortcuts, remote controls |

A detail worth stating: for undo, a command either **stores the inverse operation** (append → truncate) or **snapshots the prior state** (the Memento pattern, used by `UpperCase` above). Snapshots are simpler and always correct; inverses use far less memory. Choose by the size of the state.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-command-q1", "type": "mcq",
      "prompt": "Which capability is the primary reason to model an operation as a Command object rather than calling a method directly?",
      "options": [
        {"id":"a","text":"It runs faster than a direct method call"},
        {"id":"b","text":"Because the request becomes a first-class object it can be stored, queued, logged, replayed, and — most importantly — undone, none of which is possible with a plain method invocation"},
        {"id":"c","text":"It removes the need for interfaces"},
        {"id":"d","text":"It guarantees the operation succeeds"}
      ],
      "correct": "b",
      "explanation": "Reification is the whole point: once the request is an object, everything you can do with objects (store, schedule, serialise, reverse) becomes available to it." }
] }
```

## State and Template Method

**State — intent: an object changes its behaviour when its internal state changes, as if it changed class.** Use it whenever a domain object has a lifecycle with rules about which transitions are legal — orders, tickets, documents, vending machines, ATMs, elevators.

```python
from abc import ABC, abstractmethod

class OrderState(ABC):
    @abstractmethod
    def pay(self, order: "Order") -> None: ...
    @abstractmethod
    def cancel(self, order: "Order") -> None: ...
    @abstractmethod
    def name(self) -> str: ...

class Created(OrderState):
    def name(self) -> str: return "created"
    def pay(self, order): order.state = Paid()
    def cancel(self, order): order.state = Cancelled()

class Paid(OrderState):
    def name(self) -> str: return "paid"
    def pay(self, order): raise ValueError("already paid")
    def cancel(self, order): order.state = Refunded()      # cancelling a paid order refunds

class Cancelled(OrderState):
    def name(self) -> str: return "cancelled"
    def pay(self, order): raise ValueError("cannot pay a cancelled order")
    def cancel(self, order): raise ValueError("already cancelled")

class Refunded(OrderState):
    def name(self) -> str: return "refunded"
    def pay(self, order): raise ValueError("cannot pay a refunded order")
    def cancel(self, order): raise ValueError("already refunded")

class Order:
    def __init__(self): self.state: OrderState = Created()
    def pay(self): self.state.pay(self)
    def cancel(self): self.state.cancel(self)
    @property
    def status(self) -> str: return self.state.name()


o = Order(); assert o.status == "created"
o.pay();     assert o.status == "paid"
o.cancel();  assert o.status == "refunded"

bad = Order(); bad.cancel()
try:
    bad.pay()
    raise AssertionError("illegal transition allowed")
except ValueError as e:
    print("state machine rejected:", e)
```

Compare this with the alternative — `if self.status == "created" and action == "pay": ...` repeated in every method. The State version makes **illegal transitions impossible to write by accident**, puts each state's rules in one readable place, and adds a new state without touching the existing ones.

The trade-off to name: one class per state means more classes, and the transition map is distributed rather than visible in one table. For a small, stable state machine an enum plus a transition table is often clearer — and saying that is better than reflexively applying the pattern.

**Template Method — intent: a base class fixes the *skeleton* of an algorithm and lets subclasses fill in specific steps.**

```python
from abc import ABC, abstractmethod

class ReportGenerator(ABC):
    def generate(self, rows: list[int]) -> str:      # the template: order is fixed here
        data = self.fetch(rows)
        body = self.format(data)
        return self.decorate(body)                    # hook with a default

    @abstractmethod
    def fetch(self, rows: list[int]) -> list[int]: ...
    @abstractmethod
    def format(self, data: list[int]) -> str: ...
    def decorate(self, body: str) -> str: return body     # optional hook

class TotalsReport(ReportGenerator):
    def fetch(self, rows): return rows
    def format(self, data): return f"total={sum(data)}"

class TopNReport(ReportGenerator):
    def fetch(self, rows): return sorted(rows, reverse=True)[:2]
    def format(self, data): return f"top={data}"
    def decorate(self, body): return f"** {body} **"      # overrides the hook


assert TotalsReport().generate([3, 1, 2]) == "total=6"
assert TopNReport().generate([3, 1, 2]) == "** top=[3, 2] **"
print(TopNReport().generate([9, 4, 7, 1]))
```

**Template Method vs Strategy** is the last confusion to clear: Template Method uses **inheritance** and fixes the algorithm's *structure* at compile time, letting subclasses vary steps; Strategy uses **composition** and swaps the *whole* algorithm at runtime. Template Method is the right call when the sequence of steps genuinely must not vary (a build pipeline, a request lifecycle, a test fixture's setup/run/teardown); Strategy is the right call otherwise — and given the composition-over-inheritance heuristic, Strategy is the more common answer.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-state-q1", "type": "mcq",
      "prompt": "An `Order` has statuses created → paid → shipped → delivered, with cancellation allowed only before shipping. Why prefer the State pattern over status checks scattered through each method?",
      "options": [
        {"id":"a","text":"It uses fewer classes"},
        {"id":"b","text":"Each state's legal transitions live in one class, so illegal transitions are impossible to write by accident and adding a new status means adding a class rather than editing every method's conditionals"},
        {"id":"c","text":"It makes the order object immutable"},
        {"id":"d","text":"It removes the need to persist the status"}
      ],
      "correct": "b",
      "explanation": "Scattered status checks are an Open/Closed violation and drift out of sync as statuses are added. State localises the rules — at the cost of more classes, which is why a small fixed machine may be clearer as an enum plus a transition table." }
] }
```

## Key takeaways

**The recall table:**

| Pattern | Intent | Reach for it when |
|---|---|---|
| **Strategy** | Interchangeable algorithms, chosen at runtime | Pricing, matching, eviction, sorting, split rules — anything with "…policy" in its name |
| **Observer** | Notify many dependents of a state change | Notifications, cache invalidation, UI updates, "and also do X when Y happens" |
| **Command** | A request as an object | Undo/redo, queues, schedulers, audit logs, remote controls |
| **State** | Behaviour changes with lifecycle stage | Orders, tickets, vending machines, ATMs, elevators, documents |
| **Template Method** | Fixed skeleton, variable steps | Pipelines where the sequence must not change |

- **Strategy and Observer appear in almost every LLD problem in this section.** Pricing is a strategy; "notify the user, update inventory, log analytics" is an observer list.
- **State is how you get lifecycle correctness**, and "illegal transitions become unwritable" is the sentence that earns the point.
- **Command is the undo answer**, and knowing the inverse-vs-snapshot trade-off is the follow-up.
- **Prefer Strategy over Template Method** unless the step *order* genuinely must be fixed — composition over inheritance applies to patterns too.
- **Know when the pattern is overkill.** A dict of functions is a strategy; a callback list is an observer. Saying so is a senior signal, not a gap.
