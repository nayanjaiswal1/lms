---
kind: lesson
id_key: interview-prep-45/day-04-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "State Management"
position: 7
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"When would you reach for Redux vs Context vs local state?" is one of the most common system-design-flavored frontend questions, because the honest answer reveals whether you've actually shipped something at scale or just followed tutorials. Today you'll build a Redux-like store from scratch so "how does Redux work internally" stops being a black box, and nail down `useReducer` for local complex state.

## When to use local state vs global state

Default to the narrowest scope that works, and only lift when you have a concrete reason:

| Signal | Use |
|---|---|
| Only one component (and maybe its direct children) needs the value | `useState` / `useReducer` in that component |
| Several sibling components need it, but it doesn't cross large parts of the tree | Lift state to their common parent, pass down as props |
| Truly cross-cutting (theme, auth session, locale) that rarely changes | React Context |
| Complex, frequently-updated, shared across distant parts of the app, needs middleware/devtools/time-travel | Redux / Zustand / Jotai (external store) |
| Comes from the server and just needs caching + revalidation | React Query / SWR / TanStack Query, not Redux |

**Interview trap: "Context is a state management solution."** It isn't. Context is a *dependency injection* mechanism for avoiding prop drilling. It has no built-in way to prevent unrelated consumers from re-rendering on unrelated value changes (every consumer of a Context re-renders on ANY change to that Context's value, unless you split contexts or memoize), and no middleware/devtools/selectors. Redux (or Zustand) solves a different problem: efficient, selective subscriptions to slices of a large, frequently-changing store.

| | Redux | Context API | Zustand |
|---|---|---|---|
| Boilerplate | High (actions, reducers, dispatch), much less with Redux Toolkit | Low | Very low |
| Re-render granularity | Fine: `useSelector` only re-renders on the selected slice changing | Coarse: any Context value change re-renders every consumer | Fine: selector-based, like Redux |
| DevTools / time-travel | Yes, excellent | No | Yes, via middleware |
| Async / middleware | Thunks, Sagas, RTK Query | None built-in, DIY | Simple built-in async actions |
| Best for | Large apps, complex cross-cutting state, need for strict predictability | Rarely-changing app-wide values: theme, auth, locale | Most apps that outgrew Context but don't need Redux's ceremony |

## Build: a simple Redux-like store

This is the core of what `createStore` does: a subscription list, a reducer, and dispatch that runs the reducer and notifies subscribers:

```tsx
type Action = { type: string; payload?: unknown };
type Reducer<S> = (state: S, action: Action) => S;
type Listener = () => void;

function createStore<S>(reducer: Reducer<S>, initialState: S) {
  let state = initialState;
  const listeners = new Set<Listener>();

  function getState(): S {
    return state;
  }

  function dispatch(action: Action): Action {
    state = reducer(state, action); // reducer MUST be pure: same inputs -> same output, no mutation
    listeners.forEach(listener => listener()); // notify every subscriber, unconditionally
    return action;
  }

  function subscribe(listener: Listener): () => void {
    listeners.add(listener);
    return () => listeners.delete(listener); // unsubscribe function
  }

  return { getState, dispatch, subscribe };
}

// Usage:
type CounterState = { count: number };
type CounterAction = { type: 'increment' } | { type: 'decrement' } | { type: 'reset' };

function counterReducer(state: CounterState, action: CounterAction): CounterState {
  switch (action.type) {
    case 'increment':
      return { count: state.count + 1 }; // new object — never mutate state directly
    case 'decrement':
      return { count: state.count - 1 };
    case 'reset':
      return { count: 0 };
    default:
      return state;
  }
}

const store = createStore(counterReducer, { count: 0 });
const unsubscribe = store.subscribe(() => console.log('new state:', store.getState()));
store.dispatch({ type: 'increment' }); // logs: new state: { count: 1 }
store.dispatch({ type: 'increment' }); // logs: new state: { count: 2 }
unsubscribe();
```

