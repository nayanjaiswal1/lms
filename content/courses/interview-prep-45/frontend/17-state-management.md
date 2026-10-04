---
kind: lesson
id_key: interview-prep-45/day-04-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "State Management"
position: 17
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
"When would you reach for Redux versus Context versus local state?" is one of the most common system-design-flavored frontend questions there is, because the honest answer reveals whether you've actually shipped something at scale or just followed a tutorial. This lesson builds a Redux-like store from scratch so "how does Redux work internally" stops being a black box, covers `useReducer` for local, complex state, and settles the controlled-versus-uncontrolled question for form inputs.

## Picking a scope, narrowest first

Default to the smallest scope that works, and only lift when there's a concrete reason to.

| Signal | Use |
|---|---|
| Only one component (and maybe its direct children) needs the value | `useState` / `useReducer` in that component |
| Several sibling components need it, but it doesn't cross large parts of the tree | Lift to their common parent, pass down as props |
| Truly cross-cutting (theme, auth session, locale) and rarely changes | React Context |
| Complex, frequently-updated, shared across distant parts of the app, needs middleware/devtools/time-travel | Redux / Zustand / Jotai |
| Comes from the server and just needs caching plus revalidation | React Query / SWR, not Redux |

Context is *not* a state management solution on its own, it's a dependency-injection mechanism for avoiding prop drilling. It has no built-in way to stop unrelated consumers from re-rendering on unrelated value changes: every consumer of a Context re-renders on *any* change to that Context's value, unless you split contexts or memoize deliberately, and it has no middleware, devtools, or selectors. Redux and Zustand solve a genuinely different problem: efficient, selective subscriptions to slices of a large, frequently-changing store.

| | Redux | Context API | Zustand |
|---|---|---|---|
| Boilerplate | High (actions, reducers, dispatch), much less with Redux Toolkit | Low | Very low |
| Re-render granularity | Fine: `useSelector` only re-renders on the selected slice | Coarse: any value change re-renders every consumer | Fine: selector-based |
| DevTools / time-travel | Yes | No | Via middleware |
| Async / middleware | Thunks, Sagas, RTK Query | None built-in | Simple built-in async actions |
| Best for | Large apps, complex cross-cutting state | Rarely-changing app-wide values | Apps that outgrew Context but don't need Redux's ceremony |

> **Remember:** Context is dependency injection, not a state manager. Every consumer re-renders on any value change, with no built-in way to subscribe to just a slice.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-contextscope-q1", "type": "mcq",
      "prompt": "A `<Toggle>` shows or hides a `<Sidebar>` used by exactly one parent component. Local state, Context, or Redux, and why?",
      "options": [
        {"id":"a","text":"Redux, since all UI state should live in one central store"},
        {"id":"b","text":"Local useState, since only one component and its direct child need the value; reaching for Context or Redux here adds ceremony with no real benefit"},
        {"id":"c","text":"Context, since it's the recommended default for all shared state"},
        {"id":"d","text":"It doesn't matter, all three options are equivalent here"}
      ],
      "correct": "b",
      "explanation": "The scope-picking rule is: default to the narrowest scope that works. A value needed by one component and maybe its direct children has no reason to be lifted any further, let alone into a global store." }
] }
```

## Building a store from scratch

This is the core of what `createStore` actually does: a subscription list, a reducer, and a `dispatch` that runs the reducer and notifies every subscriber.

```tsx
type Action = { type: string; payload?: unknown };
type Reducer<S> = (state: S, action: Action) => S;

function createStore<S>(reducer: Reducer<S>, initialState: S) {
  let state = initialState;
  const listeners = new Set<() => void>();

  function getState(): S { return state; }
  function dispatch(action: Action): Action {
    state = reducer(state, action); // reducer MUST be pure: same inputs → same output, no mutation
    listeners.forEach(listener => listener());
    return action;
  }
  function subscribe(listener: () => void): () => void {
    listeners.add(listener);
    return () => listeners.delete(listener);
  }
  return { getState, dispatch, subscribe };
}

type CounterState = { count: number };
function counterReducer(state: CounterState, action: Action): CounterState {
  switch (action.type) {
    case 'increment': return { count: state.count + 1 }; // new object — never mutate directly
    case 'decrement': return { count: state.count - 1 };
    default: return state;
  }
}

const store = createStore(counterReducer, { count: 0 });
store.subscribe(() => console.log('new state:', store.getState()));
store.dispatch({ type: 'increment' }); // logs: new state: { count: 1 }
```

A React binding for this, roughly what `react-redux`'s `useSelector` does, uses `useSyncExternalStore`, the hook purpose-built for subscribing to external, non-React state sources without tearing:

```tsx
import { useSyncExternalStore } from 'react';

function useStoreSelector<S, T>(store: { getState: () => S; subscribe: (l: () => void) => () => void }, selector: (state: S) => T): T {
  return useSyncExternalStore(store.subscribe, () => selector(store.getState()));
}

