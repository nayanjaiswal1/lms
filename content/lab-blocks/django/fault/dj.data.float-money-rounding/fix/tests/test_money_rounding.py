"""Money is rounded half-up to whole cents, exactly, never through binary floats."""

from decimal import Decimal

from core.testing import *  # noqa: F401,F403


def test_quantize_rounds_halves_up():
    from core.money import quantize

    assert quantize("2.675") == Decimal("2.68")
    assert quantize(Decimal("0.005")) == Decimal("0.01")


def test_tax_rounds_exact_halves_up():
    from orders.pricing import tax

    assert tax(Decimal("6.00")) == Decimal("0.50")  # 0.495 exactly
    assert tax(Decimal("50.00")) == Decimal("4.13")  # 4.125 exactly
