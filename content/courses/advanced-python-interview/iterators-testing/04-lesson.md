---
kind: lesson
id_key: advanced-python-interview/iterators-testing/dependency-injection
course: advanced-python-interview
section: iterators-testing
section_title: "Iterators, Generators & Testing"
section_position: 3
title: "Dependency Injection"
position: 3
estimated_minutes: 15
source: [fifty-advanced-python-concepts/24.without_dependency_injection.py, fifty-advanced-python-concepts/24.with_dependency_injection.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Dependency Injection (DI) means a class receives the objects it depends on from the outside — usually through its constructor — instead of creating them itself internally. It sounds like a heavyweight framework concept (and in Java/Spring, it often is one), but in Python it's frequently just "pass the dependency as an argument."

## Without DI: the dependency is hardcoded inside

```python
class PayPalService:
    def process_payment(self, amount):
        print(f"Processing payment of ${amount} through PayPal.")

class PaymentProcessor:
    def __init__(self):
        self.payment_service = PayPalService()  # created internally — hardcoded

    def pay(self, amount):
        self.payment_service.process_payment(amount)

processor = PaymentProcessor()
processor.pay(100)
```

`PaymentProcessor` is permanently welded to `PayPalService`. Want to support Stripe? You have to edit `PaymentProcessor.__init__`. Want to unit-test `pay()` without making a real network call? You can't — every `PaymentProcessor` always constructs a real `PayPalService`.

## With DI: the dependency is passed in

```python
class PayPalService:
    def process_payment(self, amount):
        print(f"Processing payment of ${amount} through PayPal.")

class PaymentProcessor:
    def __init__(self, payment_service):
        self.payment_service = payment_service  # supplied by the caller

    def pay(self, amount):
        self.payment_service.process_payment(amount)

payment_service = PayPalService()
processor = PaymentProcessor(payment_service)
processor.pay(100)
```

`PaymentProcessor` no longer knows or cares which payment provider it's using — it just calls `.process_payment()` on whatever it was handed (this is the polymorphism/duck-typing lesson applied in practice). Swapping in `StripeService()` requires zero changes to `PaymentProcessor` itself.

## Why this is the whole point of testability

```python
class FakePaymentService:
    def __init__(self):
        self.calls = []

    def process_payment(self, amount):
        self.calls.append(amount)  # no real network call — just records the call

fake = FakePaymentService()
test_processor = PaymentProcessor(fake)
test_processor.pay(100)

assert fake.calls == [100]  # verify behavior without touching PayPal's real API
```

This is exactly how unit tests avoid hitting real external services: inject a fake/mock object that implements the same interface, and assert on what was called. Without constructor injection, there'd be no way to substitute `PayPalService` for `FakePaymentService` — the real dependency is baked in.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-dependency-injection-q1",
      "type": "mcq",
      "prompt": "What is the key structural difference between the 'without DI' and 'with DI' versions of PaymentProcessor?",
      "options": [
        { "id": "a", "text": "The with-DI version doesn't have a pay() method" },
        { "id": "b", "text": "The with-DI version receives payment_service as a constructor argument instead of constructing PayPalService internally" },
        { "id": "c", "text": "The with-DI version uses async/await" },
        { "id": "d", "text": "There is no real difference; both behave identically in every context" }
      ],
      "correct": "b",
      "explanation": "Dependency injection moves object creation to the caller. PaymentProcessor stops constructing its own PayPalService and instead accepts any object with a compatible process_payment() method."
    },
    {
      "id": "iterators-testing-dependency-injection-q2",
      "type": "mcq",
      "prompt": "Why does constructor injection make PaymentProcessor easier to unit test?",
      "options": [
        { "id": "a", "text": "It doesn't — testing difficulty is unrelated to how dependencies are constructed" },
        { "id": "b", "text": "A test can pass in a fake/mock payment service instead of the real PayPalService, avoiding real network calls" },
        { "id": "c", "text": "Constructor injection automatically generates test cases" },
        { "id": "d", "text": "It removes the need for the pay() method to take an amount argument" }
      ],
      "correct": "b",
      "explanation": "Because the dependency is supplied externally, a test can substitute a fake object that records calls instead of performing real side effects, then assert on what was recorded."
    }
  ]
}
```
