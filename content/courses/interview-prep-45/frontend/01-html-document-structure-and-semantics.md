---
kind: lesson
id_key: interview-prep-45/fe-html-structure-semantics
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "HTML Document Structure and Semantics"
position: 1
estimated_minutes: 25
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Everything else in this track, CSS, React, rendering performance, sits on top of HTML. That's not a formality: the tags you choose decide what a screen reader announces, what a search crawler indexes, and how much JavaScript you need to write to make something as basic as a button behave like a button. This lesson is the on-ramp the rest of the course assumes you already climbed.

## A minimal document, piece by piece

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Product Catalog</title>
</head>
<body>
  <h1>Welcome</h1>
</body>
</html>
```

`<!DOCTYPE html>` isn't optional decoration. Without it, browsers fall back to "quirks mode," an old compatibility mode that changes how box sizing and a handful of CSS properties are calculated to match 1990s-era browser bugs. You don't want that turned on by accident.

`lang="en"` tells screen readers which pronunciation rules to use and tells translation tools what they're translating from. `<meta charset="UTF-8">` should be the first thing inside `<head>` (within the first 1024 bytes of the file), because the browser has to know the encoding before it can correctly parse any text after it, including the `<title>`. `<meta name="viewport" ...>` is what makes a page render at mobile width instead of a zoomed-out desktop layout; skip it and every phone shows your site shrunk to fit a 980px-wide assumption.

## Semantic tags versus div soup

Every one of these can be built with a `<div>`. The reason not to is that `<div>` and `<span>` carry zero meaning, they're invisible to anything but a human staring at your CSS classes.

```html
<header>
  <nav>
    <a href="/">Home</a>
    <a href="/products">Products</a>
  </nav>
</header>

<main>
  <article>
    <h1>How Caching Works</h1>
    <section>
      <h2>Cache-Control headers</h2>
      <p>...</p>
    </section>
  </article>

  <aside>Related posts</aside>
</main>

<footer>© 2026</footer>
```

`<header>`, `<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`, and `<footer>` are landmark elements. Three things fall out of using real landmarks instead of `<div class="header">`:

- **Screen readers navigate by landmark.** A user can jump straight to "main" or "navigation" with a keyboard shortcut instead of tabbing through everything above it. A `<div>` never shows up in that list, no matter what class name you give it.
- **Search crawlers weight semantic structure.** `<article>` and `<h1>`-`<h6>` tell a crawler what the actual content of the page is versus chrome around it, which affects how accurately your page gets summarized in results.
- **The next person reading your markup doesn't have to guess.** `<nav>` documents itself. A `<div className="top-bar-wrapper-2">` doesn't.

`<article>` versus `<section>` is the one distinction people mix up: `<article>` is content that would make sense distributed on its own, a blog post, a product card, a forum comment. `<section>` is a thematic grouping *within* something else, a chapter, a tab panel. A blog post is an `<article>`; the "Comments" heading and its list inside that post is a `<section>`.

## Forms: the parts that aren't just inputs

```html
<form action="/search" method="get">
  <label for="query">Search</label>
  <input type="search" id="query" name="q" required minlength="2" />

  <fieldset>
    <legend>Sort by</legend>
    <label><input type="radio" name="sort" value="relevance" checked /> Relevance</label>
    <label><input type="radio" name="sort" value="price" /> Price</label>
  </fieldset>

  <button type="submit">Search</button>
</form>
```

`<label for="query">` paired with `id="query"` on the input does two things at once: clicking the label focuses the input (a bigger, more forgiving click target than the input alone), and a screen reader announces "Search, edit text" when the input receives focus instead of announcing nothing at all. This is the single most common accessibility bug in real forms, an input with a `placeholder` standing in for a label. Placeholder text disappears the moment you start typing, and it's never read the same way a real label is.

`required`, `minlength`, `type="email"`, `type="number"` — these give you free client-side validation and, just as importantly, the correct on-screen keyboard on mobile (a numeric pad for `type="number"`, an `@`-friendly layout for `type="email"`). `<fieldset>` and `<legend>` group related radio buttons or checkboxes and give that group its own announced label, "Sort by," which a bare row of `<input type="radio">` elements has no way to express.

`<button>` versus `<div onClick>` isn't a style choice. A real `<button>` is keyboard-focusable, triggers on both Enter and Space, has `role="button"` for free, and shows up correctly in a screen reader's list of interactive controls. A clickable `<div>` gets none of that until you manually add `tabIndex`, a `role`, and keydown handlers to reinvent what `<button>` already does.

## Accessibility trees and the DOM aren't the same tree

The browser builds a second tree alongside the DOM, called the accessibility tree, and it's what screen readers actually read from. Every element gets a computed **role** (its type, like `button` or `heading`), a computed **name** (what gets announced, usually from text content, a `<label>`, or an `aria-label`), and a computed **state** (`checked`, `expanded`, `disabled`).

Semantic HTML fills in role and name automatically. `<button>Save</button>` has role `button` and name `"Save"` with zero extra work. The moment you build a control out of a `<div>`, you're on the hook for supplying all of that yourself with ARIA attributes, and it's easy to get subtly wrong in a way that looks fine visually but announces nonsense (or nothing) to a screen reader. The rule worth internalizing now, since accessibility gets its own full lesson later in this course: reach for the native element first, and only add ARIA for the handful of widgets, like a custom dropdown, that HTML genuinely has no element for.

## Where this shows up in an interview

"Why does this matter if I'm just going to build everything in React with `<div>`s and Tailwind classes" is a fair question, and it's usually what's actually being tested when semantic HTML comes up. The honest answer: React doesn't change any of this. JSX compiles down to the exact same DOM nodes, so a `<div onClick>` in a React component has precisely the same accessibility gap as one in raw HTML, it's not something the framework fixes for you. Knowing when to reach for `<button>` versus `<div>`, or `<nav>` versus `<div className="nav">`, is a decision you make in every component you write, framework or not.
