---
kind: lesson
id_key: interview-prep-45/lld-12-splitwise
course: interview-prep-45
section: lld
section_title: "Low-Level Design (LLD)"
section_position: 4
title: "LLD: Splitwise (Expense Sharing)"
position: 12
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

Splitwise is the *money and algorithms* problem of LLD. The class model is small; what interviewers test is whether you represent money correctly, whether your split strategies are pluggable, and whether you can produce the settlement algorithm — "minimise the number of transactions needed to clear all debts" — on demand.

## Step 1 — Requirements and the money rules

**Functional requirements:**

- Add users; create groups of users.
- Add an expense: who paid, how much, who shares it, and how the share is computed.
- Support **equal**, **exact**, and **percentage** splits (and be able to add more).
- Show each user's balance: who owes whom, and how much.
- **Simplify debts**: settle a group with the fewest transactions.
- Record a settlement payment between two users.

**The money rules, stated up front** — these earn points immediately because most candidates skip them:

1. **Never use floating point for money.** Store integer minor units (paise). `0.1 + 0.2 != 0.3` in binary floating point, and an expense report that is one paisa off is a bug report.
2. **A split must sum exactly to the total.** Dividing ₹100 three ways gives 33.33…; the standard resolution is to give the remainder to the first *n* participants (or to the payer). Say which — an unassigned remainder is money that vanishes.
3. **Balances are derived, never stored as the source of truth.** Keep the immutable expense list; compute balances from it. This is the ledger argument from the HLD distributed-transactions lesson, and it makes every balance explainable and every operation replay-safe.

**The clarifying questions:**

| Question | Answer taken here | Effect |
|---|---|---|
| Split types? | Equal, exact, percentage — more later | **Strategy** |
| Multiple payers for one expense? | Support it | `paid_by` is a map, not a single user |
| Multiple currencies? | Out of scope, but mention it | Would need a `Money` with a currency and a conversion policy |
| Do we need history? | Yes | Expenses are immutable records, never edited in place |
| Group and non-group expenses? | Both | A group is a convenience, not a requirement for an expense |

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-money-q1", "type": "mcq",
      "prompt": "Three friends split ₹100 equally. What must the design specify, and why?",
      "options": [
        {"id":"a","text":"Nothing — 100/3 is handled by floating point arithmetic"},
        {"id":"b","text":"That amounts are integer paise and that the 1-paisa remainder of 10000/3 is assigned deterministically (e.g. to the first participants), so the shares sum to exactly the total"},
        {"id":"c","text":"That the total should be rounded up to ₹102 so it divides evenly"},
        {"id":"d","text":"That splits must always be exact amounts, never equal"}
      ],
      "correct": "b",
      "explanation": "10000 paise ÷ 3 = 3333 remainder 1. Without an explicit rule the missing paisa either disappears or is double-counted, and floating point introduces its own drift. Integer minor units plus a deterministic remainder rule is the standard answer." }
] }
```

## Step 2 — Entities and the split strategies

| Concept | Kind | Notes |
|---|---|---|
| `User` | Entity | id, name |
| `Group` | Entity | A named set of users |
| `Money` | Value object | Immutable, integer paise |
| `Expense` | Entity, **immutable** | description, total, `paid_by`, computed `shares` |
| `SplitStrategy` | **Interface** | Equal / exact / percentage / share-units |
| `BalanceSheet` | Service | Derives net balances from the expense list |
| `SettlementService` | Service | The debt-simplification algorithm |

```
User ◇──── Group
  ▲           ▲
  │           │
  └──── Expense ──> SplitStrategy (interface)
          - total: Money                △
          - paid_by: {user: paise}      │
          - shares:  {user: paise}   Equal / Exact / Percentage
                │
                ▼
          BalanceSheet  →  SettlementService.simplify()
