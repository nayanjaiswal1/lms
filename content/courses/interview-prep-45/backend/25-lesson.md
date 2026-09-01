---
kind: lesson
id_key: interview-prep-45/day-25-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "WebSocket Systems"
position: 25
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Today is real-time communication: the WebSocket protocol, building a WebSocket endpoint in FastAPI, managing connections, and the part interviewers actually care about, which is what happens when it breaks and how you scale it past one process. Chat, live notifications, collaborative editing, and trading dashboards all rest on this.

## The WebSocket protocol

HTTP is request-response: client asks, server answers, connection (mostly) closes. WebSocket is a persistent, full-duplex connection where either side can push a message at any time without the other asking first. It starts as an HTTP request and gets **upgraded**:

```
GET /ws/chat HTTP/1.1
Host: example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

Server responds `101 Switching Protocols` and from then on both sides speak the WebSocket framing protocol over the same TCP socket. There are no more HTTP headers per message, just lightweight frames (data frames, plus control frames for ping/pong/close). This is why WebSocket is cheaper than polling: one TCP connection, one handshake, no repeated HTTP overhead per message.

**Interview point**: WebSocket is not "HTTP but faster." It's a different protocol layered on the same initial handshake. Also know the alternatives and when each fits:

| Approach | Direction | Overhead | Use when |
|---|---|---|---|
| Polling | Client pulls | High (repeated HTTP requests) | Simple, infrequent updates |
| Long polling | Client pulls, server holds | Medium | No WebSocket support, near-real-time |
| Server-Sent Events (SSE) | Server → client only | Low | One-way streams (feeds, notifications) |
| WebSocket | Full duplex | Low after handshake | Chat, gaming, collaborative editing |

## FastAPI WebSocket endpoint

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()


@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            await websocket.send_text(f"echo: {data}")
    except WebSocketDisconnect:
        print(f"{client_id} disconnected")
```

`await websocket.accept()` completes the HTTP-to-WebSocket upgrade. The `while True` loop is the connection's lifetime: it runs until the client disconnects, which raises `WebSocketDisconnect` rather than returning normally. This is a common gotcha: forgetting the try/except means an unhandled exception on every disconnect, spamming your logs and error tracker.

## Connection management

A single endpoint handling one socket isn't a system. You need a registry so you can broadcast, target a specific user, and clean up on disconnect.

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import Dict, Set

app = FastAPI()


class ConnectionManager:
    def __init__(self):
        # user_id -> set of active sockets (a user can have multiple tabs/devices)
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(user_id, set()).add(websocket)

    def disconnect(self, user_id: str, websocket: WebSocket):
        connections = self.active_connections.get(user_id)
        if connections:
            connections.discard(websocket)
            if not connections:
                del self.active_connections[user_id]

    async def send_personal(self, user_id: str, message: str):
        for ws in self.active_connections.get(user_id, ()):
            await ws.send_text(message)

    async def broadcast(self, message: str, exclude_user: str | None = None):
        for user_id, sockets in self.active_connections.items():
            if user_id == exclude_user:
                continue
            for ws in sockets:
                await ws.send_text(message)


manager = ConnectionManager()


