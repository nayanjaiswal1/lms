"""backfill missing shipping names

Revision ID: 7c2e9d41a0b6
Revises: e4a6f27c0d81
Create Date: 2025-02-03 09:40:00
"""

from alembic import op

revision = "7c2e9d41a0b6"
down_revision = "e4a6f27c0d81"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("UPDATE orders SET shipping_name = '(not provided)' WHERE shipping_name IS NULL OR shipping_name = ''")


def downgrade() -> None:
    op.execute("UPDATE orders SET shipping_name = NULL WHERE shipping_name = '(not provided)'")
