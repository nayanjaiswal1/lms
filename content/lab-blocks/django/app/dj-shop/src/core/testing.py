"""Shared test helpers and fixtures.

Test modules do ``from core.testing import *  # noqa`` instead of relying on a
conftest.py, so the same tests run with any pytest invocation (including
``--noconftest``). Importing this module selects the test settings.
"""

import itertools
import os
from decimal import Decimal

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.test")

import django  # noqa: E402
import pytest  # noqa: E402

# Plain ``pytest`` configures Django from pytest.ini; a hardened run (-I, another
# rootdir) does not, so make sure the app registry is ready before models load.
django.setup()

_counter = itertools.count(1)


def make_customer(email=None, password="pw-12345678", **extra):
    from customers.models import Customer

    n = next(_counter)
    return Customer.objects.create_user(email or f"user{n}@shop.test", password, **extra)


def make_staff(**extra):
    return make_customer(is_staff=True, **extra)


def make_category(name=None):
    from catalog.models import Category
    from django.utils.text import slugify

    name = name or f"Category {next(_counter)}"
    return Category.objects.create(name=name, slug=slugify(name))


def make_product(price="10.00", name=None, sku=None, category=None, **extra):
    from catalog.models import Product

    n = next(_counter)
    return Product.objects.create(
        sku=sku or f"SKU-{n:05d}",
        name=name or f"Product {n}",
        price=Decimal(price),
        category=category or make_category(),
        **extra,
    )


def main_warehouse():
    from inventory.models import Warehouse

    return Warehouse.objects.get_or_create(code="MAIN", defaults={"name": "Main warehouse"})[0]


def make_stock(product, quantity, warehouse=None):
    from inventory.models import StockLevel

    return StockLevel.objects.update_or_create(
        product=product, warehouse=warehouse or main_warehouse(), defaults={"on_hand": quantity}
    )[0]


class FakePayments:
    """Stands in for PaymentsClient: records charges, optionally fails."""

    def __init__(self):
        self.charges = []
        self.error = None
        self.status = "succeeded"

    def charge(self, *, amount_cents, currency, reference, idempotency_key):
        from payments.client import ChargeResult

        if self.error:
            raise self.error
        self.charges.append({"amount_cents": amount_cents, "reference": reference, "key": str(idempotency_key)})
        return ChargeResult(id=f"ch_{len(self.charges)}", status=self.status, amount_cents=amount_cents)


@pytest.fixture
def fake_payments(monkeypatch):
    fake = FakePayments()
    monkeypatch.setattr("payments.services.PaymentsClient", lambda: fake)
    return fake


@pytest.fixture
def customer(db):
    return make_customer()


@pytest.fixture
def staff(db):
    return make_staff()


@pytest.fixture
def api_client():
    from rest_framework.test import APIClient

    return APIClient()


def authed(customer):
    from rest_framework.test import APIClient

    client = APIClient()
    client.force_authenticate(customer)
    return client


def on_postgres():
    from django.db import connection

    return connection.vendor == "postgresql"


needs_postgres = pytest.mark.skipif(
    "postgresql" not in os.environ.get("DATABASE_URL", "postgresql"), reason="needs a PostgreSQL database"
)
