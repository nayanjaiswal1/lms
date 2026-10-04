---
kind: lesson
id_key: interview-prep-45/lld-12-splitwise
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Design an Expense-Sharing App (Splitwise)"
position: 12
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
---

This is the *money and algorithms* problem of the section. The class model is genuinely small. What interviewers are actually checking is whether you represent money correctly, whether your split rules can be swapped out, and whether you can produce the settlement algorithm — "work out the fewest transactions needed to clear everyone's debts" — the moment they ask.

## Step 1 — Requirements and the money rules

**What the system needs to do:**

- Add users, and let them form groups.
- Add an expense: who paid, how much, who shares it, and how the split is worked out.
- Support **equal**, **exact**, and **percentage** splits — and be ready to add more later.
- Show each user's balance: who owes whom, and how much.
- **Simplify debts**: settle up a whole group in the fewest transactions possible.
- Record a settlement payment between two people.

**The money rules, stated up front** — say these immediately, because most people skip them entirely:

1. **Never use floating-point numbers for money.** Store whole numbers in the smallest unit — paise, not rupees. In binary floating point, `0.1 + 0.2` doesn't equal `0.3`, and an expense report that's off by one paisa is a real bug report waiting to happen.
2. **A split has to add up exactly to the total.** Splitting ₹100 three ways gives 33.33... rupees each. The standard fix is to hand the leftover remainder to the first few participants, or to the person who paid. Whichever you pick, say it out loud — an unassigned remainder is money that just vanishes.
3. **Balances are worked out on the fly. They're never stored as the actual source of truth.** Keep the list of expenses, unchangeable, and calculate balances from that list whenever you need them. This is the same reasoning behind any accounting ledger, and it means every balance can always be explained, and every calculation can always be redone from scratch.

**The clarifying questions:**

| Question | Answer used here | What it changes |
|---|---|---|
| What split types? | Equal, exact, percentage — more coming later | **Strategy** |
| Can more than one person pay for one expense? | Yes | `paid_by` is a map, not just a single person |
| Multiple currencies? | Out of scope, but worth mentioning | Would need `Money` to carry a currency and a conversion rule |
| Do we need a full history? | Yes | Expenses are unchangeable records, never edited after the fact |
| Group and non-group expenses? | Both | A group is just a convenience — not required for an expense to exist |

> **Remember:** store money as whole paise, never as a float. And every split must be checked to add up exactly to the total — never just assumed.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-money-q1", "type": "mcq",
      "prompt": "Three friends split ₹100 equally. What does the design need to spell out, and why?",
      "options": [
        {"id":"a","text":"Nothing — 100 divided by 3 is fine with floating-point arithmetic"},
        {"id":"b","text":"That amounts are stored as whole paise, and the 1-paisa remainder left over from 10000 divided by 3 is assigned in a clear, repeatable way (say, to the first participants), so the shares always add up to exactly the total"},
        {"id":"c","text":"That the total should be rounded up to ₹102 so it divides evenly"},
        {"id":"d","text":"That splits always have to be exact amounts, never equal shares"}
      ],
      "correct": "b",
      "explanation": "10000 paise divided by 3 is 3333 with 1 left over. Without a clear rule, that missing paisa either just disappears or gets counted twice, and floating point introduces its own small errors on top. Whole paise plus a clear, repeatable remainder rule is the standard fix." }
] }
```

## Step 2 — Entities and the split strategies

| Concept | Kind of thing | Notes |
|---|---|---|
| `User` | Entity | id, name |
| `Group` | Entity | A named set of users |
| `Money` | Value object | Never changes, whole paise |
| `Expense` | Entity, **never changes once created** | description, total, `paid_by`, calculated `shares` |
| `SplitStrategy` | **Interface** | Equal / exact / percentage / share-units |
| `BalanceSheet` | Service | Works out net balances from the expense list |
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

**Why `Expense` should never change once created**: editing an expense after the fact would quietly change balances that people already acted on, without any warning. Real accounting systems fix mistakes with a new, offsetting entry — the same idea as a ledger correction. If someone asks for editing support, propose "add a corrected version" rather than mutating the original.

**Why `paid_by` is a map, not just one person**: two friends can easily split the bill at the restaurant together. Forcing the payer to be a single person means creating an awkward second expense just to represent that.

> **Remember:** an expense once written down should never change. Corrections are new entries, not edits to the old one.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-entities-q1", "type": "mcq",
      "prompt": "Why calculate balances from the expense list instead of keeping a single changeable `balance` field per user?",
      "options": [
        {"id":"a","text":"Because adding numbers up is faster than reading a field"},
        {"id":"b","text":"Unchangeable expenses form a ledger: balances can always be explained and recalculated from scratch, corrections become new entries instead of silent edits, and there's no risk of one update accidentally overwriting another"},
        {"id":"c","text":"Because balances change too rarely to bother storing them"},
        {"id":"d","text":"Because each user can only ever have one balance"}
      ],
      "correct": "b",
      "explanation": "This is the same reasoning as a double-entry ledger: a calculated balance can always be justified, line by line, and two expenses added at the same time can never quietly overwrite each other's update the way a shared counter could. You can still cache a balance for speed if you need to, but the individual entries stay the actual source of truth." }
] }
```

