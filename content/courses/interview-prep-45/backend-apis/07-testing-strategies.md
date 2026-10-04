---
kind: lesson
id_key: interview-prep-45/day-27-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "Testing Strategies"
position: 7
estimated_minutes: 55
source:
    - 45-day-interview-roadmap.md
    - final-prep/37-lesson.md
---

Every backend interview loop asks some version of "how would you test this," sometimes as its own question, more often as a follow-up right after you write code on a whiteboard. This lesson covers the testing pyramid, pytest unit tests, integration tests with fixtures, testing async code, mocking at a system boundary, the mock-versus-stub distinction, and writing tests toward a coverage target.

## The testing pyramid

The pyramid is a guide to how much of each test type to write, based on speed and cost:

```
        /\
       /  \      E2E (few): slow, brittle, high confidence in the whole system
      /----\
     /      \    Integration (some): real DB/cache, one service boundary at a time
    /--------\
   /          \  Unit (many): fast, isolated, one function/class at a time
  /------------\
```

- **Unit tests** check one function or class in isolation, with its dependencies mocked or faked. Each one runs in milliseconds. These should be most of your suite.
- **Integration tests** check how your code talks to a real dependency, a real Postgres through a test container or a rolled-back transaction, or a real Redis. Write fewer of these, since they're slower and need real infrastructure to run.
- **End-to-end tests** hit the whole system through its real interface, usually HTTP, sometimes across several services. These are the slowest and the most brittle, since any unrelated change can break one, but they catch integration bugs unit tests structurally can't see. Keep them to your critical user flows only.

If asked "what's wrong with only unit tests" or "only end-to-end tests": all-unit gives fast feedback but no confidence the pieces actually work together, since a mock can quietly drift from what the real dependency does. All-end-to-end gives high confidence but a slow, flaky suite that's expensive to maintain and hard to debug when something fails. The pyramid's shape is a deliberate trade-off between speed and confidence, not an arbitrary ratio.

> **Remember:** unit tests are fast but can't catch integration bugs; end-to-end tests catch those bugs but are slow and brittle. Write mostly unit tests, some integration tests, and only a few end-to-end tests for the flows that matter most.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-pyramid-q1", "type": "mcq",
      "prompt": "A team's test suite is 90% end-to-end tests hitting a real staging environment. What's the most likely downside an interviewer expects you to name?",
      "options": [
        {"id":"a","text":"End-to-end tests can never catch real bugs"},
        {"id":"b","text":"A suite dominated by end-to-end tests runs slowly and is brittle, since any unrelated change can break one, making the suite expensive to maintain and slow to give feedback"},
        {"id":"c","text":"End-to-end tests cannot check the whole system, only individual functions"},
        {"id":"d","text":"Unit tests are unnecessary once end-to-end tests exist"}
      ],
      "correct": "b",
      "explanation": "End-to-end tests give strong confidence but are slow and easily broken by unrelated changes, since they exercise the entire system through its real interface. A healthy suite keeps them as a small layer on top of a much larger base of fast unit tests." }
] }
```

## Unit tests with pytest

```python
# app/pricing.py
def apply_discount(price: float, percent: float) -> float:
    if not 0 <= percent <= 100:
        raise ValueError("percent must be between 0 and 100")
    return round(price * (1 - percent / 100), 2)
```

```python
# tests/test_pricing.py
import pytest
from app.pricing import apply_discount


def test_apply_discount_basic():
    assert apply_discount(100, 20) == 80.0


def test_apply_discount_zero_percent():
    assert apply_discount(50, 0) == 50.0


def test_apply_discount_full_discount():
    assert apply_discount(50, 100) == 0.0


@pytest.mark.parametrize("bad_percent", [-1, 101, 150])
def test_apply_discount_rejects_out_of_range(bad_percent):
    with pytest.raises(ValueError):
        apply_discount(100, bad_percent)


@pytest.mark.parametrize(
    "price, percent, expected",
    [
        (99.99, 10, 89.99),
        (10, 33.33, 6.67),
        (0, 50, 0.0),
    ],
)
def test_apply_discount_table(price, percent, expected):
    assert apply_discount(price, percent) == expected
