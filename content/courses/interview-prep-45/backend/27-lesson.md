---
kind: lesson
id_key: interview-prep-45/day-27-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Testing Strategies"
position: 27
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Today covers how to test backend code well: the testing pyramid, pytest unit tests, integration tests with fixtures, testing async code, and the mock-vs-stub distinction. Every backend interview loop includes some form of "how would you test this," sometimes as a dedicated question, often as a follow-up after you write code on a whiteboard.

## The testing pyramid

The pyramid is a guide to how much of each test type you should write, based on speed and cost:

```
        /\
       /  \      E2E (few): slow, brittle, high confidence in the whole system
      /----\
     /      \    Integration (some): real DB/cache, one service boundary at a time
    /--------\
   /          \  Unit (many): fast, isolated, one function/class at a time
  /------------\
```

- **Unit tests**: test one function/class in isolation, dependencies mocked or faked. Milliseconds each. Should be most of your suite.
- **Integration tests**: test how your code talks to a real dependency, such as a real Postgres (via a test container or transaction rollback) or a real Redis. Fewer of these because they're slower and need infrastructure.
- **End-to-end tests**: hit the whole system through its real interface (HTTP), possibly across service boundaries. Slowest, most brittle (any unrelated change can break them), but catch integration bugs unit tests can't. Keep to critical user flows only.

**Interview answer if asked "what's wrong with only unit tests" or "only E2E tests":** all-unit gives you fast feedback but no confidence the pieces work together (mocks can drift from real behavior); all-E2E gives you high confidence but a slow, flaky suite that's expensive to maintain and hard to debug when it fails. The pyramid shape is a deliberate trade-off between speed and confidence.

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

`pytest.mark.parametrize` is the tool most candidates under-use. It replaces N nearly-identical test functions with one table of cases, and each row shows up as a separate result in the test report so a failure points at the exact input that broke.

Good unit tests cover: the happy path, boundary values (0, negative, max), and invalid input that should raise. If you only test the happy path in an interview, expect to be asked "what about X," so pre-empt it.

## Integration tests with fixtures

Fixtures set up and tear down shared state (a DB connection, a test client, seed data) so every test starts from a known baseline.

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

The transaction-rollback fixture pattern (`db_session`) is the detail that shows real experience: it gives every test a clean database state without the cost of dropping and recreating tables per test, by wrapping the whole test in a transaction that never commits.

For a FastAPI app, an integration test typically also spins up a `TestClient` and overrides the DB dependency to point at the test session:

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

## Testing async code

`pytest-asyncio` is the standard plugin. The two things people trip on: marking the test, and mocking async dependencies correctly.

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

Key detail: use `AsyncMock`, not `Mock`, for anything the code will `await`. A plain `Mock` returns a `Mock` object when called, not something awaitable, so `await some_mock()` raises `TypeError: object Mock can't be used in 'await' expression`. `AsyncMock` (built into `unittest.mock` since Python 3.8) returns a coroutine automatically.

Testing concurrency itself (not just individual async functions), for example verifying two tasks actually ran concurrently, or a lock actually serialized access, needs a different approach: run both coroutines with `asyncio.gather`, and assert on timing or on the interleaving of recorded events rather than on final state alone.

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

## Mock vs stub: the interview answer

Both are "test doubles," meaning fake objects standing in for real dependencies, but they answer different questions.

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

Rule of thumb: use a stub when you're testing what the function under test *returns*; use a mock when you're testing that the function under test *calls something correctly*, where the call itself is the side effect you care about (like sending an email or publishing an event, with no return value to assert on).

## Writing tests to a coverage target

Coverage measures which lines executed during the test run. It's a useful floor, not a quality signal by itself (100% coverage with no assertions on behavior proves nothing).

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

`--cov-report=term-missing` prints the exact uncovered line numbers so you know exactly which branch to target next, usually error-handling paths and edge cases, since the happy path gets covered first almost by accident. `--cov-fail-under=80` makes CI fail below the threshold, which is how "80% coverage" becomes an enforced gate rather than an aspiration.

To hit 80% on a module deliberately: run coverage once, read the `Missing` column, and write one test per uncovered branch rather than one giant test that happens to touch more lines. Branch-targeted tests are the ones that catch regressions; incidental coverage from a broad test often isn't asserting on the branch it happens to execute.
