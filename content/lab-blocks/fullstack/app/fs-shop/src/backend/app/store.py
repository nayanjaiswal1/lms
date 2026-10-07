"""In-memory data for the shop. Seeded at startup; restarting the API resets it."""

import hashlib
import hmac
import secrets
import threading
from datetime import datetime, timedelta, timezone

PASSWORD_ITERATIONS = 1000
PASSWORD_SALT = b"shop-demo-salt"
DEMO_PASSWORD = "correct-horse-battery"
FIRST_ORDER_AT = datetime(2025, 2, 1, 9, 0, tzinfo=timezone.utc)
ORDER_SPACING = timedelta(hours=31)
# The newest demo order was placed just after midnight UTC.
NEWEST_ORDER_AT = datetime(2025, 3, 6, 2, 30, tzinfo=timezone.utc)
STATUSES = ["paid", "shipped", "delivered", "pending"]

# id, sku, name, price in cents, units in stock
PRODUCTS = [
    (1, "KB-100", "Mechanical Keyboard", 8900, 12),
    (2, "MS-210", "Wireless Mouse", 3450, 40),
    (3, "RD-301", "R&D Kit", 15900, 6),
    (4, "CB-050", "USB-C Cable 2m", 1250, 100),
    (5, "HB-420", "4-Port USB Hub", 2790, 25),
    (6, "MN-270", "27 inch Monitor", 21900, 3),
    (7, "LP-150", "Laptop Stand", 4200, 18),
    (8, "WC-720", "HD Webcam", 5900, 9),
    (9, "HS-880", "Headset + Mic", 7600, 14),
    (10, "DK-900", "Desk Mat 90cm", 2400, 30),
    (11, "SD-512", "512GB SSD", 9900, 0),
    (12, "PW-650", "Power Strip 6-way", 1990, 55),
]
# id, email, name, phone, number of seeded orders
USERS = [
    (1, "alice@shop.test", "Alice Nguyen", "555-0100", 23),
    (2, "bob@shop.test", "Bob Okafor", "555-0101", 3),
]


def hash_password(password: str) -> str:
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), PASSWORD_SALT, PASSWORD_ITERATIONS)
    return digest.hex()


class Store:
    """Products, users, sessions and orders. Mutations take `lock`."""

    def __init__(self) -> None:
        self.lock = threading.RLock()
        self.products = {
            pid: {"id": pid, "sku": sku, "name": name, "price_cents": price, "stock": stock}
            for pid, sku, name, price, stock in PRODUCTS
        }
        self.users = {
            uid: {
                "id": uid,
                "email": email,
                "name": name,
                "phone": phone,
                "password_hash": hash_password(DEMO_PASSWORD),
                "version": 1,
            }
            for uid, email, name, phone, _ in USERS
        }
        self.sessions: dict[str, dict] = {}
        self.orders: list[dict] = []
        self._seed_orders()

    def _seed_orders(self) -> None:
        product_ids = sorted(self.products)
        for uid, _email, _name, _phone, count in USERS:
            for n in range(1, count + 1):
                line = product_ids[(uid * 3 + n) % len(product_ids)]
                newest = uid == 1 and n == count
                self.add_order(
                    uid,
                    [(line, 1 + n % 3)],
                    STATUSES[n % len(STATUSES)],
                    NEWEST_ORDER_AT if newest else FIRST_ORDER_AT + n * ORDER_SPACING,
                    adjust_stock=False,
                )

    def add_order(
        self,
        user_id: int,
        lines: list[tuple[int, int]],
        status: str,
        placed_at: datetime,
        adjust_stock: bool = True,
    ) -> dict:
        with self.lock:
            items = []
            for product_id, quantity in lines:
                product = self.products[product_id]
                if adjust_stock:
                    product["stock"] -= quantity
                items.append(
                    {
                        "product_id": product_id,
                        "name": product["name"],
                        "quantity": quantity,
                        "unit_cents": product["price_cents"],
                    }
                )
            order = {
                "id": len(self.orders) + 1,
                "user_id": user_id,
                "status": status,
                "placed_at": placed_at,
                "items": items,
                "total_cents": sum(i["quantity"] * i["unit_cents"] for i in items),
            }
            self.orders.append(order)
            return order

    def orders_for(self, user_id: int) -> list[dict]:
        """The user's orders, newest first."""
        mine = (o for o in self.orders if o["user_id"] == user_id)
        return sorted(mine, key=lambda o: o["id"], reverse=True)

    def authenticate(self, email: str, password: str) -> dict | None:
        user = next((u for u in self.users.values() if u["email"] == email.strip().lower()), None)
        candidate = hash_password(password)
        # Compare even for an unknown email so the timing does not reveal which emails exist.
        expected = user["password_hash"] if user else hash_password("")
        if hmac.compare_digest(candidate, expected) and user:
            return user
        return None

    def open_session(self, user_id: int) -> tuple[str, str]:
        token, csrf = secrets.token_urlsafe(24), secrets.token_urlsafe(16)
        with self.lock:
            self.sessions[token] = {"user_id": user_id, "csrf": csrf}
        return token, csrf

    def close_session(self, token: str) -> None:
        with self.lock:
            self.sessions.pop(token, None)
