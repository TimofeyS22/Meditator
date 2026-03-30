"""add_password_reset_tokens

Revision ID: f7c2a8b91d3e
Revises: 8424dd47a0bd
Create Date: 2026-03-27 20:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "f7c2a8b91d3e"
down_revision: Union[str, None] = "8424dd47a0bd"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "password_reset_tokens",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("token", sa.Text(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token"),
    )
    with op.batch_alter_table("password_reset_tokens", schema=None) as batch_op:
        batch_op.create_index("ix_password_reset_tokens_token", ["token"], unique=False)
        batch_op.create_index("ix_password_reset_tokens_user", ["user_id"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("password_reset_tokens", schema=None) as batch_op:
        batch_op.drop_index("ix_password_reset_tokens_user")
        batch_op.drop_index("ix_password_reset_tokens_token")

    op.drop_table("password_reset_tokens")
