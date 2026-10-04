---
kind: lesson
id_key: interview-prep-45/lld-13-vending-atm
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design a Vending Machine and an ATM"
position: 13
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

These two problems are really the same problem wearing different clothes: a physical machine with a strict **lifecycle**, where nearly every bug turns out to be an illegal transition — "dispensed without payment," "cash released without a matching debit." They're the textbook use case for the **State pattern**, and each one adds a genuinely interesting algorithm on top — coin change for the vending machine, cash denomination selection for the ATM.

## Step 1 — Requirements and the state machine

**Vending machine — what it needs to do:**

- Show the products on offer, with their prices and how many are left.
- Accept coins or notes one at a time, and show the running total.
- Let the customer pick a product: dispense it and hand back the right change, or refuse with a clear reason.
- Cancel at any point before dispensing: refund everything that was put in.
- Admin actions: restock products, refill change, collect the cash.

**Here's the state machine, drawn before writing a single class:**

```
        ┌──────── refund / cancel ─────────┐
        ▼                                   │
     IDLE ──insert coin──▶ HAS_MONEY ──select──▶ DISPENSING ──▶ IDLE
       ▲                       │  ▲                     │
       │                       └──┘ (more coins)        │
       └──────────── out of stock / insufficient ───────┘
                     (stay, with a message)

   Any state ──admin──▶ OUT_OF_SERVICE ──service done──▶ IDLE
```

Every rule the machine has to follow is either an edge on that diagram, or a deliberately missing one:

| Attempted action | Current state | Correct behaviour |
|---|---|---|
| Select a product | IDLE, with no money in | Refuse: "insert money first" |
| Insert a coin | DISPENSING | Refuse: "please wait" |
| Cancel | DISPENSING | Refuse: it's already committed |
| Select an out-of-stock item | HAS_MONEY | Stay in HAS_MONEY, show a message, keep the money |
| Select with not enough credit | HAS_MONEY | Stay, show exactly how much more is needed |
| The machine can't make exact change | HAS_MONEY | **Refuse the sale and refund** — never quietly short-change the customer |

That last row is the interesting one. "I can sell it to you, but I can't give you your change back" must never mean the machine quietly keeps the difference. The standard fix is to refuse the sale and refund everything, or offer the customer store credit instead. Raising this yourself, unprompted, shows you were thinking about the actual domain, not just the code.

