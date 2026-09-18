---
kind: lesson
id_key: advanced-python-interview/iterators-testing/pytest-fixtures
course: advanced-python-interview
section: iterators-testing
section_title: "Iterators, Generators & Testing"
section_position: 3
title: "Fixtures (Testing Setup & Teardown)"
position: 5
estimated_minutes: 12
source: [fifty-advanced-python-concepts/26.pytest_fixtures.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
A fixture provides a piece of test setup (a database connection, a temp file, an authenticated client) to any test that asks for it by name, and cleans it up afterward — without every test having to repeat that setup/teardown code itself.

## `@pytest.fixture`: setup, `yield`, teardown

```text
import pytest
import sqlite3

@pytest.fixture
def temp_db():
    # Setup: runs before the test that uses this fixture
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES ('Alice')")
    yield conn
    # Teardown: runs after the test finishes, even if it failed
    conn.close()

def test_query_user(temp_db):
    cursor = temp_db.cursor()
    cursor.execute("SELECT name FROM users WHERE id=1")
    user = cursor.fetchone()
    assert user[0] == "Alice"
```

pytest sees that `test_query_user` takes a parameter named `temp_db`, matches it against the fixture of the same name, runs `temp_db()` up to its `yield`, passes the yielded value (`conn`) into the test as the `temp_db` argument, runs the test, and then resumes the fixture *after* the `yield` to run teardown — regardless of whether the test passed or raised. This needs pytest's collection/injection machinery to run; it isn't triggered by a plain `python file.py`.

## The same shape, without pytest: a context manager

The setup / `yield` / teardown structure of a fixture is exactly the same shape as a context manager's `__enter__` / `yield` / `__exit__` (covered later in this course) — worth seeing side by side, since it demonstrates the underlying pattern in code you can run directly:

```python
from contextlib import contextmanager
import sqlite3

@contextmanager
def temp_db():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES ('Alice')")
    try:
        yield conn          # setup done, hand the resource to the caller
    finally:
        conn.close()         # teardown, guaranteed even if the caller raises

with temp_db() as conn:
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM users WHERE id=1")
    user = cursor.fetchone()
    assert user[0] == "Alice"
    print(f"Fetched user: {user[0]}")
```

`@pytest.fixture` is, structurally, a generator-based context manager wired into pytest's dependency-injection-by-parameter-name system: a test requests a fixture by naming a parameter, pytest runs setup, hands over the yielded value, runs the test, then runs teardown — the same setup/`yield`/teardown shape as `@contextmanager`, just triggered by pytest's test collection instead of a `with` block.

## Why fixtures matter beyond convenience

Repeating `sqlite3.connect(":memory:")` + table creation + seed data in every test function that needs a database means a schema change requires editing every test. A shared fixture means the schema and seed data live in exactly one place, and every test that needs a database just declares a `temp_db` parameter.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-pytest-fixtures-q1",
      "type": "mcq",
      "prompt": "In a pytest fixture using `yield`, what happens to the code after the `yield` statement?",
      "options": [
        { "id": "a", "text": "It never runs" },
        { "id": "b", "text": "It runs as teardown, after the test that used the fixture finishes (pass or fail)" },
        { "id": "c", "text": "It runs before the yielded value is handed to the test" },
        { "id": "d", "text": "It only runs if the test raises an exception" }
      ],
      "correct": "b",
      "explanation": "Everything before yield is setup; the yielded value is injected into the test; everything after yield is teardown, run once the test completes regardless of outcome."
    },
    {
      "id": "iterators-testing-pytest-fixtures-q2",
      "type": "mcq",
      "prompt": "How does a test function access a fixture's value in pytest?",
      "options": [
        { "id": "a", "text": "By importing it explicitly with `import fixture`" },
        { "id": "b", "text": "By declaring a parameter with the same name as the fixture — pytest matches by name and injects the yielded value" },
        { "id": "c", "text": "By calling the fixture function directly inside the test body" },
        { "id": "d", "text": "Fixtures are global variables automatically available everywhere" }
      ],
      "correct": "b",
      "explanation": "pytest inspects each test function's parameter names, finds a fixture with a matching name, runs it, and passes the yielded value as that argument."
    }
  ]
}
```
