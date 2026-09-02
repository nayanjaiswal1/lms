---
kind: lesson
id_key: interview-prep-45/day-25-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Error Handling"
position: 37
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Every production frontend fails in the field: a network drops, an API returns malformed JSON, a third-party script throws. Interviewers ask about error handling to see whether you design for that reality or only for the happy path. This lesson covers React error boundaries, global error capture, retry strategies, and how to turn a caught error into something a user can actually act on.

## Error boundaries, and their real limits

An error boundary catches JavaScript errors thrown during rendering, in lifecycle methods, and in constructors of its child tree, and renders a fallback instead of crashing the whole app. As of React 19 it's still only implementable as a **class component**, there's no hook equivalent, because the underlying mechanism, `getDerivedStateFromError`/`componentDidCatch`, requires the instance semantics only a class provides.

```tsx
class ErrorBoundary extends Component<{ fallback: (error: Error, reset: () => void) => ReactNode; onError?: (error: Error, info: ErrorInfo) => void; children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };
  static getDerivedStateFromError(error: Error) { return { error }; } // runs during render
  componentDidCatch(error: Error, info: ErrorInfo) { this.props.onError?.(error, info); } // runs after render — the right place for logging
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

What error boundaries do **not** catch is the single most common trap here, and it's worth knowing the full list cold. Errors in event handlers, an `onClick` throwing, are regular JS errors, catch them with `try`/`catch` in the handler itself. Errors in asynchronous code, `setTimeout`, a promise, a `fetch` callback, since by the time the callback runs, React is no longer "inside" a render it can intercept. Errors during server-side rendering. And errors thrown inside the error boundary's own `render`, a boundary can't catch its own failure, nesting a second boundary above it is the only way to cover that case.

There's no framework-level fix for the async and event-handler gaps, catch those manually, and if you want the nearest boundary to actually handle them, re-throw during a state update so the *next render* is what actually throws:

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

In production code, most teams reach for the `react-error-boundary` package instead of hand-rolling the class above, same underlying mechanism, better ergonomics: a `useErrorBoundary` hook for the manual-throw pattern, and a `resetKeys` prop to auto-reset when relevant props change.

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

## What catches everything a boundary can't

Error boundaries only cover the React render tree. Two browser-level events catch what escapes it:

```ts
// Uncaught synchronous errors anywhere on the page, including outside React entirely
window.addEventListener("error", (event) => {
  reportToSentry(event.error ?? new Error(event.message), { filename: event.filename, lineno: event.lineno });
});

// Unhandled promise rejections — exactly the async gap error boundaries can't cover
window.addEventListener("unhandledrejection", (event) => {
  reportToSentry(event.reason instanceof Error ? event.reason : new Error(String(event.reason)));
  event.preventDefault(); // suppress the default "Uncaught (in promise)" console noise
});
```

Most teams don't hand-roll this either. Sentry, Bugsnag, and similar tools install both listeners automatically and add source-map-resolved stack traces, breadcrumbs, a trail of recent user actions and console logs leading up to the error, and release/environment tagging on top. Knowing what they hook into, `error`, `unhandledrejection`, plus `componentDidCatch` for React, is what interviewers actually probe for, not which vendor happens to be in use.

## Retrying transient failures without making things worse

Network calls fail transiently: a blip, a timeout, a momentarily overloaded server. Retrying with **exponential backoff and jitter** is the standard pattern, backing off exponentially so you don't hammer a server that's already struggling, and adding jitter so many clients retrying at once don't collide on the same schedule, the "thundering herd" problem.

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

Trace one failing call: attempt 0 gets a 503, `lastError` is set, and the loop waits ~300ms plus jitter before attempt 1. If attempt 1 also fails, the wait roughly doubles, capped at `maxDelayMs`. Once `attempt` exceeds `maxRetries`, the loop exits and the last recorded error is thrown, so the caller sees a real error object rather than a silent `undefined`.

Four details interviewers listen for specifically. **Which failures are retryable**: a 404 or 400 fails identically on retry, don't retry client errors; 5xx and 429 (respecting a `Retry-After` header if present) are the retryable cases. **A retry ceiling**: unbounded retries turn a transient blip into an indefinite hang from the user's perspective, always cap attempts and surface a final failure state. **Idempotency**: retrying a `POST` that creates a resource can duplicate it if the first attempt actually succeeded but the response was lost in transit; `GET`/`PUT`/`DELETE` are safe to retry by HTTP semantics, `POST` is risky without an idempotency key. **Libraries**: TanStack Query and SWR implement this exact pattern out of the box, and reaching for one of them is usually the right production call, over hand-rolling retry logic, unless the interview specifically asks you to implement it yourself.

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

Three principles worth stating explicitly. **Specific error messages, not "Something went wrong."** Distinguish "you're offline," "you're not authorized," and "the server failed," since each has a different correct next action for the user to take. **Always offer a next step**: retry, sign in again, contact support. An error state with no action is a dead end. **Degrade partial failures gracefully.** If a dashboard has five independent widgets and one API call fails, the other four should still render, isolate error boundaries per widget rather than wrapping the whole page in one boundary that takes everything down together.

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

React's boundaries, the browser's global listeners, and a retry policy each cover a different failure surface, and a production app needs all three, plus UI that tells the user something specific and actionable happened, not just that something did.
