from django.db import migrations, models
from django.utils.text import slugify


def build_slug(title, pk):
    """Titles are optional and not unique; the primary key makes every slug unique."""
    return f"{slugify(title or '') or 'review'}-{pk}"


def backfill_slugs(apps, schema_editor):
    Review = apps.get_model("reviews", "Review")
    for review in Review.objects.filter(slug__isnull=True).iterator():
        review.slug = build_slug(review.title, review.pk)
        review.save(update_fields=["slug"])


class Migration(migrations.Migration):
    dependencies = [
        ("reviews", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="review",
            name="slug",
            field=models.SlugField(max_length=140, null=True, db_index=False),
        ),
        migrations.RunPython(backfill_slugs, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="review",
            name="slug",
            field=models.SlugField(max_length=140, unique=True, blank=True),
        ),
    ]