```

**Why `Expense` is immutable**: an edited expense would silently change historical balances that people have already acted on. Real systems model a correction as a new compensating record — the same reasoning as an accounting ledger. If the interviewer asks for editing, propose "supersede with a new version" rather than mutation.

**Why `paid_by` is a map**: two people can split the bill at the restaurant. Modelling the payer as a single user forces an artificial second expense.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-entities-q1", "type": "mcq",
      "prompt": "Why compute balances from the expense list rather than maintaining a mutable `balance` field per user?",
      "options": [
        {"id":"a","text":"Because summing is faster than reading a field"},
        {"id":"b","text":"Immutable expenses are a ledger: balances become explainable and reproducible, corrections are new records rather than silent edits, and there is no lost-update risk from concurrent increments"},
        {"id":"c","text":"Because balances change too rarely to store"},
        {"id":"d","text":"Because users can have only one balance"}
      ],
      "correct": "b",
      "explanation": "The same argument as a double-entry ledger: a derived balance can always be justified line by line, and concurrent expense additions cannot lose an update the way a shared mutable counter can. Store a cached balance for speed if needed, but the entries stay the truth." }
] }
```

## Step 3 — The debt simplification algorithm

The question you will be asked: *"n people owe each other various amounts; what is the minimum number of transactions to settle everyone?"*

**Step 1 — collapse to net balances.** All that matters per person is one number: total paid minus total owed. Positive = should receive; negative = should pay. This alone collapses a tangle of pairwise debts (A→B, B→C, C→A) into something settleable.

**Step 2 — greedily match the largest creditor with the largest debtor.** Take the person owed the most and the person owing the most, transfer the smaller of the two magnitudes, and repeat. Each transaction zeroes at least one person, so with *n* non-zero balances you need at most *n−1* transactions.

```
Balances: A +60, B −40, C −20
  match A(+60) with B(−40) → B pays A 40 → A +20, B 0
  match A(+20) with C(−20) → C pays A 20 → all zero
  2 transactions for 3 people — the n−1 bound
```

**The honest caveat, which is the senior part of the answer**: the greedy algorithm is **not guaranteed optimal**. Finding the true minimum is NP-hard (it is a subset-sum/partition problem — every group of people whose balances sum to zero can be settled among themselves, and finding all such groups is the hard part). Greedy always achieves at most *n−1* transactions and is what production systems use. Naming that limitation earns more than presenting greedy as optimal.

