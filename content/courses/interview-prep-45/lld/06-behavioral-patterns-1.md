---
kind: lesson
id_key: interview-prep-45/lld-06-behavioral-patterns-1
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Behavioral Patterns I — Strategy, Observer, Command, State, Template Method"
position: 6
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Behavioral patterns are about **how objects talk to each other, and who's responsible for what**. These five show up in real LLD answers over and over: nearly every problem in this section reaches for Strategy to handle pricing, Observer to handle notifications, and State to handle lifecycles. Get comfortable with these five, and you can design most of the classic interview problems.

## Strategy — swap an algorithm while the program runs

**The idea: define a family of interchangeable algorithms, and pick one while the program runs.** It's the direct cure for a growing `if/elif` chain of *behaviours* — as opposed to types, which is what Factory fixes.

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
        hours = -(-minutes // 60)                 # round part-hours up
        return hours * self.rate

class Progressive(PricingStrategy):
    """Cheap for the first hour, then pricier each hour after — real parking pricing."""
    def price_paise(self, minutes: int) -> int:
        hours, total, rate = -(-minutes // 60), 0, 2_000
        for _ in range(hours):
            total += rate
            rate += 1_000
        return total

class ParkingTicket:
    def __init__(self, strategy: PricingStrategy):
        self.strategy = strategy                   # the ticket just HOLDS a strategy
    def fee(self, minutes: int) -> int:
        return self.strategy.price_paise(minutes)


assert ParkingTicket(FlatRate()).fee(300) == 5_000
assert ParkingTicket(PerHour(3_000)).fee(90) == 6_000        # 1.5 hours billed as 2
assert ParkingTicket(Progressive()).fee(180) == 2_000 + 3_000 + 4_000

ticket = ParkingTicket(FlatRate())
ticket.strategy = Progressive()                    # swapped while the program is running
print("progressive 3h:", ticket.fee(180))
```

**Where you'll actually use this in the problems ahead**: parking fees, ride surge pricing, seat allocation rules, split algorithms in an expense-sharing app, what gets evicted from a cache, which rate-limiting algorithm to run, sorting or matching rules.

**Strategy vs. State — this comes up constantly, and it's really about *who's in charge*:**

| | Strategy | State |
|---|---|---|
| Picked by | Whoever's using it, before or during the call | The states themselves, as the object moves through its life |
| Do the options know each other? | No — each algorithm stands alone | Yes — each state knows what it can turn into next |
| Represents | *How* to do something | *What* the object currently is |

**The lightweight version is worth knowing too**: in Python, a strategy can just be a plain function. `ParkingTicket(lambda m: 5000)` is a perfectly valid strategy, and a dictionary of named functions is often the entire pattern, no classes needed. Saying this — knowing when a class would just be extra ceremony — is itself a senior-level signal.

> **Remember:** Strategy is chosen from outside by whoever's using it. State is chosen from inside, by the object as it moves through its own life.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-strategy-q1", "type": "mcq",
      "prompt": "What's the clearest way to tell Strategy and State apart?",
      "options": [
        {"id":"a","text":"Strategy uses interfaces, State uses enums"},
        {"id":"b","text":"With Strategy, whoever is using the object picks which independent algorithm runs; with State, the object's own states drive transitions between each other, modelling a lifecycle rather than an interchangeable algorithm"},
        {"id":"c","text":"Strategy is a creational pattern, State is behavioral"},
        {"id":"d","text":"State can only ever have two possible alternatives"}
      ],
      "correct": "b",
      "explanation": "Their class diagrams look almost identical, so intent is what actually separates them. Strategies stand alone and are picked from outside; states know their own successors and drive the object through a lifecycle from the inside." }
] }
```

## Observer — tell everyone interested when something changes

**The idea: when one object changes, notify everyone who signed up for it, without that object needing to know who they are.** This is publish-subscribe at the object level, and it's exactly what makes "add a new listener for this event" a zero-edit change.

```python
from abc import ABC, abstractmethod

class OrderObserver(ABC):
    @abstractmethod
    def on_order_placed(self, order_id: str, total_paise: int) -> None: ...

class Order:                                   # the thing being watched
    def __init__(self):
        self._observers: list[OrderObserver] = []

    def subscribe(self, o: OrderObserver) -> None: self._observers.append(o)
    def unsubscribe(self, o: OrderObserver) -> None: self._observers.remove(o)

    def place(self, order_id: str, total_paise: int) -> None:
        # ... save the order somewhere ...
        for o in list(self._observers):        # copy the list: a handler might unsubscribe
            try:
                o.on_order_placed(order_id, total_paise)
            except Exception as exc:            # one broken observer must not sink the rest
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
assert email.sent == ["ord_1"] and inventory.updates == 1   # unaffected by the broken one
print("observers notified; email queue:", email.sent)
```

Four details that turn a textbook answer into a strong one:

1. **Isolate failures.** One observer throwing an exception must never stop the others, exactly as shown above.
2. **Decide up front: synchronous or asynchronous?** Notifying synchronously means the subject is only as fast as its slowest observer. Pushing to a queue instead is this same pattern applied at the scale of a whole system, and it connects directly to the messaging lesson in HLD.
3. **Unsubscribe, or leak memory.** A subject that keeps strong references to observers forever keeps them alive forever too — this is the classic listener memory leak. Weak references or an explicit teardown step fix it.
4. **Never mutate the observer list while you're looping over it.** Copy it first, exactly as shown above.

You've already used this everywhere, whether you called it Observer or not: DOM event listeners, React state subscriptions, Kafka consumer groups, database triggers, and every `on_change` callback you've ever written.

> **Remember:** a subject holding onto observers forever is the classic memory leak here. Every subscribe needs a matching unsubscribe somewhere.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-observer-q1", "type": "mcq",
      "prompt": "What's the most common memory bug in an Observer setup?",
      "options": [
        {"id":"a","text":"The subject stores too many past events"},
        {"id":"b","text":"Observers never get unsubscribed, so the subject's strong references keep them alive forever — the classic listener leak, fixed with explicit unsubscribing or weak references"},
        {"id":"c","text":"Observers get notified in the wrong order"},
        {"id":"d","text":"The interface has too many methods"}
      ],
      "correct": "b",
      "explanation": "A long-lived subject holding references to short-lived observers — closed dialogs, finished requests, unmounted components — stops garbage collection from ever cleaning them up. That's why UI frameworks always pair a subscribe with a teardown." }
] }
```

## Command — turn a request into an object

**The idea: wrap a request up as an object**, so it can be handed around, queued, logged, and — the reason it matters most — **undone**.

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
        self._before = self.doc.text                 # remember the old state, to undo later
        self.doc.text = self.doc.text.upper()
    def undo(self) -> None: self.doc.text = self._before

class Editor:                                        # the thing that runs commands
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

Four things Command makes possible, and why it turns up in so many LLD problems:

| It gives you | How | Where you'll see it |
|---|---|---|
| **Undo / redo** | Each command knows how to reverse itself | Text editors, drawing apps, transactions |
| **Queueing** | A command is just an object, so it can wait in a list | Job queues, thread pools, schedulers |
| **Logging and replay** | Save the stream of commands somewhere | Event sourcing, audit trails, crash recovery |
| **Decoupling** | The thing running the command only ever calls `execute()` | Buttons, menu items, keyboard shortcuts, remote controls |

Worth knowing: to make undo work, a command either **stores the reverse operation** (append, then undo by truncating) or **snapshots the state from before** (called the Memento pattern, which is what `UpperCase` does above). Snapshots are simpler and always correct; reverse operations use far less memory. Pick based on how big the state actually is.

> **Remember:** once a request is an object, everything you can do to objects — store it, queue it, log it, reverse it — becomes available. That's the whole reason Command exists.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-command-q1", "type": "mcq",
      "prompt": "What's the main reason to wrap an operation as a Command object instead of just calling a method directly?",
      "options": [
        {"id":"a","text":"It runs faster than a plain method call"},
        {"id":"b","text":"Once the request is a real object it can be stored, queued, logged, replayed, and — most importantly — undone, none of which a plain method call can do"},
        {"id":"c","text":"It removes the need for interfaces"},
        {"id":"d","text":"It guarantees the operation will succeed"}
      ],
      "correct": "b",
      "explanation": "Turning a request into an object is the whole point. Once it's an object, everything objects can do — being stored, scheduled, saved, or reversed — becomes available to it." }
] }
```

