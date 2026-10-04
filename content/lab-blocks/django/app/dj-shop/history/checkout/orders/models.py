import uuid

from django.conf import settings
from django.db import models
from django.db.models import Q

from core.clock import now


class Order(models.Model):
    # mf:slot orders.model.status_choices
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PAID = "paid", "Paid"
        SHIPPED = "shipped", "Shipped"
        DELIVERED = "delivered", "Delivered"
        CANCELLED = "cancelled", "Cancelled"
        REFUNDED = "refunded", "Refunded"

    # mf:endslot

    public_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    # mf:slot orders.model.customer_fk
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="orders")
    # mf:endslot
    # mf:slot orders.model.handler_fk
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="handled_orders"
    )
    # mf:endslot
    status = models.CharField(max_length=16, choices=Status.choices, default="pending")
    # mf:slot orders.model.totals
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # mf:endslot
    currency = models.CharField(max_length=3, default="USD")
    shipping_name = models.CharField(max_length=120, blank=True)
    created_at = models.DateTimeField(default=now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        # mf:slot orders.model.indexes
        indexes = [models.Index(fields=["status", "-created_at"], name="order_status_created_idx")]
        # mf:endslot
        # mf:slot orders.model.constraints
        constraints = [
            models.CheckConstraint(
                condition=Q(status__in=["pending", "paid", "shipped", "delivered", "cancelled", "refunded"]),
                name="order_status_valid",
            )
        ]
        # mf:endslot

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._loaded_status = self.status

    def __str__(self):
        return f"Order #{self.pk}"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self._loaded_status = self.status

    @property
    def status_changed(self):
        return self.status != self._loaded_status

    @property
    def status_label(self):
        return self.Status(self.status).label


class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey("catalog.Product", on_delete=models.PROTECT, related_name="order_items")
    quantity = models.PositiveIntegerField()
    # mf:slot orders.model.item_prices
    unit_price = models.DecimalField(max_digits=12, decimal_places=2)
    line_total = models.DecimalField(max_digits=12, decimal_places=2)
    # mf:endslot

    def __str__(self):
        return f"{self.quantity} x {self.product_id}"


class Invoice(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name="invoice")
    number = models.CharField(max_length=32, unique=True)
    issued_at = models.DateTimeField(default=now)
    total = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        ordering = ["-issued_at", "-id"]

    def __str__(self):
        return self.number
