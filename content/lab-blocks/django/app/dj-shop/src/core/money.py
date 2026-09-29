"""Money helpers. All amounts are Decimal in the shop currency (two places)."""

from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")


def quantize(value):
    """Round to whole cents, halves away from zero."""
    # mf:slot core.money.quantize
    return Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP)
    # mf:endslot


def to_cents(value):
    return int(quantize(value) * 100)


def from_cents(cents):
    return (Decimal(int(cents)) / 100).quantize(CENT)
