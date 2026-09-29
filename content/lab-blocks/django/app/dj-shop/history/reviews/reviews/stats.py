from django.db.models import Count, Sum

from catalog.models import Product
from reviews.models import Review


def update_product_stats(product_id):
    """Recompute the denormalised review counters of one product from the source rows."""
    agg = Review.objects.filter(product_id=product_id, is_approved=True).aggregate(n=Count("id"), total=Sum("rating"))
    Product.all_objects.filter(pk=product_id).update(review_count=agg["n"] or 0, rating_total=agg["total"] or 0)