@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(user_id, websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(f"{user_id}: {data}", exclude_user=user_id)
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
        await manager.broadcast(f"{user_id} left the chat")
```

Notice the `disconnect` always runs in the `except` block. Cleanup on disconnect is not optional; it's how you avoid a slow memory leak of dead socket references that never get sent to (and error) again.

## Handling WebSocket failures

Networks drop. Mobile clients switch from WiFi to cellular. Interviewers want to hear you plan for this, not assume a happy path.

- **Ping/pong heartbeats.** WebSocket has built-in ping/pong control frames. Without them, a half-dead TCP connection (client vanished, no FIN sent) can sit in your server's connection pool for a long time before the OS notices. Send a ping periodically; if no pong comes back within a timeout, treat the connection as dead and clean it up.

```python
import asyncio

async def heartbeat(websocket: WebSocket, interval: int = 30, timeout: int = 10):
    while True:
        await asyncio.sleep(interval)
        try:
            await asyncio.wait_for(websocket.send_text('{"type":"ping"}'), timeout=timeout)
        except (asyncio.TimeoutError, Exception):
            await websocket.close()
            break
```

- **Client-side reconnect with exponential backoff.** The client should assume disconnects are normal and reconnect automatically, backing off (1s, 2s, 4s, 8s... capped) to avoid hammering a struggling server.
- **Message delivery guarantees.** WebSocket itself gives you no "at least once" guarantee. If the socket drops mid-send, the message is gone. For anything that must not be lost (chat history, order events), persist the message server-side *before* pushing it, and give the client a way to request "messages since sequence N" on reconnect so it can catch up.
- **Backpressure.** A slow client (bad network) can't drain messages as fast as the server produces them. Unbounded `send_text` calls queue up in memory. Use a bounded queue per connection and drop or disconnect a client that falls too far behind rather than let server memory grow unbounded.

## Scaling WebSockets

This is the question that separates "I built a demo" from "I understand production systems."

The core problem: WebSocket connections are **stateful and sticky**. A client is connected to exactly one server process, unlike stateless HTTP where any server in a pool can handle any request. A naive `ConnectionManager` like the one above only knows about sockets on *its own process*. If user A is connected to server 1 and user B to server 2, server 1's in-memory broadcast never reaches user B.

Fix: a shared **pub/sub backbone** (Redis Pub/Sub, or Kafka for higher durability) that every server instance subscribes to. When a server needs to deliver a message to a user who might be connected to a different instance, it publishes to the shared channel; every instance receives it and forwards to any locally-connected sockets for that user.

```python
import redis.asyncio as redis
import json

class ScalableConnectionManager:
    def __init__(self, redis_url: str):
        self.local_connections: Dict[str, Set[WebSocket]] = {}
        self.redis = redis.from_url(redis_url)
        self.pubsub = self.redis.pubsub()

    async def start(self):
        await self.pubsub.subscribe("broadcast")
        asyncio.create_task(self._listen())

    async def _listen(self):
        async for message in self.pubsub.listen():
            if message["type"] != "message":
                continue
            payload = json.loads(message["data"])
            for ws in self.local_connections.get(payload["user_id"], ()):
                await ws.send_text(payload["text"])

    async def publish(self, user_id: str, text: str):
        # Any server instance can call this; only the instance holding
        # that user's live socket will actually deliver it.
        await self.redis.publish("broadcast", json.dumps({"user_id": user_id, "text": text}))
```

Other pieces of the scaling picture, worth naming even if you don't code them in an interview:

- **Sticky sessions at the load balancer** so a reconnect from the same client lands on the same instance where useful, though the pub/sub approach above removes the hard requirement for this.
- **Connection count is the bottleneck, not CPU.** A single process can hold tens of thousands of idle WebSocket connections (each is cheap: a socket plus a small buffer), so scaling is about connection count and message fan-out volume, not raw compute. Horizontal scaling adds more connection capacity.
- **Presence/session state goes in Redis**, not in-process, so any instance can answer "is user X online" and route accordingly.

## Building a real-time chat app

Putting it together: a minimal but complete chat server using the connection manager above, with room support.

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from collections import defaultdict
import json

app = FastAPI()
rooms: dict[str, set[WebSocket]] = defaultdict(set)


@app.websocket("/ws/{room_id}/{username}")
async def chat_endpoint(websocket: WebSocket, room_id: str, username: str):
    await websocket.accept()
    rooms[room_id].add(websocket)
    await _broadcast(room_id, {"type": "join", "user": username})

    try:
        while True:
            raw = await websocket.receive_text()
            await _broadcast(room_id, {"type": "message", "user": username, "text": raw})
    except WebSocketDisconnect:
        rooms[room_id].discard(websocket)
        await _broadcast(room_id, {"type": "leave", "user": username})


async def _broadcast(room_id: str, payload: dict):
    dead = []
    for ws in rooms[room_id]:
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:
            dead.append(ws)  # client vanished mid-send
    for ws in dead:
        rooms[room_id].discard(ws)
```

This single-process version is what you'd write in a 45-minute interview. Say out loud that production requires the Redis pub/sub layer above to fan out across multiple server instances. That's the detail that shows you know where the demo stops and the real system begins.
