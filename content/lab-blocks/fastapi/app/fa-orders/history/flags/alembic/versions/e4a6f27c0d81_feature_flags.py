"""feature flags

Revision ID: e4a6f27c0d81
Revises: d8e0a4b71c59
Create Date: 2025-01-28 10:15:00
"""

import sqlalchemy as sa
from alembic import op

revision = "e4a6f27c0d81"
down_revision = "d8e0a4b71c59"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "feature_flags",
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("key", name=op.f("pk_feature_flags")),
    )


def downgrade() -> None:
    op.drop_table("feature_flags")