## State and Template Method

**State — the idea: an object changes how it behaves as its internal state changes, almost as if it swapped its own class.** Reach for this whenever something has a real lifecycle with rules about which transitions are allowed — orders, tickets, documents, vending machines, ATMs, elevators.

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
    def cancel(self, order): order.state = Refunded()      # cancelling a paid order = a refund

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

Compare that to the alternative: `if self.status == "created" and action == "pay": ...`, repeated in every method that touches an order. The State version makes **illegal transitions impossible to write by accident**, keeps each state's own rules in exactly one readable place, and lets you add a brand-new state without touching any of the existing ones.

There is a real trade-off worth naming: one class per state means more classes overall, and the full map of transitions is spread across several files instead of sitting in one table. For a small, stable state machine, a plain enum plus a transition table is often clearer — and saying that out loud beats reaching for the pattern on reflex.

**Template Method — the idea: a base class fixes the *order* of an algorithm's steps, and subclasses fill in just the steps that actually change.**

```python
from abc import ABC, abstractmethod

class ReportGenerator(ABC):
    def generate(self, rows: list[int]) -> str:      # the template — the order is fixed here
        data = self.fetch(rows)
        body = self.format(data)
        return self.decorate(body)                    # a hook, with a default

    @abstractmethod
    def fetch(self, rows: list[int]) -> list[int]: ...
    @abstractmethod
    def format(self, data: list[int]) -> str: ...
    def decorate(self, body: str) -> str: return body     # optional to override

class TotalsReport(ReportGenerator):
    def fetch(self, rows): return rows
    def format(self, data): return f"total={sum(data)}"

class TopNReport(ReportGenerator):
    def fetch(self, rows): return sorted(rows, reverse=True)[:2]
    def format(self, data): return f"top={data}"
    def decorate(self, body): return f"** {body} **"      # chose to override the hook

assert TotalsReport().generate([3, 1, 2]) == "total=6"
assert TopNReport().generate([3, 1, 2]) == "** top=[3, 2] **"
print(TopNReport().generate([9, 4, 7, 1]))
```

