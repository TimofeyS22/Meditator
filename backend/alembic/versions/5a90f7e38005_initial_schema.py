"""initial_schema

Revision ID: 5a90f7e38005
Revises: 
Create Date: 2026-03-27 18:50:49.351091
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY


revision: str = '5a90f7e38005'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'profiles',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('email', sa.Text, unique=True, nullable=True),
        sa.Column('display_name', sa.Text, nullable=True),
        sa.Column('avatar_url', sa.Text, nullable=True),
        sa.Column('password_hash', sa.Text, nullable=False, server_default=''),
        sa.Column('goals', ARRAY(sa.String), server_default='{}'),
        sa.Column('stress_level', sa.Text, nullable=True),
        sa.Column('preferred_duration', sa.Text, nullable=True),
        sa.Column('preferred_voice', sa.Text, nullable=True),
        sa.Column('preferred_time_hour', sa.Integer, nullable=True),
        sa.Column('is_premium', sa.Boolean, server_default='false'),
        sa.Column('total_sessions', sa.Integer, server_default='0'),
        sa.Column('current_streak', sa.Integer, server_default='0'),
        sa.Column('longest_streak', sa.Integer, server_default='0'),
        sa.Column('total_minutes', sa.Integer, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
    )

    op.create_table(
        'meditations',
        sa.Column('id', sa.Text, primary_key=True),
        sa.Column('title', sa.Text, nullable=False),
        sa.Column('description', sa.Text, nullable=True),
        sa.Column('category', sa.Text, nullable=False),
        sa.Column('duration_minutes', sa.Integer, nullable=False),
        sa.Column('audio_url', sa.Text, nullable=True),
        sa.Column('image_url', sa.Text, nullable=True),
        sa.Column('is_generated', sa.Boolean, server_default='false'),
        sa.Column('is_premium', sa.Boolean, server_default='false'),
        sa.Column('voice_name', sa.Text, nullable=True),
        sa.Column('rating', sa.Numeric(3, 2), nullable=True),
        sa.Column('play_count', sa.Integer, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
    )
    op.create_index('ix_meditations_category', 'meditations', ['category'])

    op.create_table(
        'sessions',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('meditation_id', sa.Text, sa.ForeignKey('meditations.id', ondelete='SET NULL'), nullable=True),
        sa.Column('duration_seconds', sa.Integer, server_default='0'),
        sa.Column('completed', sa.Boolean, server_default='false'),
        sa.Column('mood_before', sa.Text, nullable=True),
        sa.Column('mood_after', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
    )
    op.create_index('ix_sessions_user_created', 'sessions', ['user_id', 'created_at'])

    op.create_table(
        'mood_entries',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('primary_emotion', sa.Text, nullable=False),
        sa.Column('secondary_emotions', ARRAY(sa.String), server_default='{}'),
        sa.Column('intensity', sa.Integer, nullable=False),
        sa.Column('note', sa.Text, nullable=True),
        sa.Column('ai_insight', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.CheckConstraint('intensity >= 1 AND intensity <= 5'),
    )
    op.create_index('ix_mood_entries_user_created', 'mood_entries', ['user_id', 'created_at'])

    op.create_table(
        'garden_plants',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('type', sa.Text, nullable=False),
        sa.Column('stage', sa.Text, nullable=False),
        sa.Column('water_count', sa.Integer, server_default='0'),
        sa.Column('health_level', sa.Numeric(5, 2), server_default='100'),
        sa.Column('pos_x', sa.Numeric(10, 4), server_default='0'),
        sa.Column('pos_y', sa.Numeric(10, 4), server_default='0'),
        sa.Column('planted_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.Column('last_watered_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_garden_plants_user', 'garden_plants', ['user_id'])

    op.create_table(
        'partnerships',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('partner_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('partner_name', sa.Text, nullable=True),
        sa.Column('status', sa.Text, server_default='pending'),
        sa.Column('shared_goals', ARRAY(sa.String), server_default='{}'),
        sa.Column('my_streak', sa.Integer, server_default='0'),
        sa.Column('partner_streak', sa.Integer, server_default='0'),
        sa.Column('shared_sessions', sa.Integer, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
        sa.CheckConstraint('user_id != partner_id', name='partnerships_no_self'),
        sa.UniqueConstraint('user_id', 'partner_id', name='partnerships_user_partner_unique'),
    )

    op.create_table(
        'pair_messages',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('pair_id', UUID(as_uuid=True), sa.ForeignKey('partnerships.id', ondelete='CASCADE'), nullable=False),
        sa.Column('sender_id', UUID(as_uuid=True), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('type', sa.Text, server_default='text'),
        sa.Column('content', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
    )
    op.create_index('ix_pair_messages_pair_created', 'pair_messages', ['pair_id', 'created_at'])

    op.create_table(
        'knowledge_chunks',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('content', sa.Text, nullable=False),
        sa.Column('source', sa.Text, nullable=False),
        sa.Column('category', sa.Text, nullable=False),
        sa.Column('language', sa.Text, nullable=False, server_default='ru'),
        sa.Column('metadata_', JSONB, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()')),
    )
    op.create_index('ix_knowledge_chunks_category', 'knowledge_chunks', ['category'])


def downgrade() -> None:
    op.drop_table('knowledge_chunks')
    op.drop_table('pair_messages')
    op.drop_table('partnerships')
    op.drop_table('garden_plants')
    op.drop_table('mood_entries')
    op.drop_table('sessions')
    op.drop_table('meditations')
    op.drop_table('profiles')
