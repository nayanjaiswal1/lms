from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("orders", "0002_orderitem_line_total"),
    ]

    operations = [
        migrations.AlterField(
            model_name="orderitem",
            name="line_total",
            field=models.DecimalField(decimal_places=2, max_digits=12),
        ),
    ]
