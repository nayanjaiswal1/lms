from django.db.models import F

from core.models import Counter


def incr(name, amount=1):
    """Atomically bump a named counter."""
    Counter.objects.get_or_create(name=name)
    Counter.objects.filter(name=name).update(value=F("value") + amount)


def get(name):
    return Counter.objects.filter(name=name).values_list("value", flat=True).first() or 0
