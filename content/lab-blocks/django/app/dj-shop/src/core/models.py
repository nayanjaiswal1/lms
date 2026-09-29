from django.conf import settings
from django.db import models

from core.clock import now


class AuditEntry(models.Model):
    """Append-only trail of who changed what."""

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    action = models.CharField(max_length=64)
    target_type = models.CharField(max_length=64)
    target_id = models.CharField(max_length=64)
    data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(default=now)

    class Meta:
        ordering = ["-created_at", "-id"]
        indexes = [models.Index(fields=["target_type", "target_id"], name="audit_target_idx")]

    def __str__(self):
        return f"{self.action} {self.target_type}#{self.target_id}"


class Counter(models.Model):
    """Named monotonic counters, readable with plain SQL."""

    name = models.CharField(max_length=128, primary_key=True)
    value = models.BigIntegerField(default=0)

    def __str__(self):
        return f"{self.name}={self.value}"
