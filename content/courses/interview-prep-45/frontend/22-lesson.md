---
kind: lesson
id_key: interview-prep-45/day-22-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "CSS Architecture"
position: 25
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

CSS architecture questions come up whenever an interviewer wants to know if you can keep styles maintainable past a five-file prototype. Today covers the major approaches — BEM, CSS Modules, CSS-in-JS, Atomic CSS — their real trade-offs, and how to build a themeable, responsive component with design tokens.

## BEM

Block-Element-Modifier is a naming convention, not a tool — it works with plain CSS and adds structure by encoding relationships in class names.

```css
/* Block: standalone component */
.card { border-radius: 8px; padding: 16px; }

/* Element: a part of the block, connected with __ */
.card__title { font-size: 1.25rem; font-weight: 600; }
.card__body { color: #555; }

/* Modifier: a variant, connected with -- */
.card--featured { border: 2px solid gold; }
.card__title--large { font-size: 1.5rem; }
```

```tsx
<div className="card card--featured">
  <h3 className="card__title card__title--large">Featured Post</h3>
  <p className="card__body">...</p>
</div>
```

Strength: zero tooling, works anywhere, self-documenting relationships. Weakness: no true scoping — nothing stops another file from defining `.card__title` and colliding; discipline is the only enforcement, which breaks down at scale.

## CSS Modules

CSS Modules solve BEM's scoping problem at build time — every class name is locally scoped to the file by default, compiled to a unique hash.

```css
/* Card.module.css */
.card {
  border-radius: 8px;
  padding: 16px;
}
.title {
  font-size: 1.25rem;
  font-weight: 600;
}
.featured {
  border: 2px solid gold;
}
```

```tsx
import styles from "./Card.module.css";
import clsx from "clsx";

function Card({ title, featured }: { title: string; featured?: boolean }) {
  return (
    <div className={clsx(styles.card, featured && styles.featured)}>
      <h3 className={styles.title}>{title}</h3>
    </div>
  );
}
```

At build time, `.card` compiles to something like `.Card_card__a1b2c`, guaranteeing no cross-file collisions without any naming convention discipline required. This is the default in Next.js and Vite with zero extra config, which is why it's a common baseline choice.

## CSS-in-JS and its runtime cost

Libraries like styled-components and Emotion let you write CSS directly in JavaScript/TypeScript, colocated with the component and able to reference props and theme values directly.

```tsx
import styled from "styled-components";

const Card = styled.div<{ $featured?: boolean }>`
  border-radius: 8px;
  padding: 16px;
  border: ${(props) => (props.$featured ? "2px solid gold" : "1px solid #ddd")};
`;

function ProductCard({ featured }: { featured?: boolean }) {
  return <Card $featured={featured}>...</Card>;
}
```

**The runtime cost interviewers want you to name:** traditional CSS-in-JS libraries parse template literals and inject `<style>` tags *at runtime*, in the browser, on every render where a dynamic style changes. This adds:

- A JS parsing/serialization cost on the client that plain CSS or CSS Modules don't have.
- Extra work during SSR — style extraction has to happen server-side and be reconciled with what the client injects, which is why styled-components needed a Babel plugin and careful SSR setup to avoid a flash of unstyled content.
- Harder static analysis for bundlers — dynamic class generation makes tree shaking and critical CSS extraction harder than build-time CSS.

