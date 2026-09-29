from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.utils import timezone

from core.testing import *  # noqa: F401,F403


def test_quantize_rounds_half_up():
    from core.money import quantize

    assert quantize("2.675") == Decimal("2.68")
    assert quantize(Decimal("0.005")) == Decimal("0.01")
    assert quantize(1) == Decimal("1.00")


def test_cents_roundtrip():
    from core.money import from_cents, to_cents

    assert to_cents(Decimal("19.99")) == 1999
    assert from_cents(1999) == Decimal("19.99")


def test_localize_and_day_bounds_use_business_timezone():
    from core.timeutils import day_bounds, localize

    tz = ZoneInfo("America/New_York")
    aware = localize(datetime(2025, 3, 1, 22, 30), tz)
    assert aware.utcoffset().total_seconds() == -5 * 3600
    start, end = day_bounds(date(2025, 3, 9), tz)  # DST starts this day
    assert (end.astimezone(ZoneInfo("UTC")) - start.astimezone(ZoneInfo("UTC"))).total_seconds() == 23 * 3600
    assert timezone.is_aware(start) and timezone.is_aware(end)


def test_clock_now_is_aware():
    from core.clock import now

    assert timezone.is_aware(now())