## Step 3 — The debt simplification algorithm

Here's the question you'll get asked directly: *"n people owe each other various amounts. What's the fewest transactions needed to settle everyone up?"*

**Step 1 — reduce it all down to net balances.** All that actually matters, per person, is one single number: total paid, minus total owed. Positive means they should receive money; negative means they should pay. Just this step alone collapses a tangled web of individual debts (A owes B, B owes C, C owes A) into something you can actually settle cleanly.

**Step 2 — greedily pair up the biggest creditor with the biggest debtor.** Take whoever is owed the most and whoever owes the most, transfer the smaller of the two amounts between them, and repeat. Every single transaction brings at least one person's balance down to exactly zero, so with *n* people whose balance isn't zero, you'll need at most *n − 1* transactions.

```
Balances: A +60, B −40, C −20
  match A(+60) with B(−40) → B pays A 40 → A +20, B 0
  match A(+20) with C(−20) → C pays A 20 → all zero
  2 transactions for 3 people — the n−1 bound holds
```

**Here's the honest part, and it's the senior half of the answer**: this greedy method is **not guaranteed to be the true minimum**. Finding the actual smallest number of transactions turns out to be an NP-hard problem — it's really about finding every possible group of people whose balances happen to add up to zero, and that search itself is the hard part. Greedy always stays at or under *n − 1* transactions, and it's genuinely what production systems use. Naming this limitation earns you more credit than just presenting greedy as if it were provably optimal.

On complexity: sorting or using a heap gives you O(n log n) work per transaction, with at most n − 1 transactions total.

> **Remember:** greedy settlement guarantees at most n − 1 transactions. It's not provably the minimum — say that out loud, don't present it as optimal.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-settle-q1", "type": "mcq",
      "prompt": "How should you correctly describe the greedy \"largest creditor pays largest debtor\" settlement algorithm?",
      "options": [
        {"id":"a","text":"It always produces the provably smallest possible number of transactions"},
        {"id":"b","text":"It's guaranteed to need at most n−1 transactions, and it's what production systems actually use, but it isn't provably optimal — finding the true minimum is NP-hard because it means finding every subset of balances that adds up to zero"},
        {"id":"c","text":"It requires storing every pairwise debt explicitly"},
        {"id":"d","text":"It only works when every balance happens to be equal"}
      ],
      "correct": "b",
      "explanation": "Every greedy step brings at least one person's balance to exactly zero, which bounds it at n−1. Actually proving optimality would mean partitioning the balances into zero-sum groups, and that's the NP-hard part — stating that distinction is the stronger version of this answer." }
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
    """Returns {user: paise}, guaranteed to add up to exactly `total_paise`."""
    @abstractmethod
    def split(self, total_paise: int, participants: list[str], **kwargs) -> dict[str, int]: ...


