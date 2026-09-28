---
kind: lesson
id_key: interview-prep-45/day-23-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Accessibility"
position: 33
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Accessibility questions are now standard in frontend interviews, and answering "use semantic HTML" with no mechanics behind it is an easy place to lose points. It's true, but it doesn't show you actually know how or why. This lesson covers WCAG's real structure, ARIA's one big rule, keyboard navigation, and a fully accessible form built end to end.

## WCAG's shape

WCAG is organized around four principles, remembered by the acronym **POUR**: **Perceivable** (alt text for images, captions for video, enough color contrast), **Operable** (reachable by keyboard, no flashing that could trigger a seizure, enough time to read or act), **Understandable** (predictable navigation, clear error messages, consistent labels), and **Robust** (works with a wide range of assistive technology, which means markup that's valid and semantic enough not to confuse a screen reader).

Conformance has three levels: A (minimum), AA (the level virtually every legal requirement and company policy targets), and AAA (highest, rarely required in full). If asked what level to target, the answer is AA, the industry-standard bar.

> **Remember:** if asked what accessibility level to target, the answer is almost always AA.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-a11y-wcag-q1", "type": "mcq",
      "prompt": "What conformance level do virtually all legal requirements and company policies target?",
      "options": [
        {"id":"a","text":"Level A, the bare minimum"},
        {"id":"b","text":"Level AA, the industry-standard bar most requirements are actually written against"},
        {"id":"c","text":"Level AAA, the highest level"},
        {"id":"d","text":"There is no standard level"}
      ],
      "correct": "b",
      "explanation": "AA is the practical target almost everywhere. AAA is rarely mandated in full, and A alone falls short of what most policies actually require." }
] }
```

## ARIA adds to HTML, it doesn't replace it

The first rule of ARIA, literally written that way in the spec, is: don't use ARIA if a native HTML element already gives you what you need. ARIA attributes tell assistive technology about a role or a state, but they grant none of the native *behavior* that comes free with a real element, keyboard handling, focus management. Reach for `<button>` before you reach for `role="button"`.

```tsx
// Bad: reinventing a button, and now you owe it keyboard support, focus, and a role
// that a real <button> already gives you for free
<div className="btn" onClick={handleClick} role="button" tabIndex={0}
  onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") handleClick(); }}>
  Submit
</div>

// Good
<button className="btn" onClick={handleClick}>Submit</button>
```

Reach for ARIA specifically where HTML genuinely has no built-in equivalent:

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
// Live regions — announce dynamic content without moving focus,
// e.g. a toast notification or an async validation result
<div aria-live="polite" aria-atomic="true">{statusMessage}</div>
// aria-live="assertive" interrupts immediately — reserve it for genuinely urgent/error messages
<div role="alert">{errorMessage}</div>
```

`role="alert"` implies `aria-live="assertive"` and `aria-atomic="true"` automatically, it's the shorthand meant specifically for error messages that need to be announced right away.

> **Remember:** ARIA's own first rule is not to use ARIA if a native HTML element already does the job. A `<div role="button">` still owes you all the keyboard behavior a real `<button>` gives for free.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-a11y-aria-q1", "type": "mcq",
      "prompt": "A developer builds a clickable div with role=\"button\" instead of using a real <button> element. What are they still responsible for adding by hand?",
      "options": [
        {"id":"a","text":"Nothing, role=\"button\" gives it full button behavior automatically"},
        {"id":"b","text":"Keyboard focusability, activation on Enter/Space, and correct focus styling, all of which a real <button> gives for free"},
        {"id":"c","text":"Only visual styling"},
        {"id":"d","text":"A click handler, since role=\"button\" already handles keyboard events"}
      ],
      "correct": "b",
      "explanation": "ARIA roles only describe semantics to assistive technology. They grant none of a native element's actual keyboard behavior, which has to be rebuilt by hand, tabIndex, a keydown handler, focus styles, the moment you reach for a div instead." }
] }
```

## Keyboard navigation and focus management

Every interactive element must be reachable and usable with only a keyboard. The single most common real-world accessibility bug is something clickable that a keyboard user simply can't get to at all.

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
      previouslyFocused.current?.focus(); // return focus to whatever opened the modal — often missed
    };
  }, [onClose]);

  return <div role="dialog" aria-modal="true" ref={modalRef}>{children}</div>;
}
```

Three focus rules get checked directly in interviews. Trap focus inside a modal while it's open, so `Tab` never escapes to the page behind it. Move focus into the modal on open, and back to whatever triggered it on close, losing focus back to `<body>` is a jarring, common bug. And `Escape` closes overlays, an expected convention across virtually every app and OS. One more rule that applies everywhere, not only modals: never set `outline: none` on a focusable element without a replacement focus style, that removes the one visible sign of where keyboard focus is, a genuinely common and easy-to-avoid regression.

Skip links are the other keyboard staple: a link, hidden until focused, sitting at the very top of the page, that lets a keyboard user jump straight past repeated navigation to the main content.

```tsx
<a href="#main-content" className="skip-link">Skip to main content</a>
{/* ... nav ... */}
<main id="main-content">...</main>
```

