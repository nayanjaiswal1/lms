---
kind: lesson
id_key: interview-prep-45/day-23-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 23 — Accessibility (a11y)"
position: 26
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Accessibility questions are increasingly standard in frontend interviews, and they're an easy place to lose points by giving a vague answer ("use semantic HTML") without concrete mechanics. Today covers WCAG's actual structure, ARIA's rules (including when not to use it), keyboard navigation, and a fully accessible form built end to end.

## WCAG: the shape of the guidelines

WCAG (Web Content Accessibility Guidelines) is organized around four principles, commonly remembered as **POUR**:

- **Perceivable** — content must be presentable in ways users can perceive (alt text for images, captions for video, sufficient color contrast).
- **Operable** — interface components must be operable (keyboard-reachable, no seizure-inducing flashing, enough time to read/interact).
- **Understandable** — content and operation must be understandable (predictable navigation, clear error messages, consistent labeling).
- **Robust** — content must work with a wide range of user agents, including assistive technology (valid, semantic markup that doesn't break screen reader parsing).

Conformance levels are A (minimum), AA (the level virtually every legal requirement and company policy targets), and AAA (highest, rarely mandated in full). If an interviewer asks "what level do you target," the correct answer is AA — that's the industry-standard bar.

## ARIA: augment, don't replace

The **first rule of ARIA** (literally called that in the spec) is: **don't use ARIA if a native HTML element already gives you the semantics you need.** ARIA attributes tell assistive technology about a role/state, but they don't grant any of the native behavior (keyboard handling, focus management) that comes for free with real elements.

```tsx
// Bad: reinventing a button, and now you owe it keyboard support, focus,
// and role that a real <button> already has
<div className="btn" onClick={handleClick} role="button" tabIndex={0}
  onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleClick(); }}>
  Submit
</div>

// Good: all of the above is free
<button className="btn" onClick={handleClick}>Submit</button>
```

Use ARIA for cases native HTML genuinely can't express:

```tsx
// A custom dropdown/combobox — no single native element covers this exactly
<div role="combobox" aria-expanded={isOpen} aria-haspopup="listbox" aria-controls="options-list">
  <input aria-autocomplete="list" aria-activedescendant={activeOptionId} />
</div>
<ul id="options-list" role="listbox">
  {options.map((opt) => (
    <li key={opt.id} id={opt.id} role="option" aria-selected={opt.id === activeOptionId}>
      {opt.label}
    </li>
  ))}
</ul>
```

```tsx
// Live regions — announce dynamic content changes to screen readers
// without moving focus, e.g. a toast notification or async validation result
<div aria-live="polite" aria-atomic="true">
  {statusMessage}
</div>

// aria-live="assertive" interrupts immediately — reserve for urgent/error
// messages only, overusing it is disorienting for screen reader users
<div role="alert">{errorMessage}</div>
```

`role="alert"` implies `aria-live="assertive"` and `aria-atomic="true"` automatically — it's the shorthand for error messages that must be announced immediately.

## Keyboard navigation and focus management

Every interactive element must be reachable and operable using only the keyboard — this is the single most common a11y bug: something clickable that a keyboard user simply cannot reach.

```tsx
// Focus trap for a modal — Tab/Shift+Tab must cycle within the modal,
// not escape into the page behind it
function Modal({ onClose, children }: { onClose: () => void; children: React.ReactNode }) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previouslyFocused = useRef<HTMLElement | null>(null);

  useEffect(() => {
    previouslyFocused.current = document.activeElement as HTMLElement;
    const modal = modalRef.current;
    const focusable = modal?.querySelectorAll<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    focusable?.[0]?.focus();

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
      if (e.key === "Tab" && focusable && focusable.length > 0) {
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      // Return focus to whatever triggered the modal — critical, often missed
      previouslyFocused.current?.focus();
    };
  }, [onClose]);

  return (
    <div role="dialog" aria-modal="true" ref={modalRef}>
      {children}
    </div>
  );
}
```

The three focus-management rules interviewers listen for:

1. **Trap focus inside a modal/dialog** while it's open (Tab shouldn't escape to the page behind it).
2. **Move focus to the modal on open** and **return focus to the trigger element on close** — losing focus back to `<body>` is a common, jarring bug.
3. **`Escape` closes overlays** — expected keyboard convention across virtually every OS and app.

Skip links are another keyboard-navigation staple: a visually-hidden-until-focused link at the top of the page that lets keyboard users jump past repeated navigation straight to main content.

```tsx
<a href="#main-content" className="skip-link">Skip to main content</a>
{/* ... nav ... */}
<main id="main-content">...</main>
```

```css
.skip-link {
  position: absolute;
  top: -40px; /* hidden off-screen until focused */
  left: 0;
}
.skip-link:focus {
  top: 0; /* becomes visible on keyboard focus */
}
```

## An accessible form, end to end