The industry has moved toward **zero-runtime CSS-in-JS** (vanilla-extract, Panda CSS, Linaria, styled-components' own newer compiler mode) which extracts styles to static CSS files at *build* time, keeping the developer ergonomics of CSS-in-JS without the runtime cost. Naming this shift is a strong signal in an interview — it shows you're tracking why the ecosystem moved, not just which library is popular.

## Atomic CSS (Tailwind)

Atomic CSS uses small, single-purpose utility classes composed directly in markup instead of writing new CSS per component.

```tsx
function Card({ featured }: { featured?: boolean }) {
  return (
    <div
      className={`rounded-lg p-4 ${featured ? "border-2 border-yellow-400" : "border border-gray-200"}`}
    >
      <h3 className="text-xl font-semibold">Title</h3>
    </div>
  );
}
```

Trade-offs to articulate:

- **Pro:** no unbounded CSS file growth — the utility set is finite and shared across the whole app, so the CSS bundle size plateaus as the app grows (Tailwind's build step also purges unused classes).
- **Pro:** no naming invention required (no more debating what to call a wrapper div's class) and no risk of specificity conflicts, since utility classes are single-property and roughly equal specificity.
- **Con:** markup gets visually noisy, and repeated utility combinations across files need extraction into components (or `@apply` in Tailwind) to stay DRY.
- **Con:** the mental model shift (styling in JSX/markup instead of a separate stylesheet) is a real onboarding cost for teams used to traditional CSS.

## Design tokens and a theme system with CSS variables

Design tokens are the named, centralized values (colors, spacing, radii, font sizes) that back a design system — the goal is one source of truth that both design and code reference, instead of hardcoded magic values scattered through the codebase.

CSS custom properties (`--variables`) are the natural implementation for a runtime-swappable theme, because unlike Sass variables they're resolved in the browser, not at build time — so they can change based on a class or media query without recompiling any CSS.

```css
/* tokens.css */
:root {
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
  --color-primary: #2563eb;
  --color-border: #e5e7eb;

  --space-1: 4px;
  --space-2: 8px;
  --space-3: 16px;
  --space-4: 24px;

  --radius-md: 8px;
  --font-size-base: 1rem;
}

[data-theme="dark"] {
  --color-bg: #0f0f0f;
  --color-text: #f5f5f5;
  --color-primary: #60a5fa;
  --color-border: #2a2a2a;
}
```

```css
/* Card.module.css — consumes tokens, never hardcodes values */
.card {
  background: var(--color-bg);
  color: var(--color-text);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: var(--space-3);
}
```

```tsx
// ThemeToggle.tsx — flips the data-theme attribute, CSS vars cascade instantly
function ThemeToggle() {
  const [theme, setTheme] = useState<"light" | "dark">("light");

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  return (
    <button onClick={() => setTheme((t) => (t === "light" ? "dark" : "light"))}>
      Switch to {theme === "light" ? "dark" : "light"} mode
    </button>
  );
}
```

No React re-render is required for the visual theme change — the browser recomputes styles for every element referencing a changed custom property the moment the attribute flips. This is a meaningfully cheaper theme-switch mechanism than a JS-driven CSS-in-JS theme object passed through Context, which does require a re-render of every consuming component.

## A responsive component

```css
/* ProductGrid.module.css */
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: var(--space-3);
  padding: var(--space-4);
}

.card {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  padding: var(--space-3);
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.title {
  font-size: var(--font-size-base);
  font-weight: 600;
}

/* Container queries — responsive to the CARD's own width, not the viewport */
@container (min-width: 320px) {
  .card {
    flex-direction: row;
    align-items: center;
  }
}
```

```tsx
import styles from "./ProductGrid.module.css";

interface Product {
  id: string;
  name: string;
  price: number;
}

function ProductGrid({ products }: { products: Product[] }) {
  return (
    <div className={styles.grid}>
      {products.map((p) => (
        <div key={p.id} className={styles.card} style={{ containerType: "inline-size" }}>
          <h3 className={styles.title}>{p.name}</h3>
          <p>${p.price.toFixed(2)}</p>
        </div>
      ))}
    </div>
  );
}
```

Two responsive mechanisms worth distinguishing in an interview: `grid-template-columns: repeat(auto-fill, minmax(...))` gives you a reflowing grid with **zero media queries**, driven purely by available width. Container queries (`@container`) let an individual component adapt to *its own* box size rather than the viewport — the modern answer to "how do you make a component responsive to its container, not the screen," which media queries fundamentally cannot do.

## Key takeaways

- BEM is a free naming convention with no real scoping guarantee; CSS Modules give true build-time scoping with near-zero runtime cost and are the sane default in Next.js/Vite.
- Traditional CSS-in-JS parses and injects styles at runtime — that cost is why the ecosystem moved toward zero-runtime CSS-in-JS (vanilla-extract, Panda) that compiles to static CSS at build time.
- Atomic CSS (Tailwind) caps CSS bundle growth and removes naming/specificity debates at the cost of markup verbosity and an onboarding shift.
- Design tokens as CSS custom properties enable instant, re-render-free theme switching by flipping a `data-theme` attribute — cheaper than a JS theme object through Context.
- Container queries (`@container`) solve "make this component responsive to its own box," which viewport media queries cannot do.
- There's no universally "correct" CSS architecture — the right answer in an interview names the trade-offs and picks based on team size, SSR needs, and existing tooling.