```

`pytest.mark.parametrize` is the tool most candidates under-use. It replaces N nearly identical test functions with one table of cases, and each row shows up as its own separate result in the test report, so a failure points straight at the exact input that broke.

Good unit tests cover the happy path, boundary values (zero, negative, the maximum), and invalid input that should raise. Test only the happy path in an interview, and expect to get asked "what about X" as a follow-up, so cover it yourself first.

> **Remember:** `pytest.mark.parametrize` turns a pile of copy-pasted test functions into one table, with each row reported separately on failure. Always cover the happy path, the boundaries, and the invalid input that should raise.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-pytest-q1", "type": "mcq",
      "prompt": "Why does @pytest.mark.parametrize on test_apply_discount_rejects_out_of_range report a failure more usefully than one test function with a for loop over the same bad values?",
      "options": [
        {"id":"a","text":"Parametrize makes the test run faster in every case"},
        {"id":"b","text":"Each parametrized case shows up as its own result in the test report, so a failure points directly at the exact input that broke, instead of stopping the whole loop at the first failure"},
        {"id":"c","text":"A for loop cannot call pytest.raises inside it"},
        {"id":"d","text":"Parametrize is required for pytest.raises to work at all"}
      ],
      "correct": "b",
      "explanation": "A for loop inside one test function stops at the first failing iteration and reports one generic failure. Parametrize runs each case as its own independently reported test, so you immediately see which specific input failed." }
] }
```

## Integration tests with fixtures

Fixtures set up and tear down shared state, a DB connection, a test client, seed data, so every test starts from the same known baseline.

```python
# tests/conftest.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.db import Base
from app.models import User

TEST_DB_URL = "postgresql://test:test@localhost:5432/test_db"


@pytest.fixture(scope="session")
def engine():
    engine = create_engine(TEST_DB_URL)
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)


@pytest.fixture
def db_session(engine):
    connection = engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection)
    session = Session()

    yield session

    # Roll back everything the test did: next test starts clean,
    # and we never pay the cost of recreating the schema per test.
    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def sample_user(db_session):
    user = User(username="alice", email="alice@example.com")
    db_session.add(user)
    db_session.commit()
    return user
```

```python
# tests/test_user_repository.py
from app.repository import get_user_by_username, deactivate_user


def test_get_user_by_username(db_session, sample_user):
    found = get_user_by_username(db_session, "alice")
    assert found.id == sample_user.id


def test_deactivate_user(db_session, sample_user):
    deactivate_user(db_session, sample_user.id)
    db_session.refresh(sample_user)
    assert sample_user.is_active is False
```

The transaction-rollback pattern in `db_session` is the detail that shows real experience: it gives every test a clean database state without paying the cost of dropping and recreating the schema per test, by wrapping the whole test in a transaction that never commits.

For a FastAPI app, an integration test usually also spins up a `TestClient` and overrides the DB dependency to point at the test session:

```python
from fastapi.testclient import TestClient
from app.main import app
from app.dependencies import get_db


@pytest.fixture
def client(db_session):
    def override_get_db():
        yield db_session
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_create_user_endpoint(client):
    response = client.post("/users", json={"username": "bob", "email": "bob@example.com"})
    assert response.status_code == 201
    assert response.json()["username"] == "bob"
```

> **Remember:** wrap each test in a transaction that rolls back at the end. That gives every test a clean database without the cost of rebuilding the schema between tests.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-fixtures-q1", "type": "mcq",
      "prompt": "Why does the db_session fixture roll back its transaction at the end instead of dropping and recreating the whole schema before every test?",
      "options": [
        {"id":"a","text":"SQLAlchemy does not support dropping tables between tests"},
        {"id":"b","text":"Rolling back a transaction gives each test a clean state at a fraction of the cost of rebuilding the schema, since nothing the test did was ever actually committed"},
        {"id":"c","text":"Rolling back is required for pytest fixtures to function"},
        {"id":"d","text":"Recreating the schema would change the test's expected results"}
      ],
      "correct": "b",
      "explanation": "Wrapping a test in a transaction and rolling it back at the end undoes every change the test made instantly, without the overhead of tearing down and rebuilding the whole schema for each individual test." }
] }
```

## Testing async code

`pytest-asyncio` is the standard plugin. Two things trip people up: marking the test as async, and mocking async dependencies correctly.

```python
# pip install pytest-asyncio
import pytest
from app.services import fetch_user_profile

pytestmark = pytest.mark.asyncio  # apply to every test in this module


async def test_fetch_user_profile_success(mocker):
    mock_http = mocker.AsyncMock()
    mock_http.get.return_value.json = mocker.AsyncMock(return_value={"id": 1, "name": "Alice"})
    mocker.patch("app.services.http_client", mock_http)

    profile = await fetch_user_profile(user_id=1)

    assert profile["name"] == "Alice"
    mock_http.get.assert_awaited_once_with("/users/1")
