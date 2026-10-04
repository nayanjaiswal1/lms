"""The HS code migration must apply to a products table that already has rows, like production."""

from app.testing import *  # noqa: F401,F403

BEFORE_HS_CODE = "e4a6f27c0d81"


def test_hs_code_migration_applies_to_a_populated_products_table(scratch_database_url):
    assert alembic_cli(scratch_database_url, "upgrade", BEFORE_HS_CODE).returncode == 0
    with psycopg.connect(scratch_database_url, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO products (sku, name, category, price_cents) "
            "SELECT 'OLD-' || g, 'Old product ' || g, 'misc', 100 FROM generate_series(1, 3) g"
        )
    result = alembic_cli(scratch_database_url, "upgrade", "head")
    assert result.returncode == 0, result.stderr
    with psycopg.connect(scratch_database_url, autocommit=True) as conn:
        assert conn.execute("SELECT count(*) FROM products WHERE hs_code IS NULL").fetchone()[0] == 0
        nullable = conn.execute(
            "SELECT is_nullable FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'hs_code'"
        ).fetchone()[0]
        assert nullable == "NO"
