---
kind: lesson
id_key: interview-prep-45/day-24-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "State Machines in React"
position: 18
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Complex UI state, a multi-step form, an async fetch with loading/error/retry, a media player, tends to accumulate boolean flags until the component can represent states that make no sense at all: `isLoading: true` and `isError: true` simultaneously. State machines eliminate that entire class of bug by design, and this comes up in interviews both as a direct question, "how would you model this UI's state?", and as a general signal of engineering maturity.

## The problem with flags

```tsx
// Every new state is another independent boolean, and the number of
// *reachable* combinations grows exponentially while the number of
// *valid* combinations stays small.
function useFetchUser(id: string) {
  const [isLoading, setIsLoading] = useState(false);
  const [isError, setIsError] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [data, setData] = useState<User | null>(null);
  const [error, setError] = useState<string | null>(null);
  // Nothing stops isLoading and isSuccess from both being true.
  // Nothing stops isError being true while data is also populated
  // from a stale previous fetch. Every consumer has to guess which
  // combination is actually "real."
}
```

A state machine's core promise is to model the finite set of states explicitly, and only allow the transitions between them that you've defined. Every other combination simply isn't representable, not because you remembered to guard against it, but because the type system or the transition table doesn't allow it to exist in the first place.

## The shape of it: states, events, a transition table

A state machine is a finite set of **states**, a finite set of **events**, and a **transition table** mapping `(state, event) → next state`. Nothing else can move it. The current state plus an incoming event is the entire input to "what happens next," which is what makes the whole thing reason-about-able and testable independent of any rendered UI.

```
        FETCH                    RESOLVE
idle ─────────────► loading ─────────────► success
                        │
                        │ REJECT
                        ▼
                      error ──── RETRY ────► loading
```

This is the same unidirectional-flow idea React's own render model runs on: data flows one way, and transitions are explicit function calls, never ad hoc mutation. A state machine just applies that same discipline to the state's *shape*, not only to rendering.

## Getting most of the benefit with useReducer

You don't need a library to capture the core win. `useReducer` with a discriminated-union state and an explicit transition function already gets you there, and it's often the right call in an interview unless XState is specifically what's being asked for.

```tsx
type FetchState<T> =
  | { status: "idle" } | { status: "loading" }
  | { status: "success"; data: T } | { status: "error"; message: string };
type FetchEvent<T> =
  | { type: "FETCH" } | { type: "RESOLVE"; data: T }
  | { type: "REJECT"; message: string } | { type: "RETRY" };

function fetchReducer<T>(state: FetchState<T>, event: FetchEvent<T>): FetchState<T> {
  switch (state.status) {
    case "idle": return event.type === "FETCH" ? { status: "loading" } : state;
    case "loading":
      if (event.type === "RESOLVE") return { status: "success", data: event.data };
      if (event.type === "REJECT") return { status: "error", message: event.message };
      return state;
    case "success": return state; // no valid transitions out of success in this machine
    case "error": return event.type === "RETRY" ? { status: "loading" } : state;
  }
}

function useFetchUser(id: string) {
  const [state, dispatch] = useReducer(fetchReducer<User>, { status: "idle" });
  useEffect(() => {
    dispatch({ type: "FETCH" });
    fetch(`/api/users/${id}`)
      .then(res => res.json())
      .then((data: User) => dispatch({ type: "RESOLVE", data }))
      .catch(err => dispatch({ type: "REJECT", message: String(err) }));
  }, [id]);
  return state;
}
```

Every unreachable combination from the flags version, loading and error at once, success with no data, simply can't exist here. Trace what happens if a stray `RETRY` fires while a fetch is still in flight: the reducer is in `case "loading"`, and that branch only recognizes `RESOLVE` and `REJECT`. `RETRY` falls through to `return state`, a no-op, so the component keeps rendering its loading UI, unbothered. No flag gets left in a stale, contradictory position, because there was never a flag to leave stale in the first place.

## XState, for when a reducer isn't enough anymore

XState is the standard library once a machine needs to be visualizable, or genuinely complex: nested and parallel states, guards, actions tied to transitions, and, critically for interviews, a visual diagram generated straight from the machine definition.

