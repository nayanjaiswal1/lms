import hashlib
import hmac
import json

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.orders.models import Order

router = APIRouter(prefix="/api/v1/webhooks", tags=["webhooks"])


def valid_signature(secret: str, body: bytes, header: str | None) -> bool:
    expected = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, header or "")


@router.post("/payments")
async def payment_event(
    request: Request,
    x_signature: str | None = Header(default=None),
    session: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    """Signed events from the payments provider. Only ``payment.refunded`` changes an order."""
    body = await request.body()
    if not valid_signature(request.app.state.settings.webhook_secret, body, x_signature):
        raise HTTPException(status_code=401, detail="invalid signature")
    try:
        event = json.loads(body)
        event_type, order_id = event["type"], int(event["order_id"])
    except (ValueError, KeyError, TypeError):
        raise HTTPException(status_code=400, detail="malformed event") from None
    if event_type == "payment.refunded":
        await session.execute(
            update(Order).where(Order.id == order_id, Order.status == "paid").values(status="refunded")
        )
        await session.commit()
    return {"status": "accepted"}