```css
.skip-link { position: absolute; top: -40px; left: 0; } /* hidden off-screen until focused */
.skip-link:focus { top: 0; }
```

> **Remember:** removing an outline with `outline: none` and no replacement makes keyboard focus invisible. Always swap it for a visible focus style, never just delete it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-a11y-focus-q1", "type": "mcq",
      "prompt": "A modal opens, and focus moves inside it. What must happen when the modal closes?",
      "options": [
        {"id":"a","text":"Nothing, focus can stay wherever it happens to be"},
        {"id":"b","text":"Focus must return to whatever element triggered the modal opening; letting it fall back to <body> is a jarring, common bug"},
        {"id":"c","text":"Focus should move to the page's first link"},
        {"id":"d","text":"The page should scroll to the top"}
      ],
      "correct": "b",
      "explanation": "A keyboard or screen-reader user needs to land back exactly where they were before the modal opened. Losing focus to <body> forces them to re-navigate the whole page to find their place again." }
] }
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

Each piece here does specific, testable work. `htmlFor`/`id` pairing lets clicking a label focus its input, and a screen reader announces the label the moment the input receives focus. Without it, the input announces as unlabeled entirely. `aria-invalid` tells assistive technology a field currently fails validation, independent of any visual styling alone. `aria-describedby` links an input to its hint or error text, so a screen reader reads that alongside the field, not just the bare label. `role="alert"` on the error text announces the failure right away, with no need to navigate to it manually. `noValidate` on the form turns off the browser's own validation popups, so you can fully control the accessible error experience instead of getting an inconsistent browser tooltip on top.

> **Remember:** `aria-describedby` is what lets a screen reader read a hint or error alongside a field, not just its label.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-a11y-form-q1", "type": "mcq",
      "prompt": "What does aria-describedby=\"password-error password-hint\" actually accomplish on a password input?",
      "options": [
        {"id":"a","text":"It validates the password's length automatically"},
        {"id":"b","text":"It links the input to both pieces of text so a screen reader reads them alongside the field, not just the bare label"},
        {"id":"c","text":"It hides the hint text visually"},
        {"id":"d","text":"It has no effect without aria-invalid also being set"}
      ],
      "correct": "b",
      "explanation": "aria-describedby connects an input to supplementary text elsewhere in the DOM, so assistive technology announces that text together with the field, exactly like the hint and error here." }
] }
```

## Contrast is a number, not a feeling

WCAG AA requires a contrast ratio of **4.5:1** for normal text and **3:1** for large text (18pt and up, or 14pt and up bold) and UI components. This is a hard numeric threshold, check it with DevTools' color picker or a tool like WebAIM's.

```css
.text { color: #999; background: #fff; } /* fails AA, about 2.85:1 */
.text { color: #767676; background: #fff; } /* passes AA, about 4.6:1 */
```

A designer picking brand colors for text on a brand-colored background without checking contrast is one of the most common real-world accessibility bugs, and a common interview scenario: given a mockup with light gray text on white, name the issue.

## Testing it for real

Every major operating system ships a screen reader: **VoiceOver** (macOS/iOS), **NVDA** (free, Windows), **JAWS** (Windows, paid), **TalkBack** (Android). The genuinely useful exercise: close your eyes, or turn off the monitor, and try to complete a task using only the screen reader and keyboard. This surfaces missing labels, a confusing heading order, and unreachable controls fast. Check that headings step down logically, `h1` then `h2` then `h3`, with nothing skipped, since screen reader users often navigate by heading instead of reading top to bottom.

Automated tools, `axe-core`, Lighthouse's accessibility audit, `eslint-plugin-jsx-a11y`, catch roughly 30 to 40 percent of real issues, missing alt text, contrast failures, invalid ARIA. Necessary, but not enough on their own. Manual keyboard and screen-reader testing catches what automation structurally can't: a confusing reading order, unclear error messages, whether a flow is actually usable start to finish.

```bash
npm install --save-dev eslint-plugin-jsx-a11y
```

```json
{ "extends": ["plugin:jsx-a11y/recommended"] }
```

> **Remember:** automated tools catch roughly a third of real accessibility issues. The rest only surface when a person actually tries the page with a keyboard and a screen reader.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-a11y-testing-q1", "type": "mcq",
      "prompt": "Automated tools like axe-core and Lighthouse pass a page with no accessibility errors. Does that mean the page is fully accessible?",
      "options": [
        {"id":"a","text":"Yes, automated tools catch every real accessibility problem"},
        {"id":"b","text":"No — automated tools catch roughly 30-40% of real issues like missing labels and contrast failures, but a confusing reading order or unclear error messaging only surfaces through manual keyboard and screen-reader testing"},
        {"id":"c","text":"Yes, as long as the page also passes a visual design review"},
        {"id":"d","text":"No, automated tools catch nothing useful at all"}
      ],
      "correct": "b",
      "explanation": "Automated audits are necessary but not sufficient. They can check for missing attributes and contrast ratios mechanically, but they can't judge whether a flow actually makes sense to a real screen-reader user." }
] }
```
