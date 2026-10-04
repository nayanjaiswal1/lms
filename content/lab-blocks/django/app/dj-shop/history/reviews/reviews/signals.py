from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from reviews.models import Review
from reviews.stats import update_product_stats


# mf:slot reviews.signals.counters
@receiver([post_save, post_delete], sender=Review)
def refresh_product_stats(sender, instance, **kwargs):
    update_product_stats(instance.product_id)


# mf:endslot
