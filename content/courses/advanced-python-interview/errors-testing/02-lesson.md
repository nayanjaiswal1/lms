---
kind: lesson
id_key: advanced-python-interview/performance-testing/unittest-basics
course: advanced-python-interview
section: errors-testing
section_title: "Exceptions & Testing"
section_position: 4
section_group: Fundamentals
title: "Unit Testing with unittest"
position: 1
estimated_minutes: 11
source: ["knowledge/backend/python/testing.md"]
---
`unittest` ships with Python and is the model many other frameworks follow. In an interview you are expected to write a small test class from memory, explain the setup and teardown hooks, and describe what makes a test good.

## Structure of a test case

Subclass `unittest.TestCase`. Every method whose name starts with `test_` is a test. `setUp` runs before each test and `tearDown` after each one; `setUpClass` and `tearDownClass` (class methods) run once per class, which suits expensive shared resources.

```python
import unittest

def add(a, b):
    return a + b

class TestAdd(unittest.TestCase):
    def setUp(self):
        self.a = 10
        self.b = 5

    def test_add_positive(self):
        self.assertEqual(add(self.a, self.b), 15)

    def test_add_negative(self):
        self.assertEqual(add(-1, -1), -2)

    def test_add_zero(self):
        self.assertEqual(add(0, 5), 5)

suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestAdd)
result = unittest.TextTestRunner(verbosity=0).run(suite)
print(result.testsRun, result.wasSuccessful())  # 3 True
```

In a real file you end with `if __name__ == "__main__": unittest.main()`. Run tests from the shell with `python -m unittest test_mymodule.py` for one file or `python -m unittest discover` to find all `test_*.py` files; `pytest` can run the same classes.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-unittest-basics-q1",
      "type": "mcq",
      "prompt": "Which hook runs once before all tests in a class rather than before each test?",
      "options": [
        { "id": "a", "text": "`setUp`" },
        { "id": "b", "text": "`setUpClass`" },
        { "id": "c", "text": "`tearDown`" },
        { "id": "d", "text": "`__init__`" }
      ],
      "correct": "b",
      "explanation": "`setUpClass` (a classmethod) runs once per class; `setUp` runs before every test method."
    },
    {
      "id": "performance-testing-unittest-basics-q2",
      "type": "mcq",
      "prompt": "A method in a TestCase is named `check_total`. What happens when the suite runs?",
      "options": [
        { "id": "a", "text": "It runs as a test" },
        { "id": "b", "text": "It is skipped because the name does not start with `test`" },
        { "id": "c", "text": "It raises an error" },
        { "id": "d", "text": "It runs only in `setUp`" }
      ],
      "correct": "b",
      "explanation": "The loader only collects methods whose names start with `test`."
    }
  ]
}
```

## Assertions and testing exceptions

Use the specific assertion that matches intent; failure messages then show both values. The common ones are `assertEqual`, `assertNotEqual`, `assertTrue`, `assertFalse`, `assertIsNone`, `assertIn` and `assertRaises`. For exceptions, prefer the context-manager form: it lets you run a block and inspect the exception afterwards.

```python
import unittest

def divide(a, b):
    return a / b

class TestDivide(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(divide(10, 4), 2.5)
        self.assertIn(2, [1, 2, 3])
        self.assertIsNone(None)

    def test_divide_by_zero(self):
        with self.assertRaises(ZeroDivisionError) as ctx:
            divide(10, 0)
        self.assertIn("division", str(ctx.exception))

result = unittest.TextTestRunner(verbosity=0).run(
    unittest.defaultTestLoader.loadTestsFromTestCase(TestDivide)
)
print(result.wasSuccessful())  # True
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-unittest-basics-q3",
      "type": "mcq",
      "prompt": "How do you assert that `divide(10, 0)` raises `ZeroDivisionError`?",
      "options": [
        { "id": "a", "text": "`self.assertEqual(divide(10, 0), ZeroDivisionError)`" },
        { "id": "b", "text": "`with self.assertRaises(ZeroDivisionError): divide(10, 0)`" },
        { "id": "c", "text": "`self.assertIsNone(divide(10, 0))`" },
        { "id": "d", "text": "A bare `try` without any assertion" }
      ],
      "correct": "b",
      "explanation": "`assertRaises` as a context manager passes only if the block raises that exception, and it exposes the exception as `ctx.exception`."
    }
  ]
}
```

## Arrange, Act, Assert and good test habits

Structure each test in three steps: **Arrange** the inputs and objects, **Act** by calling the code under test, **Assert** on the outcome. Keep tests short and readable that way.

Habits interviewers listen for:

- Name files `test_*.py` and methods `test_<behavior>`.
- Aim for one logical assertion per test, so a failure points at one thing.
- Keep tests independent: no shared mutable state, no required order.
- Mock external systems (database, network) so tests are fast and deterministic.

```python
import unittest

