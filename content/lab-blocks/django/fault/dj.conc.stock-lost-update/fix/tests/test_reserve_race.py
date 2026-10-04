"""Two reservations racing for the last unit: exactly one wins and stock never goes wrong."""

import threading

from core.testing import *  # noqa: F401,F403

pytestmark = [pytest.mark.django_db(transaction=True), needs_postgres]


def test_two_racing_reservations_never_oversell(monkeypatch):
    from django.db import connection

    from inventory import services
    from inventory.models import StockLevel

    product = make_product()
    make_stock(product, 1)
    barrier = threading.Barrier(2, timeout=3)
    real_save = StockLevel.save

    def racing_save(self, *args, **kwargs):
        try:
            barrier.wait()  # both workers have read the row before either one writes it back
        except threading.BrokenBarrierError:
            pass
        return real_save(self, *args, **kwargs)

    monkeypatch.setattr(StockLevel, "save", racing_save)
    results = []

    def worker():
        try:
            services.reserve(product.pk, 1)
            results.append("reserved")
        except services.OutOfStock:
            results.append("out-of-stock")
        finally:
            connection.close()

    threads = [threading.Thread(target=worker) for _ in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=15)
    assert sorted(results) == ["out-of-stock", "reserved"]
    assert StockLevel.objects.get(product=product).on_hand == 0