**Template Method vs. Strategy** is the last confusion worth clearing up: Template Method uses **inheritance** and fixes the *order* of steps at write-time, only letting subclasses vary individual steps. Strategy uses **composition** and swaps out the *entire* algorithm while the program is running. Reach for Template Method when the sequence genuinely must never change — a build pipeline, a request's lifecycle, a test's setup-run-teardown. Reach for Strategy for basically everything else — and given the "composition over inheritance" habit from earlier, Strategy is the more common answer in practice.

> **Remember:** State means "illegal transitions become impossible to write by accident," not just "fewer if-statements."

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-06-state-q1", "type": "mcq",
      "prompt": "An `Order` moves through created -> paid -> shipped -> delivered, and can only be cancelled before shipping. Why prefer the State pattern over status checks spread across each method?",
      "options": [
        {"id":"a","text":"It uses fewer classes overall"},
        {"id":"b","text":"Each state's legal moves live in exactly one class, so illegal transitions become impossible to write by accident, and adding a new status means adding a class instead of editing every method's conditionals"},
        {"id":"c","text":"It makes the order object unchangeable"},
        {"id":"d","text":"It removes the need to save the status anywhere"}
      ],
      "correct": "b",
      "explanation": "Status checks scattered across methods are an Open/Closed violation, and they drift out of sync as new statuses get added. State keeps the rules in one place per state — at the cost of more classes, which is why a small, stable machine might be clearer as an enum plus a transition table instead." }
] }
```

## Quick recap

| Pattern | Intent | Reach for it when |
|---|---|---|
| **Strategy** | Interchangeable algorithms, picked at runtime | Pricing, matching, eviction, sorting, split rules — anything with "…policy" in its name |
| **Observer** | Notify many listeners when one thing changes | Notifications, cache invalidation, UI updates, "and also do X when Y happens" |
| **Command** | A request, turned into an object | Undo/redo, queues, schedulers, audit logs, remote controls |
| **State** | Behaviour changes with lifecycle stage | Orders, tickets, vending machines, ATMs, elevators, documents |
| **Template Method** | Fixed order, variable steps | Pipelines where the sequence must never change |

- **Strategy and Observer show up in nearly every LLD problem in this section.** Pricing is a strategy. "Notify the user, update inventory, log it for analytics" is an observer list.
- **State is how you get lifecycle correctness right**, and "illegal transitions become unwritable" is the exact sentence that earns credit.
- **Command is the answer to undo**, and knowing the reverse-vs-snapshot trade-off is the natural follow-up question.
- **Prefer Strategy over Template Method** unless the *order* of steps genuinely has to stay fixed — composition over inheritance applies to patterns too, not just plain classes.
- **Know when a pattern is overkill.** A dictionary of functions is a strategy. A plain list of callbacks is an observer. Saying so out loud is a senior-level signal, not a gap in your knowledge.