class TestCart(unittest.TestCase):
    def test_total_sums_prices(self):
        # Arrange
        prices = [3, 4, 5]
        # Act
        total = sum(prices)
        # Assert
        self.assertEqual(total, 12)

result = unittest.TextTestRunner(verbosity=0).run(
    unittest.defaultTestLoader.loadTestsFromTestCase(TestCart)
)
print(result.wasSuccessful())  # True
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-unittest-basics-q4",
      "type": "mcq",
      "prompt": "What does the AAA pattern stand for?",
      "options": [
        { "id": "a", "text": "Assert, Answer, Approve" },
        { "id": "b", "text": "Arrange, Act, Assert" },
        { "id": "c", "text": "Async, Await, Assert" },
        { "id": "d", "text": "Authorize, Authenticate, Audit" }
      ],
      "correct": "b",
      "explanation": "Set up the data, run the code under test, then check the result."
    },
    {
      "id": "performance-testing-unittest-basics-q5",
      "type": "mcq",
      "prompt": "Why should unit tests be independent of each other?",
      "options": [
        { "id": "a", "text": "So they can run in any order, alone or in parallel, and a failure points at one cause" },
        { "id": "b", "text": "Because unittest forbids shared helper methods" },
        { "id": "c", "text": "To make them run slower and safer" },
        { "id": "d", "text": "Because each test needs its own file" }
      ],
      "correct": "a",
      "explanation": "Order-dependent tests are flaky and hard to debug; independence keeps them reliable."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

##### Unit test structure in Python

Python uses the built-in `unittest` module (or `pytest`) for writing unit tests.

**Basic structure using `unittest`**
```text
import unittest
from mymodule import add  # function being tested

class TestAdd(unittest.TestCase):

    def setUp(self):
        """Runs before every test method"""
        self.a = 10
        self.b = 5

    def tearDown(self):
        """Runs after every test method"""
        pass

    def test_add_positive_numbers(self):
        result = add(self.a, self.b)
        self.assertEqual(result, 15)

    def test_add_negative_numbers(self):
        self.assertEqual(add(-1, -1), -2)

    def test_add_zero(self):
        self.assertEqual(add(0, 5), 5)

if __name__ == "__main__":
    unittest.main()
```

**Key components**

| Component | Purpose |
|---|---|
| `unittest.TestCase` | Base class for all test classes |
| `setUp()` | Runs before each test — initialize objects |
| `tearDown()` | Runs after each test — cleanup |
| `setUpClass()` | Runs once before all tests in the class |
| `tearDownClass()` | Runs once after all tests in the class |
| Test methods | Must start with `test_` |

**Common assertions**
```text
self.assertEqual(a, b)        # a == b
self.assertNotEqual(a, b)     # a != b
self.assertTrue(x)            # bool(x) is True
self.assertFalse(x)           # bool(x) is False
self.assertIsNone(x)          # x is None
self.assertIn(a, b)           # a in b
self.assertRaises(ValueError, func, arg)  # func raises ValueError
```

**Testing exceptions**
```text
def test_divide_by_zero(self):
    with self.assertRaises(ZeroDivisionError):
        divide(10, 0)
```

**Running tests**
```bash
python -m unittest test_mymodule.py      # specific file
python -m unittest discover              # auto-discover all test files
pytest test_mymodule.py                  # using pytest
```

**AAA pattern (interview favourite)**

Every test should follow Arrange → Act → Assert:
```text
def test_add(self):
    # Arrange
    a, b = 3, 4

    # Act
    result = add(a, b)

    # Assert
    self.assertEqual(result, 7)
```

Key rules to mention in interview:
- Test file should be named `test_*.py` or `_test.py`
- One assertion per test (ideally)
- Tests should be independent — no dependency on each other
- Mock external calls (DB, API) using `unittest.mock`
