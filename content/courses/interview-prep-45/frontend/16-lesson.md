---
kind: lesson
id_key: interview-prep-45/day-16-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "WebSockets and Real-time"
position: 19
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Real-time features — chat, live dashboards, collaborative editors, notifications — are a staple "build a feature" interview prompt, and the follow-up questions almost always probe whether you understand *why* WebSockets exist versus polling, and what happens when the connection drops. Today covers the transport options, a production-shaped React WebSocket hook with reconnection, and the scaling questions that come after the live-coding portion.

## WebSocket vs HTTP long-polling vs SSE

| | How it works | Direction | Overhead | Use when |
|---|---|---|---|---|
| **Short polling** | Client requests every N seconds | Client → Server only | High — most requests return nothing new | Simple, infrequent updates, no real-time requirement |
| **Long polling** | Client requests, server holds the connection open until there's data or a timeout, client immediately re-requests | Client → Server only | Medium — fewer wasted round trips, but a new TCP/TLS handshake per cycle | Need near-real-time without WebSocket infra (proxies/firewalls that block upgrades) |
| **SSE (Server-Sent Events)** | Single long-lived HTTP connection, server streams `text/event-stream` | Server → Client only | Low — one connection, built-in auto-reconnect | Live feeds, notifications, stock tickers — anything one-directional |
| **WebSocket** | HTTP upgrade to a persistent full-duplex TCP connection | Bidirectional | Lowest per-message overhead — no HTTP headers per message after the handshake | Chat, collaborative editing, multiplayer — anything needing client → server pushes too |

**Interview question: "Why not just use WebSockets for everything?"**
SSE is simpler to operate — it's plain HTTP, so it works through existing proxies/load balancers/CDNs without special configuration, has automatic reconnection built into `EventSource`, and text-based, so it's easy to debug. If the client never needs to push data mid-stream (a dashboard, a notification feed), SSE is less infrastructure for the same result. Reach for WebSockets when the client also needs to send, or you need lower per-message latency at high message rates.

## A React WebSocket component

The naive approach — opening a `WebSocket` in `useEffect` — breaks the moment the network blips. A real implementation needs reconnection, cleanup, and a way to expose connection state to the UI.

