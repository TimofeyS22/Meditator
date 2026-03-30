"""add push_tokens and scheduled_notifications

Revision ID: c8e1b4a92f10
Revises: a4f91c2e8b00
Create Date: 2026-03-27 12:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB


revision: str = "c8e1b4a92f10"
down_revision: Union[str, None] = "a4f91c2e8b00"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "push_tokens",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "token", name="uq_push_token"),
    )
    op.create_table(
        "scheduled_notifications",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("action_type", sa.String(length=50), nullable=False),
        sa.Column("action_data", JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sent", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_scheduled_notifications_user_sent_scheduled",
        "scheduled_notifications",
        ["user_id", "sent", "scheduled_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_scheduled_notifications_user_sent_scheduled", table_name="scheduled_notifications")
    op.drop_table("scheduled_notifications")
    op.drop_table("push_tokens")