function Counter() {
  const count = useStoreSelector(store, s => s.count);
  return <button onClick={() => store.dispatch({ type: 'increment' })}>{count}</button>;
}
```

A reducer is a pure function with the signature `(state, action) => newState`, and `dispatch(action)` is the only sanctioned way to trigger one; `action` is a plain object with a `type` field and usually a `payload`. Never mutate `state` in place, both React and Redux detect change with a reference-equality check, and a mutated-in-place object still has the exact same reference, so the change goes unnoticed. `combineReducers` lets each reducer own one slice of the overall state tree, which keeps individual reducers small and independently testable, rather than one giant reducer trying to handle every action for the whole app.

> **Remember:** a store is nothing more than state plus a pure reducer plus a set of subscribers. `dispatch` runs the reducer, then notifies everyone.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-store-q1", "type": "mcq",
      "prompt": "Why must a reducer never mutate `state` directly, even if the mutation is logically correct?",
      "options": [
        {"id":"a","text":"JavaScript throws an error on object mutation inside a function"},
        {"id":"b","text":"React and Redux both detect change via reference equality; a mutated-in-place object keeps the exact same reference, so subscribers never notice anything changed"},
        {"id":"c","text":"Mutation is slower than creating a new object"},
        {"id":"d","text":"Reducers are not allowed to touch objects at all"}
      ],
      "correct": "b",
      "explanation": "Both React and Redux compare state by reference, not by deep value. If a reducer mutates the existing object instead of returning a new one, the reference never changes, so nothing downstream detects that anything is different." }
] }
```

## useReducer: the same pattern, scaled down to one component

`useReducer` is `createStore` shrunk to a single component, same reducer pattern, no external store. Reach for it over a pile of `useState` calls when fields update together, or when the "next state" logic reads more clearly as a switch statement than as scattered setters.

```tsx
type FormState = {
  values: { email: string; password: string };
  errors: { email?: string; password?: string };
  isSubmitting: boolean;
};
type FormAction =
  | { type: 'CHANGE_FIELD'; field: 'email' | 'password'; value: string }
  | { type: 'SET_ERRORS'; errors: FormState['errors'] }
  | { type: 'SUBMIT_START' } | { type: 'SUBMIT_END' };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'CHANGE_FIELD':
      return {
        ...state,
        values: { ...state.values, [action.field]: action.value },
        errors: { ...state.errors, [action.field]: undefined }, // clear that field's error on edit
      };
    case 'SET_ERRORS': return { ...state, errors: action.errors };
    case 'SUBMIT_START': return { ...state, isSubmitting: true };
    case 'SUBMIT_END': return { ...state, isSubmitting: false };
    default: return state;
  }
}

function LoginForm() {
  const [state, dispatch] = useReducer(formReducer, {
    values: { email: '', password: '' }, errors: {}, isSubmitting: false,
  });
  const handleChange = (field: 'email' | 'password') => (e: React.ChangeEvent<HTMLInputElement>) => {
    dispatch({ type: 'CHANGE_FIELD', field, value: e.target.value });
  };
  return (
    <form>
      <input value={state.values.email} onChange={handleChange('email')} />
      {state.errors.email && <span>{state.errors.email}</span>}
      <button disabled={state.isSubmitting}>Log in</button>
    </form>
  );
}
```

`SET_ERRORS` is what a submit handler dispatches after running validation, replacing the whole `errors` object in one atomic update rather than setting each field's error individually.

The win over five separate `useState` calls: every field update is one `dispatch` with clear intent, the reducer is a pure function you can unit-test with zero rendering involved, and related fields update together atomically instead of risking an inconsistent intermediate render where `values` updated but `errors` hasn't yet.

