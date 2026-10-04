from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("orders", "0004_backfill_shipping_names"),
        ("orders", "0004_normalize_currency_codes"),
    ]

    operations = []
