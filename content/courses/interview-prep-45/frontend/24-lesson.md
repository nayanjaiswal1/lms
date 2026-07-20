---
kind: lesson
id_key: interview-prep-45/day-24-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 24 — State Machines in React"
position: 27
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Complex UI state (a multi-step form, an async fetch with loading/error/retry, a media player) tends to accumulate boolean flags until the component can represent states that make no sense — `isLoading: true` and `isError: true` at once. State machines eliminate that class of bug by design. This comes up in interviews both as a direct question ("how would you model this UI's state?") and as a signal of engineering maturity.

## The problem: boolean soup

```tsx
// The "flags" approach — every new state is another independent boolean,
// and the number of *reachable* combinations grows exponentially while
// the number of *valid* combinations stays small.
function useFetchUser(id: string) {
  const [isLoading, setIsLoading] = useState(false);
  const [isError, setIsError] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [data, setData] = useState<User | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Nothing stops isLoading and isSuccess from both being true.
  // Nothing stops isError being true while data is also populated
  // from a stale previous fetch. Every consumer has to defensively
  // guess which combination is "real."
}
```

A state machine's core promise: **model the finite set of states explicitly, and only allow transitions between them that you've defined.** Every other combination is unrepresentable — the type system (or the machine's transition table) simply doesn't allow it.

## Unidirectional data flow and predictable transitions

A state machine is: a finite set of **states**, a finite set of **events**, and a **transition table** mapping `(state, event) → next state`. Nothing else can move it — the current state plus an incoming event is the entire input to "what happens next," which is what makes the system reason-about-able and testable in isolation from the UI that renders it.

```
        FETCH                    RESOLVE
idle ─────────────► loading ─────────────► success
                        │
                        │ REJECT
                        ▼
                      error ──── RETRY ────► loading
```

This is the same unidirectional-flow idea React's own render model is built on — data flows one way, transitions are explicit function calls, not ad hoc mutation — a state machine just applies that discipline to the state shape itself, not only to rendering.

## A lightweight state machine with `useReducer`

You don't need a library to get the core benefit — `useReducer` with a discriminated-union state and an explicit transition function already buys you most of it, and it's often the right call in an interview unless the interviewer specifically wants XState.

```tsx
type FetchState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; message: string };

type FetchEvent<T> =
  | { type: "FETCH" }
  | { type: "RESOLVE"; data: T }
  | { type: "REJECT"; message: string }
  | { type: "RETRY" };

function fetchReducer<T>(state: FetchState<T>, event: FetchEvent<T>): FetchState<T> {
  switch (state.status) {
    case "idle":
      return event.type === "FETCH" ? { status: "loading" } : state;
    case "loading":
      if (event.type === "RESOLVE") return { status: "success", data: event.data };
      if (event.type === "REJECT") return { status: "error", message: event.message };
      return state;
    case "success":
      return state; // no valid transitions out of success in this machine
    case "error":
      return event.type === "RETRY" ? { status: "loading" } : state;
  }
}

function useFetchUser(id: string) {
  const [state, dispatch] = useReducer(fetchReducer<User>, { status: "idle" });

  useEffect(() => {
    dispatch({ type: "FETCH" });
    fetch(`/api/users/${id}`)
      .then((res) => res.json())
      .then((data: User) => dispatch({ type: "RESOLVE", data }))
      .catch((err) => dispatch({ type: "REJECT", message: String(err) }));
  }, [id]);

  return state;
}
```

Every unreachable combination from the boolean version — loading and error simultaneously, success with no data — simply cannot exist here. The switch statement's `case "loading"` branch only knows how to respond to `RESOLVE`/`REJECT`; a `RETRY` event sent while `loading` falls through to `return state`, a no-op, by construction.

## XState basics

XState is the standard library when you need visualizable, more complex machines — nested/parallel states, guards, actions on transition, and (critically for interviews) a visual diagram generated directly from the machine definition.

```bash
npm install xstate @xstate/react
```

```ts
import { createMachine, assign } from "xstate";

const fetchMachine = createMachine({
  id: "fetch",
  initial: "idle",
  types: {} as {
    context: { data: User | null; error: string | null };
    events: { type: "FETCH" } | { type: "RESOLVE"; data: User } | { type: "REJECT"; error: string } | { type: "RETRY" };
  },
  context: { data: null, error: null },
  states: {
    idle: {
      on: { FETCH: "loading" },
    },
    loading: {
      on: {
        RESOLVE: { target: "success", actions: assign({ data: ({ event }) => event.data }) },
        REJECT: { target: "error", actions: assign({ error: ({ event }) => event.error }) },
      },
    },
    success: {
      on: { FETCH: "loading" }, // allow refetch
    },
    error: {
      on: { RETRY: "loading" },
    },
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
      .then((res) => res.json())
      .then((data) => send({ type: "RESOLVE", data }))
      .catch((error) => send({ type: "REJECT", error: String(error) }));
  }, [userId, send]);

  if (state.matches("loading")) return <Spinner />;
  if (state.matches("error")) {
    return (
      <div>
        <p>{state.context.error}</p>
        <button onClick={() => send({ type: "RETRY" })}>Retry</button>
      </div>
    );
  }
  if (state.matches("success")) return <div>{state.context.data?.name}</div>;
  return null;
}
```

`state.matches("loading")` is the render-time check; `send({ type: ... })` is the only way to attempt a transition, and the machine itself decides whether that event does anything in the current state.

## A complex form with a state machine

Multi-step forms are the canonical case where the flags approach becomes unmanageable — "which step am I on," "can I go back," "is this step's data valid enough to advance" all interact.

```ts
const checkoutMachine = createMachine({
  id: "checkout",
  initial: "shipping",
  states: {
    shipping: {
      on: { NEXT: { target: "payment", guard: "shippingValid" } },
    },
    payment: {
      on: {
        NEXT: { target: "review", guard: "paymentValid" },
        BACK: "shipping",
      },
    },
    review: {
      on: {
        BACK: "payment",
        SUBMIT: "submitting",
      },
    },
    submitting: {
      on: {
        RESOLVE: "confirmed",
        REJECT: "review", // failed submission returns to review, not a dead end
      },
    },
    confirmed: { type: "final" },
  },
});
```

The **guard** (`shippingValid`) is a predicate function evaluated against the machine's context — the transition simply doesn't happen if the guard returns false, so "can't advance with an invalid shipping address" is enforced by the machine, not by scattered `if` checks across every button's `onClick`. This is the concrete answer when an interviewer asks "how does a state machine help with a multi-step form specifically" — the machine becomes the single source of truth for both *what step we're on* and *whether we're allowed to leave it*.

## Testing benefits

State machines are unusually easy to test because the transition table is a pure function independent of any rendered UI:

```ts
test("checkout: submission failure returns to review, not a dead end", () => {
  const service = createActor(checkoutMachine).start();
  service.send({ type: "NEXT" }); // shipping -> payment (assuming guard passes)
  service.send({ type: "NEXT" }); // payment -> review
  service.send({ type: "SUBMIT" }); // review -> submitting
  service.send({ type: "REJECT" }); // submitting -> review

  expect(service.getSnapshot().value).toBe("review");
});
```

No `render()`, no DOM, no `userEvent` — you're testing the actual business rule ("a failed submission must not strand the user") as a pure state transition, which is both faster to run and more precisely targeted than an integration test that has to click through a full rendered form to exercise the same path. You still want a smaller number of integration tests on top to confirm the UI actually calls `send` correctly, but the exhaustive edge-case coverage of *valid and invalid transitions* belongs at the machine level.

## When to reach for a state machine vs. plain state

| Situation | Approach |
|---|---|
| A couple of independent, genuinely independent booleans (`isOpen`, `isDarkMode`) | Plain `useState` — a machine is overkill |
| A small closed set of mutually exclusive states (idle/loading/success/error) | `useReducer` with a discriminated union — gets you the safety without a new dependency |
| Multi-step flows, guarded transitions, nested/parallel states, need for visualization or hierarchical states | XState — the complexity has crossed the point where a hand-rolled reducer becomes its own maintenance burden |

## Key takeaways

- Boolean-flag state allows unreachable/invalid combinations (loading + error at once); a state machine makes those combinations structurally unrepresentable.
- A state machine is fully defined by states, events, and a transition table — the current state plus an incoming event is the entire input to what happens next.
- `useReducer` with a discriminated-union state already gets you most of the safety benefit without a new dependency — reach for it before XState for simple cases.
- XState adds guards, nested/parallel states, and visualization — valuable once flows get genuinely complex (multi-step forms, guarded transitions).
- Guards enforce business rules ("can't advance with invalid data") inside the machine itself, replacing scattered validation checks across every button handler.
- State machines are pure and UI-independent, which makes them fast and precise to unit test — exercise invalid-transition edge cases at the machine level, not through full UI integration tests.

## Today's checklist

- [ ] Read: XState basics
- [ ] Implement: Simple state machine for UI
- [ ] Implement: Complex form with state machine
- [ ] Understand unidirectional data flow in state machines
- [ ] Understand how guards prevent invalid transitions
- [ ] Write at least one unit test against a machine's transition table directly
