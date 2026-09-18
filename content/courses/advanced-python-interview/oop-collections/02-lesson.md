---
kind: lesson
id_key: advanced-python-interview/oop-collections/encapsulation
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "Encapsulation"
position: 1
estimated_minutes: 12
source: [fifty-advanced-python-concepts/15.encapsulation.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Encapsulation means hiding an object's internal state and forcing outside code to go through a controlled interface (methods) instead of reaching in and mutating fields directly. It protects invariants — rules that must always hold, like "balance can never go negative."

## Python has no real "private" — it has a convention

Unlike Java's `private` keyword, Python doesn't enforce access restrictions at the language level. Instead it uses naming conventions the whole ecosystem agrees to respect:

- `self.balance` — public, anyone can read/write it
- `self._balance` — single underscore, "internal use, but I trust you" (a hint, nothing more)
- `self.__balance` — double underscore, triggers **name mangling**

```python
class BankAccount:
    def __init__(self, owner, balance):
        self.owner = owner
        self.__balance = balance  # name-mangled to _BankAccount__balance

    def deposit(self, amount):
        if amount > 0:
            self.__balance += amount

    def withdraw(self, amount):
        if 0 < amount <= self.__balance:
            self.__balance -= amount

    def get_balance(self):
        return self.__balance  # controlled, read-only access

account = BankAccount("Alice", 1000)
account.deposit(500)
account.withdraw(200)
print(account.get_balance())  # 1300

# The double underscore doesn't make this impossible, just inconvenient:
print(account._BankAccount__balance)  # 1300 — name mangling, not real privacy
```

## What name mangling actually does

`self.__balance` inside `BankAccount` is rewritten by the interpreter at compile time to `self._BankAccount__balance`. The point isn't security — it's collision avoidance in inheritance: if a subclass also defines `__balance`, the two don't clash, because each gets mangled with its own class name as the prefix. Treat it as "strongly discourage accidental external access," not "make private."

## Why bother, if it's not enforced?

The `deposit`/`withdraw` methods are the *only* way to change `__balance`, and both validate their input (`amount > 0`, `amount <= self.__balance`) before mutating state. If external code could write `account.balance = -500` directly, that invariant — balance never goes negative — would be trivial to break by accident. Encapsulation isn't about stopping malicious code; it's about making the one correct way to change state the only *easy* way to change state.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-encapsulation-q1",
      "type": "mcq",
      "prompt": "What does Python actually do with an attribute named `self.__balance` inside class `BankAccount`?",
      "options": [
        { "id": "a", "text": "Makes it truly inaccessible from outside the class, like Java's private" },
        { "id": "b", "text": "Renames it to `self._BankAccount__balance` (name mangling) — still accessible, just inconvenient" },
        { "id": "c", "text": "Raises a SyntaxError, since double underscores are reserved" },
        { "id": "d", "text": "Turns it into a class variable shared by all instances" }
      ],
      "correct": "b",
      "explanation": "Python has no enforced privacy. A double-underscore attribute is name-mangled to `_ClassName__attr`, which discourages accidental access but doesn't prevent it."
    },
    {
      "id": "oop-collections-encapsulation-q2",
      "type": "mcq",
      "prompt": "Why does `BankAccount` expose `deposit()`/`withdraw()` methods instead of letting callers set `account.balance` directly?",
      "options": [
        { "id": "a", "text": "Direct attribute access is slower in Python" },
        { "id": "b", "text": "So the class can validate every mutation (e.g. reject a negative withdrawal) and protect its invariants" },
        { "id": "c", "text": "Because Python doesn't allow public numeric attributes" },
        { "id": "d", "text": "It's purely a stylistic convention with no functional benefit" }
      ],
      "correct": "b",
      "explanation": "Routing every state change through validated methods is how the class guarantees an invariant (balance never negative) stays true no matter how the object is used."
    }
  ]
}
```
