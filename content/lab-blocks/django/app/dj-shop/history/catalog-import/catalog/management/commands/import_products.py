from django.core.management.base import BaseCommand, CommandError

from catalog.importer import import_products, read_csv


class Command(BaseCommand):
    help = "Import products from a CSV file (sku,name,category,price,description)."

    def add_arguments(self, parser):
        parser.add_argument("path")

    def handle(self, *args, **options):
        try:
            with open(options["path"], newline="", encoding="utf-8") as handle:
                rows = read_csv(handle)
        except OSError as exc:
            raise CommandError(str(exc)) from exc
        result = import_products(rows)
        self.stdout.write(f"created={result.created} updated={result.updated} errors={len(result.errors)}")
        for err in result.errors:
            self.stderr.write(f"line {err['line']}: {err['error']}")
        if result.errors:
            raise CommandError("Some rows were rejected")
