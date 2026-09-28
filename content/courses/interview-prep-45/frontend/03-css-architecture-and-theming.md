---
kind: lesson
id_key: interview-prep-45/day-22-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "CSS Architecture and Theming"
position: 3
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
A five-file prototype survives any CSS approach you throw at it. What separates the options in this lesson is what happens at file two hundred: whether class names collide, whether a theme change forces a re-render, whether the CSS bundle keeps growing forever or levels off. None of these approaches is "the best" one, and treating one as a favorite is usually the wrong answer in an interview. What matters is knowing the real trade-offs well enough to pick the right one for a given team and app.

## BEM: discipline, not tooling

Block-Element-Modifier is a naming convention, nothing more. It needs no build step and works in a plain `.css` file, which is exactly why it predates every other option here.

```css
.card { border-radius: 8px; padding: 16px; }               /* Block */
.card__title { font-size: 1.25rem; font-weight: 600; }     /* Element, connected with __ */
.card--featured { border: 2px solid gold; }                /* Modifier, connected with -- */
```

```tsx
<div className="card card--featured">
  <h3 className="card__title">Featured Post</h3>
</div>
```

The strength is zero tooling, and a class name that documents its own relationships. The weakness is that nothing actually enforces the scoping: another file can define its own `.card__title` and silently collide with yours. BEM only works as well as everyone's discipline holds, and that discipline is the first thing to slip once more than one team touches the codebase.

> **Remember:** BEM is a naming convention, not a guarantee. Nothing stops a second file from reusing the same class name by accident.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-bem-q1", "type": "mcq",
      "prompt": "Two unrelated files both define a `.card__title` class under BEM. What actually prevents them from colliding?",
      "options": [
        {"id":"a","text":"BEM automatically namespaces class names at build time"},
        {"id":"b","text":"Nothing — BEM is purely a naming convention with no build-time scoping, so a collision is a real risk"},
        {"id":"c","text":"The browser refuses to load a duplicate class name"},
        {"id":"d","text":"BEM classes are scoped to their file by default"}
      ],
      "correct": "b",
      "explanation": "BEM is just a discipline for humans to follow when naming classes. It needs zero tooling precisely because it adds no actual scoping mechanism." }
] }
```

## CSS Modules: scoping enforced by the build

CSS Modules solve exactly the problem BEM cannot: every class name gets scoped to its own file automatically, compiled to a hashed name at build time.

```css
/* Card.module.css */
.card { border-radius: 8px; padding: 16px; }
.featured { border: 2px solid gold; }
```

```tsx
import styles from "./Card.module.css";
import clsx from "clsx";

function Card({ featured }: { featured?: boolean }) {
  return <div className={clsx(styles.card, featured && styles.featured)}>...</div>;
}
```

`.card` compiles to something like `.Card_card__a1b2c`, so a class named `card` in a completely unrelated file can never collide with this one. No naming convention is needed to make that true; the build enforces it. It is the default in both Next.js and Vite with zero configuration, which is a big part of why it is such a common starting point.

> **Remember:** CSS Modules turn scoping from a human habit into a build-time guarantee.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-modules-q1", "type": "mcq",
      "prompt": "What actually stops a `.card` class in one CSS Module from colliding with a `.card` class in a completely different file?",
      "options": [
        {"id":"a","text":"Developer discipline, same as BEM"},
        {"id":"b","text":"The build tool hashes each class name to something unique per file, like `.Card_card__a1b2c`"},
        {"id":"c","text":"CSS Modules disallow the name 'card' entirely"},
        {"id":"d","text":"Nothing, collisions are still possible"}
      ],
      "correct": "b",
      "explanation": "The build step compiles each class into a unique, file-scoped hashed name, so two files can both write `.card` in their source and never collide in the shipped CSS." }
] }
```

## CSS-in-JS, and the runtime cost that changed the ecosystem

Libraries like styled-components and Emotion let you write CSS directly in TypeScript, next to the component, with full access to props and theme values.

