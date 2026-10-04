"""add the customs HS code to products (nullable)

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
    op.add_column("products", sa.Column("hs_code", sa.String(length=12), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "hs_code")
