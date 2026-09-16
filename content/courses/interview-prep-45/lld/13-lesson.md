---
kind: lesson
id_key: interview-prep-45/lld-13-vending-atm
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Vending Machine and ATM"
position: 13
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

These two problems are the same problem: a physical machine with a strict **lifecycle** where most bugs are illegal transitions ("dispensed without payment", "cash released without a debit"). They are the canonical interview use of the **State pattern**, and they add one genuinely interesting algorithm each — coin change for the vending machine, cash denomination selection for the ATM.

## Step 1 — Requirements and the state machine

**Vending machine — functional requirements:**

- Show available products with prices and stock.
- Accept coins/notes one at a time; show the running credit.
- Select a product: dispense it and return correct change, or reject with a reason.
- Cancel at any point before dispensing: refund everything inserted.
- Admin: restock products, refill change, collect cash.

**The state machine, drawn before any class:**

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

Every rule the machine must obey is an edge (or a missing edge) on that diagram:

| Attempted action | State | Correct behaviour |
|---|---|---|
| Select a product | IDLE (no money) | Reject: "insert money first" |
| Insert a coin | DISPENSING | Reject: "please wait" |
| Cancel | DISPENSING | Reject: already committed |
| Select an out-of-stock item | HAS_MONEY | Stay in HAS_MONEY, show a message, keep the money |
| Select with insufficient credit | HAS_MONEY | Stay, show the shortfall |
| Machine cannot make change | HAS_MONEY | **Refuse the sale and refund** — never short-change the customer |

That last row is the interesting one. "I can sell it but I can't give you your change" must not silently keep the difference; the standard answer is to refuse and refund, or to ask the customer to accept credit. Raising it unprompted shows you thought about the domain rather than the code.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-states-q1", "type": "mcq",
      "prompt": "The customer has enough credit, the item is in stock, but the machine cannot make exact change. What is the correct design behaviour?",
      "options": [
        {"id":"a","text":"Dispense the item and keep the difference"},
        {"id":"b","text":"Refuse the sale and refund the inserted money (optionally offering store credit) — silently keeping the difference is theft and silently dispensing without change is a support ticket"},
        {"id":"c","text":"Dispense the item and dispense the closest available change"},
        {"id":"d","text":"Enter OUT_OF_SERVICE immediately"}
      ],
      "correct": "b",
      "explanation": "The change-availability check belongs *before* the commit, alongside the stock and credit checks. This is the domain-level thinking the problem is designed to elicit; it is also why the coin inventory must be part of the model." }
] }
```

## Step 2 — The State pattern implementation

Each state is a class implementing the same interface; the machine delegates to its current state and the states decide the transitions. This is what makes illegal transitions *impossible to write by accident* rather than *checked everywhere*.

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
    """Every action is defined for every state; the default is a clear rejection."""
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
        machine.accept(paise)                 # into escrow, not the vault, until the sale commits
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
            return "out of stock"                        # stay in HAS_MONEY, keep credit
        if machine.credit < product.price_paise:
            return f"need {product.price_paise - machine.credit} more"

        change_due = machine.credit - product.price_paise
        coins = machine.plan_change(change_due)
        if coins is None:                                 # cannot make exact change
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
        machine.commit_escrow()                           # escrowed coins join the vault
        for denom, count in coins.items():                # remove the change we hand out
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

    # --- delegation: the machine never decides anything itself ---------------
    def insert(self, paise: int) -> str: return self.state.insert(self, paise)
    def select(self, code: str) -> str: return self.state.select(self, code)
    def cancel(self) -> str: return self.state.cancel(self)

    def plan_change(self, amount: int) -> dict[int, int] | None:
        """Greedy over available denominations. Returns None if exact change is impossible."""
        remaining, plan = amount, {}
        for denom in sorted(self.coin_box, reverse=True):
            take = min(remaining // denom, self.coin_box[denom])
            if take:
                plan[denom] = take
                remaining -= denom * take
        return plan if remaining == 0 else None

    def refund_all(self) -> int:
        """Return the exact coins inserted — escrow is why a refund is always possible."""
        refund, self.credit = self.credit, 0
        self.escrow.clear()
        return refund


machine = VendingMachine(
    products=[Product("A1", "chips", 3_000, stock=1), Product("A2", "cola", 5_000, stock=0)],
    coins={1_000: 5, 500: 2, 100: 10},
)

assert machine.select("A1") == "insert money first"        # illegal in IDLE
assert machine.state.name() == "IDLE"

machine.insert(2_000)
assert machine.state.name() == "HAS_MONEY"
assert machine.select("A1") == "need 1000 more"            # stays in HAS_MONEY
assert machine.select("A2") == "out of stock"              # credit retained

machine.insert(2_000)                                       # credit 4000
assert machine.select("A1") == "dispensed chips, change 1000"
assert machine.state.name() == "IDLE" and machine.credit == 0
assert machine.products["A1"].stock == 0

machine.insert(1_000)
assert machine.cancel() == "refunded 1000"                  # cancel refunds everything
assert machine.state.name() == "IDLE"
print("final state:", machine.state.name(), "| vault:", machine.coin_box, "| escrow:", machine.escrow)
```

