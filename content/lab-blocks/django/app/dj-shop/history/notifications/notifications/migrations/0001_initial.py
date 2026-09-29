import core.clock
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='EmailLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('kind', models.CharField(max_length=48)),
                ('reference', models.CharField(max_length=64)),
                ('recipient', models.EmailField(max_length=254)),
                ('sent_at', models.DateTimeField(default=core.clock.now)),
            ],
            options={
                'constraints': [models.UniqueConstraint(fields=('kind', 'reference'), name='uniq_email_kind_reference')],
            },
        ),
    ]
