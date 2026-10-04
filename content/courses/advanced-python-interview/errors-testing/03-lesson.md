---
kind: lesson
id_key: advanced-python-interview/performance-testing/mocking
course: advanced-python-interview
section: errors-testing
section_title: "Exceptions & Testing"
section_position: 4
section_group: Fundamentals
title: "Mocking with unittest.mock"
position: 2
estimated_minutes: 12
source: ["knowledge/backend/python/testing.md"]
---
Mocking replaces a real dependency (HTTP call, database, file, clock) with a controllable fake so a test exercises only the unit in question and has no side effects. The standard tool is `unittest.mock`.

## Mock and MagicMock

A `Mock` accepts any attribute access or call and records how it was used, so you can assert on it afterwards. `MagicMock` is a `Mock` that also supports magic methods such as `__len__`, `__iter__` and `__str__`; prefer it when the code under test uses them.

```python
from unittest.mock import Mock, MagicMock

m = Mock()
m.method(1, 2)
m.method.assert_called_once_with(1, 2)
print(m.method.call_count)  # 1

mm = MagicMock()
mm.__len__.return_value = 3
print(len(mm))  # 3
```

Common assertions: `assert_called_once_with(...)`, `assert_called_with(...)` (last call), `assert_not_called()`, plus the `call_count` and `call_args` attributes.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-mocking-q1",
      "type": "mcq",
      "prompt": "When is `MagicMock` preferable to `Mock`?",
      "options": [
        { "id": "a", "text": "When the code under test uses magic methods like `len()` or iteration on the object" },
        { "id": "b", "text": "When you want the mock to raise on any attribute access" },
        { "id": "c", "text": "When you need real network calls" },
        { "id": "d", "text": "Never; they are identical" }
      ],
      "correct": "a",
      "explanation": "MagicMock pre-configures dunder methods; plain Mock does not support them."
    }
  ]
}
```

## patch: replace where it is used

`patch` temporarily swaps a name for a mock and restores it when the test ends. Use it as a decorator (the mock is passed in as an argument) or as a context manager. The key rule: **patch the name where it is looked up, not where it is defined.** If `service.py` does `import requests` and calls `requests.get`, patch `service.requests.get`. If it does `from os.path import exists`, the name `exists` now lives in your module, so patch `service.exists`.

```python
import os
from unittest.mock import patch

def config_exists(path):
    return os.path.exists(path)

# Patch the name as this module looks it up: __main__.os.path.exists
with patch("__main__.os.path.exists") as mock_exists:
    mock_exists.return_value = True
    print(config_exists("/no/such/file"))  # True, the fake answered
    mock_exists.assert_called_once_with("/no/such/file")

print(config_exists("/no/such/file"))  # False, patch is undone
```

In a normal project the pattern is simply `@patch("mymodule.requests.get")` on a test method, or `with patch("mymodule.os.path.exists") as mock_exists:`.

```text
@patch("mymodule.requests.get")
def test_api_call(self, mock_get):
    mock_get.return_value.status_code = 200
    self.assertEqual(mymodule.fetch_data(), 200)
    mock_get.assert_called_once()
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-mocking-q2",
      "type": "mcq",
      "prompt": "`mymodule.py` has `import requests` and calls `requests.get(...)`. What should the test patch?",
      "options": [
        { "id": "a", "text": "`mymodule.requests.get`, the name as the module under test looks it up" },
        { "id": "b", "text": "Only the `requests` package source file" },
        { "id": "c", "text": "`unittest.requests.get`" },
        { "id": "d", "text": "Nothing; patch is not needed" }
      ],
      "correct": "a",
      "explanation": "Patch where the name is used. For `from x import y`, the name `y` lives in your module, so patch `yourmodule.y`."
    }
  ]
}
```

## return_value vs side_effect

`return_value` sets what a call returns every time. `side_effect` is more flexible: an exception instance makes the call raise, an iterable returns its items one per call, and a function computes the result from the arguments.

```python
from unittest.mock import Mock

m = Mock()
m.return_value = 42
print(m(), m())  # 42 42

m.side_effect = ValueError("fail")
try:
    m()
except ValueError as e:
    print("raised", e)  # raised fail

