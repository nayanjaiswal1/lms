---
kind: lesson
id_key: interview-prep-45/day-25-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Error Handling"
position: 28
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Every production frontend fails in the field: a network drops, an API returns malformed JSON, a third-party script throws. Interviewers ask about error handling to see whether you design for that reality or only for the happy path. Today covers React error boundaries, global error capture, retry strategies, and how to turn a caught error into something a user can actually act on.

## Error boundaries

An error boundary is a component that catches JavaScript errors thrown during rendering, in lifecycle methods, and in constructors of its child tree, and renders a fallback UI instead of crashing the whole app. It is still, as of React 19, only implementable as a **class component**. There is no hook equivalent, because the underlying mechanism (`getDerivedStateFromError`/`componentDidCatch`) requires the component instance semantics classes provide.

```tsx
import { Component, type ErrorInfo, type ReactNode } from "react";

interface ErrorBoundaryProps {
  fallback: (error: Error, reset: () => void) => ReactNode;
  onError?: (error: Error, info: ErrorInfo) => void;
  children: ReactNode;
}

interface ErrorBoundaryState {
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    // Runs during render — update state so the next render shows the fallback
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Runs after render — the right place for side effects like logging
    this.props.onError?.(error, info);
  }

  reset = () => this.setState({ error: null });

  render() {
    if (this.state.error) {
      return this.props.fallback(this.state.error, this.reset);
    }
    return this.props.children;
  }
}
```

```tsx
<ErrorBoundary
  fallback={(error, reset) => (
    <div role="alert">
      <p>Something went wrong: {error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  )}
  onError={(error, info) => reportToSentry(error, info.componentStack)}
>
  <Dashboard />
</ErrorBoundary>
```

**What error boundaries do NOT catch, the single most common interview trap:**

- Errors in event handlers (`onClick` throwing). These are regular JS errors; catch them with `try`/`catch` in the handler itself.
- Errors in asynchronous code (`setTimeout`, promises, `fetch` callbacks). By the time the async callback runs, React is no longer "inside" a render it can intercept.
- Errors thrown during server-side rendering.
- Errors thrown in the error boundary's own `render`. A boundary can't catch its own failure; nest a second boundary above it if you need that covered.

For the async and event-handler gaps, there's no framework-level fix: catch those manually and, if you want the boundary to handle them, re-throw during a state update so the next render is what actually throws.

```tsx
function DangerousButton() {
  const [, setError] = useState();
  return (
    <button
      onClick={() => {
        try {
          riskyOperation();
        } catch (err) {
          // Re-throw during render so the nearest error boundary catches it
          setError(() => { throw err; });
        }
      }}
    >
      Run
    </button>
  );
}
```

## `react-error-boundary`

In production code, most teams use the `react-error-boundary` package instead of hand-rolling the class above. It's the same underlying mechanism, with better ergonomics: a `useErrorBoundary` hook for the manual-throw pattern, and a `resetKeys` prop to auto-reset when relevant props change.

```bash
npm install react-error-boundary
```

```tsx
import { ErrorBoundary } from "react-error-boundary";

function App() {
  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
      onError={(error, info) => reportToSentry(error, info)}
      onReset={() => window.location.reload()}
    >
      <Dashboard />
    </ErrorBoundary>
  );
}

function ErrorFallback({ error, resetErrorBoundary }: { error: Error; resetErrorBoundary: () => void }) {
  return (
    <div role="alert">
      <p>{error.message}</p>
      <button onClick={resetErrorBoundary}>Try again</button>
    </div>
  );
}
```

## Global error handling

Error boundaries only cover the React render tree. Two browser-level events catch what escapes it:

```ts
// Uncaught synchronous errors anywhere on the page, including outside React
window.addEventListener("error", (event) => {
  reportToSentry(event.error ?? new Error(event.message), {
    filename: event.filename,
    lineno: event.lineno,
  });
});

// Unhandled promise rejections — the async gap error boundaries can't cover
window.addEventListener("unhandledrejection", (event) => {
  reportToSentry(event.reason instanceof Error ? event.reason : new Error(String(event.reason)));
  event.preventDefault(); // suppress the default "Uncaught (in promise)" console noise
});
```

In practice, most teams don't hand-roll this either. Sentry, Bugsnag, and similar tools install both listeners for you and add source-map-resolved stack traces, breadcrumbs (a trail of recent user actions and console logs leading up to the error), and release/environment tagging automatically. Knowing what they hook into (`error`, `unhandledrejection`, plus `componentDidCatch` for React) is the part interviewers actually probe, not which vendor you use.