```tsx
const Card = styled.div<{ $featured?: boolean }>`
  border-radius: 8px;
  border: ${(props) => (props.$featured ? "2px solid gold" : "1px solid #ddd")};
`;
```

Here is the detail worth naming precisely, because it is what actually pushed the ecosystem to change: the classic version of this approach parses those template literals and injects `<style>` tags at runtime, in the browser, on every render where a dynamic style changes. That costs real JS parsing time on the client, makes server-side rendering harder (style extraction has to happen on the server and reconcile with what the client injects, which is why styled-components needed its own build plugin just to avoid a flash of unstyled content), and makes a bundler's job harder, since dynamically generated class names resist tree shaking and critical-CSS extraction.

That cost is exactly why the industry moved toward **zero-runtime CSS-in-JS**: vanilla-extract, Panda CSS, and styled-components' own newer compiler mode, among others. These extract styles to static CSS files at build time instead of runtime. You keep the convenience of writing CSS next to your component; you drop the browser-side parsing tax. Naming this shift, and why it happened, reads as someone who has tracked the ecosystem, not someone reciting whichever library happens to be popular this year.

> **Remember:** the problem with classic CSS-in-JS was never the syntax, it was generating styles in the browser at runtime instead of once at build time.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-cssinjs-q1", "type": "mcq",
      "prompt": "What specific cost pushed the ecosystem from classic CSS-in-JS toward zero-runtime CSS-in-JS?",
      "options": [
        {"id":"a","text":"Classic CSS-in-JS couldn't access component props"},
        {"id":"b","text":"Classic CSS-in-JS parses styles and injects <style> tags in the browser at runtime, which costs JS parsing time and complicates server-side rendering"},
        {"id":"c","text":"Zero-runtime tools support more CSS properties"},
        {"id":"d","text":"Classic CSS-in-JS required jQuery"}
      ],
      "correct": "b",
      "explanation": "The runtime cost is the real issue: generating and injecting styles in the browser on every dynamic render, instead of once at build time. Zero-runtime tools keep the same developer ergonomics while moving that work to build time." }
] }
```

## Atomic CSS: composing utilities instead of writing new rules

Tailwind is the dominant example: small, single-purpose classes composed directly in markup, instead of authoring new CSS per component.

```tsx
<div className={`rounded-lg p-4 ${featured ? "border-2 border-yellow-400" : "border border-gray-200"}`}>
  <h3 className="text-xl font-semibold">Title</h3>
</div>
```

The upside is real: the utility set is finite and shared across the whole app, so unlike a hand-written stylesheet, the CSS bundle levels off instead of growing with every new component, and Tailwind purges anything unused at build time on top of that. There is also no more debating what to name a wrapper `<div>`, and no specificity conflicts, since every utility class touches one property and carries roughly equal weight. The cost is markup that reads noisier, and a real learning curve for anyone used to styling in a separate stylesheet instead of inline in JSX.

> **Remember:** a hand-written stylesheet grows with every component. A shared, finite utility set does not.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-atomic-q1", "type": "mcq",
      "prompt": "Why does a Tailwind-style utility CSS bundle tend to level off in size as an app grows, unlike a hand-written stylesheet?",
      "options": [
        {"id":"a","text":"Tailwind compresses CSS more aggressively than other tools"},
        {"id":"b","text":"The utility set is finite and shared across the whole app, and unused utilities are purged at build time, so new components mostly reuse existing classes instead of adding new rules"},
        {"id":"c","text":"Tailwind doesn't support custom styles at all"},
        {"id":"d","text":"It doesn't — utility CSS bundles grow just as fast"}
      ],
      "correct": "b",
      "explanation": "A hand-written stylesheet gets new rules for every new component. Utility classes are reused across components from a fixed, purged set, so growth flattens out." }
] }
```

## Design tokens and a theme that doesn't need a re-render