```

Use `AsyncMock`, not `Mock`, for anything your code will `await`. A plain `Mock` returns another `Mock` object when called, not something awaitable, so `await some_mock()` raises `TypeError: object Mock can't be used in 'await' expression`. `AsyncMock`, built into `unittest.mock` since Python 3.8, returns a coroutine automatically.

Testing concurrency itself, not just one async function in isolation, needs a different approach: run the coroutines together with `asyncio.gather` and assert on timing or on the order events happened in, rather than only on the final state.

```python
import asyncio
import time

async def test_requests_run_concurrently():
    async def slow_call():
        await asyncio.sleep(0.2)
        return "done"

    start = time.monotonic()
    results = await asyncio.gather(slow_call(), slow_call(), slow_call())
    elapsed = time.monotonic() - start

    assert results == ["done", "done", "done"]
    assert elapsed < 0.5  # concurrent, not 0.6s sequential
```

> **Remember:** mock anything the code under test will `await` with `AsyncMock`, never a plain `Mock`. A plain Mock's return value isn't awaitable and will raise a TypeError the moment it's awaited.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-async-q1", "type": "mcq",
      "prompt": "A test mocks an async HTTP client method using mocker.Mock() instead of mocker.AsyncMock(), then the code under test does await client.get(url). What happens?",
      "options": [
        {"id":"a","text":"The test passes normally, since Mock and AsyncMock behave identically"},
        {"id":"b","text":"A TypeError is raised, since a plain Mock's return value is a Mock object, not something awaitable"},
        {"id":"c","text":"pytest-asyncio automatically converts the Mock into an AsyncMock"},
        {"id":"d","text":"The await keyword is silently ignored for mocked objects"}
      ],
      "correct": "b",
      "explanation": "A plain Mock returns a Mock object synchronously when called; that object is not awaitable. AsyncMock exists specifically to return something the await keyword can actually work with." }
] }
```

## Mocking at the boundary

The rule to state out loud in an interview: mock at the *boundary*, the external dependency, not the function you're actually testing. A payment gateway client is a good boundary to mock; the business logic that calls it is what you want to actually exercise.

```python
from unittest.mock import patch, MagicMock
import pytest

from orders.services import charge_and_create_order


@patch("orders.services.payment_gateway")
def test_charge_and_create_order_success(mock_gateway):
    mock_gateway.charge.return_value = MagicMock(id="ch_123", status="succeeded")

    order = charge_and_create_order(user_id=1, amount_cents=2500)

    mock_gateway.charge.assert_called_once_with(amount_cents=2500, user_id=1)
    assert order.status == "paid"
    assert order.charge_id == "ch_123"


@patch("orders.services.payment_gateway")
def test_charge_and_create_order_gateway_failure_rolls_back(mock_gateway):
    mock_gateway.charge.side_effect = Exception("card declined")

    with pytest.raises(Exception, match="card declined"):
        charge_and_create_order(user_id=1, amount_cents=2500)

    # verify no partial order was persisted: the transaction rolled back
    from orders.models import Order
    assert not Order.objects.filter(user_id=1).exists()
```

The second test is worth more in an interview than a second happy-path test would be: it proves a failed external call doesn't leave a half-created order behind, that the database write genuinely rolled back. Testing a real failure mode beats testing the happy path twice.

> **Remember:** mock the external dependency at the boundary, never the function you're actually testing. Testing that a failure rolls back cleanly is worth more than a second happy-path test.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-boundary-q1", "type": "mcq",
      "prompt": "Why does test_charge_and_create_order_gateway_failure_rolls_back check that no Order row exists, rather than just asserting an exception was raised?",
      "options": [
        {"id":"a","text":"Checking the database is unnecessary once the exception is confirmed"},
        {"id":"b","text":"It proves the transaction actually rolled back and left no partial, half-created order behind, a real failure mode worth more than confirming the exception alone"},
        {"id":"c","text":"MagicMock requires a database assertion to function correctly"},
        {"id":"d","text":"The exception assertion alone would always fail without it"}
      ],
      "correct": "b",
      "explanation": "Confirming the exception only proves the failure was raised. Confirming no Order row exists proves the more important thing: that the database write was actually rolled back and didn't leave inconsistent data behind." }
] }
```

## Mock vs stub: the interview answer

Both are "test doubles," fake objects standing in for a real dependency, but they answer different questions.

