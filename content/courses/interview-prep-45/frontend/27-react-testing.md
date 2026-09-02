---
kind: lesson
id_key: interview-prep-45/day-13-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Testing"
position: 27
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Testing questions in frontend interviews usually aren't about syntax. They're about judgment: what should you test, how do you avoid tests that break on every refactor, and how do you test something that talks to a network. This lesson covers React Testing Library's philosophy and the concrete patterns for unit tests, mocked API calls, and integration tests.

## Behavior, not implementation

React Testing Library is built around one principle: the more your tests resemble how the software is actually used, the more confidence they give you. Tests should interact with rendered output the way a user would, find text, click buttons, fill inputs, and they shouldn't reach into a component's internals at all.

```tsx
// Brittle: tests an implementation detail, breaks the moment `count` is renamed to `value`
test("counter increments — brittle version", () => {
  const wrapper = shallow(<Counter />);
  wrapper.instance().setState({ count: 1 });
  expect(wrapper.instance().state.count).toBe(1);
});

// Resilient: tests the behavior a user actually experiences
test("counter increments when button is clicked", async () => {
  render(<Counter />);
  const user = userEvent.setup();
  expect(screen.getByText("Count: 0")).toBeInTheDocument();
  await user.click(screen.getByRole("button", { name: /increment/i }));
  expect(screen.getByText("Count: 1")).toBeInTheDocument();
});
```

The first version breaks the instant an internal variable gets renamed, even though the feature still works exactly the same for a real user. The second only breaks if the actual user-facing behavior breaks, which is the entire point of writing it this way.

## Query priority: pick the one that matches how a real user finds things

RTL exposes several ways to find elements, ranked by how closely they match how a real user, including someone using assistive technology, would find the same thing.

1. **`getByRole`**: matches the accessibility-tree role (`button`, `textbox`, `heading`). Preferred almost always, and it quietly forces you to write accessible markup in the first place.
2. **`getByLabelText`**: for form fields, matching how a screen reader user finds an input through its label.
3. **`getByPlaceholderText`**, **`getByText`**: reasonable fallbacks for non-interactive or unlabeled content.
4. **`getByTestId`**: last resort, when nothing else identifies the element, a decorative element with no accessible name.

```tsx
// Preferred
screen.getByRole("button", { name: /submit/i });
screen.getByLabelText(/email address/i);
// Fallback only when nothing else can target the element
screen.getByTestId("loading-spinner");
```

`getBy*` throws if it finds nothing, so use it for asserting something exists. `queryBy*` returns `null` instead of throwing, so use it to assert something is absent, `getBy*` would throw before you got the chance to assert the absence. `findBy*` is async and retries until timeout, so use it whenever you're waiting for something to appear after an async action.

```tsx
expect(screen.queryByText("Error")).not.toBeInTheDocument(); // asserting absence
const successMessage = await screen.findByText("Saved!");    // waiting for async appearance
```

## A unit test end to end

```tsx
function LoginForm({ onSubmit }: { onSubmit: (email: string, password: string) => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.includes("@")) { setError("Enter a valid email"); return; }
    setError("");
    onSubmit(email, password);
  };

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="email">Email</label>
      <input id="email" value={email} onChange={(e) => setEmail(e.target.value)} />
      <label htmlFor="password">Password</label>
      <input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
      {error && <p role="alert">{error}</p>}
      <button type="submit">Log in</button>
    </form>
  );
}
```

```tsx
describe("LoginForm", () => {
  test("submits email and password when valid", async () => {
    const handleSubmit = vi.fn();
    const user = userEvent.setup();
    render(<LoginForm onSubmit={handleSubmit} />);
    await user.type(screen.getByLabelText(/email/i), "jane@example.com");
    await user.type(screen.getByLabelText(/password/i), "hunter2");
    await user.click(screen.getByRole("button", { name: /log in/i }));
    expect(handleSubmit).toHaveBeenCalledWith("jane@example.com", "hunter2");
  });

  test("shows a validation error for an invalid email", async () => {
    const handleSubmit = vi.fn();
    const user = userEvent.setup();
    render(<LoginForm onSubmit={handleSubmit} />);
    await user.type(screen.getByLabelText(/email/i), "not-an-email");
    await user.click(screen.getByRole("button", { name: /log in/i }));
    expect(screen.getByRole("alert")).toHaveTextContent(/valid email/i);
    expect(handleSubmit).not.toHaveBeenCalled();
  });
});
```

