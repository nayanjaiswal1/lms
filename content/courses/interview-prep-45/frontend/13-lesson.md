---
kind: lesson
id_key: interview-prep-45/day-13-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Testing"
position: 16
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Testing questions in frontend interviews aren't usually about syntax. They're about judgment: what should you test, how do you avoid tests that break on every refactor, and how do you test something that talks to a network. Today covers React Testing Library's philosophy and the concrete patterns for unit tests, mocked API calls, and integration tests.

## Testing philosophy: behavior, not implementation

React Testing Library (RTL) is built around one guiding principle: **the more your tests resemble the way your software is used, the more confidence they give you.** That means tests should interact with the rendered output the way a user would: find text, click buttons, fill inputs. They shouldn't reach into component internals.

```tsx
// Bad: tests implementation detail (state variable name, internal method)
test("counter increments — brittle version", () => {
  const wrapper = shallow(<Counter />);
  wrapper.instance().setState({ count: 1 });
  expect(wrapper.instance().state.count).toBe(1);
});

// Good: tests behavior a user actually experiences
test("counter increments when button is clicked", async () => {
  render(<Counter />);
  const user = userEvent.setup();

  expect(screen.getByText("Count: 0")).toBeInTheDocument();
  await user.click(screen.getByRole("button", { name: /increment/i }));
  expect(screen.getByText("Count: 1")).toBeInTheDocument();
});
```

The bad version breaks if you rename `count` to `value` even though the feature still works perfectly. The good version only breaks if the actual user-facing behavior breaks, which is the whole point.

## Query priority

RTL exposes many ways to find elements. They're ranked by how closely they match how a real user, including someone using assistive technology, finds things. Use this order:

1. **`getByRole`**: matches accessibility tree role (`button`, `textbox`, `heading`). Preferred almost always; forces you to use accessible markup.
2. **`getByLabelText`**: for form fields, matches how a screen reader user finds an input via its label.
3. **`getByPlaceholderText`**, **`getByText`**: reasonable fallbacks for non-interactive or unlabeled content.
4. **`getByTestId`**: last resort, only when nothing else identifies the element, such as a decorative element with no accessible name.

```tsx
// Preferred
screen.getByRole("button", { name: /submit/i });
screen.getByLabelText(/email address/i);

// Fallback only when there's no accessible way to target the element
screen.getByTestId("loading-spinner");
```

**Interview detail:** `getBy*` throws if not found, so use it for assertions that something exists. `queryBy*` returns `null` instead of throwing, so use it to assert something is absent. `findBy*` is async and retries until timeout, so use it when waiting for something to appear after an async action.

```tsx
// Asserting absence — must use queryBy, getBy would throw before you can assert
expect(screen.queryByText("Error")).not.toBeInTheDocument();

// Waiting for async appearance — must use findBy
const successMessage = await screen.findByText("Saved!");
expect(successMessage).toBeInTheDocument();
```

## Unit test for a component

```tsx
// LoginForm.tsx
interface LoginFormProps {
  onSubmit: (email: string, password: string) => void;
}

function LoginForm({ onSubmit }: LoginFormProps) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.includes("@")) {
      setError("Enter a valid email");
      return;
    }
    setError("");
    onSubmit(email, password);
  };

  return (
    <form onSubmit={handleSubmit}>
      <label htmlFor="email">Email</label>
      <input id="email" value={email} onChange={(e) => setEmail(e.target.value)} />

      <label htmlFor="password">Password</label>
      <input
        id="password"
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />

      {error && <p role="alert">{error}</p>}
      <button type="submit">Log in</button>
    </form>
  );
}
```

```tsx
// LoginForm.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LoginForm } from "./LoginForm";

describe("LoginForm", () => {
  test("submits email and password when valid", async () => {
    const handleSubmit = vi.fn(); // or jest.fn()
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

Note `userEvent` over `fireEvent`. `userEvent` simulates a real user interaction sequence (focus, keydown, keypress, keyup, and an input event for each character typed) while `fireEvent` dispatches a single raw DOM event. `userEvent` catches bugs `fireEvent` can't, like a component that only works because you skipped the focus event.

## Mocking API calls

The standard modern approach is **Mock Service Worker (MSW)**. It intercepts requests at the network level, so your component code makes real `fetch` calls and has no idea it's being tested. This is more resilient than mocking `fetch` directly, because it doesn't couple the test to how the component fetches data.

```bash
npm install --save-dev msw
```

```ts
// mocks/handlers.ts
import { http, HttpResponse } from "msw";

