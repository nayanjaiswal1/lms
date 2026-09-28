---
kind: lesson
id_key: interview-prep-45/day-16-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "WebSockets and Real-time"
position: 29
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Chat, live dashboards, collaborative editors, notifications: real-time features are a staple "build this" interview prompt. The follow-up questions almost always probe whether you understand why WebSockets exist instead of just polling, and what happens the moment the connection drops.

## Four transports, one decision

| | How it works | Direction | Use when |
|---|---|---|---|
| Short polling | Client asks again every N seconds | Client to server only | Simple, infrequent updates, no real real-time need |
| Long polling | Server holds the request open until there's data or a timeout | Client to server only | Near-real-time without WebSocket infrastructure |
| SSE | One long-lived HTTP connection, server streams updates | Server to client only | Live feeds, notifications, anything one-directional |
| WebSocket | An HTTP upgrade to a persistent, two-way connection | Both directions | Chat, collaborative editing, anything needing the client to push too |

Why not just use WebSockets for everything? SSE is genuinely simpler to run: it's plain HTTP, so it passes through existing proxies and load balancers with no special setup, `EventSource` reconnects on its own, and it's plain text, easy to read on the wire. If the client never needs to push data mid-stream, a live feed, a notification list, SSE gets the same result with less machinery. Reach for a WebSocket specifically when the client also needs to send, or when the message rate is high enough that per-message delay actually matters.

> **Remember:** if data only ever flows one way, from server to client, SSE is simpler than a WebSocket and does the same job.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-realtime-transport-q1", "type": "mcq",
      "prompt": "A dashboard only needs to receive live updates from the server; it never sends anything back mid-stream. Which transport fits best, and why not a WebSocket?",
      "options": [
        {"id":"a","text":"A WebSocket, since it's always the most modern choice"},
        {"id":"b","text":"SSE — it's plain HTTP, reconnects automatically, and passes through existing infrastructure with no special setup, all without paying for two-way capability the app doesn't need"},
        {"id":"c","text":"Short polling, since it's the simplest to implement"},
        {"id":"d","text":"Long polling, since it uses the least bandwidth"}
      ],
      "correct": "b",
      "explanation": "SSE gets the same one-directional result as a WebSocket with less operational overhead, since it's plain HTTP with automatic reconnection built in. A WebSocket earns its extra complexity only when the client genuinely needs to push data too." }
] }
```

## A WebSocket hook that survives a real network

The naive version, opening a `WebSocket` inside `useEffect` and nothing else, breaks the instant the network blips even once. A real implementation needs reconnection, cleanup, and a way to show connection state in the UI.

```tsx
type ConnectionState = "connecting" | "open" | "closed" | "error";