| | Stub | Mock |
|---|---|---|
| Purpose | Provide canned responses so the test can run | Verify *interactions* happened as expected |
| What it checks | Nothing on its own; you assert on the code under test's output | Asserts the code under test called it correctly (`assert_called_with`, `assert_awaited_once`) |
| Typical use | "When this dependency is called, return X" | "Prove we called `send_email` exactly once with these args" |

```python
# Stub: just returns canned data, no assertion on how it was called
def test_get_user_greeting_stub(mocker):
    stub_repo = mocker.Mock()
    stub_repo.get_user.return_value = {"name": "Alice"}

    greeting = get_user_greeting(stub_repo, user_id=1)

    assert greeting == "Hello, Alice!"
    # We don't care HOW get_user was called, just that we got usable data back.


# Mock: asserts the interaction itself
def test_send_welcome_email_mock(mocker):
    mock_mailer = mocker.Mock()

    send_welcome_email(mock_mailer, "alice@example.com")

    mock_mailer.send.assert_called_once_with(
        to="alice@example.com", subject="Welcome!"
    )
    # We DO care that send() was called with exactly these args:
    # that's the whole behavior being tested here.
```

Rule of thumb: reach for a stub when testing what a function *returns*, and reach for a mock when testing that a function *calls something correctly*, where the call itself is the side effect you care about, like sending an email or publishing an event, with no return value to assert on instead.

> **Remember:** a stub answers "what did the function return." A mock answers "did the function call the right thing, the right number of times, with the right arguments."

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-mockstub-q1", "type": "mcq",
      "prompt": "A function's whole job is to call an external mailer's send() method; it has no meaningful return value. Should the test use a stub or a mock for the mailer?",
      "options": [
        {"id":"a","text":"A stub, since it always runs faster than a mock"},
        {"id":"b","text":"A mock, since the behavior being tested is the interaction itself, that send() was called with the right arguments, not any returned value"},
        {"id":"c","text":"Neither; functions with no return value cannot be tested"},
        {"id":"d","text":"A stub, since mocks can only be used with async functions"}
      ],
      "correct": "b",
      "explanation": "When a function's real job is to trigger a side effect through a dependency, the test needs to verify that interaction happened correctly, which is exactly what a mock's call assertions are for." }
] }
```

## Writing tests to a coverage target

Coverage measures which lines executed during a test run. It's a useful floor, not a quality signal by itself, since 100% coverage with no real assertions on behavior proves nothing.

```bash
pip install pytest-cov
pytest --cov=app --cov-report=term-missing --cov-fail-under=80
```

```
Name                 Stmts   Miss  Cover   Missing
--------------------------------------------------
app/pricing.py          12      0   100%
app/repository.py       28      4    86%   45-48
app/services.py         40     12    70%   88-99
--------------------------------------------------
TOTAL                    80     16    80%
```

`--cov-report=term-missing` prints the exact uncovered line numbers, so you know exactly which branch to target next, usually error-handling paths and edge cases, since the happy path tends to get covered first almost by accident. `--cov-fail-under=80` makes CI fail below the threshold, which is what turns "80% coverage" from an aspiration into an enforced gate.

To hit a target deliberately: run coverage once, read the `Missing` column, and write one test per uncovered branch, rather than one large test that happens to touch more lines. A test aimed directly at a specific branch is the kind that actually catches a regression there later; incidental coverage from a broad test often isn't asserting anything meaningful about the branch it happens to execute.

> **Remember:** 100% coverage with weak assertions proves nothing. Read the Missing column and write one targeted test per uncovered branch, favoring error paths, which are the ones the happy path never touches.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-testing-coverage-q1", "type": "mcq",
      "prompt": "A module has 100% test coverage, but every test only calls the function and checks that it didn't raise an exception, with no assertions on the actual output. Does this coverage number mean the module is well-tested?",
      "options": [
        {"id":"a","text":"Yes, 100% coverage always means a module is fully verified"},
        {"id":"b","text":"No, coverage only measures which lines executed, not whether the tests actually verified correct behavior; weak assertions can hit 100% coverage while proving very little"},
        {"id":"c","text":"No, because pytest-cov cannot reach 100% without real assertions"},
        {"id":"d","text":"Yes, as long as --cov-fail-under is set to 80 or higher"}
      ],
      "correct": "b",
      "explanation": "Coverage is a floor on which lines ran, not a signal about test quality. A test that executes every line but never checks the actual output can reach 100% coverage while catching no real bugs." }
] }
```
