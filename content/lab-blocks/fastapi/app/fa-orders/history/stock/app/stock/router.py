from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.customers.deps import staff_only
from app.db import get_session

router = APIRouter(prefix="/api/v1/staff/products", tags=["stock"], dependencies=[Depends(staff_only)])


class StockChange(BaseModel):
    delta: int = Field(ge=-100_000, le=100_000)


class StockOut(BaseModel):
    product_id: int
    stock: int


@router.post("/{product_id:int}/stock", response_model=StockOut)
async def adjust_stock(
    product_id: int, change: StockChange, session: AsyncSession = Depends(get_session)
) -> StockOut:
    """Add (or remove, with a negative delta) units; the stock never goes below zero."""
    result = await session.execute(
        update(Product)
        .where(Product.id == product_id, Product.stock + change.delta >= 0)
        .values(stock=Product.stock + change.delta)
        .returning(Product.stock)
    )
    stock = result.scalar_one_or_none()
    if stock is None:
        await session.rollback()
        raise HTTPException(status_code=409, detail="unknown product or not enough stock")
    await session.commit()
    return StockOut(product_id=product_id, stock=stock)
