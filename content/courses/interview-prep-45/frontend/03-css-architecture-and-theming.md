---
kind: lesson
id_key: interview-prep-45/day-22-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "CSS Architecture and Theming"
position: 3
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
A five-file prototype survives any CSS approach. What separates the options covered here is what happens at file two hundred: whether class names collide, whether a theme change means a re-render, whether the CSS bundle grows forever or plateaus. None of these approaches is "the best" one, and pretending otherwise is usually the wrong answer in an interview. What matters is knowing the actual trade-offs well enough to pick the right one for a given team and app.

## BEM: discipline, not tooling

Block-Element-Modifier is just a naming convention. It needs no build step and works in a plain `.css` file, which is exactly why it predates every other option here.

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

The strength is zero tooling and self-documenting relationships in the class name itself. The weakness is that nothing actually enforces scoping: another file can define its own `.card__title` and silently collide with yours. BEM only works as well as everyone's discipline holds, and that discipline is the first thing to erode once a codebase has more than one team touching it.

## CSS Modules: scoping enforced by the build

CSS Modules solve exactly the problem BEM can't: every class name is scoped to its own file automatically, compiled to a hashed name at build time.

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

`.card` compiles to something like `.Card_card__a1b2c`, so a class named `card` in a completely unrelated file can never collide with this one, no naming convention required to make that true. It's the default in both Next.js and Vite with zero configuration, which is a big part of why it's such a common starting point.

## CSS-in-JS, and the runtime cost that changed the ecosystem

Libraries like styled-components and Emotion let you write CSS directly in TypeScript, colocated with the component, with full access to props and theme values.

```tsx
const Card = styled.div<{ $featured?: boolean }>`
  border-radius: 8px;
  border: ${(props) => (props.$featured ? "2px solid gold" : "1px solid #ddd")};
`;
```

The part worth naming precisely, because it's what actually pushed the ecosystem to change: the classic version of this approach parses those template literals and injects `<style>` tags at runtime, in the browser, on every render where a dynamic style changes. That costs real JS parsing time on the client, complicates SSR (style extraction has to happen server-side and reconcile with what the client injects, which is why styled-components needed its own Babel plugin just to avoid a flash of unstyled content), and makes bundlers' job harder, since dynamically generated class names resist tree shaking and critical-CSS extraction.

That cost is exactly why the industry moved toward **zero-runtime CSS-in-JS**, vanilla-extract, Panda CSS, and styled-components' own newer compiler mode among them, which extract styles to static CSS files at build time instead of runtime. You keep the ergonomics of writing CSS next to your component; you lose the browser-side parsing tax. Being able to name this shift, and why it happened, reads as someone who's tracked the ecosystem rather than someone reciting which library is currently popular.

## Atomic CSS: composing utilities instead of writing new rules

Tailwind is the dominant example: small, single-purpose classes composed directly in markup, instead of authoring new CSS per component.

```tsx
<div className={`rounded-lg p-4 ${featured ? "border-2 border-yellow-400" : "border border-gray-200"}`}>
  <h3 className="text-xl font-semibold">Title</h3>
</div>
```

The upside is real: the utility set is finite and shared across the entire app, so unlike a hand-written stylesheet, the CSS bundle plateaus instead of growing linearly with every new component (Tailwind also purges anything unused at build time). There's also no more debating what to name a wrapper `<div>`, and no specificity conflicts, since utility classes are single-property and roughly equal weight. The cost is markup that reads noisier, and a genuine onboarding curve for anyone used to styling in a separate stylesheet rather than inline in JSX.

## Design tokens and a theme that doesn't need a re-render

Design tokens are the named, centralized values, colors, spacing, radii, that both design and code point to instead of scattering hardcoded values through the codebase. CSS custom properties are the natural way to implement a theme that can change at runtime, because unlike a Sass variable, a `--variable` is resolved in the browser, not baked in at build time.

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

Notice there's no React re-render anywhere in that theme switch. Flipping the `data-theme` attribute makes the browser recompute styles for every element referencing a changed custom property, on its own, without React knowing or caring. Compare that to a JS-driven theme object passed through Context, where every consuming component genuinely re-renders on every theme change. For a value that changes as rarely as a light/dark toggle, CSS variables are the cheaper mechanism by a wide margin.

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

Two distinct responsive mechanisms are stacked here, and it's worth being able to tell them apart. `repeat(auto-fill, minmax(220px, 1fr))` gives you a reflowing grid with zero media queries: the number of columns is whatever fits, driven purely by available width. Container queries (`@container`) solve a different problem entirely: they let one component respond to *its own* box size, not the viewport's, which a media query structurally cannot do. A card component that needs to lay out differently depending on whether its parent gave it 300px or 900px, regardless of the overall screen size, is exactly the case container queries exist for.

## Actually picking one

If an interviewer asks which CSS approach is "correct," the useful answer names the actual constraints rather than a favorite: CSS Modules for a small team with no design-system ambitions and a Next.js or Vite setup that already supports it for free; Tailwind for a team that wants to move fast and skip naming debates entirely; a zero-runtime CSS-in-JS library for a design system that needs runtime theming without paying the classic styled-components performance tax. Scoping guarantees, runtime cost, markup verbosity, and theming story are the four axes the decision actually runs on, and naming those four is worth more than naming a winner.
