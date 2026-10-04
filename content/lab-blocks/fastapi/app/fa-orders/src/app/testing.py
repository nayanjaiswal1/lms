"""Shared test helpers and fixtures.

Test modules do ``from app.testing import *  # noqa`` instead of relying on a conftest.py, so the same tests run with
any pytest invocation (including ``--noconftest``).

Every test module gets its own throw-away PostgreSQL database (created from DATABASE_URL's server, schema built from
the models) and an empty set of tables before each test. Tests drive the API through ``client`` (a Starlette
TestClient, so the real lifespan, dependencies and middleware run) and prepare or inspect data with plain SQL through
``db``.
"""

import itertools
import os
import subprocess
import sys
import uuid
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import urlsplit, urlunsplit

import psycopg
import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("BCRYPT_ROUNDS", "4")
# Nothing listens on the discard port: a test that forgets to fake the payments provider fails fast instead of calling out.
os.environ.setdefault("PAYMENTS_BASE_URL", "http://127.0.0.1:9")

PROJECT_ROOT = Path(__file__).resolve().parents[1]
_counter = itertools.count(1)
_hashes: dict[int, str] = {}


def _with_database(url: str, name: str) -> str:
    return urlunsplit(urlsplit(url)._replace(path="/" + name))


def _admin(url: str):
    return psycopg.connect(_with_database(url, "postgres"), autocommit=True)


def _create_database(base_url: str) -> tuple[str, str]:
    name = f"t_{os.getpid()}_{uuid.uuid4().hex[:8]}"
    with _admin(base_url) as admin:
        admin.execute(f'CREATE DATABASE "{name}" TEMPLATE template0')
    return name, _with_database(base_url, name)


def _drop_database(base_url: str, name: str) -> None:
    with _admin(base_url) as admin:
        admin.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


class Db:
    """Plain SQL against the test database (autocommit)."""

    def __init__(self, url: str):
        self.conn = psycopg.connect(url, autocommit=True)

    def execute(self, sql: str, *params) -> None:
        self.conn.execute(sql, params)

    def one(self, sql: str, *params):
        row = self.conn.execute(sql, params).fetchone()
        if row is None:
            return None
        return row[0] if len(row) == 1 else row

    def all(self, sql: str, *params) -> list:
        return self.conn.execute(sql, params).fetchall()

    def close(self) -> None:
        self.conn.close()


@pytest.fixture(scope="module")
def database_url():
    from sqlalchemy import create_engine

    from app.db import Base
    from app.registry import load_models

    base_url = os.environ.get("DATABASE_URL", "postgresql://labuser@127.0.0.1:5432/app")
    name, url = _create_database(base_url)
    previous = os.environ.get("DATABASE_URL")
    os.environ["DATABASE_URL"] = url
    load_models()
    engine = create_engine(url.replace("postgresql://", "postgresql+psycopg://", 1))
    Base.metadata.create_all(engine)
    engine.dispose()
    try:
        yield url
    finally:
        if previous is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = previous
        _drop_database(base_url, name)


@pytest.fixture
def db(database_url):
    from app.db import Base

    handle = Db(database_url)
    tables = ", ".join(f'"{t.name}"' for t in Base.metadata.sorted_tables)
    handle.execute(f"TRUNCATE {tables} RESTART IDENTITY CASCADE")
    yield handle
    handle.close()


@pytest.fixture
def client(db):
    from app.main import create_app

    with TestClient(create_app()) as test_client:
        yield test_client


@pytest.fixture
def scratch_database_url():
    """An empty database, for migration tests."""
    base_url = os.environ.get("DATABASE_URL", "postgresql://labuser@127.0.0.1:5432/app")
    name, url = _create_database(base_url)
    try:
        yield url
    finally:
        _drop_database(base_url, name)


def alembic_cli(url: str, *args: str) -> subprocess.CompletedProcess:
    """Run ``python -m alembic <args>`` in the project against the database ``url``."""
    return subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=PROJECT_ROOT,
        env={**os.environ, "DATABASE_URL": url},
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )


def password_hash(rounds: int = 4) -> str:
    from app.customers.security import hash_password_sync

    if rounds not in _hashes:
        _hashes[rounds] = hash_password_sync("pw-12345678", rounds)
    return _hashes[rounds]


def make_customer(db, email=None, staff=False, credit_cents=0, **columns):
    n = next(_counter)
    token = f"mf_tok_test{n}_{uuid.uuid4().hex[:6]}"
    values = {
        "email": email or f"user{n}@shop.test",
        "display_name": f"User {n}",
        "password_hash": password_hash(),
        "api_token": token,
        "is_staff": staff,
        "credit_cents": credit_cents,
        **columns,
    }
    names = ", ".join(values)
    marks = ", ".join(["%s"] * len(values))
    customer_id = db.one(f"INSERT INTO customers ({names}) VALUES ({marks}) RETURNING id", *values.values())
    return SimpleNamespace(
        id=customer_id,
        email=values["email"],
        token=token,
        headers={"Authorization": f"Bearer {token}"},
    )


def make_staff(db, **columns):
    return make_customer(db, staff=True, **columns)


def make_product(db, price_cents=1000, stock=100, name=None, category="general", **columns):
    n = next(_counter)
    values = {
        "sku": f"SKU-{n:05d}",
        "name": name or f"Product {n}",
        "category": category,
        "price_cents": price_cents,
        "stock": stock,
        **columns,
    }
    names = ", ".join(values)
    marks = ", ".join(["%s"] * len(values))
    product_id = db.one(f"INSERT INTO products ({names}) VALUES ({marks}) RETURNING id", *values.values())
    return SimpleNamespace(id=product_id, sku=values["sku"], price_cents=price_cents, name=values["name"])


def make_order(db, customer, lines=(), status="pending", shipping_name="Test Customer"):
    """Insert an order with ``lines`` of ``(product, quantity)`` and return its id."""
    total = sum(product.price_cents * quantity for product, quantity in lines)
    order_id = db.one(
        "INSERT INTO orders (customer_id, status, total_cents, shipping_name) VALUES (%s, %s, %s, %s) RETURNING id",
        customer.id,
        status,
        total,
        shipping_name,
    )
    for product, quantity in lines:
        db.execute(
            "INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents) VALUES (%s, %s, %s, %s)",
            order_id,
            product.id,
            quantity,
            product.price_cents,
        )
    return order_id


class FakePayments:
    """Stands in for the payments client: records charges, optionally fails."""

    def __init__(self):
        self.charges = []
        self.error = None

    async def aclose(self) -> None:
        """The application's lifespan closes ``app.state.payments`` on shutdown."""

    async def charge(self, *, amount_cents, currency, reference, idempotency_key):
        from app.payments.client import Charge

        if self.error:
            raise self.error
        self.charges.append(
            {"amount_cents": amount_cents, "currency": currency, "reference": reference, "key": idempotency_key}
        )
        return Charge(id=f"ch_{len(self.charges):04d}", status="succeeded", amount_cents=amount_cents)


@pytest.fixture
def fake_payments(client):
    fake = FakePayments()
    client.app.state.payments = fake
    return fake
