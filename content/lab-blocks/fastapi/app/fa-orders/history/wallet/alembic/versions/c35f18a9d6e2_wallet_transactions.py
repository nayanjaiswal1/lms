"""wallet transactions

Revision ID: c35f18a9d6e2
Revises: b72d90e5c418
Create Date: 2025-01-14 11:05:00
"""

import sqlalchemy as sa
from alembic import op

revision = "c35f18a9d6e2"
down_revision = "b72d90e5c418"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "wallet_transactions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("customer_id", sa.Integer(), nullable=False),
        sa.Column("delta_cents", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(length=60), nullable=False),
        sa.Column("balance_after_cents", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(
            ["customer_id"], ["customers.id"], name=op.f("fk_wallet_transactions_customer_id_customers")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_wallet_transactions")),
    )
    op.create_index(
        op.f("ix_wallet_transactions_customer_id"), "wallet_transactions", ["customer_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_wallet_transactions_customer_id"), table_name="wallet_transactions")
    op.drop_table("wallet_transactions")
