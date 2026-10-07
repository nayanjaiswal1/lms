"""The order list must run a constant number of SQL statements, however many orders the customer has."""

from sqlalchemy import event

from app.testing import *  # noqa: F401,F403


def _customer_with_orders(db, count):
    customer = make_customer(db)
    for _ in range(count):
        make_order(db, customer, lines=[(make_product(db), 1), (make_product(db), 2)])
    return customer


def _statements_for(client, customer):
    statements = []

    def count(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    engine = client.app.state.engine.sync_engine
    event.listen(engine, "before_cursor_execute", count)
    try:
        response = client.get("/api/v1/orders", headers=customer.headers)
    finally:
        event.remove(engine, "before_cursor_execute", count)
    assert response.status_code == 200
    return len(statements), len(response.json())


def test_order_list_query_count_does_not_grow_with_the_number_of_orders(client, db):
    few_queries, few_orders = _statements_for(client, _customer_with_orders(db, 3))
    many_queries, many_orders = _statements_for(client, _customer_with_orders(db, 15))
    assert (few_orders, many_orders) == (3, 15)
    assert many_queries == few_queries
