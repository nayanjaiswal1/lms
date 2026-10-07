"""add the customs HS code to products

Revision ID: f5b7c38d1e92
Revises: e4a6f27c0d81
Create Date: 2025-02-10 15:20:00
"""

import sqlalchemy as sa
from alembic import op

revision = "f5b7c38d1e92"
down_revision = "e4a6f27c0d81"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Existing rows get the default; the model declares the same server_default.
    op.add_column("products", sa.Column("hs_code", sa.String(length=12), server_default="0000.00", nullable=False))


def downgrade() -> None:
    op.drop_column("products", "hs_code")
