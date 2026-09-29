"""Bulk product import from CSV rows: sku,name,category,price,description."""

import csv
import logging
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.utils.text import slugify

from catalog.models import Category, Product

logger = logging.getLogger(__name__)
REQUIRED = ("sku", "name", "category", "price")


@dataclass
class ImportResult:
    created: int = 0
    updated: int = 0
    errors: list = field(default_factory=list)

    @property
    def ok(self):
        return not self.errors


def _import_row(row):
    missing = [key for key in REQUIRED if not (row.get(key) or "").strip()]
    if missing:
        raise ValueError(f"missing {', '.join(missing)}")
    try:
        price = Decimal(row["price"].strip())
    except InvalidOperation as exc:
        raise ValueError(f"invalid price {row['price']!r}") from exc
    if price < 0:
        raise ValueError("price must not be negative")
    name = row["category"].strip()
    category, _ = Category.objects.get_or_create(slug=slugify(name), defaults={"name": name})
    _, created = Product.all_objects.update_or_create(
        sku=row["sku"].strip(),
        defaults={
            "name": row["name"].strip(),
            "category": category,
            "price": price,
            "description": (row.get("description") or "").strip(),
            "is_deleted": False,
            "deleted_at": None,
        },
    )
    return created


def import_products(rows):
    """Import rows one by one; a bad row is reported and does not stop the others."""
    result = ImportResult()
    for line, row in enumerate(rows, start=2):
        # mf:slot catalog.importer.row
        try:
            with transaction.atomic():
                created = _import_row(row)
        except (ValueError, KeyError) as exc:
            logger.warning("product import: line %s rejected: %s", line, exc)
            result.errors.append({"line": line, "error": str(exc)})
            continue
        # mf:endslot
        if created:
            result.created += 1
        else:
            result.updated += 1
    return result


def read_csv(handle):
    return list(csv.DictReader(handle))
