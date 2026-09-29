"""Order pricing. Every amount is a Decimal rounded to whole cents."""

from decimal import Decimal

from django.conf import settings

from core.money import quantize


def line_total(unit_price, quantity):
    # mf:slot orders.pricing.line_total
    return quantize(Decimal(unit_price) * quantity)
    # mf:endslot


def tax(subtotal):
    # mf:slot orders.pricing.tax
    return quantize(Decimal(subtotal) * Decimal(settings.SALES_TAX_RATE))
    # mf:endslot


def order_totals(lines):
    """Return (subtotal, tax, total) for (unit_price, quantity) pairs."""
    subtotal = sum((line_total(price, qty) for price, qty in lines), Decimal("0.00"))
    order_tax = tax(subtotal)
    return subtotal, order_tax, subtotal + order_tax
