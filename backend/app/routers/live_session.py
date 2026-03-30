"""WebSocket endpoint for live synchronized meditation between partners."""

from __future__ import annotations

import asyncio
import json
import time
from collections import defaultdict
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Partnership, Profile

logger = structlog.get_logger()
router = APIRouter(tags=["live_session"])

_rooms: dict[str, dict[str, WebSocket]] = defaultdict(dict)
_breathing: dict[str, dict[str, dict]] = defaultdict(dict)


async def _get_user_from_token(token: str, db: AsyncSession) -> Profile | None:
    """Resolve a JWT access token to a Profile."""
    try:
        from app.auth import decode_token
        user_id = decode_token(token, expected_type="access")
        if user_id is None:
            return None
        result = await db.execute(select(Profile).where(Profile.id == user_id))
        return result.scalar_one_or_none()
    except Exception:
        return None


async def _get_pair_room(user_id: UUID, db: AsyncSession) -> str | None:
    """Find the partnership room id for a user."""
    result = await db.execute(
        select(Partnership).where(
            (Partnership.user_id == user_id) | (Partnership.partner_id == user_id),
            Partnership.status == "active",
        )
    )
    partnership = result.scalar_one_or_none()
    if partnership is None:
        return None
    return str(partnership.id)


async def _broadcast(room_id: str, sender_id: str, message: dict):
    """Send a message to all other participants in the room."""
    msg_json = json.dumps(message)
    for uid, ws in list(_rooms[room_id].items()):
        if uid == sender_id:
            continue
        try:
            await ws.send_text(msg_json)
        except Exception:
            pass


@router.websocket("/ws/live-session")
async def live_session_ws(
    websocket: WebSocket,
    token: str = Query(...),
):
    from app.database import async_session

    async with async_session() as db:
        user = await _get_user_from_token(token, db)
        if user is None:
            await websocket.close(code=4001, reason="Unauthorized")
            return

        room_id = await _get_pair_room(user.id, db)
        if room_id is None:
            await websocket.close(code=4002, reason="No active partnership")
            return

    user_id = str(user.id)
    await websocket.accept()
    _rooms[room_id][user_id] = websocket
    logger.info("live_session_join", room=room_id, user=user_id)

    await _broadcast(room_id, user_id, {
        "type": "partner_joined",
        "user_id": user_id,
        "partner_count": len(_rooms[room_id]),
    })

    await websocket.send_text(json.dumps({
        "type": "room_state",
        "room_id": room_id,
        "partner_count": len(_rooms[room_id]),
        "breathing": _breathing.get(room_id, {}),
    }))

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = data.get("type")

            if msg_type == "breathing":
                phase = data.get("phase", "idle")
                _breathing[room_id][user_id] = {
                    "phase": phase,
                    "ts": time.time(),
                }
                await _broadcast(room_id, user_id, {
                    "type": "partner_breathing",
                    "user_id": user_id,
                    "phase": phase,
                    "ts": time.time(),
                })

            elif msg_type == "session_start":
                await _broadcast(room_id, user_id, {
                    "type": "partner_session_start",
                    "user_id": user_id,
                    "ts": time.time(),
                })

            elif msg_type == "session_end":
                await _broadcast(room_id, user_id, {
                    "type": "partner_session_end",
                    "user_id": user_id,
                    "ts": time.time(),
                })

            elif msg_type == "emoji":
                await _broadcast(room_id, user_id, {
                    "type": "partner_emoji",
                    "user_id": user_id,
                    "emoji": data.get("emoji", ""),
                })

            elif msg_type == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))

    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.warning("live_session_error", room=room_id, user=user_id, error=str(exc))
    finally:
        _rooms[room_id].pop(user_id, None)
        _breathing.get(room_id, {}).pop(user_id, None)
        if not _rooms[room_id]:
            _rooms.pop(room_id, None)
            _breathing.pop(room_id, None)
        else:
            await _broadcast(room_id, user_id, {
                "type": "partner_left",
                "user_id": user_id,
                "partner_count": len(_rooms[room_id]),
            })
        logger.info("live_session_leave", room=room_id, user=user_id)