m.side_effect = [1, 2, 3]
print(m(), m(), m())  # 1 2 3
```

Use `side_effect = [...]` to simulate a retry (fail, fail, succeed) and an exception to test your error handling.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-mocking-q3",
      "type": "mcq",
      "prompt": "You set `mock.side_effect = [10, 20]` and call the mock three times. What happens on the third call?",
      "options": [
        { "id": "a", "text": "It returns 20 again" },
        { "id": "b", "text": "It returns None" },
        { "id": "c", "text": "It raises StopIteration because the sequence is exhausted" },
        { "id": "d", "text": "It returns 10 again" }
      ],
      "correct": "c",
      "explanation": "An iterable side_effect yields one value per call and raises StopIteration when it runs out."
    }
  ]
}
```

## patch.object and the overuse caveat

`patch.object(target, "attribute", ...)` patches an attribute on a specific object or class, which avoids string paths and typos.

```python
from unittest.mock import patch

class PaymentService:
    def charge(self):
        return "real charge"

with patch.object(PaymentService, "charge", return_value="success") as mock_charge:
    result = PaymentService().charge()
    print(result)  # success
    mock_charge.assert_called_once()

print(PaymentService().charge())  # real charge, patch is undone after the block
```

Mocking has a cost. A mock verifies that you *called* something, not that the real thing works, and tests tied to exact call patterns break on harmless refactors. Mock at the boundaries you do not own (network, database, clock) and use real objects for your own pure logic.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-mocking-q4",
      "type": "mcq",
      "prompt": "What is the main risk of mocking too much?",
      "options": [
        { "id": "a", "text": "Mocks are slower than real objects" },
        { "id": "b", "text": "Tests pass while real behavior is broken, and they become brittle against refactors" },
        { "id": "c", "text": "Python limits the number of mocks per file" },
        { "id": "d", "text": "Mocks cannot raise exceptions" }
      ],
      "correct": "b",
      "explanation": "Mocks only prove calls were made as expected; over-mocking hides integration bugs and couples tests to implementation."
    },
    {
      "id": "performance-testing-mocking-q5",
      "type": "mcq",
      "prompt": "After a `with patch.object(...)` block ends, what is the state of the patched attribute?",
      "options": [
        { "id": "a", "text": "It stays mocked for the rest of the process" },
        { "id": "b", "text": "It is restored to its original value" },
        { "id": "c", "text": "It is deleted" },
        { "id": "d", "text": "It becomes None" }
      ],
      "correct": "b",
      "explanation": "`patch` undoes itself on exit, whether the block succeeds or raises."
    }
  ]
}
```

## Original notes

Your original wording from the Notes vault, kept verbatim for reference.

##### Mocking in Python

**What is mocking?**
Mocking is replacing real objects/functions with fake ones during testing to isolate the unit under test and avoid side effects (DB calls, API calls, file I/O, etc.). Python's built-in library: `unittest.mock`.

**Core components**

| Component | Purpose |
|---|---|
| `Mock` | Generic mock object |
| `MagicMock` | Mock with magic methods (`__len__`, `__str__`, etc.) pre-configured |
| `patch` | Temporarily replaces an object in a module |
| `patch.object` | Patches an attribute on a specific object/class |

**Basic mock usage**
```text
from unittest.mock import Mock

mock = Mock()
mock.method(1, 2)

mock.method.assert_called_once_with(1, 2)  # passes
print(mock.method.call_count)  # 1
```

**`patch` as decorator**
```text
from unittest.mock import patch

# Patches where it's USED, not where it's defined
@patch("mymodule.requests.get")
def test_api_call(mock_get):
    mock_get.return_value.status_code = 200
    result = mymodule.fetch_data()
    mock_get.assert_called_once()
    assert result == 200
```

**`patch` as context manager**
```text
with patch("mymodule.os.path.exists") as mock_exists:
    mock_exists.return_value = True
    # test code here
```

**`return_value` vs `side_effect`**
```text
mock.return_value = 42          # always returns 42

mock.side_effect = ValueError("fail")   # raises exception when called

mock.side_effect = [1, 2, 3]    # returns 1, then 2, then 3 on successive calls
```

**`patch.object`**
```text
from unittest.mock import patch

class PaymentService:
    def charge(self): ...

with patch.object(PaymentService, "charge", return_value="success") as mock_charge:
    svc = PaymentService()
    result = svc.charge()
    assert result == "success"
```

Key interview points:
- Patch where it's used, not where it's defined — e.g., if `mymodule.py` imports `requests`, patch `mymodule.requests`, not `requests.get` directly.
- `MagicMock` is preferred over `Mock` when the code under test uses dunder methods.
- `assert_called_once_with()`, `assert_called_with()`, `assert_not_called()` are the common assertion methods.
- Mocking does not test real behavior — overuse leads to brittle tests.