Complexity: sorting or a heap gives O(n log n) per transaction and at most n−1 transactions.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-settle-q1", "type": "mcq",
      "prompt": "What is the correct characterisation of the greedy \"largest creditor pays largest debtor\" settlement algorithm?",
      "options": [
        {"id":"a","text":"It always produces the provably minimum number of transactions"},
        {"id":"b","text":"It guarantees at most n−1 transactions and is what production systems use, but it is not provably optimal — the true minimum is NP-hard because it requires finding all subsets whose balances sum to zero"},
        {"id":"c","text":"It requires every pairwise debt to be stored explicitly"},
        {"id":"d","text":"It only works when all balances are equal"}
      ],
      "correct": "b",
      "explanation": "Each greedy step zeroes at least one participant, bounding it at n−1. Optimality would require partitioning the balances into zero-sum subsets, which is the NP-hard part — stating this distinction is the strong version of the answer." }
] }
```

## Step 4 — The implementation

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from collections import defaultdict
import heapq
import itertools


@dataclass(frozen=True)
class Money:
    paise: int
    def __str__(self) -> str: return f"Rs {self.paise / 100:.2f}"


class SplitStrategy(ABC):
    """Returns {user: paise}, guaranteed to sum to exactly `total_paise`."""
    @abstractmethod
    def split(self, total_paise: int, participants: list[str], **kwargs) -> dict[str, int]: ...


class EqualSplit(SplitStrategy):
    def split(self, total_paise, participants, **kwargs):
        n = len(participants)
        if n == 0:
            raise ValueError("no participants")
        base, remainder = divmod(total_paise, n)
        # Deterministic remainder rule: the first `remainder` participants pay 1 paisa more.
        return {u: base + (1 if i < remainder else 0) for i, u in enumerate(participants)}


class ExactSplit(SplitStrategy):
    def split(self, total_paise, participants, *, amounts: dict[str, int], **kwargs):
        if sum(amounts.values()) != total_paise:
            raise ValueError(f"exact shares sum to {sum(amounts.values())}, not {total_paise}")
        if set(amounts) != set(participants):
            raise ValueError("amounts must cover exactly the participants")
        return dict(amounts)


class PercentageSplit(SplitStrategy):
    def split(self, total_paise, participants, *, percentages: dict[str, float], **kwargs):
        if abs(sum(percentages.values()) - 100.0) > 1e-9:
            raise ValueError("percentages must sum to 100")
        shares = {u: int(total_paise * percentages[u] / 100) for u in participants}
        # Rounding down loses paise; give the shortfall to the largest share deterministically.
        shortfall = total_paise - sum(shares.values())
        for u in sorted(shares, key=lambda x: (-shares[x], x))[:shortfall]:
            shares[u] += 1
        return shares


@dataclass(frozen=True)
class Expense:                                     # immutable record
    expense_id: str
    description: str
    total_paise: int
    paid_by: tuple[tuple[str, int], ...]           # ((user, paise), ...) — supports co-payers
    shares: tuple[tuple[str, int], ...]            # ((user, paise), ...)


class ExpenseBook:
    def __init__(self):
        self._expenses: list[Expense] = []
        self._ids = itertools.count(1)

    def add(self, description: str, total_paise: int, paid_by: dict[str, int],
            participants: list[str], strategy: SplitStrategy, **kwargs) -> Expense:
        if sum(paid_by.values()) != total_paise:
            raise ValueError("payments must sum to the expense total")
        shares = strategy.split(total_paise, participants, **kwargs)
        if sum(shares.values()) != total_paise:    # invariant, always checked
            raise AssertionError("split does not sum to total")
        expense = Expense(f"E{next(self._ids)}", description, total_paise,
                          tuple(paid_by.items()), tuple(shares.items()))
        self._expenses.append(expense)
        return expense

    def settle(self, payer: str, payee: str, paise: int) -> Expense:
        """A settlement is just an expense the payee 'owes' entirely to the payer."""
        return self.add(f"settlement {payer}->{payee}", paise,
                        paid_by={payer: paise}, participants=[payee], strategy=ExactSplit(),
                        amounts={payee: paise})

    def balances(self) -> dict[str, int]:
        """Net position per user: positive = owed money, negative = owes money."""
        net: dict[str, int] = defaultdict(int)
        for e in self._expenses:
            for user, paid in e.paid_by:
                net[user] += paid
            for user, share in e.shares:
                net[user] -= share
        return {u: v for u, v in net.items() if v != 0}

    def simplify(self) -> list[tuple[str, str, int]]:
        """Greedy largest-creditor / largest-debtor matching. At most n-1 transfers."""
        net = self.balances()
        # Max-heaps via negated keys; tie-break on name so the output is deterministic.
        creditors = [(-v, u) for u, v in net.items() if v > 0]
        debtors = [(v, u) for u, v in net.items() if v < 0]
        heapq.heapify(creditors)
        heapq.heapify(debtors)

        transfers: list[tuple[str, str, int]] = []
        while creditors and debtors:
            credit, creditor = heapq.heappop(creditors)
            debt, debtor = heapq.heappop(debtors)
            amount = min(-credit, -debt)
            transfers.append((debtor, creditor, amount))       # debtor pays creditor
            if -credit - amount > 0:
                heapq.heappush(creditors, (credit + amount, creditor))
            if -debt - amount > 0:
                heapq.heappush(debtors, (debt + amount, debtor))
        return transfers


book = ExpenseBook()

# Dinner: Asha pays Rs 1000, split equally among three -> 33333/33333/33334 paise
dinner = book.add("dinner", 100_000, {"asha": 100_000},
                  ["asha", "ravi", "meera"], EqualSplit())
assert sum(dict(dinner.shares).values()) == 100_000
assert sorted(dict(dinner.shares).values()) == [33_333, 33_333, 33_334]

# Cab: Ravi and Meera co-pay; exact shares
book.add("cab", 60_000, {"ravi": 40_000, "meera": 20_000},
         ["asha", "ravi", "meera"], ExactSplit(),
         amounts={"asha": 30_000, "ravi": 20_000, "meera": 10_000})

# Groceries: percentage split
book.add("groceries", 45_000, {"meera": 45_000},
         ["asha", "ravi", "meera"], PercentageSplit(),
         percentages={"asha": 50, "ravi": 25, "meera": 25})

net = book.balances()
assert sum(net.values()) == 0                     # money is always conserved

transfers = book.simplify()
assert len(transfers) <= len(net) - 1             # the n-1 bound
assert sum(amount for _, _, amount in transfers) == sum(v for v in net.values() if v > 0)

for debtor, creditor, amount in transfers:
    book.settle(debtor, creditor, amount)
assert book.balances() == {}                      # everything settles to zero

print("net before settling:", {u: str(Money(v)) for u, v in net.items()})
print("transfers:", [(d, c, str(Money(a))) for d, c, a in transfers])
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-impl-q1", "type": "mcq",
      "prompt": "`EqualSplit` uses `divmod(total, n)` and gives the remainder to the first participants. Why is that rule necessary rather than just rounding?",
      "options": [
        {"id":"a","text":"To make the split faster to compute"},
        {"id":"b","text":"Because integer division discards the remainder: without redistributing it the shares sum to less than the total, so money silently disappears from the ledger — the rule must be explicit and deterministic so the sum invariant always holds"},
        {"id":"c","text":"Because participants must be sorted alphabetically"},
        {"id":"d","text":"Because floating point rounding is not allowed in Python"}
      ],
      "correct": "b",
      "explanation": "10000 ÷ 3 = 3333 each, totalling 9999 — one paisa short. Any split strategy must guarantee shares sum exactly to the total, which is why the implementation asserts that invariant after every split." }
] }
```

