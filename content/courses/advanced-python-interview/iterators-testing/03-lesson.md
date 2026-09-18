---
kind: lesson
id_key: advanced-python-interview/iterators-testing/staticmethod-classmethod
course: advanced-python-interview
section: iterators-testing
section_title: "Iterators, Generators & Testing"
section_position: 3
title: "`@staticmethod` and `@classmethod`"
position: 2
estimated_minutes: 12
source: [fifty-advanced-python-concepts/23.staticmethods_and_classmethods.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
A regular method automatically receives the instance as its first argument (`self`). `@staticmethod` and `@classmethod` change what — if anything — gets passed in automatically, and each exists for a different reason.

## `@classmethod`: receives the class, not the instance

```python
class BankAccount:
    interest_rate = 0.03  # class-level default, shared unless overridden per-instance

    def __init__(self, account_type, balance):
        self.account_type = account_type
        self.balance = balance

    @staticmethod
    def is_valid_transaction(amount):
        """No self, no cls — behaves like a plain function namespaced under the class."""
        return amount > 0

    @classmethod
    def create_savings_account(cls, initial_deposit):
        """Factory method: cls is the class itself (BankAccount, or a subclass)."""
        if not cls.is_valid_transaction(initial_deposit):
            raise ValueError("Initial deposit must be positive.")
        return cls("Savings", initial_deposit)  # cls(...) — works for subclasses too

    @classmethod
    def create_business_account(cls, initial_deposit):
        if not cls.is_valid_transaction(initial_deposit):
            raise ValueError("Initial deposit must be positive.")
        account = cls("Business", initial_deposit)
        account.interest_rate = 0.05  # business accounts get a higher rate
        return account

savings = BankAccount.create_savings_account(1000)
business = BankAccount.create_business_account(5000)

print(f"Savings: ${savings.balance}, rate {savings.interest_rate}")   # $1000, 0.03
print(f"Business: ${business.balance}, rate {business.interest_rate}") # $5000, 0.05
```

`create_savings_account` and `create_business_account` are **factory methods** — alternate, named constructors. This is the single most common real-world use of `@classmethod`: `BankAccount.create_savings_account(1000)` reads far more clearly at the call site than `BankAccount("Savings", 1000)`, where the string `"Savings"` gives no hint what it means without reading the constructor.

## `@staticmethod`: no automatic argument at all

`is_valid_transaction` doesn't need `self` (it doesn't touch instance state) or `cls` (it doesn't touch class state) — it's pure logic that happens to belong conceptually to `BankAccount`. Marking it `@staticmethod` means it can be called on the class directly (`BankAccount.is_valid_transaction(-50)`) or on an instance (`account.is_valid_transaction(100)`) with identical behavior, since nothing is auto-injected either way.

## Why `cls` (not the class name) inside a classmethod

`create_savings_account` calls `cls(...)`, not `BankAccount(...)`, specifically so that if a subclass `PremiumAccount(BankAccount)` calls `PremiumAccount.create_savings_account(1000)`, `cls` is `PremiumAccount` — the factory correctly returns a `PremiumAccount` instance, not a plain `BankAccount`. Hardcoding the class name would silently break for every subclass.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-staticmethod-classmethod-q1",
      "type": "mcq",
      "prompt": "What is automatically passed as the first argument to a method decorated with `@staticmethod`?",
      "options": [
        { "id": "a", "text": "self, the instance" },
        { "id": "b", "text": "cls, the class" },
        { "id": "c", "text": "Nothing — no argument is auto-injected" },
        { "id": "d", "text": "Both self and cls" }
      ],
      "correct": "c",
      "explanation": "@staticmethod strips the automatic first-argument injection entirely — it behaves like a plain function that happens to live in the class's namespace."
    },
    {
      "id": "iterators-testing-staticmethod-classmethod-q2",
      "type": "mcq",
      "prompt": "Why does `create_savings_account` call `cls(...)` instead of `BankAccount(...)`?",
      "options": [
        { "id": "a", "text": "cls(...) is just a stylistic preference with no functional difference" },
        { "id": "b", "text": "So that if a subclass inherits this classmethod, calling it on the subclass returns an instance of the subclass, not BankAccount" },
        { "id": "c", "text": "BankAccount(...) would raise a NameError inside the class body" },
        { "id": "d", "text": "cls(...) is required syntax for any method that returns an instance" }
      ],
      "correct": "b",
      "explanation": "cls is bound to whichever class the method was actually called on. Using cls(...) instead of hardcoding the class name keeps factory methods correct for subclasses."
    }
  ]
}
```