A React binding for this store (roughly what `react-redux`'s `useSelector` does) uses `useSyncExternalStore`, the hook purpose-built for subscribing to external (non-React) state sources without tearing:

```tsx
import { useSyncExternalStore } from 'react';

function useStoreSelector<S, T>(store: { getState: () => S; subscribe: (l: () => void) => () => void }, selector: (state: S) => T): T {
  return useSyncExternalStore(
    store.subscribe,
    () => selector(store.getState()),
  );
}

function Counter() {
  const count = useStoreSelector(store, s => s.count);
  return (
    <div>
      <p>{count}</p>
      <button onClick={() => store.dispatch({ type: 'increment' })}>+</button>
    </div>
  );
}
```

## useReducer for complex local state

`useReducer` is `createStore` scaled down to a single component: same reducer pattern, no external store. Reach for it over multiple `useState` calls when state fields update together, or when the "next state" depends on complex logic that's easier to read as a switch statement than a pile of setters.

```tsx
type FormState = {
  values: { email: string; password: string };
  errors: { email?: string; password?: string };
  isSubmitting: boolean;
};

type FormAction =
  | { type: 'CHANGE_FIELD'; field: 'email' | 'password'; value: string }
  | { type: 'SET_ERRORS'; errors: FormState['errors'] }
  | { type: 'SUBMIT_START' }
  | { type: 'SUBMIT_END' };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'CHANGE_FIELD':
      return {
        ...state,
        values: { ...state.values, [action.field]: action.value },
        errors: { ...state.errors, [action.field]: undefined }, // clear that field's error on edit
      };
    case 'SET_ERRORS':
      return { ...state, errors: action.errors };
    case 'SUBMIT_START':
      return { ...state, isSubmitting: true };
    case 'SUBMIT_END':
      return { ...state, isSubmitting: false };
    default:
      return state;
  }
}

function LoginForm() {
  const [state, dispatch] = useReducer(formReducer, {
    values: { email: '', password: '' },
    errors: {},
    isSubmitting: false,
  });

  const handleChange = (field: 'email' | 'password') => (e: React.ChangeEvent<HTMLInputElement>) => {
    dispatch({ type: 'CHANGE_FIELD', field, value: e.target.value });
  };

  return (
    <form>
      <input value={state.values.email} onChange={handleChange('email')} />
      {state.errors.email && <span>{state.errors.email}</span>}
      <input type="password" value={state.values.password} onChange={handleChange('password')} />
      <button disabled={state.isSubmitting}>Log in</button>
    </form>
  );
}
```

Why this beats five `useState` calls: every field update is one `dispatch` with clear intent, the reducer is a pure function you can unit-test in isolation with no rendering involved, and related fields (`values`, `errors`, `isSubmitting`) update together atomically instead of risking inconsistent intermediate renders.

## Immutable update patterns

React (and Redux) detect changes with reference equality (`Object.is`/`===`), not deep equality. Mutating state in place doesn't change the reference, so React never notices: the UI silently goes stale.

```tsx
// WRONG — mutates, reference stays the same, React won't re-render
state.user.name = 'New Name';
state.items.push(newItem);

// RIGHT — spread creates new references at every level that changed
const newState = {
  ...state,
  user: { ...state.user, name: 'New Name' },
  items: [...state.items, newItem],
};

// Arrays: common immutable operations
const added = [...items, newItem];
const removed = items.filter(item => item.id !== targetId);
const updated = items.map(item => item.id === targetId ? { ...item, done: true } : item);
```

For deeply nested state, spreading by hand at every level gets unreadable fast. That's what libraries like Immer (which Redux Toolkit uses under the hood) solve: you write code that *looks* mutable, and it produces a new immutable tree behind the scenes via a proxy.

## State normalization

Nested/duplicated state (arrays of objects containing arrays of objects) makes updates require deep traversal and risks the same entity existing in two places with different data. Normalize it like a relational database: flat lookup tables keyed by ID, plus ID arrays for ordering.

```tsx
// Denormalized — hard to update a single comment, duplicated author data
type DenormalizedState = {
  posts: Array<{
    id: string;
    title: string;
    author: { id: string; name: string };
    comments: Array<{ id: string; text: string; author: { id: string; name: string } }>;
  }>;
};

// Normalized — O(1) lookup and update by ID, single source of truth per entity
type NormalizedState = {
  posts: { byId: Record<string, { id: string; title: string; authorId: string; commentIds: string[] }>; allIds: string[] };
  comments: { byId: Record<string, { id: string; text: string; authorId: string }>; allIds: string[] };
  users: { byId: Record<string, { id: string; name: string }>; allIds: string[] };
};

// Updating one comment is now a targeted, cheap operation:
function editComment(state: NormalizedState, commentId: string, text: string): NormalizedState {
  return {
    ...state,
    comments: {
      ...state.comments,
      byId: { ...state.comments.byId, [commentId]: { ...state.comments.byId[commentId], text } },
    },
  };
}
```