## Steps 5 and 6 — Concurrency and extensions

**Shared mutable state**: the expense list. Because expenses are **append-only and immutable**, concurrency is unusually easy here:

| Concern | Handling |
|---|---|
| Two users add expenses simultaneously | Appends are independent; balances are recomputed from the list. No lock needed beyond the append itself |
| Two users settle the same debt simultaneously | Both settlements record; the balance goes negative and shows as an overpayment. Fix with an idempotency key per settlement, or a conditional insert on `(group, payer, payee, amount, client_ref)` |
| Balance display under concurrent writes | A slightly stale balance is acceptable — say so; it is eventual consistency with a clear justification |
| Cached balances for performance | Treat the cache as derived: recompute or invalidate on append, never as the source of truth |

The general lesson to state: **immutable, append-only data models make concurrency nearly free.** That is why ledgers are designed this way.

**Extensions and how they land:**

| Requirement | Change |
|---|---|
| New split type (by shares/units, e.g. "2 shares to Asha, 1 to Ravi") | New `SplitStrategy` class; nothing else moves |
| Multiple currencies | `Money` gains a currency; a `ConversionPolicy` fixes the rate **at expense time** and stores it — never convert historical balances at today's rate |
| Recurring expenses (rent, subscriptions) | A scheduler creating expenses; the model is unchanged |
| Expense attachments (receipts) | A field on `Expense`; blobs in object storage, not the database |
| Simplify per group vs globally | The settlement service takes a filtered balance map — same algorithm, different input |
| Notifications when someone adds an expense | **Observer** on `expense.added` |
| Editing an expense | Supersede: mark the original as reversed with a compensating record, then add the corrected one. History stays intact |

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-extend-q1", "type": "mcq",
      "prompt": "The product wants multi-currency support. What is the critical design decision?",
      "options": [
        {"id":"a","text":"Store all amounts in USD and convert on display"},
        {"id":"b","text":"Record the currency and the exchange rate used *at the time of the expense* on the expense itself, so historical balances never change when today's rate moves"},
        {"id":"c","text":"Convert every balance to the user's currency on every read using the live rate"},
        {"id":"d","text":"Only allow one currency per group"}
      ],
      "correct": "b",
      "explanation": "Re-converting history at the current rate makes settled debts drift, so a balance a user acted on yesterday changes today. Freezing the rate on the immutable expense record is the same principle as the append-only ledger: recorded facts do not change." }
] }
```

## Key takeaways

- **Money rules first**: integer minor units, an explicit remainder rule, and shares that sum exactly to the total — asserted, not assumed.
- **Expenses are immutable; balances are derived.** This gives explainability, replay safety, and near-free concurrency, and it is the same ledger argument that appears in payment systems.
- **Split type is the strategy**, and it is the axis the interviewer will extend along.
- **The settlement algorithm is net balances plus greedy max-creditor/max-debtor matching**, at most n−1 transfers — and you should volunteer that greedy is not provably optimal, because the true minimum is NP-hard.
- **`paid_by` as a map** handles co-payers without contorting the model, and costs nothing to add up front.
