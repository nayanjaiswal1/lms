from django.db import migrations


def backfill_shipping_names(apps, schema_editor):
    Order = apps.get_model("orders", "Order")
    Order.objects.filter(shipping_name="").update(shipping_name="(not provided)")


def clear_backfilled_names(apps, schema_editor):
    Order = apps.get_model("orders", "Order")
    Order.objects.filter(shipping_name="(not provided)").update(shipping_name="")


class Migration(migrations.Migration):
    dependencies = [
        ("orders", "0003_orderitem_line_total_required"),
    ]

    operations = [
        migrations.RunPython(backfill_shipping_names, clear_backfilled_names),
    ]