```ts
import { createMachine, assign } from "xstate";

const fetchMachine = createMachine({
  id: "fetch",
  initial: "idle",
  context: { data: null as User | null, error: null as string | null },
  states: {
    idle: { on: { FETCH: "loading" } },
    loading: {
      on: {
        RESOLVE: { target: "success", actions: assign({ data: ({ event }) => event.data }) },
        REJECT: { target: "error", actions: assign({ error: ({ event }) => event.error }) },
      },
    },
    success: { on: { FETCH: "loading" } }, // allow refetch
    error: { on: { RETRY: "loading" } },
  },
});
```

```tsx
import { useMachine } from "@xstate/react";

function UserProfile({ userId }: { userId: string }) {
  const [state, send] = useMachine(fetchMachine);
  useEffect(() => {
    send({ type: "FETCH" });
    fetch(`/api/users/${userId}`)
      .then(res => res.json())
      .then(data => send({ type: "RESOLVE", data }))
      .catch(error => send({ type: "REJECT", error: String(error) }));
  }, [userId, send]);

  if (state.matches("loading")) return <Spinner />;
  if (state.matches("error")) return <div><p>{state.context.error}</p><button onClick={() => send({ type: "RETRY" })}>Retry</button></div>;
  if (state.matches("success")) return <div>{state.context.data?.name}</div>;
  return null;
}
```

`state.matches("loading")` is the render-time check; `send({ type: ... })` is the only way to attempt a transition, and the machine itself decides whether that event does anything at all given the current state.

## Where guards earn their keep: a multi-step form

Multi-step forms are the canonical case where the flags approach becomes unmanageable, "which step am I on," "can I go back," and "is this step's data valid enough to advance" all interact with each other.

```ts
const checkoutMachine = createMachine({
  id: "checkout",
  initial: "shipping",
  states: {
    shipping: { on: { NEXT: { target: "payment", guard: "shippingValid" } } },
    payment: { on: { NEXT: { target: "review", guard: "paymentValid" }, BACK: "shipping" } },
    review: { on: { BACK: "payment", SUBMIT: "submitting" } },
    submitting: { on: { RESOLVE: "confirmed", REJECT: "review" } }, // failed submission returns to review, not a dead end
    confirmed: { type: "final" },
  },
});
```

The **guard** (`shippingValid`) is a predicate evaluated against the machine's context, and the transition simply doesn't happen if it returns false. "Can't advance with an invalid shipping address" is enforced by the machine itself, not by scattered `if` checks stapled onto every button's `onClick`. This is the concrete answer when an interviewer asks how a state machine specifically helps a multi-step form: it becomes the single source of truth for both what step you're on and whether you're allowed to leave it.

## Why this is unusually easy to test

The transition table is a pure function, independent of any rendered UI:

```ts
test("checkout: submission failure returns to review, not a dead end", () => {
  const service = createActor(checkoutMachine).start();
  service.send({ type: "NEXT" }); // shipping -> payment
  service.send({ type: "NEXT" }); // payment -> review
  service.send({ type: "SUBMIT" }); // review -> submitting
  service.send({ type: "REJECT" }); // submitting -> review
  expect(service.getSnapshot().value).toBe("review");
});
```

No `render()`, no DOM, no `userEvent`. This tests the actual business rule, a failed submission must never strand the user, as a pure state transition, faster to run and more precisely targeted than an integration test that has to click through an entire rendered form to exercise the same path. You still want a handful of integration tests confirming the UI actually calls `send` correctly, but the exhaustive edge-case coverage of valid and invalid transitions belongs at the machine level, not the component level.

## Choosing the right tool for the job

| Situation | Approach |
|---|---|
| A couple of genuinely independent booleans (`isOpen`, `isDarkMode`) | Plain `useState`; a machine is overkill |
| A small closed set of mutually exclusive states (idle/loading/success/error) | `useReducer` with a discriminated union |
| Multi-step flows, guarded transitions, nested or parallel states, need for visualization | XState |

The thread running through all three: define the reachable states up front, and let the transition function, however small or large it ends up, be the only door between them.
