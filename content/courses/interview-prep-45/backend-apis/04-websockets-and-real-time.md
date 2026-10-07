---
kind: lesson
id_key: interview-prep-45/day-25-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "WebSockets and Real-Time Systems"
position: 4
estimated_minutes: 50
source:
    - 45-day-interview-roadmap.md
---

Chat, live notifications, collaborative editing, and trading dashboards all rest on one idea: a connection that stays open so either side can push a message whenever it wants. This lesson covers the WebSocket protocol itself, building an endpoint in FastAPI, managing connections at scale, what interviewers actually care about, which is what happens when a connection breaks, and how you scale real-time delivery past a single process.

## The WebSocket protocol

HTTP is request-response: the client asks, the server answers, and the connection mostly closes. A WebSocket is a persistent, full-duplex connection where either side can push a message at any time, without the other side asking first. It starts life as a normal HTTP request and gets **upgraded**:

```
GET /ws/chat HTTP/1.1
Host: mindforge.test
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

The server answers `101 Switching Protocols`, and from then on both sides speak the WebSocket framing protocol over that same TCP socket. There are no more HTTP headers per message, just lightweight frames, data frames plus control frames for ping, pong, and close. That's the whole reason a WebSocket is cheaper than polling: one handshake, one TCP connection, no repeated HTTP overhead on every single message.

WebSocket is not "HTTP but faster." It's a different protocol layered on top of the same initial handshake. It also isn't the only option:

| Approach | Direction | Overhead | Use when |
|---|---|---|---|
| Polling | Client pulls | High (repeated HTTP requests) | Simple, infrequent updates |
| Long polling | Client pulls, server holds the request open | Medium | No WebSocket support, near-real-time is good enough |
| Server-Sent Events (SSE) | Server pushes to the client only | Low | One-way streams, like a feed or notifications |
| WebSocket | Full duplex | Low, after the handshake | Chat, gaming, collaborative editing |

> **Remember:** a WebSocket starts as an HTTP request and upgrades once; everything after that is lightweight frames on the same TCP socket, not repeated HTTP requests.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-websockets-protocol-q1", "type": "mcq",
      "prompt": "A feature only needs the server to push updates to the client, and the client never needs to send anything back. Which approach fits best?",
      "options": [
        {"id":"a","text":"A full WebSocket connection, since it's always the right choice for real-time updates"},
        {"id":"b","text":"Server-Sent Events, since the traffic is one-way and SSE is simpler for exactly that case"},
        {"id":"c","text":"Plain polling, since it's the only option that works over HTTP"},
        {"id":"d","text":"Long polling, since it uses less overhead than SSE"}
      ],
      "correct": "b",
      "explanation": "SSE is built for server-to-client-only streams and is simpler to run than a full duplex WebSocket when the client never needs to send anything back." }
] }
```

## A FastAPI WebSocket endpoint

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

`await websocket.accept()` completes the upgrade from HTTP to WebSocket. The `while True` loop is the connection's whole lifetime: it runs until the client disconnects, and a disconnect raises `WebSocketDisconnect` rather than the loop just returning normally.

**Common mistake:** forgetting the `try`/`except` around the loop. Every single disconnect then raises an unhandled exception, quietly spamming your logs and error tracker on completely normal client behavior.

> **Remember:** a disconnect is a raised `WebSocketDisconnect`, not a quiet return. Always wrap the receive loop so a normal disconnect doesn't look like a crash.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-websockets-endpoint-q1", "type": "mcq",
      "prompt": "What happens if the try/except WebSocketDisconnect block is removed from a FastAPI WebSocket handler?",
      "options": [
        {"id":"a","text":"Disconnects stop working entirely"},
        {"id":"b","text":"Every normal client disconnect raises an unhandled exception, filling logs and error trackers with noise from completely ordinary behavior"},
        {"id":"c","text":"The server crashes on the first connection"},
        {"id":"d","text":"Nothing changes; the exception is handled automatically regardless"}
      ],
      "correct": "b",
      "explanation": "A disconnect raises WebSocketDisconnect inside the loop. Without a handler for it, that exception propagates as an unhandled error on every single disconnect, even though disconnecting is normal, expected client behavior." }
] }
```

## Managing many connections

A single endpoint handling one socket isn't a system. You need a registry so you can broadcast, target a specific user, and clean up after a disconnect.

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

Notice `disconnect` always runs inside the `except` block. Cleanup on disconnect isn't optional: skip it, and dead socket references pile up quietly, each one erroring out the moment you try to send to it again, which is a slow memory leak in disguise.

> **Remember:** always clean up a user's socket reference in the disconnect path. A registry that never forgets dead sockets is a leak waiting to be noticed in production.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-websockets-manager-q1", "type": "mcq",
      "prompt": "Why does ConnectionManager.disconnect() always run inside the except WebSocketDisconnect block, never skipped?",
      "options": [
        {"id":"a","text":"It's just a stylistic convention with no functional effect"},
        {"id":"b","text":"Without it, dead socket references stay in the registry forever, causing a slow memory leak and errors the next time the server tries to send to them"},
        {"id":"c","text":"FastAPI requires cleanup code to be inside an except block"},
        {"id":"d","text":"It prevents the broadcast function from running at all"}
      ],
      "correct": "b",
      "explanation": "A disconnected socket that isn't removed from the registry lingers indefinitely, growing memory usage and causing send errors on every future broadcast attempt to that dead reference." }
] }
```

## Handling failure: heartbeats, reconnects, and backpressure

Networks drop. Mobile clients switch from Wi-Fi to cellular mid-conversation. An interviewer wants to hear you plan for this, not assume a happy path.