Design tokens are the named, central values, colors, spacing, radii, that both design and code point to, instead of scattering hardcoded values through the codebase. CSS custom properties are the natural way to build a theme that can change at runtime, because unlike a Sass variable, a `--variable` is resolved in the browser, not baked in at build time.

```css
:root {
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
  --space-3: 16px;
}
[data-theme="dark"] {
  --color-bg: #0f0f0f;
  --color-text: #f5f5f5;
}
```

```css
.card {
  background: var(--color-bg);
  color: var(--color-text);
  padding: var(--space-3);
}
```

```tsx
function ThemeToggle() {
  const [theme, setTheme] = useState<"light" | "dark">("light");
  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);
  return <button onClick={() => setTheme(t => t === "light" ? "dark" : "light")}>Toggle theme</button>;
}
```

Notice there is no React re-render anywhere in that theme switch. Flipping the `data-theme` attribute makes the browser recompute styles for every element referencing a changed custom property, on its own, with React never knowing or caring. Compare that to a JS-driven theme object passed through Context, where every consuming component genuinely re-renders on every theme change. For a value that changes as rarely as a light/dark toggle, CSS variables are the cheaper mechanism by a wide margin.

> **Remember:** flipping one HTML attribute lets the browser update every themed element on its own. No React re-render involved.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-tokens-q1", "type": "mcq",
      "prompt": "A theme toggle flips `document.documentElement.setAttribute('data-theme', 'dark')`, and every component using `var(--color-bg)` updates instantly. Why does this not require a React re-render?",
      "options": [
        {"id":"a","text":"React automatically detects DOM attribute changes and re-renders"},
        {"id":"b","text":"CSS custom properties are resolved by the browser itself; changing which values they point to makes the browser recompute affected styles directly, with no JavaScript re-render involved"},
        {"id":"c","text":"The theme toggle silently triggers a full page reload"},
        {"id":"d","text":"It does require a re-render, just a very fast one"}
      ],
      "correct": "b",
      "explanation": "CSS variables are a browser-native mechanism. The browser recomputes styles for anything referencing a changed custom property on its own, entirely outside React's render cycle." }
] }
```

## A responsive card grid, using both ideas at once

```css
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: var(--space-3);
}

@container (min-width: 320px) {
  .card { flex-direction: row; align-items: center; }
}
```

Two distinct responsive mechanisms are stacked here, and it is worth being able to tell them apart. `repeat(auto-fill, minmax(220px, 1fr))` gives you a reflowing grid with zero media queries: the number of columns is whatever fits, driven purely by available width. Container queries (`@container`) solve a different problem entirely: they let one component respond to *its own* box size, not the screen's, which a media query structurally cannot do. A card that needs to lay out differently depending on whether its parent gave it 300px or 900px, regardless of the overall screen size, is exactly the case container queries exist for.

> **Remember:** a media query answers "how big is the screen?" A container query answers "how big is my own box?"

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-container-q1", "type": "mcq",
      "prompt": "A card component needs to switch to a horizontal layout whenever its parent container is at least 320px wide, regardless of the overall screen size. What is the right tool?",
      "options": [
        {"id":"a","text":"A media query checking the viewport width"},
        {"id":"b","text":"A container query, since it responds to the component's own box size, not the screen"},
        {"id":"c","text":"JavaScript polling window.innerWidth"},
        {"id":"d","text":"grid-template-columns alone"}
      ],
      "correct": "b",
      "explanation": "Media queries only see the viewport. A component that needs to react to the size of its own container, independent of the screen, needs a container query." }
] }
```

## Actually picking one

If an interviewer asks which CSS approach is "correct," the strong answer names the actual constraints rather than a favorite: CSS Modules for a small team with no design-system ambitions on a Next.js or Vite setup that already supports it for free; Tailwind for a team that wants to move fast and skip naming debates entirely; a zero-runtime CSS-in-JS library for a design system that needs runtime theming without the classic styled-components performance tax. Scoping guarantees, runtime cost, markup verbosity, and theming story are the four axes the decision actually runs on. Naming those four is worth more than naming a winner.