## Retry logic for failed requests

Network calls fail transiently: a blip, a timeout, a momentarily overloaded server. Retrying with **exponential backoff and jitter** is the standard pattern. Back off exponentially so you don't hammer a struggling server, and add jitter so many clients retrying at once don't all collide on the same schedule (the "thundering herd" problem).

```ts
interface RetryOptions {
  maxRetries?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
}

async function fetchWithRetry(
  url: string,
  options?: RequestInit,
  { maxRetries = 3, baseDelayMs = 300, maxDelayMs = 5000 }: RetryOptions = {}
): Promise<Response> {
  let lastError: unknown;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const res = await fetch(url, options);
      // Only retry on 5xx (server-side) or 429 (rate limited) — never retry
      // 4xx client errors like 400/404, they won't succeed on retry.
      if (res.ok || (res.status < 500 && res.status !== 429)) {
        return res;
      }
      lastError = new Error(`HTTP ${res.status}`);
    } catch (err) {
      lastError = err; // network failure, DNS error, etc.
    }

    if (attempt < maxRetries) {
      const exponential = Math.min(baseDelayMs * 2 ** attempt, maxDelayMs);
      const jitter = Math.random() * exponential * 0.3;
      await new Promise((resolve) => setTimeout(resolve, exponential + jitter));
    }
  }

  throw lastError;
}
```

Trace one failing call through this: attempt 0 gets a 503, so `lastError` is set and the loop waits `~300ms` (plus jitter) before attempt 1. If attempt 1 also fails, the wait roughly doubles to `~600ms`, capped at `maxDelayMs`. Once `attempt` exceeds `maxRetries`, the loop exits and the last recorded error is thrown, so the caller sees a real error object rather than a silent `undefined`.

Key details interviewers listen for:

- **Which failures are retryable.** A 404 or 400 will fail identically on retry, so don't retry client errors. 5xx and 429 (with a `Retry-After` header respected if present) are the retryable cases.
- **A retry ceiling.** Unbounded retries turn a transient blip into an indefinite hang from the user's perspective. Always cap attempts and surface a final failure state.
- **Idempotency.** Retrying a `POST` that creates a resource can create duplicates if the first attempt actually succeeded but the response was lost. It's safe to retry `GET`/`PUT`/`DELETE` (idempotent by HTTP semantics), but risky for `POST` without an idempotency key.
- **Libraries** (TanStack Query, SWR) implement this exact pattern out of the box. In a real project, reaching for a data-fetching library is often the right call over hand-rolling retry logic, unless you're specifically being asked to implement it in the interview.

## Graceful degradation and user feedback

The goal isn't "never fail." It's to fail in a way the user can understand and recover from.

```tsx
function DataPanel({ userId }: { userId: string }) {
  const { data, error, isLoading, refetch } = useUserData(userId);

  if (isLoading) return <Skeleton />;

  if (error) {
    // Distinguish error types so the message is actually actionable
    if (error.status === 401) return <SignInPrompt />;
    if (error.status === 0) {
      return (
        <div role="alert">
          <p>You appear to be offline. Check your connection.</p>
          <button onClick={refetch}>Retry</button>
        </div>
      );
    }
    return (
      <div role="alert">
        <p>Couldn't load this data right now.</p>
        <button onClick={refetch}>Retry</button>
      </div>
    );
  }

  return <UserSummary data={data} />;
}
```

Principles worth stating explicitly in an interview:

- **Specific error messages, not "Something went wrong."** Distinguish "you're offline," "you're not authorized," and "the server failed," since each has a different correct next action.
- **Always offer a next step**: retry, sign in again, contact support. An error state with no action is a dead end.
- **Degrade partial failures gracefully.** If a dashboard has five independent widgets and one API call fails, the other four should still render. Isolate error boundaries per widget rather than wrapping the whole page in one boundary that takes everything down together.

```tsx
// Isolated boundaries — one failing widget doesn't take down the dashboard
function Dashboard() {
  return (
    <div className="grid">
      <ErrorBoundary fallback={() => <WidgetError name="Revenue" />}>
        <RevenueWidget />
      </ErrorBoundary>
      <ErrorBoundary fallback={() => <WidgetError name="Traffic" />}>
        <TrafficWidget />
      </ErrorBoundary>
    </div>
  );
}
```

The thread connecting all of this: React's boundaries, the browser's global listeners, and a retry policy each cover a different failure surface, and a production app needs all three plus UI that tells the user something specific and actionable happened.
