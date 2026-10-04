from django.db import migrations, models


def backfill_line_totals(apps, schema_editor):
    OrderItem = apps.get_model("orders", "OrderItem")
    OrderItem.objects.filter(line_total__isnull=True).update(line_total=models.F("unit_price") * models.F("quantity"))


def clear_line_totals(apps, schema_editor):
    OrderItem = apps.get_model("orders", "OrderItem")
    OrderItem.objects.update(line_total=None)


class Migration(migrations.Migration):
    dependencies = [
        ("orders", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="orderitem",
            name="line_total",
            field=models.DecimalField(decimal_places=2, max_digits=12, null=True),
        ),
        migrations.RunPython(backfill_line_totals, clear_line_totals),
    ]
