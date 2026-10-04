---
kind: lesson
id_key: interview-prep-45/day-25-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Error Handling"
position: 34
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Every production frontend fails in the field eventually: a network drops, an API sends back broken JSON, a third-party script throws. Interviewers ask about error handling to see whether you design for that reality, or only for the happy path.

## Error boundaries, and their real limits

An error boundary catches JavaScript errors thrown while rendering, in lifecycle methods, and in constructors of the tree below it, and shows a fallback instead of crashing the whole app. As of React 19 it's still only possible as a **class component**, there's no hook version, because the underlying mechanism, `getDerivedStateFromError`/`componentDidCatch`, needs instance behavior only a class gives you.

```tsx
class ErrorBoundary extends Component<{ fallback: (error: Error, reset: () => void) => ReactNode; onError?: (error: Error, info: ErrorInfo) => void; children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };
  static getDerivedStateFromError(error: Error) { return { error }; } // runs during render
  componentDidCatch(error: Error, info: ErrorInfo) { this.props.onError?.(error, info); } // runs after render — the right place to log
  reset = () => this.setState({ error: null });
  render() {
    if (this.state.error) return this.props.fallback(this.state.error, this.reset);
    return this.props.children;
  }
}
```

```tsx
<ErrorBoundary
  fallback={(error, reset) => <div role="alert"><p>Something went wrong: {error.message}</p><button onClick={reset}>Try again</button></div>}
  onError={(error, info) => reportToSentry(error, info.componentStack)}
>
  <Dashboard />
</ErrorBoundary>
```

What error boundaries do **not** catch is the most common trap here, worth knowing cold. Errors inside event handlers, an `onClick` throwing, are ordinary JavaScript errors, catch those with `try`/`catch` right in the handler. Errors inside async code, a `setTimeout`, a promise, a `fetch` callback, since by the time the callback runs, React is no longer "inside" a render it can intercept. Errors during server-side rendering. And an error thrown inside the boundary's own `render`, a boundary can't catch its own failure, a second boundary nested above it is the only way to cover that.

There's no built-in fix for the async and event-handler gaps, catch those by hand, and if you want the nearest boundary to actually handle one, re-throw it during a state update so the *next render* is what actually throws:

```tsx
function DangerousButton() {
  const [, setError] = useState();
  return (
    <button onClick={() => {
      try { riskyOperation(); }
      catch (err) { setError(() => { throw err; }); } // re-throw during render so the nearest boundary catches it
    }}>Run</button>
  );
}
```

In production code, most teams reach for the `react-error-boundary` package instead of hand-writing the class above, same mechanism, better ergonomics: a `useErrorBoundary` hook for the manual-throw pattern, and a `resetKeys` prop that auto-resets when relevant props change.

```tsx
import { ErrorBoundary } from "react-error-boundary";
function App() {
  return (
    <ErrorBoundary FallbackComponent={ErrorFallback} onError={(error, info) => reportToSentry(error, info)} onReset={() => window.location.reload()}>
      <Dashboard />
    </ErrorBoundary>
  );
}
```

> **Remember:** an error boundary only catches errors thrown while rendering. It never catches an error from an event handler, a promise, or a timer.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-errors-boundary-q1", "type": "mcq",
      "prompt": "A button's onClick handler throws an error. Does the nearest error boundary catch it?",
      "options": [
        {"id":"a","text":"Yes, error boundaries catch every error anywhere in their subtree"},
        {"id":"b","text":"No — error boundaries only catch errors thrown during rendering, lifecycle methods, and constructors; an event handler error is an ordinary JS error caught with try/catch instead"},
        {"id":"c","text":"Only if the handler is declared with async"},
        {"id":"d","text":"Only in development mode"}
      ],
      "correct": "b",
      "explanation": "Event handlers run outside React's render cycle, so an error boundary has no way to intercept them. That gap has to be covered manually with try/catch inside the handler itself." }
] }
```

## What catches everything a boundary can't

Error boundaries only cover the React render tree. Two browser-level events catch what escapes it.

```ts
// Uncaught synchronous errors anywhere on the page, including entirely outside React
window.addEventListener("error", (event) => {
  reportToSentry(event.error ?? new Error(event.message), { filename: event.filename, lineno: event.lineno });
});

// Unhandled promise rejections — exactly the async gap error boundaries can't cover
window.addEventListener("unhandledrejection", (event) => {
  reportToSentry(event.reason instanceof Error ? event.reason : new Error(String(event.reason)));
  event.preventDefault(); // suppress the default "Uncaught (in promise)" console noise
});
```

Most teams don't hand-write this either. Sentry, Bugsnag, and similar tools install both listeners automatically, and add resolved stack traces, a trail of recent user actions leading up to the error, and release tagging on top. Knowing what they actually hook into, `error`, `unhandledrejection`, plus `componentDidCatch` for React, is what interviewers are really probing for, not which vendor happens to be in use.

> **Remember:** `window.addEventListener("error", ...)` and `"unhandledrejection"` are what catch exactly the two gaps error boundaries leave open.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-errors-global-q1", "type": "mcq",
      "prompt": "A fetch call's promise rejects with no .catch() attached anywhere. What catches this in a production app?",
      "options": [
        {"id":"a","text":"The nearest React error boundary"},
        {"id":"b","text":"A window.addEventListener(\"unhandledrejection\", ...) listener, which is specifically for promise rejections that escape error boundaries entirely"},
        {"id":"c","text":"Nothing catches this, it always crashes the app"},
        {"id":"d","text":"React's Suspense boundary"}
      ],
      "correct": "b",
      "explanation": "A rejected promise with no handler is exactly the async gap error boundaries can't cover. The unhandledrejection event is the browser-level mechanism built for catching it." }
] }
```

