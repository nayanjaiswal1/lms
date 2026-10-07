"""payments

Revision ID: d8e0a4b71c59
Revises: c35f18a9d6e2
Create Date: 2025-01-21 16:40:00
"""

import sqlalchemy as sa
from alembic import op

revision = "d8e0a4b71c59"
down_revision = "c35f18a9d6e2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "payments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("order_id", sa.Integer(), nullable=False),
        sa.Column("provider_charge_id", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("amount_cents", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["order_id"], ["orders.id"], name=op.f("fk_payments_order_id_orders")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_payments")),
        sa.UniqueConstraint("order_id", name=op.f("uq_payments_order_id")),
    )


def downgrade() -> None:
    op.drop_table("payments")