Notice the property the pattern buys: `VendingMachine` contains **no `if state ==` anywhere**. Adding a `MAINTENANCE` state is one new class, and no existing method changes.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-state-q1", "type": "mcq",
      "prompt": "What does the base `VendingState` class gain by defining every action with a default rejection message?",
      "options": [
        {"id":"a","text":"It reduces the number of classes needed"},
        {"id":"b","text":"Every state automatically handles every action — a new state cannot accidentally leave an action undefined, and each concrete state only overrides the transitions that are actually legal for it"},
        {"id":"c","text":"It makes the machine thread-safe"},
        {"id":"d","text":"It allows states to be compared for equality"}
      ],
      "correct": "b",
      "explanation": "A safe default plus selective overrides means the legal transitions are exactly the overridden methods — the state class becomes a readable declaration of what is permitted, with no way to forget a case." }
] }
```

## Step 3 — The ATM: the same machine with harder money

**Functional requirements**: authenticate a card and PIN, check balance, withdraw cash, deposit, print a receipt, eject the card. **States**: `IDLE → CARD_INSERTED → AUTHENTICATED → TRANSACTION → DISPENSING → IDLE`, plus `OUT_OF_SERVICE`.

Three things make the ATM more than a re-skinned vending machine:

**1. Authentication is a state with a retry counter.** Three wrong PINs must capture or block the card. The counter lives on the session, not on the card object, and the block is a state transition — not a boolean checked in five places.

**2. Cash dispensing is a denomination problem, not a subtraction.** Withdrawing ₹3,700 from a machine holding ₹2,000, ₹500 and ₹100 notes needs a note plan, and the machine must **refuse cleanly** when it cannot compose the amount from what it holds.

Greedy (largest note first) works for the standard Indian and most real note sets, but it is **not correct in general** — for denominations {1, 3, 4} and amount 6, greedy gives 4+1+1 (three notes) while the optimum is 3+3 (two). The general answer is a coin-change dynamic program. Say both: greedy for canonical denomination systems, DP when the set is arbitrary or when you must minimise note count exactly. That single observation is one of the highest-value things you can say in this problem, because it connects LLD to the DSA section's coin-change pattern.

**3. The debit and the dispense must not diverge.** The failure that matters: the account is debited and then the cash dispenser jams. The correct sequence is **reserve → dispense → commit**, with a compensating credit if dispensing fails — the saga pattern from the HLD distributed-transactions lesson, in miniature. Volunteering this is the senior move in the ATM problem.

```python
def plan_notes(amount: int, inventory: dict[int, int]) -> dict[int, int] | None:
    """Greedy note selection, bounded by what the machine actually holds."""
    remaining, plan = amount, {}
    for note in sorted(inventory, reverse=True):
        take = min(remaining // note, inventory[note])
        if take:
            plan[note] = take
            remaining -= note * take
    return plan if remaining == 0 else None


def min_notes_dp(amount: int, denominations: list[int]) -> int | None:
    """Unbounded coin change: the provably minimal note count, when greedy is unsafe."""
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
assert plan_notes(100_000, inventory) is None            # more than the machine holds

# Where greedy is wrong and DP is right:
assert min_notes_dp(6, [1, 3, 4]) == 2                   # 3 + 3
greedy_count = sum(plan_notes(6, {4: 5, 3: 5, 1: 5}).values())
assert greedy_count == 3                                 # 4 + 1 + 1
print("greedy notes:", greedy_count, "| optimal:", min_notes_dp(6, [1, 3, 4]))
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-atm-q1", "type": "mcq",
      "prompt": "Why is greedy note selection acceptable for a real ATM but not a general solution to \"minimise the number of notes\"?",
      "options": [
        {"id":"a","text":"Greedy is slower than dynamic programming"},
        {"id":"b","text":"Greedy is optimal only for canonical denomination systems; for an arbitrary set such as {1, 3, 4} it gives 4+1+1 for 6 where 3+3 is optimal, so a general minimum requires the coin-change DP"},
        {"id":"c","text":"Greedy cannot respect the machine's note inventory"},
        {"id":"d","text":"Greedy fails whenever the amount is not divisible by the largest note"}
      ],
      "correct": "b",
      "explanation": "Real currencies are canonical, so greedy is both correct and fast there — but stating the caveat and the DP fallback is what shows you know *why* it works rather than that it happens to." }
] }
```

## Steps 4 and 5 — Concurrency, edge cases, and extensions

**Concurrency.** A physical vending machine has one customer at a time, so the interesting version of the question is the ATM network:

| Concern | Handling |
|---|---|
| Two ATMs withdrawing from one account simultaneously | The **account balance is the shared state**, and it lives in the bank's database: `UPDATE accounts SET balance = balance - $1 WHERE id = $2 AND balance >= $1` — zero rows affected means insufficient funds, atomically |
| Cash inventory inside one machine | A lock (or a single-threaded controller) around plan-and-dispense; it is check-then-act |
| Card session state | Per-session, no sharing |
| Debit succeeds, dispense fails | Compensating credit; the transaction is a saga with an explicit `RESERVED` state, and reconciliation catches whatever the compensation missed |

**Edge cases worth raising:**

| Case | Handling |
|---|---|
| Power failure mid-dispense | Journal the intent before acting; on restart, reconcile the journal against the physical count |
| Card left in the machine | Timeout → capture the card, transition to IDLE |
| Note jam | Enter OUT_OF_SERVICE, raise an alert, do not silently retry |
| Daily withdrawal limit | A policy object consulted before the reservation |
| Coin box full / cash low | Admin thresholds and an alert; refuse denominations that would overflow |
| Product price changed mid-selection | The price is read once at selection time and used for the whole transaction |

**Extensions and how the design absorbs them:**

- **Card payments on the vending machine** → a `PaymentMethod` interface (`CoinPayment`, `CardPayment`, `UpiPayment`); the state machine is unchanged because states depend on "credit is sufficient", not on how it arrived.
- **Multiple currencies / regions** → a denomination set injected as configuration, not hardcoded — which is exactly why `plan_change` iterates `self.coin_box` rather than a constant list.
- **Remote telemetry and restocking alerts** → **Observers** on stock and cash-level changes.
- **A maintenance mode** → one new state class.
- **Different dispensing hardware** → an interface behind `DispensingState`.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-13-saga-q1", "type": "mcq",
      "prompt": "An ATM debits the account and the cash dispenser then jams. What is the correct design response?",
      "options": [
        {"id":"a","text":"Retry dispensing until it succeeds"},
        {"id":"b","text":"Treat it as a saga: reserve the funds, attempt the dispense, commit only on success — and on failure run a compensating credit, journal the incident, and let a reconciliation process verify the physical cash count against the ledger"},
        {"id":"c","text":"Roll back the database transaction after the dispense fails"},
        {"id":"d","text":"Mark the account as disputed and wait for the customer to call"}
      ],
      "correct": "b",
      "explanation": "The debit has already committed and cannot be rolled back once other systems may have seen it, and the physical world offers no rollback either. Reserve–act–commit with a compensating transaction plus reconciliation is the standard pattern, exactly as in cross-service workflows." }
] }
```

## Key takeaways

- **Draw the state machine before writing a class.** Both problems are lifecycles, and the diagram *is* the design; every rule is an edge or a deliberately missing edge.
- **State pattern with a rejecting base class** means every state handles every action, illegal transitions are unwritable, and a new state is one new class with zero edits.
- **The change/notes problem is the algorithmic core**: greedy bounded by real inventory, with a clean refusal when exact change is impossible — and the honest caveat that greedy is only optimal for canonical denomination sets.
- **Never silently keep the customer's money.** Check change availability alongside stock and credit, before committing.
- **The ATM's debit-then-dispense is a saga.** Reserve, act, commit, compensate, reconcile — the same reasoning as any cross-system workflow, which is why this problem shows up in backend interviews as often as in LLD ones.
