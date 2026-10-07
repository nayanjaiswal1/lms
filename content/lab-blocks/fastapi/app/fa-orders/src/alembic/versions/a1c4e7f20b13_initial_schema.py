"""initial schema: customers and products

Revision ID: a1c4e7f20b13
Revises:
Create Date: 2025-01-06 09:12:00
"""

import sqlalchemy as sa
from alembic import op

revision = "a1c4e7f20b13"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "customers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(length=254), nullable=False),
        sa.Column("display_name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=32), nullable=True),
        sa.Column("company", sa.String(length=120), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("locale", sa.String(length=10), server_default="en", nullable=False),
        sa.Column("password_hash", sa.String(length=100), nullable=False),
        sa.Column("api_token", sa.String(length=64), nullable=False),
        sa.Column("is_staff", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("credit_cents", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_customers")),
        sa.UniqueConstraint("email", name=op.f("uq_customers_email")),
        sa.UniqueConstraint("api_token", name=op.f("uq_customers_api_token")),
    )
    op.create_table(
        "products",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("sku", sa.String(length=32), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("category", sa.String(length=40), nullable=False),
        sa.Column("price_cents", sa.Integer(), nullable=False),
        sa.Column("stock", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_products")),
        sa.UniqueConstraint("sku", name=op.f("uq_products_sku")),
    )


def downgrade() -> None:
    op.drop_table("products")
    op.drop_table("customers")