## Retrying transient failures without making things worse

Network calls fail transiently: a blip, a timeout, a momentarily overloaded server. Retrying with **exponential backoff and jitter** is the standard pattern, backing off exponentially so you don't hammer a server that's already struggling, and adding jitter, a small random amount, so many clients retrying at once don't all collide on the same schedule.

```ts
async function fetchWithRetry(url: string, options?: RequestInit, { maxRetries = 3, baseDelayMs = 300, maxDelayMs = 5000 } = {}): Promise<Response> {
  let lastError: unknown;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const res = await fetch(url, options);
      // Only retry on 5xx or 429 — a 4xx client error like 400/404 won't succeed on retry
      if (res.ok || (res.status < 500 && res.status !== 429)) return res;
      lastError = new Error(`HTTP ${res.status}`);
    } catch (err) { lastError = err; } // network failure, DNS error, etc.

    if (attempt < maxRetries) {
      const exponential = Math.min(baseDelayMs * 2 ** attempt, maxDelayMs);
      const jitter = Math.random() * exponential * 0.3;
      await new Promise((resolve) => setTimeout(resolve, exponential + jitter));
    }
  }
  throw lastError;
}
```

Trace one failing call: attempt 0 gets a 503, `lastError` is set, and the loop waits about 300ms plus jitter before attempt 1. If attempt 1 also fails, the wait roughly doubles, capped at `maxDelayMs`. Once `attempt` exceeds `maxRetries`, the loop exits and the last error is thrown, so the caller sees a real error, not a silent `undefined`.

Four details interviewers listen for specifically. **Which failures are worth retrying**: a 404 or 400 fails identically every time, don't retry client errors; 5xx and 429 (respecting a `Retry-After` header if present) are the ones worth retrying. **A retry ceiling**: unbounded retries turn one transient blip into an indefinite hang from the user's view, always cap attempts and show a real final failure. **Idempotency**: retrying a `POST` that creates something can duplicate it if the first attempt actually succeeded but the response was lost in transit; `GET`/`PUT`/`DELETE` are safe to retry by definition, `POST` is risky without an idempotency key. **Libraries**: TanStack Query and SWR implement this exact pattern already, reach for one of them in real projects rather than hand-rolling retry logic, unless an interview specifically asks you to build it.

> **Remember:** never retry a 4xx. It will fail the exact same way every time, and retrying it only wastes time and load.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-errors-retry-q1", "type": "mcq",
      "prompt": "A fetch fails with a 404 Not Found. Should a retry-with-backoff helper retry this request?",
      "options": [
        {"id":"a","text":"Yes, always retry every failed request"},
        {"id":"b","text":"No — a 4xx client error like 404 will fail identically on every retry, since the problem is the request itself, not a transient server issue; only 5xx and 429 are worth retrying"},
        {"id":"c","text":"Yes, but only with a longer delay"},
        {"id":"d","text":"Only if the request is a GET"}
      ],
      "correct": "b",
      "explanation": "A 404 means the resource doesn't exist, retrying won't change that. Retry logic should only target genuinely transient failures: server errors (5xx) and rate limiting (429)." }
] }
```

## Failing in a way the user can actually recover from

The goal isn't "never fail." It's failing in a way the user can understand and act on.

```tsx
function DataPanel({ userId }: { userId: string }) {
  const { data, error, isLoading, refetch } = useUserData(userId);
  if (isLoading) return <Skeleton />;
  if (error) {
    if (error.status === 401) return <SignInPrompt />;
    if (error.status === 0) return <div role="alert"><p>You appear to be offline. Check your connection.</p><button onClick={refetch}>Retry</button></div>;
    return <div role="alert"><p>Couldn't load this data right now.</p><button onClick={refetch}>Retry</button></div>;
  }
  return <UserSummary data={data} />;
}
```

Three principles worth stating out loud. **Give a specific message, never just "Something went wrong."** Tell "you're offline" apart from "you're not signed in" apart from "the server failed," since each one has a different correct next step. **Always offer a next action**: retry, sign in again, contact support. An error with no action is a dead end. **Let partial failures degrade gracefully.** If a dashboard has five independent widgets and one API call fails, the other four should still work, wrap each widget in its own error boundary instead of one boundary around the whole page that takes everything down together.

```tsx
function Dashboard() {
  return (
    <div className="grid">
      <ErrorBoundary fallback={() => <WidgetError name="Revenue" />}><RevenueWidget /></ErrorBoundary>
      <ErrorBoundary fallback={() => <WidgetError name="Traffic" />}><TrafficWidget /></ErrorBoundary>
    </div>
  );
}
```

> **Remember:** wrap each independent widget in its own error boundary. One boundary around the whole page means one failing widget takes everything else down with it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-errors-degrade-q1", "type": "mcq",
      "prompt": "A dashboard has five independent widgets. One widget's API call fails. What's the best way to keep the other four working?",
      "options": [
        {"id":"a","text":"Wrap the entire dashboard in a single error boundary"},
        {"id":"b","text":"Wrap each widget in its own error boundary, so one widget's failure shows a local error state without affecting its siblings"},
        {"id":"c","text":"Show a full-page error and stop rendering everything"},
        {"id":"d","text":"Disable error boundaries entirely for dashboards"}
      ],
      "correct": "b",
      "explanation": "A single boundary around the whole page catches the error but takes down all five widgets together. A boundary per widget isolates the failure to exactly the one thing that broke." }
] }
```

React's boundaries, the browser's global listeners, and a retry policy each cover a different failure surface, and a production app needs all three, plus UI that tells the user something specific and actionable happened, not just that something did.