> **Remember:** reach for `useReducer` over several `useState` calls when fields update together, or the "next state" logic reads better as one switch statement.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-usereducer-q1", "type": "mcq",
      "prompt": "A component has five useState calls that mostly update together during a multi-step wizard. What's the main benefit of switching to one useReducer instead?",
      "options": [
        {"id":"a","text":"useReducer is always faster than useState"},
        {"id":"b","text":"Related fields update atomically through one dispatch with clear intent, and the transition logic becomes a pure, independently unit-testable function"},
        {"id":"c","text":"useReducer avoids re-renders entirely"},
        {"id":"d","text":"There's no real benefit, they're functionally identical"}
      ],
      "correct": "b",
      "explanation": "useReducer centralizes the 'what happens next' logic into one pure, testable function and makes multi-field updates atomic through a single dispatch, instead of several separate setState calls that could leave an inconsistent intermediate render." }
] }
```

## Controlled vs. uncontrolled inputs

A **controlled** input has React state as its single source of truth: the input's `value` comes from state, and every keystroke updates that state through `onChange`.

```tsx
function ControlledInput() {
  const [value, setValue] = useState("");
  return <input value={value} onChange={(e) => setValue(e.target.value)} />;
}
```

An **uncontrolled** input lets the DOM hold the value itself. React only reaches in when it actually needs the value, through a `ref`, instead of tracking every keystroke.

```tsx
function UncontrolledInput() {
  const ref = useRef<HTMLInputElement>(null);
  const submit = () => console.log(ref.current?.value);
  return <input ref={ref} defaultValue="" />;
}
```

The trade-off is exactly what it looks like: controlled gives you validation on every keystroke and state that's always current, at the cost of a re-render on every keystroke. Uncontrolled is cheaper, since typing causes zero React re-renders, but you only get the value when you explicitly ask for it, typically on submit. A large form with dozens of fields and no per-keystroke validation is the classic case for going uncontrolled, which is exactly why **React Hook Form** keeps inputs uncontrolled internally and only re-renders on submit or blur, worth naming directly as the answer to "how would you make a big form scale."

> **Remember:** controlled means React state drives the value, and re-renders on every keystroke. Uncontrolled means the DOM holds it, and you read it through a ref when you need it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-controlled-q1", "type": "mcq",
      "prompt": "A form has 40 input fields and needs to validate only on submit, not per keystroke. Why might an uncontrolled approach scale better here than a fully controlled one?",
      "options": [
        {"id":"a","text":"Uncontrolled inputs are always more accessible"},
        {"id":"b","text":"A controlled input re-renders the component on every keystroke across every field; an uncontrolled input lets the DOM hold the value and causes zero re-renders while typing, since the value is only read on submit"},
        {"id":"c","text":"Controlled inputs can't hold string values"},
        {"id":"d","text":"There's no performance difference between the two approaches"}
      ],
      "correct": "b",
      "explanation": "Controlled inputs tie every keystroke to a state update and a re-render. For a large form that only needs the values at submit time, an uncontrolled approach (reading values through refs) avoids that per-keystroke re-render cost entirely." }
] }
```

## Immutable updates and normalized shape

React and Redux both detect change with reference equality, `Object.is`/`===`, not deep equality. Mutating state in place never changes the reference, so nothing downstream ever notices, the UI just silently goes stale.

```tsx
// WRONG — mutates, reference stays the same, nothing re-renders
state.user.name = 'New Name';
state.items.push(newItem);

// RIGHT — spread creates new references at every level that actually changed
const newState = {
  ...state,
  user: { ...state.user, name: 'New Name' },
  items: [...state.items, newItem],
};
```

For deeply nested state, hand-spreading at every level gets unreadable fast, which is exactly the problem Immer (used internally by Redux Toolkit) solves: you write code that *looks* mutable, and it produces a new immutable tree behind the scenes via a proxy.

Nested, duplicated state, arrays of objects containing arrays of objects, makes a simple update require deep traversal, and risks the same entity existing in two places with two different values.

```tsx
// Denormalized — hard to update a single comment, author data duplicated across posts
type DenormalizedState = {
  posts: Array<{
    id: string; title: string;
    author: { id: string; name: string };
    comments: Array<{ id: string; text: string; author: { id: string; name: string } }>;
  }>;
};
```

Normalize it the way a relational database would: flat lookup tables keyed by ID, plus ID arrays for ordering.

```tsx
// Normalized — O(1) lookup and update by ID, single source of truth per entity
type NormalizedState = {
  posts: { byId: Record<string, { id: string; title: string; authorId: string; commentIds: string[] }>; allIds: string[] };
  comments: { byId: Record<string, { id: string; text: string; authorId: string }>; allIds: string[] };
  users: { byId: Record<string, { id: string; name: string }>; allIds: string[] };
};

function editComment(state: NormalizedState, commentId: string, text: string): NormalizedState {
  return {
    ...state,
    comments: { ...state.comments, byId: { ...state.comments.byId, [commentId]: { ...state.comments.byId[commentId], text } } },
  };
}
```

Editing one comment becomes a targeted, cheap operation, exactly one entry in one lookup table changes, instead of hunting through a nested array of posts to find the right comment buried three levels deep.

> **Remember:** denormalized, duplicated state risks the same entity existing in two places with two different values. Normalize it into flat, keyed lookup tables instead.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-normalize-q1", "type": "mcq",
      "prompt": "State stores `posts: [{ id, comments: [{ id, author: {...} }] }]`, with author data duplicated inside every comment. What real problem does normalizing this into flat `byId` lookup tables solve?",
      "options": [
        {"id":"a","text":"It makes the state object smaller in every case"},
        {"id":"b","text":"It removes duplication that risks the same entity (like an author) existing with two different values in two places, and makes updating one entity a single, targeted O(1) operation instead of a deep traversal"},
        {"id":"c","text":"It's required for React to detect any state changes at all"},
        {"id":"d","text":"It removes the need for reducers entirely"}
      ],
      "correct": "b",
      "explanation": "Denormalized, duplicated data can drift: the same author's data embedded in multiple comments can end up out of sync. A normalized, flat lookup table keeps one copy of each entity and makes updating it a single targeted change." }
] }
```
