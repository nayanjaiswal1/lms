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

1. **Content** – actual text/media; sized by `width`/`height` (in `content-box` mode).
2. **Padding** – space between content and border; shares background with content.
3. **Border** – visible/invisible line around padding (`border-width`, `-style`, `-color`).
4. **Margin** – transparent space outside the border, separates element from siblings. Margins can **collapse** between adjacent block elements.

---

## 2. `content-box` vs `border-box`

| Aspect | `content-box` (default) | `border-box` |
|---|---|---|
| What `width`/`height` measures | Content only | Content + padding + border |
| Effect of adding padding/border | Increases total rendered size | Total size stays fixed; content shrinks to fit |
| Layout predictability | Harder — must calculate final size manually | Easier — declared width **is** the final width |
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

### One-line difference
- `content-box`: width = content only; padding/border add on top.
- `border-box`: width = content + padding + border combined; content shrinks to fit.

### Global reset (common best practice)
```css
*, *::before, *::after {
  box-sizing: border-box;
}
```
Makes layout math predictable — critical for flex/grid and responsive design, where fixed padding/border combined with percentage widths would otherwise break under `content-box`.

---

## 3. Interview-style answers

**Q: What is the CSS Box Model?**
> The CSS box model describes how every HTML element is rendered as a rectangular box composed of four layers: content, padding, border, and margin — from the inside out. `width`/`height` size the content area by default, padding adds internal spacing, border wraps around that, and margin creates external spacing between elements.

**Q: What is `box-sizing: border-box` and why is it used?**
> By default (`content-box`), `width`/`height` apply only to the content area, with padding and border added on top — increasing the actual rendered size. `border-box` changes this so the declared `width`/`height` includes content, padding, and border together; the browser shrinks the content area internally to keep the total size fixed. This makes layout calculations predictable and is why it's commonly applied globally via `*, *::before, *::after { box-sizing: border-box; }`.

**Q: Difference between `content-box` and `border-box`?**
> In `content-box`, the width property only sizes the content — padding and border are added on top, so the box grows larger than the declared width. In `border-box`, the width property sizes content + padding + border together — the box stays exactly the declared width, and the content area shrinks to accommodate padding and border.

### Common follow-up questions to be ready for
- What is **margin collapsing**, and when does it happen? (adjacent vertical margins of block-level elements collapse into the larger one)
- Does `padding` accept negative values? (No — only `margin` can be negative)
- How does the box model differ for inline vs block elements?
- Why do most developers set `border-box` globally? (predictability in flex/grid + responsive layouts)
