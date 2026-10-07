"""Password hashing. bcrypt is deliberately slow (about a quarter of a second at the production cost)."""

import bcrypt
from starlette.concurrency import run_in_threadpool


def hash_password_sync(password: str, rounds: int) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds)).decode()


def verify_password_sync(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


async def verify_password(password: str, hashed: str) -> bool:
    # mf:slot customers.security.verify
    return await run_in_threadpool(verify_password_sync, password, hashed)
    # mf:endslot
