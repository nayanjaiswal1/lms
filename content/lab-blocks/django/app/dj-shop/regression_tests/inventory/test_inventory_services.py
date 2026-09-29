import asyncio

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_reserve_decrements_and_refuses_oversell():
    from inventory import services
    from inventory.models import StockLevel

    product = make_product()
    make_stock(product, 5)
    services.reserve(product.pk, 3)
    assert StockLevel.objects.get(product=product).on_hand == 2
    with pytest.raises(services.OutOfStock):
        services.reserve(product.pk, 3)
    assert StockLevel.objects.get(product=product).on_hand == 2


def test_release_returns_units():
    from inventory import services

    product = make_product()
    make_stock(product, 1)
    services.release(product.pk, 4)
    assert services.available(product.pk) == 5


def test_available_sums_all_warehouses():
    from inventory import services
    from inventory.models import Warehouse

    product = make_product()
    make_stock(product, 4)
    make_stock(product, 6, Warehouse.objects.create(code="EAST", name="East"))
    assert services.available(product.pk) == 10


def test_transfer_moves_stock_and_audits():
    from core.models import AuditEntry
    from inventory import services
    from inventory.models import StockLevel, Warehouse

    product = make_product()
    main = main_warehouse()
    east = Warehouse.objects.create(code="EAST", name="East")
    make_stock(product, 10, main)
    services.transfer(product.pk, main, east, 4)
    assert StockLevel.objects.get(product=product, warehouse=main).on_hand == 6
    assert StockLevel.objects.get(product=product, warehouse=east).on_hand == 4
    assert AuditEntry.objects.filter(action="stock.transferred").count() == 1


def test_transfer_rejects_insufficient_stock_and_same_warehouse():
    from inventory import services
    from inventory.models import Warehouse

    product = make_product()
    main = main_warehouse()
    east = Warehouse.objects.create(code="EAST", name="East")
    make_stock(product, 2, main)
    with pytest.raises(services.OutOfStock):
        services.transfer(product.pk, main, east, 3)
    with pytest.raises(ValueError):
        services.transfer(product.pk, main, main, 1)


@pytest.mark.django_db(transaction=True)
def test_availability_endpoint_is_async_safe(client):
    product = make_product()
    make_stock(product, 7)
    resp = client.get(f"/api/products/{product.pk}/availability/")
    assert resp.status_code == 200
    assert resp.json()["available"] == 7 and resp.json()["warehouses"] == {"MAIN": 7}
    assert client.get("/api/products/999999/availability/").status_code == 404


def test_stock_level_uniqueness_is_enforced():
    from django.db import IntegrityError, transaction

    from inventory.models import StockLevel

    product = make_product()
    make_stock(product, 1)
    with pytest.raises(IntegrityError), transaction.atomic():
        StockLevel.objects.create(product=product, warehouse=main_warehouse(), on_hand=1)
