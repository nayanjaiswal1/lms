---
kind: lesson
id_key: advanced-python-interview/iterators-testing/parameterized-testing
course: advanced-python-interview
section: iterators-testing
section_title: "Iterators, Generators & Testing"
section_position: 3
title: "Parameterized Testing"
position: 4
estimated_minutes: 12
source: [fifty-advanced-python-concepts/25..py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Parameterized testing runs the *same* test logic against many different inputs, instead of copy-pasting a near-identical test function once per input. It's a testing-maturity signal interviewers look for because duplicated test functions are exactly as much of a maintenance liability as duplicated production code.

## The problem: one test function per input

Without parameterization, testing a function against six input cases means six separate test functions, all with the same body and a different literal value — any change to the assertion logic has to be copy-pasted into all six.

## `pytest.mark.parametrize`: one test body, many inputs

```text
import pytest

@pytest.mark.parametrize("user_id,expected_name", [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (8, "Gary"),
    (99, "Unknown"),
])
def test_get_user_details(user_id, expected_name):
    def fetch_user_details(user_id):
        users = {1: "Alice", 2: "Bob", 3: "Charlie", 8: "Gary"}
        return {"id": user_id, "name": users.get(user_id, "Unknown")}

    response = fetch_user_details(user_id)
    assert response["name"] == expected_name
```

`pytest` runs `test_get_user_details` once per tuple in the list, reporting each one as its own pass/fail — a failure on input `(3, "Charlie")` is reported distinctly from a failure on `(99, "Unknown")`, even though it's the same function body. (This needs `pytest` installed and run via the `pytest` CLI — it isn't something a plain `python file.py` invocation executes, since pytest discovers and drives `test_*` functions itself.)

## The same idea, without a test framework

The mechanism `pytest.mark.parametrize` provides is really just "loop over cases and assert each one" — worth seeing explicitly, since it's exactly what you'd reach for in a quick script or a language without a parametrize decorator:

```python
def fetch_user_details(user_id):
    users = {1: "Alice", 2: "Bob", 3: "Charlie", 8: "Gary"}
    return {"id": user_id, "name": users.get(user_id, "Unknown")}

test_cases = [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (8, "Gary"),
    (99, "Unknown"),
]

failures = []
for user_id, expected_name in test_cases:
    actual = fetch_user_details(user_id)["name"]
    if actual != expected_name:
        failures.append((user_id, expected_name, actual))

if failures:
    print(f"{len(failures)} case(s) failed: {failures}")
else:
    print(f"All {len(test_cases)} cases passed.")
```

What `pytest.mark.parametrize` adds on top of this manual loop: each case is reported as an independent test result (so a failure in case 3 doesn't stop cases 4 and 5 from running and reporting), readable test names/IDs per case in the output, and integration with the rest of pytest's fixture and reporting machinery.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-parameterized-testing-q1",
      "type": "mcq",
      "prompt": "What problem does `@pytest.mark.parametrize` solve compared to writing one test function per input case?",
      "options": [
        { "id": "a", "text": "It makes tests run in a separate process for isolation" },
        { "id": "b", "text": "It lets one test body run against many inputs, each reported as an independent pass/fail, instead of duplicating the test function per case" },
        { "id": "c", "text": "It automatically generates random test inputs" },
        { "id": "d", "text": "It disables tests that are expected to fail" }
      ],
      "correct": "b",
      "explanation": "parametrize decouples the test logic (written once) from the input data (a list of cases), and pytest reports each case's result independently."
    },
    {
      "id": "iterators-testing-parameterized-testing-q2",
      "type": "mcq",
      "prompt": "Why can't the pytest-based test file be executed with a plain `python file.py` command?",
      "options": [
        { "id": "a", "text": "pytest syntax is not valid Python" },
        { "id": "b", "text": "pytest discovers and drives test_* functions itself via its own CLI/runner — a bare python invocation never calls them" },
        { "id": "c", "text": "parametrize requires an internet connection" },
        { "id": "d", "text": "Test functions can only run inside Docker containers" }
      ],
      "correct": "b",
      "explanation": "Running python file.py just defines the functions and decorators — nothing invokes test_get_user_details unless a test runner like pytest scans the file and calls it for each parametrized case."
    }
  ]
}
```