Reach for `userEvent` over `fireEvent`. `userEvent` simulates a real interaction sequence, focus, keydown, keypress, keyup, and an input event per character typed, while `fireEvent` dispatches a single raw DOM event. `userEvent` catches bugs `fireEvent` structurally can't, like a component that only works because you happened to skip the focus event.

## Mocking at the network boundary

The standard modern approach is **Mock Service Worker (MSW)**. It intercepts requests at the network level, so your component code makes real `fetch` calls and has no idea it's being tested, which is more resilient than mocking `fetch` directly, since a test built that way never gets coupled to *how* the component fetches data.

```ts
// mocks/handlers.ts
import { http, HttpResponse } from "msw";
export const handlers = [
  http.get("/api/users/:id", ({ params }) => HttpResponse.json({ id: params.id, name: "Jane Doe" })),
];

// mocks/server.ts
import { setupServer } from "msw/node";
export const server = setupServer(...handlers);

// setupTests.ts
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

```tsx
test("shows user name after loading", async () => {
  render(<UserProfile userId="42" />);
  expect(screen.getByText(/loading/i)).toBeInTheDocument();
  expect(await screen.findByText("Jane Doe")).toBeInTheDocument();
});

test("shows an error state when the API fails", async () => {
  server.use(http.get("/api/users/:id", () => HttpResponse.json({ error: "Not found" }, { status: 404 }))); // override for this one test
  render(<UserProfile userId="42" />);
  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

## An integration test for a full user flow

An integration test exercises several components together through a realistic sequence of user actions, closer to end-to-end but still running in the fast, mocked-network jsdom environment rather than a real browser.

```tsx
test("user can complete checkout", async () => {
  const user = userEvent.setup();
  render(<App />, { wrapper: AppProviders }); // router, query client, etc.

  await user.click(screen.getByRole("link", { name: /wireless headphones/i }));
  expect(await screen.findByRole("heading", { name: /wireless headphones/i })).toBeInTheDocument();

  await user.click(screen.getByRole("button", { name: /add to cart/i }));
  expect(screen.getByText(/1 item in cart/i)).toBeInTheDocument();

  await user.click(screen.getByRole("link", { name: /cart/i }));
  await user.click(screen.getByRole("button", { name: /checkout/i }));
  await user.type(screen.getByLabelText(/full name/i), "Jane Doe");
  await user.click(screen.getByRole("button", { name: /place order/i }));

  expect(await screen.findByText(/order confirmed/i)).toBeInTheDocument();
});
```

This test doesn't care whether cart state lives in Context, Redux, or Zustand. It only cares that clicking "add to cart" eventually leads to a confirmation screen, which is exactly the resilience-to-refactoring RTL's philosophy is aiming for.

## Coverage measures lines, not confidence

```tsx
// Contributes to coverage, catches nothing at all
test("renders without crashing", () => { render(<Checkout />); });
```

A test with no meaningful assertion inflates a coverage percentage while catching zero bugs. Use coverage as a floor for finding genuinely untested branches, a path nobody ever hit, not as a quality score to chase upward. Deliberately test the risky paths, validation logic, error states, an empty list, a network failure, a race condition, since they deserve more attention than straightforward render paths that were never going to break anyway. **Mutation testing** (Stryker and similar tools) is the more honest signal if it comes up: it mutates your source code, flipping a `<` to `<=`, deleting a line, and checks whether any test catches it. A test that still passes after that mutation was never actually verifying that piece of code.

There's no universal coverage number to target. Critical business logic, payments, auth, data mutations, should be close to fully covered with meaningful assertions; low-risk presentational code doesn't need the same investment. Chasing a blanket 100% target usually produces exactly the kind of hollow, assertion-free test shown above.
