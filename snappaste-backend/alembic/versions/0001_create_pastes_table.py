"""create pastes table

Revision ID: 0001
Revises:
Create Date: 2026-03-16
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "pastes",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("short_code", sa.String(10), nullable=False),
        sa.Column("title", sa.String(255), nullable=True),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("language", sa.String(50), nullable=False, server_default="plaintext"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("view_count", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_pastes_short_code", "pastes", ["short_code"], unique=True)
    op.create_index("ix_pastes_expires_at", "pastes", ["expires_at"])


def downgrade() -> None:
    op.drop_index("ix_pastes_expires_at", table_name="pastes")
    op.drop_index("ix_pastes_short_code", table_name="pastes")
    op.drop_table("pastes")
