"""normalize currency codes to upper case (re-parented onto the shipping names revision)

Revision ID: 9b14f8e3d025
Revises: 7c2e9d41a0b6
Create Date: 2025-02-03 11:05:00
"""

from alembic import op

revision = "9b14f8e3d025"
down_revision = "7c2e9d41a0b6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("UPDATE orders SET currency = upper(currency) WHERE currency <> upper(currency)")


def downgrade() -> None:
    pass