> **Remember:** if the machine can't make exact change, it refuses the sale and refunds — it never quietly keeps the difference, and it never dispenses without giving full change.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-states-q1", "type": "mcq",
      "prompt": "A customer has enough credit and the item is in stock, but the machine can't make exact change. What's the correct behaviour?",
      "options": [
        {"id":"a","text":"Dispense the item and keep the difference"},
        {"id":"b","text":"Refuse the sale and refund the money that was inserted (optionally offering store credit instead) — quietly keeping the difference is theft, and dispensing without full change is a guaranteed support ticket"},
        {"id":"c","text":"Dispense the item and give back the closest change it can manage"},
        {"id":"d","text":"Go straight into OUT_OF_SERVICE"}
      ],
      "correct": "b",
      "explanation": "The change-availability check belongs right alongside the stock and credit checks, before anything commits. This is exactly the kind of domain-level thinking this problem is designed to draw out — and it's also why the coin inventory has to be part of the model at all." }
] }
```

## Step 2 — The State pattern implementation

Each state is its own class implementing the same interface. The machine simply hands off to whatever its current state is, and the states themselves decide what transitions are legal. This is exactly what makes illegal transitions *impossible to write by accident*, instead of merely *checked everywhere*.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class Product:
    code: str
    name: str
    price_paise: int
    stock: int


class VendingState(ABC):
    """Every action has a default: a clear rejection. States only override what's actually legal."""
    def insert(self, machine: "VendingMachine", paise: int) -> str:
        return "cannot insert money right now"
    def select(self, machine: "VendingMachine", code: str) -> str:
        return "cannot select right now"
    def cancel(self, machine: "VendingMachine") -> str:
        return "nothing to cancel"
    @abstractmethod
    def name(self) -> str: ...


class IdleState(VendingState):
    def name(self) -> str: return "IDLE"
    def insert(self, machine, paise):
        machine.accept(paise)                 # held in escrow, not the vault, until the sale commits
        machine.state = HasMoneyState()
        return f"credit {machine.credit}"
    def select(self, machine, code):
        return "insert money first"


class HasMoneyState(VendingState):
    def name(self) -> str: return "HAS_MONEY"

    def insert(self, machine, paise):
        machine.accept(paise)
        return f"credit {machine.credit}"

    def select(self, machine, code):
        product = machine.products.get(code)
        if product is None:
            return "unknown product"
        if product.stock == 0:
            return "out of stock"                        # stays in HAS_MONEY, keeps the credit
        if machine.credit < product.price_paise:
            return f"need {product.price_paise - machine.credit} more"

        change_due = machine.credit - product.price_paise
        coins = machine.plan_change(change_due)
        if coins is None:                                 # exact change isn't possible
            refund = machine.refund_all()
            machine.state = IdleState()
            return f"cannot make change; refunded {refund}"

        machine.state = DispensingState()
        return machine.state.dispense(machine, product, coins, change_due)

    def cancel(self, machine):
        refund = machine.refund_all()
        machine.state = IdleState()
        return f"refunded {refund}"


class DispensingState(VendingState):
    def name(self) -> str: return "DISPENSING"

    def dispense(self, machine, product, coins, change_due) -> str:
        product.stock -= 1
        machine.commit_escrow()                           # the escrowed coins now join the vault
        for denom, count in coins.items():                # remove exactly the change handed out
            machine.coin_box[denom] -= count
        machine.credit = 0
        machine.state = IdleState()
        return f"dispensed {product.name}, change {change_due}"


class VendingMachine:
    def __init__(self, products: list[Product], coins: dict[int, int]):
        self.products = {p.code: p for p in products}
        self.coin_box = dict(coins)          # the vault: denomination (paise) -> count
        self.escrow: dict[int, int] = {}     # coins inserted but not yet committed to a sale
        self.credit = 0
        self.state: VendingState = IdleState()

    def accept(self, paise: int) -> None:
        self.escrow[paise] = self.escrow.get(paise, 0) + 1
        self.credit += paise

    def commit_escrow(self) -> None:
        for denom, count in self.escrow.items():
            self.coin_box[denom] = self.coin_box.get(denom, 0) + count
        self.escrow.clear()

    # --- delegation: the machine itself never makes a decision ---------------
    def insert(self, paise: int) -> str: return self.state.insert(self, paise)
    def select(self, code: str) -> str: return self.state.select(self, code)
    def cancel(self) -> str: return self.state.cancel(self)

    def plan_change(self, amount: int) -> dict[int, int] | None:
        """Greedy over the coins on hand. Returns None if exact change isn't possible."""
        remaining, plan = amount, {}
        for denom in sorted(self.coin_box, reverse=True):
            take = min(remaining // denom, self.coin_box[denom])
            if take:
                plan[denom] = take
                remaining -= denom * take
        return plan if remaining == 0 else None

    def refund_all(self) -> int:
        """Hand back exactly the coins put in — the escrow is why a refund is always possible."""
        refund, self.credit = self.credit, 0
        self.escrow.clear()
        return refund


machine = VendingMachine(
    products=[Product("A1", "chips", 3_000, stock=1), Product("A2", "cola", 5_000, stock=0)],
    coins={1_000: 5, 500: 2, 100: 10},
)

assert machine.select("A1") == "insert money first"        # illegal while in IDLE
assert machine.state.name() == "IDLE"

machine.insert(2_000)
assert machine.state.name() == "HAS_MONEY"
assert machine.select("A1") == "need 1000 more"            # stays in HAS_MONEY
assert machine.select("A2") == "out of stock"              # the credit is untouched

machine.insert(2_000)                                       # credit is now 4000
assert machine.select("A1") == "dispensed chips, change 1000"
assert machine.state.name() == "IDLE" and machine.credit == 0
assert machine.products["A1"].stock == 0

machine.insert(1_000)
assert machine.cancel() == "refunded 1000"                  # cancel refunds everything put in
assert machine.state.name() == "IDLE"
print("final state:", machine.state.name(), "| vault:", machine.coin_box, "| escrow:", machine.escrow)
```

Notice what the pattern buys you: there's **no `if state ==` anywhere** inside `VendingMachine`. Adding a `MAINTENANCE` state means one new class, and not a single existing method has to change.

