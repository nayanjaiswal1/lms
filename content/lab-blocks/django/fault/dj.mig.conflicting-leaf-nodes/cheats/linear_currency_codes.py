from django.db import migrations


def uppercase_currency(apps, schema_editor):
    Order = apps.get_model("orders", "Order")
    for order in Order.objects.exclude(currency="USD").iterator():
        order.currency = order.currency.upper()
        order.save(update_fields=["currency"])


class Migration(migrations.Migration):
    dependencies = [
        ("orders", "0004_backfill_shipping_names"),
    ]

    operations = [
        migrations.RunPython(uppercase_currency, migrations.RunPython.noop),
    ]