function useWebSocket(url: string, { onMessage, maxReconnectDelayMs = 30_000 }: { onMessage: (data: unknown) => void; maxReconnectDelayMs?: number }) {
  const [state, setState] = useState<ConnectionState>("connecting");
  const wsRef = useRef<WebSocket | null>(null);
  const attemptRef = useRef(0);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout>>();
  const onMessageRef = useRef(onMessage);
  onMessageRef.current = onMessage; // always calls the latest callback, without re-running the effect

  const connect = useCallback(() => {
    const ws = new WebSocket(url);
    wsRef.current = ws;
    setState("connecting");

    ws.onopen = () => { setState("open"); attemptRef.current = 0; }; // a clean connect resets the backoff
    ws.onmessage = (event) => onMessageRef.current(JSON.parse(event.data));
    ws.onerror = () => setState("error");
    ws.onclose = (event) => {
      setState("closed");
      if (event.code === 1000) return; // a normal, intentional close — don't reconnect
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

Four details worth being able to point at directly. `onMessageRef` avoids a stale closure without forcing `connect` to be rebuilt, and the socket torn down, every time the parent re-renders with a fresh inline `onMessage`. Exponential backoff with a cap (`1000 * 2^attempt`) stops a reconnect storm from hammering the server right as it comes back up, and it's the single thing most often missing from a first attempt at this. Close code `1000` means a normal, intended closure; anything else, a server restart, a dropped network, should trigger a reconnect. Miss that distinction and you either reconnect forever after your own intentional `close()`, or silently fail to recover from a real drop. And the cleanup inside `useEffect`'s return closes with code `1000` on unmount, so the server treats a closed tab as a clean goodbye, not something needing recovery logic.

> **Remember:** close code `1000` means "on purpose, don't reconnect." Every other code means "something went wrong, try again."

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-realtime-reconnect-q1", "type": "mcq",
      "prompt": "Why does the WebSocket reconnection logic check event.code === 1000 before deciding whether to reconnect?",
      "options": [
        {"id":"a","text":"Code 1000 is a random number with no meaning"},
        {"id":"b","text":"1000 means the connection closed normally and on purpose; any other code means something unexpected happened, so only those should trigger a reconnect attempt"},
        {"id":"c","text":"1000 means the server is overloaded"},
        {"id":"d","text":"It has no functional purpose, it's just for logging"}
      ],
      "correct": "b",
      "explanation": "Without this check, either an intentional close triggers an unwanted reconnect loop, or a real network drop looks the same as a clean close and never gets recovered. The close code is what tells the two apart." }
] }
```

## Detecting a connection that's dead but doesn't know it yet

A TCP connection can go silently dead, a laptop sleeps, a NAT entry expires, without either side ever getting a close event. A heartbeat catches this:

```tsx
useEffect(() => {
  if (state !== "open") return;
  const interval = setInterval(() => send({ type: "ping" }), 15_000);
  return () => clearInterval(interval);
}, [state, send]);
```

The server replies with `pong`; if none arrives within a timeout, the client treats the connection as dead and reconnects on its own, instead of waiting for an OS-level timeout that can take minutes.

> **Remember:** a heartbeat exists because "the connection didn't send a close event" isn't the same thing as "the connection is still alive."

## Not losing messages across a reconnect

Fire-and-forget delivery loses a message the instant a drop happens mid-send. Chat and collaboration generally need at-least-once delivery with client-side dedup instead.

```tsx
interface OutgoingMessage { clientId: string; text: string; } // a client-generated UUID, used as an idempotency key
// Server echoes { type: "ack", clientId } once the message is saved.
// Client keeps a pending map and resends anything still unacked after reconnecting.
```

The client tags every outgoing message with a UUID, keeps it in a pending map until the server acknowledges it, and resends anything still pending after reconnecting. The server dedupes on `clientId`, so a resend after a flaky ack never creates a duplicate message.

## Scaling past one server

A single WebSocket server keeps an open connection per client, which is different from a stateless HTTP server that any instance behind a load balancer can answer. A message meant for user B has to reach whichever exact server instance is holding user B's socket.

**Sticky sessions** at the load balancer keep one client pinned to the same server for the life of a connection, but that only solves connection stability, not sending a message across servers. **Pub/sub fan-out**, Redis Pub/Sub, NATS, Kafka, is the standard fix: every server instance subscribes to one shared channel, and when server A needs to reach a user connected to server C, it publishes to that channel and server C delivers it over its own local socket. **Connection limits per instance** matter too: each server process has a file-descriptor ceiling on open sockets, so horizontal scaling is usually needed well before CPU ever becomes the real bottleneck.

If server A needs to tell a user connected to server B that they have a new message, how does it do it? Server A doesn't hold that socket, so it can't write to it directly. It publishes the event to the shared pub/sub layer; every server instance is subscribed and checks whether the target user is connected locally; whichever one actually owns the connection delivers it. That split, which server received the event versus which server holds the socket, is the whole mechanism.

> **Remember:** a WebSocket server can't scale by round-robin alone, because a message has to reach the one specific server holding that user's socket. Pub/sub is what bridges that gap.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-realtime-scaling-q1", "type": "mcq",
      "prompt": "Server A needs to deliver a message to a user whose WebSocket connection is held by server B. A and B are both behind the same load balancer with no shared state. How does server A actually reach that user?",
      "options": [
        {"id":"a","text":"It can't — messages can only be delivered by the server that receives the original event"},
        {"id":"b","text":"Server A publishes the event to a shared pub/sub channel; every server instance subscribes, and server B, which actually holds the socket, delivers it locally"},
        {"id":"c","text":"The load balancer automatically forwards the message to server B"},
        {"id":"d","text":"Server A opens a second WebSocket directly to server B"}
      ],
      "correct": "b",
      "explanation": "Server A never touches the socket directly, since it doesn't hold it. Pub/sub fan-out (Redis, NATS, Kafka) is the standard way to let any server instance publish an event that the socket-holding instance can act on." }
] }
```