export const handlers = [
  http.get("/api/users/:id", ({ params }) => {
    return HttpResponse.json({ id: params.id, name: "Jane Doe" });
  }),

  http.post("/api/login", async ({ request }) => {
    const body = await request.json();
    if (body.password === "wrong") {
      return HttpResponse.json({ error: "Invalid credentials" }, { status: 401 });
    }
    return HttpResponse.json({ token: "fake-jwt-token" });
  }),
];
```

```ts
// mocks/server.ts — for Node/Vitest/Jest test environment
import { setupServer } from "msw/node";
import { handlers } from "./handlers";

export const server = setupServer(...handlers);
```

```ts
// setupTests.ts
import { server } from "./mocks/server";

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

```tsx
// UserProfile.test.tsx
import { render, screen } from "@testing-library/react";
import { http, HttpResponse } from "msw";
import { server } from "../mocks/server";
import { UserProfile } from "./UserProfile";

test("shows user name after loading", async () => {
  render(<UserProfile userId="42" />);

  expect(screen.getByText(/loading/i)).toBeInTheDocument();
  expect(await screen.findByText("Jane Doe")).toBeInTheDocument();
});

test("shows an error state when the API fails", async () => {
  // Override the handler for just this test
  server.use(
    http.get("/api/users/:id", () => {
      return HttpResponse.json({ error: "Not found" }, { status: 404 });
    })
  );

  render(<UserProfile userId="42" />);
  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

## Integration test for a user flow

An integration test exercises multiple components together through a realistic sequence of user actions. It's closer to an end-to-end test but still runs in the fast, mocked-network jsdom environment rather than a real browser.

```tsx
// checkout flow: browse → add to cart → checkout → confirmation
test("user can complete checkout", async () => {
  const user = userEvent.setup();
  render(<App />, { wrapper: AppProviders }); // router, query client, etc.

  // Browse to a product
  await user.click(screen.getByRole("link", { name: /wireless headphones/i }));
  expect(await screen.findByRole("heading", { name: /wireless headphones/i })).toBeInTheDocument();

  // Add to cart
  await user.click(screen.getByRole("button", { name: /add to cart/i }));
  expect(screen.getByText(/1 item in cart/i)).toBeInTheDocument();

  // Go to checkout
  await user.click(screen.getByRole("link", { name: /cart/i }));
  await user.click(screen.getByRole("button", { name: /checkout/i }));

  // Fill shipping info
  await user.type(screen.getByLabelText(/full name/i), "Jane Doe");
  await user.type(screen.getByLabelText(/address/i), "123 Main St");
  await user.click(screen.getByRole("button", { name: /place order/i }));

  // Confirmation
  expect(await screen.findByText(/order confirmed/i)).toBeInTheDocument();
});
```

This test doesn't care how cart state is stored, whether that's Context, Redux, or Zustand. It only cares that clicking "add to cart" eventually leads to a confirmation screen. That's exactly the resilience to refactoring that RTL's philosophy aims for.

## Coverage vs. quality

Coverage percentage measures lines executed, not behavior verified. A test that renders a component and asserts nothing achieves 100% line coverage on that component and catches zero bugs.

```tsx
// Contributes to coverage, catches nothing
test("renders without crashing", () => {
  render(<Checkout />);
});
```

What actually matters:

- **Coverage as a floor, not a target.** Use it to find completely untested code paths, like a branch nobody ever hit, not as a quality score to maximize.
- **Test the risky paths deliberately.** Validation logic, error states, and edge cases (empty list, network failure, race conditions) deserve more attention than chasing percentage on straightforward render paths.
- **Mutation testing** (tools like Stryker) is the more honest signal. It mutates your source code, flipping a `<` to `<=` or deleting a line, and checks whether any test fails. A test that still passes after a mutation isn't actually verifying that code. Worth mentioning if an interviewer pushes on how you know your coverage number means anything.

The interview-safe answer to "what coverage percentage do you target": there's no universal number. Critical business logic (payments, auth, data mutations) should be close to fully covered with meaningful assertions; low-risk presentational code doesn't need the same investment. Chasing a blanket 100% target usually produces exactly the kind of hollow tests shown above.
