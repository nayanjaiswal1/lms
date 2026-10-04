---
kind: lesson
id_key: interview-prep-45/fe-html-structure-semantics
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "HTML Document Structure and Semantics"
position: 1
estimated_minutes: 25
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Picture two boxes of the same size. One is labeled "Fragile: this side up." The other has no label at all. Both hold the same glass, but only one tells the person carrying it what it actually is. HTML tags are that label. A `<div>` and a `<button>` can look identical on screen, but only one of them tells the browser, a screen reader, and a search engine what it actually is.

CSS, React, and every rendering trick you learn after this sits on top of HTML. The tags you pick decide what a screen reader announces, what a search engine indexes, and how much JavaScript you have to write to make a button behave like a button.

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

`<!DOCTYPE html>` is not decoration you can skip. Leave it out and the browser drops into "quirks mode," an old compatibility mode that changes how it measures boxes and applies a handful of CSS rules, to match 1990s browser bugs. You do not want that switched on by accident.

`lang="en"` tells a screen reader which pronunciation rules to use, and tells a translation tool what language it is translating from. `<meta charset="UTF-8">` has to be the first thing inside `<head>`, within the first 1024 bytes of the file, because the browser must know the text encoding before it can read anything after it, including the `<title>`. `<meta name="viewport" ...>` is what makes a page render at phone width instead of a shrunk-down desktop layout. Skip it and every phone shows your site squeezed to fit an assumed 980px-wide screen.

> **Remember:** the doctype, charset, and viewport meta tag are not boilerplate. Each one changes how the browser measures and displays everything that follows.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-html-doc-q1", "type": "mcq",
      "prompt": "What happens if a page is missing `<!DOCTYPE html>`?",
      "options": [
        {"id":"a","text":"Nothing, it's a purely historical tag with no effect in modern browsers"},
        {"id":"b","text":"The browser renders in quirks mode, an old compatibility mode that changes how box sizing and some CSS rules are calculated"},
        {"id":"c","text":"The page fails to load entirely"},
        {"id":"d","text":"JavaScript stops running"}
      ],
      "correct": "b",
      "explanation": "Quirks mode exists so very old pages built before web standards still render the way they did back then. It is still live in every modern browser, just off by default when a doctype is present." }
] }
```

## Semantic tags versus div soup

Picture a filing cabinet where every folder is labeled "Folder." You could still find things, eventually, by opening every single one. That is what a page built entirely out of `<div>` and `<span>` looks like to a screen reader or a search crawler: every folder has the same blank label, so nothing tells you what is inside without opening it.

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

`<header>`, `<nav>`, `<main>`, `<article>`, `<section>`, `<aside>`, and `<footer>` are landmark elements: real, labeled folders. Three things follow from using them instead of `<div class="header">`.

- **A screen reader user can jump straight to a landmark.** A keyboard shortcut jumps to "main" or "navigation" directly, skipping everything above it. A `<div>` never shows up in that list, no matter what class name you give it.
- **A search crawler reads structure, not just words.** `<article>` and `<h1>`–`<h6>` tell it what is actual content versus decoration around it, which affects how your page gets summarized in results.
- **The next person reading your markup does not have to guess.** `<nav>` explains itself. `<div className="top-bar-wrapper-2">` does not.

The one mix-up people make constantly: `<article>` versus `<section>`. An `<article>` is content that would still make sense on its own, cut out and pasted somewhere else: a blog post, a product card, a forum comment. A `<section>` is a grouping *inside* something bigger: a chapter, a tab panel. A blog post is an `<article>`. The "Comments" heading and its list, sitting inside that same post, is a `<section>`.

> **Remember:** if you could paste it into a new page and it would still make sense alone, it's an `<article>`. If it only makes sense as a piece of something bigger, it's a `<section>`.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-html-semantic-q1", "type": "mcq",
      "prompt": "A product review card, showing the reviewer's name, star rating, and text, appears in a grid of many other review cards. Which element should wrap one card?",
      "options": [
        {"id":"a","text":"<section>, because it's grouped with the other cards"},
        {"id":"b","text":"<article>, because a single review makes sense pulled out and shown on its own"},
        {"id":"c","text":"<aside>, because it's secondary content"},
        {"id":"d","text":"<div>, since screen readers can't tell the difference anyway"}
      ],
      "correct": "b",
      "explanation": "The test for <article> is whether the content still makes sense standing alone. A single review does. <section> is for a grouping inside something bigger, like the 'Comments' heading and list inside one article." }
] }
```

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