```tsx
import { useCallback, useEffect, useRef, useState } from "react";

type ConnectionState = "connecting" | "open" | "closed" | "error";

interface UseWebSocketOptions {
  onMessage: (data: unknown) => void;
  maxReconnectDelayMs?: number;
}

function useWebSocket(url: string, { onMessage, maxReconnectDelayMs = 30_000 }: UseWebSocketOptions) {
  const [state, setState] = useState<ConnectionState>("connecting");
  const wsRef = useRef<WebSocket | null>(null);
  const attemptRef = useRef(0);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout>>();
  const onMessageRef = useRef(onMessage);
  onMessageRef.current = onMessage; // always call the latest callback without re-running the effect

  const connect = useCallback(() => {
    const ws = new WebSocket(url);
    wsRef.current = ws;
    setState("connecting");

    ws.onopen = () => {
      setState("open");
      attemptRef.current = 0; // reset backoff on a clean connect
    };

    ws.onmessage = (event) => {
      onMessageRef.current(JSON.parse(event.data));
    };

    ws.onerror = () => setState("error");

    ws.onclose = (event) => {
      setState("closed");
      if (event.code === 1000) return; // 1000 = normal closure, don't reconnect
      const delay = Math.min(1000 * 2 ** attemptRef.current, maxReconnectDelayMs);
      attemptRef.current += 1;
      reconnectTimer.current = setTimeout(connect, delay);
    };
  }, [url, maxReconnectDelayMs]);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectTimer.current);
      wsRef.current?.close(1000, "component unmounted");
    };
  }, [connect]);

  const send = useCallback((data: unknown) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data));
    }
  }, []);

  return { state, send };
}

interface ChatMessage {
  id: string;
  author: string;
  text: string;
}

function ChatRoom({ roomId }: { roomId: string }) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");

  const { state, send } = useWebSocket(`wss://api.example.com/rooms/${roomId}`, {
    onMessage: (data) => setMessages((prev) => [...prev, data as ChatMessage]),
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!draft.trim()) return;
    send({ type: "message", text: draft });
    setDraft("");
  };

  return (
    <div>
      <p>Status: {state}</p>
      <ul>
        {messages.map((m) => (
          <li key={m.id}>
            <strong>{m.author}:</strong> {m.text}
          </li>
        ))}
      </ul>
      <form onSubmit={submit}>
        <input value={draft} onChange={(e) => setDraft(e.target.value)} disabled={state !== "open"} />
        <button type="submit" disabled={state !== "open"}>Send</button>
      </form>
    </div>
  );
}
```

Key details an interviewer will probe:

- **`onMessageRef`** avoids stale closures without forcing `connect` to be recreated (and the socket to be torn down and rebuilt) every time the parent re-renders with a new inline `onMessage`.
- **Exponential backoff with a cap** (`1000 * 2^attempt`, capped at `maxReconnectDelayMs`) prevents a reconnect storm from hammering the server when it's down — this is the single most common thing missing from candidate implementations.
- **Close code 1000** is normal closure; anything else (abnormal closure, server restart, network drop) should trigger a reconnect. Not distinguishing these means you reconnect forever even after an intentional `ws.close()`, or you silently fail to recover from an actual drop.
- **Cleanup in the `useEffect` return** closes the socket with code 1000 on unmount so the server doesn't treat the tab closing as an abnormal disconnect requiring cleanup logic.

## Heartbeat / ping-pong

TCP connections can go silently dead (a laptop sleeps, a NAT entry expires) without either side getting a close event. A heartbeat detects this:

```tsx
useEffect(() => {
  if (state !== "open") return;
  const interval = setInterval(() => send({ type: "ping" }), 15_000);
  return () => clearInterval(interval);
}, [state, send]);
```

The server replies with `pong`; if no pong arrives within a timeout, the client treats the connection as dead and reconnects proactively instead of waiting for the OS-level timeout, which can take minutes.

## Message acknowledgment

At-most-once delivery (fire and forget) loses messages on a drop mid-send. For chat/collaboration you typically want at-least-once with client-side dedup:

```tsx
interface OutgoingMessage {
  clientId: string; // client-generated UUID, idempotency key
  text: string;
}

// Server echoes back { type: "ack", clientId } once persisted.
// Client keeps a pending map and retransmits unacked messages after reconnect.
```

The client tags every outgoing message with a UUID, keeps it in a "pending" map until the server acks it, and resends anything still pending after a reconnect. The server dedupes on `clientId` so a resend after a flaky ack doesn't create a duplicate message.

## Scaling WebSocket servers

A single WebSocket server holds an open TCP connection per client, so it can't be scaled the way stateless HTTP servers are (round-robin behind a load balancer with no shared state) — a message for user B has to reach whichever server instance holds user B's socket.

- **Sticky sessions** at the load balancer route a client to the same server for the life of the connection, but that only solves connection stability, not cross-server messaging.
- **Pub/sub fan-out** (Redis Pub/Sub, NATS, Kafka) — each server instance subscribes to a shared channel; when server A needs to notify user B connected to server C, it publishes to the channel and server C delivers it over its local socket. This is the standard pattern.
- **Connection limits per instance** — each OS process has a file-descriptor ceiling per open socket, so horizontal scaling (more instances) is required well before CPU becomes the bottleneck.

**Interview question: "Server A needs to tell a user connected to Server B that they have a new message. How?"**
Server A doesn't hold that socket, so it can't write to it directly. It publishes the event to a shared pub/sub layer (Redis Pub/Sub is the usual answer); every server instance subscribes and checks whether the target user's socket is local; the instance that owns the connection (Server B) delivers it. This decouples "which server received the event" from "which server holds the socket."

## Key takeaways

- SSE is the right default for one-directional streams (simpler infra, auto-reconnect); WebSocket is for bidirectional, low-latency needs.
- A production WebSocket hook needs exponential backoff reconnection, a ref for the latest callback to avoid stale closures, and to distinguish close code 1000 from abnormal closures.
- Heartbeats (ping/pong) detect half-dead TCP connections that never fire a close event.
- At-least-once delivery needs client-generated idempotency keys and server-side dedup, not "just send it."
- WebSocket servers are stateful — scaling requires sticky sessions plus a pub/sub layer (Redis, NATS) so any instance can reach a socket held by another instance.