class EqualSplit(SplitStrategy):
    def split(self, total_paise, participants, **kwargs):
        n = len(participants)
        if n == 0:
            raise ValueError("no participants")
        base, remainder = divmod(total_paise, n)
        # A clear, repeatable rule: the first `remainder` people pay 1 extra paisa each.
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
        # Rounding down loses a little; give the shortfall to the largest shares, deterministically.
        shortfall = total_paise - sum(shares.values())
        for u in sorted(shares, key=lambda x: (-shares[x], x))[:shortfall]:
            shares[u] += 1
        return shares


@dataclass(frozen=True)
class Expense:                                     # never changes once created
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
        if sum(shares.values()) != total_paise:    # always double-checked, never just assumed
            raise AssertionError("split does not sum to total")
        expense = Expense(f"E{next(self._ids)}", description, total_paise,
                          tuple(paid_by.items()), tuple(shares.items()))
        self._expenses.append(expense)
        return expense

    def settle(self, payer: str, payee: str, paise: int) -> Expense:
        """A settlement is really just an expense the payee owes entirely to the payer."""
        return self.add(f"settlement {payer}->{payee}", paise,
                        paid_by={payer: paise}, participants=[payee], strategy=ExactSplit(),
                        amounts={payee: paise})

    def balances(self) -> dict[str, int]:
        """Each user's net position: positive means owed money, negative means owing it."""
        net: dict[str, int] = defaultdict(int)
        for e in self._expenses:
            for user, paid in e.paid_by:
                net[user] += paid
            for user, share in e.shares:
                net[user] -= share
        return {u: v for u, v in net.items() if v != 0}

    def simplify(self) -> list[tuple[str, str, int]]:
        """Greedy: match the largest creditor with the largest debtor. At most n-1 transfers."""
        net = self.balances()
        # Max-heaps via negated keys; tie-break on name so the output stays predictable.
        creditors = [(-v, u) for u, v in net.items() if v > 0]
        debtors = [(v, u) for u, v in net.items() if v < 0]
        heapq.heapify(creditors)
        heapq.heapify(debtors)

        transfers: list[tuple[str, str, int]] = []
        while creditors and debtors:
            credit, creditor = heapq.heappop(creditors)
            debt, debtor = heapq.heappop(debtors)
            amount = min(-credit, -debt)
            transfers.append((debtor, creditor, amount))       # the debtor pays the creditor
            if -credit - amount > 0:
                heapq.heappush(creditors, (credit + amount, creditor))
            if -debt - amount > 0:
                heapq.heappush(debtors, (debt + amount, debtor))
        return transfers


book = ExpenseBook()

# Dinner: Asha pays Rs 1000, split equally three ways -> 33333/33333/33334 paise
dinner = book.add("dinner", 100_000, {"asha": 100_000},
                  ["asha", "ravi", "meera"], EqualSplit())
assert sum(dict(dinner.shares).values()) == 100_000
assert sorted(dict(dinner.shares).values()) == [33_333, 33_333, 33_334]

# Cab: Ravi and Meera co-pay; exact shares
book.add("cab", 60_000, {"ravi": 40_000, "meera": 20_000},
         ["asha", "ravi", "meera"], ExactSplit(),
         amounts={"asha": 30_000, "ravi": 20_000, "meera": 10_000})

# Groceries: a percentage split
book.add("groceries", 45_000, {"meera": 45_000},
         ["asha", "ravi", "meera"], PercentageSplit(),
         percentages={"asha": 50, "ravi": 25, "meera": 25})

net = book.balances()
assert sum(net.values()) == 0                     # the money always balances out to zero

transfers = book.simplify()
assert len(transfers) <= len(net) - 1             # the n-1 bound
assert sum(amount for _, _, amount in transfers) == sum(v for v in net.values() if v > 0)

for debtor, creditor, amount in transfers:
    book.settle(debtor, creditor, amount)
assert book.balances() == {}                      # everything settles down to zero

