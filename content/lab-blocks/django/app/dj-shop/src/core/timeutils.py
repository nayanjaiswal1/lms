"""Timezone helpers for business-day calculations."""

from datetime import datetime, time, timedelta

from django.utils import timezone


def localize(naive, tz=None):
    """Attach the business timezone to a naive datetime."""
    tz = tz or timezone.get_current_timezone()
    # mf:slot core.timeutils.localize
    return timezone.make_aware(naive, tz)
    # mf:endslot


def day_bounds(day, tz=None):
    """Return [start, end) of a calendar day in the business timezone."""
    start = localize(datetime.combine(day, time.min), tz)
    end = localize(datetime.combine(day + timedelta(days=1), time.min), tz)
    return start, end
