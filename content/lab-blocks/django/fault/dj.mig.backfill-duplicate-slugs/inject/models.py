import uuid

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils.text import slugify

from core.clock import now


class Review(models.Model):
    product = models.ForeignKey("catalog.Product", on_delete=models.CASCADE, related_name="reviews")
    customer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    title = models.CharField(max_length=120, null=True, blank=True)
    slug = models.SlugField(max_length=140, unique=True, blank=True)
    body = models.TextField(blank=True)
    is_approved = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=now)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [models.UniqueConstraint(fields=["product", "customer"], name="uniq_review_product_customer")]

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = f"{slugify(self.title or '') or 'review'}-{uuid.uuid4().hex[:8]}"
        super().save(*args, **kwargs)

    # mf:slot reviews.model.lifecycle
    def __str__(self):
        return f"{self.rating}/5 on product {self.product_id}"

    # mf:endslot
