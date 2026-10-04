import core.clock
import django.db.models.deletion
import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('orders', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='Payment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('provider_ref', models.CharField(blank=True, max_length=64)),
                ('status', models.CharField(choices=[('pending', 'Pending'), ('succeeded', 'Succeeded'), ('failed', 'Failed'), ('refunded', 'Refunded')], default='pending', max_length=16)),
                ('amount', models.DecimalField(decimal_places=2, max_digits=12)),
                ('idempotency_key', models.UUIDField(default=uuid.uuid4, unique=True)),
                ('created_at', models.DateTimeField(default=core.clock.now)),
                ('order', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='payments', to='orders.order')),
            ],
            options={
                'ordering': ['-created_at', '-id'],
            },
        ),
    ]
