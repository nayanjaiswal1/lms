---
kind: lesson
id_key: interview-prep-45/note-css-box-model
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: CSS Box Model & box-sizing"
position: 92
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

## 1. What is the CSS Box Model?

Every HTML element is rendered as a rectangular box made of **4 layers**, from inside out:

```
┌─────────────────────────────────┐
│           MARGIN                │
│  ┌─────────────────────────┐    │
│  │        BORDER            │   │
│  │  ┌───────────────────┐   │   │
│  │  │     PADDING        │  │   │
│  │  │  ┌─────────────┐   │  │   │
│  │  │  │   CONTENT    │  │  │   │
│  │  │  └─────────────┘   │  │   │
│  │  └───────────────────┘   │   │
│  └─────────────────────────┘    │
└─────────────────────────────────┘
```

1. **Content**: the actual text/media, sized by `width`/`height` (in `content-box` mode).
2. **Padding**: space between content and border. It shares its background with the content.
3. **Border**: a visible or invisible line around the padding (`border-width`, `-style`, `-color`).
4. **Margin**: transparent space outside the border that separates the element from its siblings. Margins can **collapse** between adjacent block elements.

---

## 2. `content-box` vs `border-box`

| Aspect | `content-box` (default) | `border-box` |
|---|---|---|
| What `width`/`height` measures | Content only | Content plus padding plus border |
| Effect of adding padding/border | Increases total rendered size | Total size stays fixed; content shrinks to fit |
| Layout predictability | Harder: you must calculate the final size manually | Easier: the declared width **is** the final width |
| Common usage | Rarely used explicitly (spec default) | Best practice, usually applied globally |

### Example: `content-box` (default)
```css
.box {
  box-sizing: content-box;
  width: 200px;
  padding: 20px;
  border: 5px solid black;
}
/* Total rendered width = 200 + 40 (padding) + 10 (border) = 250px */
```

### Example: `border-box`
```css
.box {
  box-sizing: border-box;
  width: 200px;
  padding: 20px;
  border: 5px solid black;
}
/* Total rendered width = 200px (content area shrinks internally to 150px) */
```

In the `content-box` example, the browser starts from the declared `width: 200px` as the content size, then adds padding and border on top, so the box ends up 250px wide on the page. In the `border-box` example, the browser instead treats 200px as the final total width, and works backward, giving the content area only 150px so that padding and border still fit inside that same 200px.

### One-line difference
- `content-box`: width means content only; padding and border add on top of it.
- `border-box`: width means content, padding, and border combined; content shrinks to fit.

### Global reset (common best practice)
```css
*, *::before, *::after {
  box-sizing: border-box;
}
```
This makes layout math predictable, which matters most for flex/grid and responsive design: fixed padding and border combined with percentage widths would otherwise break under `content-box`, since the rendered box would grow past the percentage you declared.

---

## 3. Interview-style answers

**Q: What is the CSS Box Model?**
> The CSS box model describes how every HTML element is rendered as a rectangular box composed of four layers, from the inside out: content, padding, border, and margin. `width`/`height` size the content area by default, padding adds internal spacing, border wraps around that, and margin creates external spacing between elements.

**Q: What is `box-sizing: border-box` and why is it used?**
> By default (`content-box`), `width`/`height` apply only to the content area, with padding and border added on top, increasing the actual rendered size. `border-box` changes this so the declared `width`/`height` includes content, padding, and border together; the browser shrinks the content area internally to keep the total size fixed. This makes layout calculations predictable and is why it's commonly applied globally via `*, *::before, *::after { box-sizing: border-box; }`.

**Q: Difference between `content-box` and `border-box`?**
> In `content-box`, the width property only sizes the content; padding and border are added on top, so the box grows larger than the declared width. In `border-box`, the width property sizes content, padding, and border together; the box stays exactly the declared width, and the content area shrinks to accommodate padding and border.

### Common follow-up questions to be ready for
- What is **margin collapsing**, and when does it happen? Adjacent vertical margins of block-level elements collapse into whichever one is larger, rather than adding together.
- Does `padding` accept negative values? No, only `margin` can be negative.
- How does the box model differ for inline vs block elements?
- Why do most developers set `border-box` globally? It gives predictability in flex/grid and responsive layouts.
