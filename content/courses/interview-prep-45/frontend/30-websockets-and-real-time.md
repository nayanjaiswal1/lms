---
kind: lesson
id_key: interview-prep-45/day-16-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "WebSockets and Real-time"
position: 30
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Real-time features, chat, live dashboards, collaborative editors, notifications, are a staple "build a feature" prompt, and the follow-up questions almost always probe whether you understand why WebSockets exist versus polling, and what happens the moment the connection drops. This lesson covers the transport options, a production-shaped React WebSocket hook with reconnection, and the scaling questions that come after the live-coding part is done.

## Four transports, one decision

| | How it works | Direction | Use when |
|---|---|---|---|
| Short polling | Client requests every N seconds | Client → Server only | Simple, infrequent updates, no real real-time need |
| Long polling | Server holds the connection open until there's data or a timeout, client re-requests immediately | Client → Server only | Near-real-time without WebSocket infra |
| SSE | One long-lived HTTP connection, server streams `text/event-stream` | Server → Client only | Live feeds, notifications, anything one-directional |
| WebSocket | HTTP upgrade to a persistent full-duplex TCP connection | Bidirectional | Chat, collaborative editing, anything needing client-to-server push too |

Why not just use WebSockets for everything? SSE is genuinely simpler to operate: it's plain HTTP, so it passes through existing proxies, load balancers, and CDNs with no special configuration, `EventSource` reconnects automatically, and it's text-based, so it's easy to debug on the wire. If the client never needs to push data mid-stream, a dashboard, a notification feed, SSE gets the same result with less infrastructure. Reach for WebSockets specifically when the client also needs to send, or the message rate is high enough that per-message latency actually matters.

## A React WebSocket hook that survives a real network

The naive version, opening a `WebSocket` inside `useEffect` and nothing else, breaks the moment the network blips. A real implementation needs reconnection, cleanup, and a way to expose connection state to the UI.

```tsx
type ConnectionState = "connecting" | "open" | "closed" | "error";

function useWebSocket(url: string, { onMessage, maxReconnectDelayMs = 30_000 }: { onMessage: (data: unknown) => void; maxReconnectDelayMs?: number }) {
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

    ws.onopen = () => { setState("open"); attemptRef.current = 0; }; // reset backoff on a clean connect
    ws.onmessage = (event) => onMessageRef.current(JSON.parse(event.data));
    ws.onerror = () => setState("error");
    ws.onclose = (event) => {
      setState("closed");
      if (event.code === 1000) return; // normal closure — don't reconnect
      const delay = Math.min(1000 * 2 ** attemptRef.current, maxReconnectDelayMs);
      attemptRef.current += 1;
      reconnectTimer.current = setTimeout(connect, delay);
    };
  }, [url, maxReconnectDelayMs]);

  useEffect(() => {
    connect();
    return () => { clearTimeout(reconnectTimer.current); wsRef.current?.close(1000, "component unmounted"); };
  }, [connect]);

  const send = useCallback((data: unknown) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) wsRef.current.send(JSON.stringify(data));
  }, []);

  return { state, send };
}
```

```tsx
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
      <ul>{messages.map((m) => <li key={m.id}><strong>{m.author}:</strong> {m.text}</li>)}</ul>
      <form onSubmit={submit}>
        <input value={draft} onChange={(e) => setDraft(e.target.value)} disabled={state !== "open"} />
        <button type="submit" disabled={state !== "open"}>Send</button>
      </form>
    </div>
  );
}
```

Four details worth being able to point at directly, since interviewers will. `onMessageRef` avoids a stale closure without forcing `connect` to be recreated, and the socket torn down and rebuilt, every time the parent re-renders with a fresh inline `onMessage`. Exponential backoff with a cap, `1000 * 2^attempt`, prevents a reconnect storm from hammering the server the moment it comes back up, and it's the single most common thing missing from a candidate's first attempt at this. Close code `1000` is a normal closure; anything else, a server restart, a dropped network, should trigger a reconnect, not distinguishing these means either reconnecting forever after an intentional `ws.close()`, or silently failing to recover from a real drop. And the cleanup inside `useEffect`'s return closes with code `1000` on unmount, so the server treats a closed tab as a clean disconnect rather than something needing recovery logic.

## Detecting a connection that's dead but doesn't know it yet

A TCP connection can go silently dead, a laptop sleeps, a NAT entry expires, without either side ever receiving a close event. A heartbeat catches this:

```tsx
useEffect(() => {
  if (state !== "open") return;
  const interval = setInterval(() => send({ type: "ping" }), 15_000);
  return () => clearInterval(interval);
}, [state, send]);
```

The server replies with `pong`; if none arrives within a timeout, the client treats the connection as dead and reconnects proactively rather than waiting for the OS-level timeout, which can take minutes.

## Not losing messages across a reconnect

Fire-and-forget delivery loses messages the instant a drop happens mid-send. Chat and collaboration generally want at-least-once delivery with client-side dedup instead:

```tsx
interface OutgoingMessage { clientId: string; text: string; } // client-generated UUID, an idempotency key
// Server echoes { type: "ack", clientId } once persisted.
// Client keeps a pending map and retransmits unacked messages after reconnect.
```

The client tags every outgoing message with a UUID, keeps it in a pending map until the server acks it, and resends anything still pending after a reconnect. The server dedupes on `clientId`, so a resend after a flaky ack never creates a duplicate message.

## Scaling past one server

A single WebSocket server holds an open TCP connection per client, which means it can't scale the way a stateless HTTP server does, round-robin behind a load balancer with no shared state. A message for user B has to reach whichever server instance is actually holding user B's socket.

**Sticky sessions** at the load balancer keep a client on the same server for the life of the connection, but that only solves connection stability, not cross-server messaging. **Pub/sub fan-out**, Redis Pub/Sub, NATS, Kafka, is the standard fix: every server instance subscribes to a shared channel, and when server A needs to notify a user connected to server C, it publishes to the channel and server C delivers it over its own local socket. **Connection limits per instance** matter too, each OS process has a file-descriptor ceiling per open socket, so horizontal scaling is usually required well before CPU becomes the actual bottleneck.

If server A needs to tell a user connected to server B that they have a new message, how? Server A doesn't hold that socket, so it can't write to it directly. It publishes the event to the shared pub/sub layer; every instance subscribes and checks whether the target user's socket is local; the instance that actually owns the connection delivers it. That decoupling, which server received the event versus which server holds the socket, is the entire mechanism.
