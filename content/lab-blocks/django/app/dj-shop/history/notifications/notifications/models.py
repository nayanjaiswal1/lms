from django.db import models

from core.clock import now


class EmailLog(models.Model):
    """One row per (kind, reference): the record that an email was sent."""

    kind = models.CharField(max_length=48)
    reference = models.CharField(max_length=64)
    recipient = models.EmailField()
    sent_at = models.DateTimeField(default=now)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["kind", "reference"], name="uniq_email_kind_reference")]

    def __str__(self):
        return f"{self.kind}:{self.reference} -> {self.recipient}"
