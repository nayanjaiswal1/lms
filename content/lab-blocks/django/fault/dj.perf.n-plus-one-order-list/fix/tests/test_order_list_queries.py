"""The order list page must run a constant number of queries, however many orders the customer has."""

from django.db import connection
from django.test.utils import CaptureQueriesContext

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _customer_with_orders(count):
    from orders.models import Order, OrderItem

    user = make_customer()
    for _ in range(count):
        order = Order.objects.create(customer=user, status="paid", subtotal=10, total=10)
        for _ in range(2):
            OrderItem.objects.create(order=order, product=make_product(), quantity=1, unit_price=5, line_total=5)
    return user


def _queries_for(client, user):
    client.force_login(user)
    with CaptureQueriesContext(connection) as ctx:
        assert client.get("/orders/").status_code == 200
    return len(ctx)


def test_order_list_query_count_does_not_grow_with_the_number_of_orders(client):
    few = _queries_for(client, _customer_with_orders(3))
    many = _queries_for(client, _customer_with_orders(15))
    assert many == few
