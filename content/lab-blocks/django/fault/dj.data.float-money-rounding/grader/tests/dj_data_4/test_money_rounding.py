from decimal import ROUND_HALF_UP, Decimal

from core.testing import *  # noqa: F401,F403


def _expected_tax(subtotal):
    return (subtotal * Decimal("0.0825")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def test_tax_matches_exact_decimal_arithmetic_for_every_subtotal():
    from orders.pricing import tax

    wrong = [c for c in range(1, 40001) if tax(Decimal(c) / 100) != _expected_tax(Decimal(c) / 100)]
    assert not wrong, f"{len(wrong)} subtotals are taxed to the wrong cent, first: {wrong[:3]}"


def test_line_totals_and_order_totals_are_exact():
    from orders.pricing import line_total, order_totals

    for cents in range(1, 3000, 7):
        price = Decimal(cents) / 100
        for qty in (1, 2, 3, 7):
            assert line_total(price, qty) == (price * qty).quantize(Decimal("0.01"))
    subtotal, tax, total = order_totals([(Decimal("6.00"), 1)])
    assert (subtotal, tax, total) == (Decimal("6.00"), Decimal("0.50"), Decimal("6.50"))


def test_quantize_returns_decimal_half_up():
    from core.money import quantize

    for raw, want in [("2.675", "2.68"), ("1.005", "1.01"), ("0.125", "0.13"), ("10.115", "10.12")]:
        got = quantize(Decimal(raw))
        assert isinstance(got, Decimal) and got == Decimal(want), raw