print("net before settling:", {u: str(Money(v)) for u, v in net.items()})
print("transfers:", [(d, c, str(Money(a))) for d, c, a in transfers])
```

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-impl-q1", "type": "mcq",
      "prompt": "`EqualSplit` uses `divmod(total, n)` and hands the remainder to the first few participants. Why does that rule need to exist at all, instead of just rounding?",
      "options": [
        {"id":"a","text":"To make the split faster to calculate"},
        {"id":"b","text":"Integer division throws away the remainder: without redistributing it, the shares add up to less than the total, and money silently disappears from the ledger — the rule has to be explicit and repeatable so the totals always match"},
        {"id":"c","text":"Because participants have to be sorted alphabetically"},
        {"id":"d","text":"Because Python doesn't allow floating-point rounding"}
      ],
      "correct": "b",
      "explanation": "10000 divided by 3 gives 3333 each, adding up to 9999 — one paisa short. Any split strategy has to guarantee its shares add up exactly to the total, which is exactly why the implementation checks that invariant right after every single split." }
] }
```

## Steps 5 and 6 — Concurrency and extensions

**The shared, changeable data**: the expense list. Because expenses are **only ever added, never changed**, concurrency here turns out to be unusually easy:

| Concern | How it's handled |
|---|---|
| Two people add expenses at the same moment | Additions are independent of each other; balances are always recalculated from the list. No lock needed beyond the append itself |
| Two people settle the same debt at the same moment | Both settlements get recorded; the balance goes negative, which shows up as an overpayment. Fix it with an idempotency key per settlement, or a conditional insert keyed on `(group, payer, payee, amount, client_ref)` |
| A slightly stale balance shown on screen | Perfectly acceptable — and worth saying so. This is eventual consistency, with a clear reason behind it |
| Caching balances for speed | Treat the cache as something you can always recalculate — recompute it or throw it away on every new expense, and never treat it as the real source of truth |

The general lesson worth stating: **unchangeable, append-only data makes concurrency almost free.** That's exactly why every real ledger is designed this way.

**Extensions, and how they fit in:**

| Requirement | What changes |
|---|---|
| A new split type (by shares, like "2 shares to Asha, 1 to Ravi") | A new `SplitStrategy` class; nothing else moves |
| Multiple currencies | `Money` gains a currency field; a `ConversionPolicy` locks in the exchange rate **at the moment the expense is created**, and stores it — never recalculate old balances using today's rate |
| Recurring expenses (rent, subscriptions) | A scheduler that creates new expenses on a timer; the model itself is unchanged |
| Attaching receipts to an expense | A field on `Expense`; the actual files live in object storage, not the database |
| Simplifying debts per group vs. across everyone | The settlement service just takes a filtered balance map — same algorithm, different input |
| Notifying people when someone adds an expense | An **Observer** on `expense.added` |
| Editing an expense | Never edit it directly — mark the original as reversed with an offsetting entry, then add the corrected version. History stays intact either way |

> **Remember:** if multi-currency ever comes up, the exchange rate gets locked in at the moment of the expense, never recalculated later at today's rate.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-12-extend-q1", "type": "mcq",
      "prompt": "The product wants multi-currency support. What's the one decision that matters most here?",
      "options": [
        {"id":"a","text":"Store every amount in US dollars and convert it for display"},
        {"id":"b","text":"Record the currency and the exchange rate that applied *at the moment of the expense*, right on the expense itself, so past balances never shift when today's rate moves"},
        {"id":"c","text":"Convert every balance to the user's own currency on every single read, using the live rate"},
        {"id":"d","text":"Only allow one currency per group"}
      ],
      "correct": "b",
      "explanation": "Recalculating history at today's rate would make a settled debt quietly drift — a balance someone already acted on yesterday would change again today. Locking the rate onto the unchangeable expense record follows exactly the same principle as the append-only ledger: recorded facts stay recorded." }
] }
```

## Quick recap

- **State the money rules first**: whole paise, an explicit rule for leftover remainders, and shares that are checked to add up exactly to the total — never just assumed to.
- **Expenses never change; balances are calculated.** This gets you explainability, the ability to redo any calculation from scratch, and concurrency that's nearly free — the same ledger reasoning that shows up in real payment systems.
- **The split type is the strategy**, and it's exactly the axis interviewers will ask you to extend.
- **The settlement algorithm is net balances, then greedily matching the biggest creditor with the biggest debtor**, bounded at n − 1 transfers — and you should volunteer that greedy isn't provably optimal, since finding the true minimum is NP-hard.
- **`paid_by` as a map** handles people co-paying without twisting the model out of shape, and it costs nothing extra to support from the start.
