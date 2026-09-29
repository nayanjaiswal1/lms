from django.conf import settings
from django.db import models
from django.db.models import Q

from core.clock import now


class Plan(models.Model):
    code = models.SlugField(max_length=32, unique=True)
    name = models.CharField(max_length=80)
    monthly_price = models.DecimalField(max_digits=8, decimal_places=2)

    def __str__(self):
        return self.name


class Subscription(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        CANCELED = "canceled", "Canceled"
        PAST_DUE = "past_due", "Past due"

    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subscriptions")
    plan = models.ForeignKey(Plan, on_delete=models.PROTECT, related_name="subscriptions")
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.ACTIVE)
    started_at = models.DateTimeField(default=now)
    canceled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-started_at", "-id"]
        # mf:slot subscriptions.model.constraints
        constraints = [
            models.UniqueConstraint(
                fields=["customer", "plan"], condition=Q(status="active"), name="uniq_active_subscription"
            )
        ]
        # mf:endslot

    def __str__(self):
        return f"{self.customer_id} -> {self.plan_id} ({self.status})"