`<label for="query">` paired with `id="query"` on the input does two jobs at once: clicking the label focuses the input, a bigger, more forgiving click target than the input alone, and a screen reader announces "Search, edit text" the moment the input gets focus, instead of announcing nothing. Swapping a real label for a `placeholder` is the single most common accessibility bug in real forms. A placeholder disappears the moment you start typing, and it is never announced the way a real label is.

`required`, `minlength`, `type="email"`, `type="number"` give you free validation, and just as importantly, the right on-screen keyboard on mobile: a number pad for `type="number"`, an `@`-friendly layout for `type="email"`. `<fieldset>` and `<legend>` group related radio buttons or checkboxes under one announced label, "Sort by," something a bare row of `<input type="radio">` elements has no way to say on its own.

`<button>` versus `<div onClick>` is not a style choice. A real `<button>` is keyboard-focusable, fires on both Enter and Space, and shows up correctly in a screen reader's list of controls, all for free. A clickable `<div>` gets none of that until you bolt on `tabIndex`, a `role`, and keydown handlers, reinventing what `<button>` already gives you.

> **Remember:** a placeholder is not a label. It disappears the moment someone starts typing.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-html-forms-q1", "type": "mcq",
      "prompt": "Why is `<input placeholder=\"Email\">` with no `<label>` a real accessibility bug, not just a style nitpick?",
      "options": [
        {"id":"a","text":"Placeholders render in a lighter grey, which is a color-contrast issue only"},
        {"id":"b","text":"The placeholder text vanishes once the user starts typing, and a screen reader does not announce it the same way it announces a real <label>"},
        {"id":"c","text":"Placeholders don't work in older browsers"},
        {"id":"d","text":"It doesn't matter, placeholder is equivalent to label for all practical purposes"}
      ],
      "correct": "b",
      "explanation": "A label stays put and is reliably read out by assistive technology on focus. A placeholder is a hint that disappears as soon as it's needed most, once the user starts typing." }
] }
```

## The accessibility tree runs on top of the DOM, not instead of it

Alongside the DOM, the browser builds a second tree called the accessibility tree, and it is what a screen reader actually reads from. Every element gets a computed **role** (its type: `button`, `heading`), a computed **name** (what gets announced, usually the text inside it, a `<label>`, or an `aria-label`), and a computed **state** (`checked`, `expanded`, `disabled`).

Semantic HTML fills in role and name for free. `<button>Save</button>` has role `button` and name `"Save"` with zero extra work. Build the same control out of a `<div>` and you are now on the hook for supplying all of that yourself with ARIA attributes, and it is easy to get subtly wrong in a way that looks fine visually but announces nothing useful to a screen reader. This course covers accessibility as its own topic later on, but the rule to carry forward now is simple: reach for the native element first, and only add ARIA for the small set of widgets, a custom dropdown, for instance, that HTML genuinely has no built-in element for.

## Where this shows up in an interview

"Why does this matter if I'm just going to build everything in React with `<div>`s and Tailwind classes" is a fair question, and it is usually what an interviewer is actually testing when semantic HTML comes up. The honest answer: React changes none of this. JSX compiles down to the exact same DOM nodes, so a `<div onClick>` inside a React component has exactly the same accessibility gap as one in raw HTML. The framework does not fix it for you. Choosing `<button>` over `<div>`, or `<nav>` over `<div className="nav">`, is a decision you make in every component you write, framework or not.

> **Remember:** JSX compiles to the same DOM nodes as raw HTML. A `<div onClick>` has the same accessibility gap in React as it does anywhere else.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-html-a11y-q1", "type": "mcq",
      "prompt": "A React component renders `<div onClick={handleClick}>Submit</div>`. What accessibility problems does it have compared to `<button onClick={handleClick}>Submit</button>`?",
      "options": [
        {"id":"a","text":"None, React automatically adds keyboard support and the correct accessible role to every element"},
        {"id":"b","text":"It isn't keyboard-focusable, doesn't fire on Enter/Space, and has no button role for a screen reader, unless all of that is added back by hand"},
        {"id":"c","text":"It only fails in Internet Explorer"},
        {"id":"d","text":"It's a purely visual issue with no effect on screen readers"}
      ],
      "correct": "b",
      "explanation": "React compiles JSX straight to DOM nodes. A <div> is still just a <div>: no keyboard focus, no Enter/Space activation, no button role, unless you add tabIndex, a role, and key handlers yourself." }
] }
```
