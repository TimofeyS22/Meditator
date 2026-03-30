"""add_biometric_snapshots

Revision ID: a4f91c2e8b00
Revises: f7c2a8b91d3e
Create Date: 2026-03-27 22:00:00.000000
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "a4f91c2e8b00"
down_revision: Union[str, None] = "f7c2a8b91d3e"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "biometric_snapshots",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("session_id", sa.UUID(), nullable=True),
        sa.Column("snapshot_type", sa.String(length=20), nullable=False),
        sa.Column("heart_rate", sa.Numeric(), nullable=True),
        sa.Column("hrv", sa.Numeric(), nullable=True),
        sa.Column("steps_today", sa.Integer(), nullable=True),
        sa.Column("sleep_hours", sa.Numeric(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["profiles.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("biometric_snapshots", schema=None) as batch_op:
        batch_op.create_index(
            "ix_biometric_snapshots_user_created",
            ["user_id", "created_at"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("biometric_snapshots", schema=None) as batch_op:
        batch_op.drop_index("ix_biometric_snapshots_user_created")

    op.drop_table("biometric_snapshots")
