import io

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.core.management.base import CommandError

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db
CSV = (
    "sku,name,category,price,description\n"
    "IMP-1,Blue mug,Kitchen,7.50,A mug\n"
    "IMP-2,Red mug,Kitchen,8.25,\n"
    ",No sku,Kitchen,1,\n"
    "IMP-4,Bad price,Kitchen,abc,\n"
)


def test_import_reports_each_bad_row_and_keeps_good_ones():
    from catalog.importer import import_products, read_csv
    from catalog.models import Product

    result = import_products(read_csv(io.StringIO(CSV)))
    assert (result.created, result.updated) == (2, 0)
    assert [e["line"] for e in result.errors] == [4, 5]
    assert Product.objects.filter(sku__startswith="IMP-").count() == 2


def test_reimport_updates_and_undeletes():
    from catalog.importer import import_products, read_csv
    from catalog.models import Product

    import_products(read_csv(io.StringIO(CSV)))
    Product.objects.get(sku="IMP-1").soft_delete()
    result = import_products(read_csv(io.StringIO("sku,name,category,price\nIMP-1,Blue mug v2,Kitchen,9.00\n")))
    assert (result.created, result.updated) == (0, 1)
    assert Product.objects.get(sku="IMP-1").name == "Blue mug v2"


def test_command_exits_non_zero_on_rejected_rows(tmp_path):
    path = tmp_path / "products.csv"
    path.write_text(CSV, encoding="utf-8")
    out, err = io.StringIO(), io.StringIO()
    with pytest.raises(CommandError):
        call_command("import_products", str(path), stdout=out, stderr=err)
    assert "created=2" in out.getvalue() and "line 4" in err.getvalue()


def test_api_upload_returns_207_with_errors():
    client = authed(make_staff())
    upload = SimpleUploadedFile("p.csv", CSV.encode(), content_type="text/csv")
    resp = client.post("/api/products/import/", {"file": upload}, format="multipart")
    assert resp.status_code == 207 and resp.json()["created"] == 2 and len(resp.json()["errors"]) == 2
    assert authed(make_customer()).post("/api/products/import/", {}, format="multipart").status_code == 403