> **Remember:** giving every action a safe default means a new state can never accidentally forget to handle one. Its overrides become a readable list of exactly what's legal.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-state-q1", "type": "mcq",
      "prompt": "What does the base `VendingState` class gain by defining every action with a default rejection message?",
      "options": [
        {"id":"a","text":"It cuts down the number of classes needed"},
        {"id":"b","text":"Every state automatically handles every action — a new state can never accidentally leave one undefined, and each concrete state only has to override the transitions that are actually legal for it"},
        {"id":"c","text":"It makes the machine thread-safe"},
        {"id":"d","text":"It lets states be compared for equality"}
      ],
      "correct": "b",
      "explanation": "A safe default plus a few selective overrides means the legal transitions are exactly the methods that got overridden — the state class turns into a readable declaration of what's allowed, with no way to accidentally forget a case." }
] }
```

## Step 3 — The ATM: the same machine, harder money

**What it needs to do**: authenticate a card and PIN, check the balance, withdraw cash, deposit, print a receipt, eject the card. **States**: `IDLE → CARD_INSERTED → AUTHENTICATED → TRANSACTION → DISPENSING → IDLE`, plus `OUT_OF_SERVICE`.

Three things make the ATM more than just a vending machine wearing a different skin:

**1. Authentication is a state with a retry counter built in.** Three wrong PINs in a row has to capture or block the card. That counter lives on the session, not on the card itself, and being blocked is a real state transition — not just a boolean checked in five different places.

**2. Dispensing cash is a denomination problem, not just subtraction.** Withdrawing ₹3,700 from a machine holding ₹2,000, ₹500, and ₹100 notes needs an actual plan for which notes to use, and the machine has to **refuse cleanly** whenever it can't make up that amount from what it's holding.

Greedy, meaning always take the biggest note first, works fine for the standard Indian note set, and most real currencies in general, but it's **not correct in general**. For denominations {1, 3, 4} and an amount of 6, greedy gives you 4+1+1, three notes, while the actual best answer is 3+3, just two notes. The general answer is a coin-change dynamic program. Say both: greedy for a standard, well-behaved currency, and DP whenever the denomination set is arbitrary or you genuinely need the minimum note count. This single observation is one of the highest-value things you can say in this whole problem, because it ties LLD directly back to the coin-change pattern from the algorithms section.

**3. The debit and the dispense can never be allowed to disagree.** The failure that actually matters here: the account gets debited, and then the cash dispenser jams. The correct sequence is **reserve, then dispense, then commit** — with a compensating credit if the dispense fails. This is the saga pattern from the distributed-transactions HLD lesson, in miniature. Bringing this up yourself is the senior move in this whole problem.

```python
def plan_notes(amount: int, inventory: dict[int, int]) -> dict[int, int] | None:
    """Greedy note selection, limited by what the machine actually holds."""
    remaining, plan = amount, {}
    for note in sorted(inventory, reverse=True):
        take = min(remaining // note, inventory[note])
        if take:
            plan[note] = take
            remaining -= note * take
    return plan if remaining == 0 else None


def min_notes_dp(amount: int, denominations: list[int]) -> int | None:
    """Unbounded coin change: the provably minimal note count, for when greedy isn't safe."""
    INF = float("inf")
    best = [0] + [INF] * amount
    for value in range(1, amount + 1):
        for d in denominations:
            if d <= value and best[value - d] + 1 < best[value]:
                best[value] = best[value - d] + 1
    return None if best[amount] == INF else int(best[amount])


inventory = {2_000: 3, 500: 4, 100: 10}
assert plan_notes(3_700, inventory) == {2_000: 1, 500: 3, 100: 2}
assert plan_notes(50, inventory) is None                 # smaller than the smallest note
assert plan_notes(100_000, inventory) is None            # more than the machine even holds

# Where greedy gets it wrong, and DP gets it right:
assert min_notes_dp(6, [1, 3, 4]) == 2                   # 3 + 3
greedy_count = sum(plan_notes(6, {4: 5, 3: 5, 1: 5}).values())
assert greedy_count == 3                                 # 4 + 1 + 1
print("greedy notes:", greedy_count, "| optimal:", min_notes_dp(6, [1, 3, 4]))
```

> **Remember:** greedy note selection only works because real currencies are built to make it work. For an arbitrary denomination set, only dynamic programming guarantees the minimum.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-atm-q1", "type": "mcq",
      "prompt": "Why is greedy note selection fine for a real ATM, but not a general solution to \"minimise the number of notes\"?",
      "options": [
        {"id":"a","text":"Greedy runs slower than dynamic programming"},
        {"id":"b","text":"Greedy is only optimal for well-designed denomination sets; for an arbitrary set like {1, 3, 4} it gives 4+1+1 for the amount 6, where 3+3 is actually better — a true general minimum needs the coin-change DP"},
        {"id":"c","text":"Greedy can't take the machine's actual note inventory into account"},
        {"id":"d","text":"Greedy only fails when the amount doesn't divide evenly by the largest note"}
      ],
      "correct": "b",
      "explanation": "Real currencies are designed to make greedy both correct and fast. Stating the caveat, and knowing the DP fallback, is what shows you understand *why* greedy works here rather than that it just happens to." }
] }
```

## Steps 4 and 5 — Concurrency, edge cases, and extensions

**Concurrency.** A single physical vending machine only ever serves one customer at a time, so the interesting version of this question is really about the ATM network as a whole:

| Concern | How it's handled |
|---|---|
| Two ATMs withdrawing from the same account at once | The **account balance is the shared, changeable data**, and it lives in the bank's own database: `UPDATE accounts SET balance = balance - $1 WHERE id = $2 AND balance >= $1` — zero rows affected means insufficient funds, checked and applied atomically |
| Cash inventory inside a single machine | A lock (or a single-threaded controller) around planning and dispensing together — this is a check-then-act sequence |
| Card session state | Scoped to that one session, with nothing shared |
| Debit succeeds but the dispense fails | A compensating credit; the whole transaction is a saga with an explicit `RESERVED` state, and a reconciliation process catches anything the compensation missed |

**Edge cases worth raising yourself:**

| Case | How it's handled |
|---|---|
| Power failure mid-dispense | Write down the intent before acting on it. On restart, compare that journal against the physical cash count |
| Card left in the machine | A timeout, then the card gets captured and the machine returns to IDLE |
| A note gets jammed | Enter OUT_OF_SERVICE and raise an alert — never silently retry |
| Daily withdrawal limits | A policy object, checked before the funds are even reserved |
| Coin box full, or running low on cash | Admin-configured thresholds and an alert; refuse denominations that would overflow the box |
| A product's price changes mid-selection | Read the price once, at the moment of selection, and use that same value for the whole transaction |

**Extensions, and how the design absorbs each one:**

- **Card payments on the vending machine** → a `PaymentMethod` interface (`CoinPayment`, `CardPayment`, `UpiPayment`); the state machine doesn't change, since every state only cares whether "credit is sufficient," never how that credit arrived.
- **Multiple currencies or regions** → a denomination set passed in as configuration, not hardcoded — which is exactly why `plan_change` loops over `self.coin_box` instead of a fixed list.
- **Remote telemetry and restocking alerts** → **Observers** on stock levels and cash levels changing.
- **A maintenance mode** → one new state class.
- **Different dispensing hardware** → an interface sitting behind `DispensingState`.

> **Remember:** debit-then-dispense is a saga, not a single transaction. Reserve, act, commit — and have a compensating credit ready for when it fails.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-saga-q1", "type": "mcq",
      "prompt": "An ATM debits the account, and then the cash dispenser jams. What's the correct design response?",
      "options": [
        {"id":"a","text":"Keep retrying the dispense until it eventually succeeds"},
        {"id":"b","text":"Treat it as a saga: reserve the funds first, attempt the dispense, and only commit on success — on failure, run a compensating credit, log the incident, and let a reconciliation process check the physical cash count against the ledger"},
        {"id":"c","text":"Roll back the database transaction after the dispense has already failed"},
        {"id":"d","text":"Mark the account as disputed and just wait for the customer to call in"}
      ],
      "correct": "b",
      "explanation": "The debit has already gone through and other systems may have already seen it, so it can't be rolled back — and the physical world offers no rollback at all. Reserve, act, commit, with a compensating transaction plus reconciliation, is the standard fix, exactly like in any cross-service workflow." }
] }
```

## Quick recap

- **Draw the state machine before you write a single class.** Both of these problems are lifecycles at heart, and the diagram *is* the design — every rule is either an edge, or a deliberately missing one.
- **State pattern with a rejecting base class** means every state handles every action, illegal transitions become impossible to write by accident, and a new state is one new class with zero edits anywhere else.
- **The change or note-selection problem is the algorithmic core**: greedy, limited by what's actually on hand, refusing cleanly when exact change isn't possible — plus the honest caveat that greedy is only optimal for well-designed denomination sets.
- **Never silently keep the customer's money.** Check whether change is available right alongside stock and credit, before anything actually commits.
- **The ATM's debit-then-dispense is a saga.** Reserve, act, commit, compensate, and reconcile — the exact same reasoning as any cross-system workflow, which is why this problem shows up in backend interviews just as often as LLD ones.
