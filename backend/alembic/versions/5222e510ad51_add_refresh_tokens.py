"""add_refresh_tokens

Revision ID: 5222e510ad51
Revises: 5a90f7e38005
Create Date: 2026-03-27 18:54:18.528499
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


revision: str = '5222e510ad51'
down_revision: Union[str, None] = '5a90f7e38005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'refresh_tokens',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('jti', sa.Text, unique=True, nullable=False),
        sa.Column('family', sa.Text, nullable=False),
        sa.Column('revoked', sa.Boolean, server_default='false'),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
    )
    op.create_index('ix_refresh_tokens_user', 'refresh_tokens', ['user_id'])
    op.create_index('ix_refresh_tokens_family', 'refresh_tokens', ['family'])


def downgrade() -> None:
    op.drop_table('refresh_tokens')
