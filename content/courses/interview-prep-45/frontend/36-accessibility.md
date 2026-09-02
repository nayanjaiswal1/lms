---
kind: lesson
id_key: interview-prep-45/day-23-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Accessibility (a11y)"
position: 36
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Accessibility questions are increasingly standard in frontend interviews, and "use semantic HTML" without concrete mechanics is an easy place to lose points, it's true but it doesn't show you actually know how. This lesson covers WCAG's real structure, ARIA's rules, including when *not* to reach for it, keyboard navigation, and a fully accessible form built end to end.

## WCAG's shape

WCAG is organized around four principles, commonly remembered as **POUR**: **Perceivable** (alt text for images, captions for video, sufficient color contrast), **Operable** (keyboard-reachable, no seizure-inducing flashing, enough time to read or act), **Understandable** (predictable navigation, clear error messages, consistent labeling), and **Robust** (works with a wide range of user agents including assistive technology, which means valid, semantic markup that doesn't break screen-reader parsing).

Conformance levels are A (minimum), AA (the level virtually every legal requirement and company policy targets), and AAA (highest, rarely mandated in full). If asked what level to target, the correct answer is AA, the industry-standard bar.

## ARIA augments, it doesn't replace

The first rule of ARIA, literally called that in the spec, is: don't use ARIA if a native HTML element already gives you the semantics you need. ARIA attributes tell assistive technology about a role or state, but they grant none of the native *behavior*, keyboard handling, focus management, that comes free with a real element. This is the same ground the HTML fundamentals lesson covered from the other direction, reach for `<button>` before you reach for `role="button"`.

```tsx
// Bad: reinventing a button, and now you owe it keyboard support, focus, and role
// that a real <button> already gives you for free
<div className="btn" onClick={handleClick} role="button" tabIndex={0}
  onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleClick(); }}>
  Submit
</div>

// Good
<button className="btn" onClick={handleClick}>Submit</button>
```

Reach for ARIA specifically where native HTML genuinely has no equivalent:

```tsx
// A custom dropdown/combobox — no single native element covers this exactly
<div role="combobox" aria-expanded={isOpen} aria-haspopup="listbox" aria-controls="options-list">
  <input aria-autocomplete="list" aria-activedescendant={activeOptionId} />
</div>
<ul id="options-list" role="listbox">
  {options.map((opt) => <li key={opt.id} id={opt.id} role="option" aria-selected={opt.id === activeOptionId}>{opt.label}</li>)}
</ul>
```

```tsx
// Live regions — announce dynamic content changes without moving focus,
// e.g. a toast notification or an async validation result
<div aria-live="polite" aria-atomic="true">{statusMessage}</div>
// aria-live="assertive" interrupts immediately — reserve it for genuinely urgent/error messages
<div role="alert">{errorMessage}</div>
```

`role="alert"` implies `aria-live="assertive"` and `aria-atomic="true"` automatically, it's the shorthand specifically meant for error messages that need immediate announcement.

## Keyboard navigation and focus management

Every interactive element must be reachable and operable using only the keyboard, the single most common a11y bug in real apps is something clickable that a keyboard user simply cannot reach at all.

```tsx
function Modal({ onClose, children }: { onClose: () => void; children: React.ReactNode }) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previouslyFocused = useRef<HTMLElement | null>(null);

  useEffect(() => {
    previouslyFocused.current = document.activeElement as HTMLElement;
    const focusable = modalRef.current?.querySelectorAll<HTMLElement>('button, [href], input, [tabindex]:not([tabindex="-1"])');
    focusable?.[0]?.focus();

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
      if (e.key === "Tab" && focusable && focusable.length > 0) {
        const first = focusable[0], last = focusable[focusable.length - 1];
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
      }
    }
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      previouslyFocused.current?.focus(); // return focus to whatever triggered the modal — often missed
    };
  }, [onClose]);

  return <div role="dialog" aria-modal="true" ref={modalRef}>{children}</div>;
}
```

Three focus-management rules that get checked directly. Trap focus inside a modal while it's open, so `Tab` never escapes to the page behind it. Move focus to the modal on open and return it to the trigger element on close, losing focus back to `<body>` is a jarring, common bug. And `Escape` closes overlays, an expected keyboard convention across virtually every OS and app. One more rule that applies everywhere, not just modals: never set `outline: none` on a focusable element without providing a replacement focus style, removing the outline with nothing in its place makes keyboard navigation invisible, a genuinely common and easy-to-avoid regression.

Skip links are the other keyboard-navigation staple: a visually-hidden-until-focused link at the top of the page letting a keyboard user jump past repeated navigation straight to main content.

```tsx
<a href="#main-content" className="skip-link">Skip to main content</a>
{/* ... nav ... */}
<main id="main-content">...</main>
```

```css
.skip-link { position: absolute; top: -40px; left: 0; } /* hidden off-screen until focused */
.skip-link:focus { top: 0; }
```

## An accessible form, end to end

```tsx
function SignupForm() {
  const [email, setEmail] = useState(""), [password, setPassword] = useState("");
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});
  const [submitted, setSubmitted] = useState(false);

  function validate() {
    const next: typeof errors = {};
    if (!email.includes("@")) next.email = "Enter a valid email address.";
    if (password.length < 8) next.password = "Password must be at least 8 characters.";
    setErrors(next);
    return Object.keys(next).length === 0;
  }

  return (
    <form onSubmit={(e) => { e.preventDefault(); setSubmitted(true); if (validate()) { /* submit */ } }} noValidate>
      <div>
        {/* Explicit label association via htmlFor/id — required for screen readers */}
        <label htmlFor="email">Email address</label>
        <input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)}
          aria-invalid={submitted && !!errors.email}
          aria-describedby={errors.email ? "email-error" : undefined} required />
        {submitted && errors.email && <p id="email-error" role="alert">{errors.email}</p>}
      </div>
      <div>
        <label htmlFor="password">Password</label>
        <input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)}
          aria-invalid={submitted && !!errors.password}
          aria-describedby={errors.password ? "password-error password-hint" : "password-hint"} required />
        <p id="password-hint">Must be at least 8 characters.</p>
        {submitted && errors.password && <p id="password-error" role="alert">{errors.password}</p>}
      </div>
      <button type="submit">Create account</button>
    </form>
  );
}
```

Each piece here is doing specific, testable work. `htmlFor`/`id` pairing lets clicking the label focus the input, and a screen reader announces the label whenever the input receives focus, without it, the input announces as unlabeled entirely. `aria-invalid` tells assistive technology a field currently fails validation, independent of any visual styling alone. `aria-describedby` links the input to its hint or error text, so a screen reader reads that alongside the field's value, not just the bare label. `role="alert"` on the error text announces the failure immediately, with no need to navigate to it manually. `noValidate` on the form turns off the browser's native validation UI so you can fully control the accessible error experience instead of getting an inconsistent, browser-native tooltip layered on top.

## Contrast is a number, not a feeling

WCAG AA requires a contrast ratio of **4.5:1** for normal text and **3:1** for large text (18pt+, or 14pt+ bold) and UI components. This is a hard numeric threshold, check it with DevTools' contrast checker in the color picker, or a tool like WebAIM's.

```css
.text { color: #999; background: #fff; } /* fails AA, ~2.85:1 */
.text { color: #767676; background: #fff; } /* passes AA, ~4.6:1 */
```

A designer picking brand colors for text on a brand-colored background without checking contrast is one of the most frequent real-world a11y bugs, and a common interview scenario: given a mockup with light gray text on white, name the issue.

## Testing it for real

Every major OS ships a screen reader: **VoiceOver** (macOS/iOS), **NVDA** (free, Windows), **JAWS** (Windows, paid), **TalkBack** (Android). The genuinely useful workflow: close your eyes, or turn off the monitor, and try to complete the task using only the screen reader and keyboard, this surfaces missing labels, bad heading order, and unreachable controls fast. Check that heading structure is logical and sequential, `h1` → `h2` → `h3`, no skipped levels, since screen reader users frequently navigate by heading rather than reading top to bottom. Automated tools, `axe-core`, Lighthouse's accessibility audit, `eslint-plugin-jsx-a11y`, catch roughly 30-40% of real issues, missing alt text, contrast failures, invalid ARIA, necessary but not sufficient. Manual keyboard and screen-reader testing catches what automation structurally can't: illogical reading order, unclear error messaging, whether a flow is actually usable end to end.

```bash
npm install --save-dev eslint-plugin-jsx-a11y
```

```json
{ "extends": ["plugin:jsx-a11y/recommended"] }
```

The pattern running through every section here: native elements first, ARIA only for what HTML genuinely can't express, and manual testing to catch what linters and automated audits structurally miss.
