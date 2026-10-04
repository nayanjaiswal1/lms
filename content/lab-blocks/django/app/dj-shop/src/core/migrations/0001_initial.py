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
            name='Counter',
            fields=[
                ('name', models.CharField(max_length=128, primary_key=True, serialize=False)),
                ('value', models.BigIntegerField(default=0)),
            ],
        ),
        migrations.CreateModel(
            name='AuditEntry',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('action', models.CharField(max_length=64)),
                ('target_type', models.CharField(max_length=64)),
                ('target_id', models.CharField(max_length=64)),
                ('data', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(default=core.clock.now)),
                ('actor', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='+', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-created_at', '-id'],
                'indexes': [models.Index(fields=['target_type', 'target_id'], name='audit_target_idx')],
            },
        ),
    ]
