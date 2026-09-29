from django.db import models
from django.utils import timezone
from django.utils.text import slugify

from core.clock import now


class Category(models.Model):
    name = models.CharField(max_length=80, unique=True)
    slug = models.SlugField(max_length=90, unique=True)

    class Meta:
        ordering = ["name"]
        verbose_name_plural = "categories"

    def __str__(self):
        return self.name


class ActiveProductManager(models.Manager):
    """Default manager: soft-deleted products are invisible."""

    def get_queryset(self):
        return super().get_queryset().filter(is_deleted=False)


class Product(models.Model):
    sku = models.CharField(max_length=32, unique=True)
    name = models.CharField(max_length=@@mf:value catalog.product.name_max_length=120@@)
    slug = models.SlugField(max_length=140, unique=True)
    subtitle = models.CharField(max_length=160, null=True, blank=True)
    description = models.TextField(blank=True)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="products")
    # mf:slot catalog.model.price
    price = models.DecimalField(max_digits=12, decimal_places=2)
    # mf:endslot
    is_deleted = models.BooleanField(default=False)
    deleted_at = models.DateTimeField(null=True, blank=True)
    review_count = models.PositiveIntegerField(default=0)
    rating_total = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(default=now)

    # mf:slot catalog.model.managers
    objects = ActiveProductManager()
    all_objects = models.Manager()
    # mf:endslot

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(f"{self.name}-{self.sku}")[:140]
        super().save(*args, **kwargs)

    def soft_delete(self):
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.save(update_fields=["is_deleted", "deleted_at"])

    @property
    def average_rating(self):
        return round(self.rating_total / self.review_count, 2) if self.review_count else None