- **Ping/pong heartbeats.** WebSocket has built-in ping/pong control frames. Without them, a half-dead TCP connection, the client vanished with no proper close, can sit in your server's connection pool for a long time before the OS notices. Send a ping periodically; if no pong comes back within a timeout, treat the connection as dead and clean it up.

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

- **Client-side reconnect with exponential backoff.** The client should treat a disconnect as normal, not exceptional, and reconnect automatically, backing off (1s, 2s, 4s, 8s, capped) so it doesn't hammer a server that's already struggling.
- **No delivery guarantee by default.** A WebSocket gives you no "at least once" promise on its own. If the socket drops mid-send, that message is simply gone. For anything that must not be lost, chat history, order events, persist the message server-side *before* pushing it, and let the client ask for "everything since sequence N" on reconnect so it can catch up.
- **Backpressure.** A slow client on a bad connection can't drain messages as fast as the server produces them. Calling `send_text` without limits lets those messages pile up in memory. Use a bounded queue per connection, and drop or disconnect a client that falls too far behind rather than let server memory grow without limit.

> **Remember:** a WebSocket guarantees delivery to no one by default. Persist anything that can't be lost before you push it, so a client can catch up after reconnecting.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-websockets-failure-q1", "type": "mcq",
      "prompt": "A chat app pushes messages over a WebSocket and doesn't persist them anywhere else. What happens to a message if the socket drops right as it's being sent?",
      "options": [
        {"id":"a","text":"WebSocket automatically retries the send until it succeeds"},
        {"id":"b","text":"The message is simply lost; WebSocket provides no delivery guarantee on its own, so anything that must not be lost needs to be persisted server-side first"},
        {"id":"c","text":"The client automatically requests the missed message on reconnect with no extra work needed"},
        {"id":"d","text":"TCP guarantees the message eventually arrives regardless of the drop"}
      ],
      "correct": "b",
      "explanation": "WebSocket has no built-in at-least-once guarantee. A message that was mid-send when the socket dropped is gone unless the application persisted it before pushing and built its own catch-up mechanism." }
] }
```

## Scaling WebSockets past one process

This is the question that separates "I built a demo" from "I understand production systems."

The core problem: WebSocket connections are **stateful and sticky**. A client is connected to exactly one server process, unlike stateless HTTP, where any server in a pool can handle any request. A `ConnectionManager` like the one above only knows about sockets on *its own process*. If user A is connected to server 1 and user B to server 2, server 1's in-memory broadcast never reaches user B.

The fix is a shared **pub/sub backbone**, Redis Pub/Sub, or Kafka for higher durability, that every server instance subscribes to. When a server needs to deliver a message to a user who might be connected to a different instance, it publishes to the shared channel; every instance receives it and forwards it to any locally connected sockets for that user.

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

Two more pieces worth naming even if you don't code them in an interview: **connection count is the bottleneck, not CPU.** A single process can hold tens of thousands of idle WebSocket connections, since each one is cheap, a socket plus a small buffer, so scaling is about connection count and message fan-out volume, not raw compute. And **presence and session state belong in Redis**, not in-process memory, so any instance can answer "is user X online" and route accordingly. Sticky sessions at the load balancer still help a reconnect land back on a familiar instance, but the pub/sub layer above removes the hard requirement for it.

> **Remember:** a WebSocket connection is sticky to one process. A shared Redis Pub/Sub (or Kafka) channel is what lets any server instance deliver a message to a user connected to a different one.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-websockets-scaling-q1", "type": "mcq",
      "prompt": "User A is connected to server 1 and user B to server 2. A naive in-memory ConnectionManager can't let A message B directly. What's the standard fix?",
      "options": [
        {"id":"a","text":"Force every user to reconnect to the same server periodically"},
        {"id":"b","text":"A shared pub/sub channel (Redis or Kafka) that every server instance subscribes to, so any instance can publish a message that reaches whichever instance holds the recipient's live socket"},
        {"id":"c","text":"Increase the number of CPU cores on each server"},
        {"id":"d","text":"WebSocket connections cannot be scaled past one server by design"}
      ],
      "correct": "b",
      "explanation": "WebSocket connections are sticky to one process, so no single server sees every connected user. A shared pub/sub backbone lets any instance publish a message that every instance can forward to its own locally connected sockets." }
] }
```

## Putting it together: a minimal chat server

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

This single-process version is what you'd realistically write in a 45-minute interview. Say out loud that production needs the Redis pub/sub layer above it to fan out across multiple server instances. That one sentence shows you know exactly where the demo stops and the real system begins.

> **Remember:** a working single-process chat server plus one sentence about the Redis fan-out layer needed in production is the complete interview answer. You don't need to code the scaled version live.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-websockets-chatapp-q1", "type": "mcq",
      "prompt": "In the _broadcast function above, why does it collect failing sockets into a dead list instead of removing them from rooms[room_id] while iterating?",
      "options": [
        {"id":"a","text":"It's purely a style preference with no functional reason"},
        {"id":"b","text":"Removing items from a set while iterating over it can skip elements or raise an error; collecting them first and removing afterward avoids mutating the collection mid-iteration"},
        {"id":"c","text":"Python sets cannot contain WebSocket objects"},
        {"id":"d","text":"It makes the broadcast function run without using async/await"}
      ],
      "correct": "b",
      "explanation": "Mutating a set while iterating over it is unsafe in Python: it can skip elements or raise a runtime error. Collecting the sockets to remove and discarding them after the loop finishes avoids that entirely." }
] }
```