```tsx
function SignupForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [submitted, setSubmitted] = useState(false);

  function validate() {
    const next: typeof errors = {};
    if (!email.includes("@")) next.email = "Enter a valid email address.";
    if (password.length < 8) next.password = "Password must be at least 8 characters.";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSubmitted(true);
    if (validate()) {
      // submit
    }
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div>
        {/* Explicit label association via htmlFor/id — required for screen readers */}
        <label htmlFor="email">Email address</label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          aria-invalid={submitted && !!errors.email}
          aria-describedby={errors.email ? "email-error" : undefined}
          required
        />
        {submitted && errors.email && (
          <p id="email-error" role="alert">{errors.email}</p>
        )}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          aria-invalid={submitted && !!errors.password}
          aria-describedby={errors.password ? "password-error password-hint" : "password-hint"}
          required
        />
        <p id="password-hint">Must be at least 8 characters.</p>
        {submitted && errors.password && (
          <p id="password-error" role="alert">{errors.password}</p>
        )}
      </div>

      <button type="submit">Create account</button>
    </form>
  );
}
```

What each piece is doing, and why it's tested in interviews:

- `htmlFor`/`id` pairing — clicking or tapping the label focuses the input, and a screen reader announces the label whenever the input receives focus. Without it, the input is announced as unlabeled.
- `aria-invalid` — tells assistive technology the field currently fails validation, independent of any visual styling.
- `aria-describedby` — links the input to its hint/error text, so screen readers read the error/hint alongside the field's value, not just the label.
- `role="alert"` on the error text — announces the validation failure immediately without requiring the user to navigate to it manually.
- `noValidate` on the form — turns off the browser's native validation UI so you can fully control the accessible error experience instead of getting an inconsistent browser-native tooltip.

## Color contrast

WCAG AA requires a contrast ratio of **4.5:1** for normal text and **3:1** for large text (18pt+/14pt+ bold) and UI components/graphical objects. This is a hard numeric threshold, not a subjective "looks readable" judgment — check it with DevTools' contrast checker (in the color picker) or a tool like WebAIM's contrast checker.

```css
/* Fails AA for normal text — ratio ~2.85:1 */
.text { color: #999; background: #fff; }

/* Passes AA — ratio ~4.6:1 */
.text { color: #767676; background: #fff; }
```

Common trap: designers pick brand colors for text on brand-colored backgrounds without checking contrast — this is one of the most frequent real-world a11y bugs and a common interview scenario ("here's a mockup with light gray text on white, what's the issue").

## Screen reader testing

You don't need a dedicated device to test — every major OS ships a screen reader: **VoiceOver** (macOS/iOS, `Cmd+F5`), **NVDA** (free, Windows), **JAWS** (Windows, paid), **TalkBack** (Android). The interview-relevant workflow:

1. Turn off the monitor (or close your eyes) and try to complete the task using only the screen reader and keyboard — this surfaces missing labels, bad heading order, and unreachable interactive elements fast.
2. Check heading structure is logical and sequential (`h1` → `h2` → `h3`, no skipped levels) — screen reader users frequently navigate by heading, not by reading top to bottom.
3. Automated tools (`axe-core`, Lighthouse's accessibility audit, `eslint-plugin-jsx-a11y`) catch roughly 30-40% of real issues (missing alt text, contrast failures, invalid ARIA) — they are necessary but not sufficient; manual keyboard/screen-reader testing catches what automation structurally cannot (illogical reading order, unclear error messaging, whether a flow is actually usable).

```bash
npm install --save-dev eslint-plugin-jsx-a11y
```

```json
// .eslintrc — catches missing alt text, invalid ARIA usage, etc. at lint time
{
  "extends": ["plugin:jsx-a11y/recommended"]
}
```

## Key takeaways

- WCAG is organized as POUR (Perceivable, Operable, Understandable, Robust); AA is the conformance level virtually every real-world requirement targets.
- The first rule of ARIA: don't use it where a native element already provides the semantics — `<button>` beats a `div` with `role="button"` and manually reimplemented keyboard handling every time.
- Modals need a focus trap, focus moved in on open, and focus returned to the trigger on close — this three-part cycle is the detail most candidates miss.
- `htmlFor`/`id`, `aria-invalid`, and `aria-describedby` are the specific mechanics that make a form's validation errors accessible, not just visually present.
- Color contrast is a hard numeric threshold (4.5:1 normal text, 3:1 large text/UI) under WCAG AA — verify it, don't eyeball it.
- Automated tools (axe, Lighthouse, `eslint-plugin-jsx-a11y`) catch a meaningful minority of issues; manual keyboard and screen reader testing is what catches the rest.

## Today's checklist

- [ ] Read: WCAG guidelines
- [ ] Implement: Accessible form components
- [ ] Implement: Screen reader testing
- [ ] Understand ARIA attributes and when not to use them
- [ ] Practice keyboard navigation and focus management (modal focus trap)
- [ ] Verify color contrast against WCAG AA thresholds
