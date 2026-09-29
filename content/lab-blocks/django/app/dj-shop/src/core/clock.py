"""Single source of "now" so business code never builds naive datetimes."""

from django.utils import timezone


def now():
    # mf:slot core.clock.now
    return timezone.now()
    # mf:endslot
