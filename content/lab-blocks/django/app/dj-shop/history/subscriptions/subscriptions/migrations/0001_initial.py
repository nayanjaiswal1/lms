import core.clock
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Plan',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('code', models.SlugField(max_length=32, unique=True)),
                ('name', models.CharField(max_length=80)),
                ('monthly_price', models.DecimalField(decimal_places=2, max_digits=8)),
            ],
        ),
        migrations.CreateModel(
            name='Subscription',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(choices=[('active', 'Active'), ('canceled', 'Canceled'), ('past_due', 'Past due')], default='active', max_length=16)),
                ('started_at', models.DateTimeField(default=core.clock.now)),
                ('canceled_at', models.DateTimeField(blank=True, null=True)),
                ('customer', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='subscriptions', to=settings.AUTH_USER_MODEL)),
                ('plan', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='subscriptions', to='subscriptions.plan')),
            ],
            options={
                'ordering': ['-started_at', '-id'],
            },
        ),
            # mf:slot subscriptions.migration.constraints
        migrations.AddConstraint(
            model_name='subscription',
            constraint=models.UniqueConstraint(condition=models.Q(('status', 'active')), fields=('customer', 'plan'), name='uniq_active_subscription'),
        ),
        # mf:endslot
    ]
