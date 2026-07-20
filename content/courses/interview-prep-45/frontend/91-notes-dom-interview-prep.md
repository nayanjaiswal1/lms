---
kind: lesson
id_key: interview-prep-45/note-dom-basics
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: DOM — Interview Prep"
position: 91
estimated_minutes: 25
source:
    - interview-prep-notes.md
---

## 1. What DOM Is
DOM is the browser's live, in-memory JS object tree built from parsed HTML — not the HTML itself. `document` is the root.

## 2. Node Types
`1` Element · `3` Text (whitespace between tags counts!) · `8` Comment · `9` Document · `11` DocumentFragment

## 3. Traversal
- **All nodes:** `parentNode`, `childNodes`, `firstChild`, `nextSibling`
- **Elements only:** `parentElement`, `children`, `firstElementChild`, `nextElementSibling`
- `closest(selector)` — walks **up** from an element until a match is found (or `null`)

## 4. Selecting Elements
| Method | Returns |
|---|---|
| `getElementById` | single element |
| `getElementsByClassName`/`TagName` | **live** HTMLCollection |
| `querySelector`/`querySelectorAll` | single / **static** NodeList |

**Gotcha:** live collections auto-update on DOM changes; static ones don't. Mutating a live collection mid-loop skips elements — convert with `Array.from()` first.

## 5. Creating/Mutating
`createElement`, `appendChild`/`append` (multiple nodes/strings), `prepend`, `insertBefore`, `replaceChild`, `remove()`, `cloneNode(deep)` (never copies listeners), `createDocumentFragment()` (batch inserts → one reflow instead of many).

## 6. Attribute vs Property
- **Attribute** = string from HTML source, frozen at load time (`getAttribute`/`setAttribute`)
- **Property** = live current state (`el.value`, `el.checked`)
- Diverge after user interaction: `el.value` updates live; `el.getAttribute('value')` stays original.
- **Boolean attributes** (`checked`, `disabled`, `required`, `readonly`, `selected`): presence = true, absence = false. Present → `getAttribute` returns `""`. Absent → returns `null`, never `"true"`/`"false"`.
- Disable a button: `button.disabled = true` (property, standard way).

## 7. Content: innerHTML vs textContent vs innerText
- `innerHTML` — parses as HTML, XSS risk, re-renders subtree
- `textContent` — plain text, safe, includes hidden text, no reflow needed
- `innerText` — respects CSS visibility, forces reflow to compute (slowest)
- `innerHTML +=` destroys and recreates all child nodes → kills existing listeners on them

## 8. Events
**Flow:** capturing (top→down) → target → bubbling (bottom→up). Default listeners = bubbling; `{ capture: true }` = capturing phase.

- `e.target` = actual clicked element · `e.currentTarget` = element the listener is attached to
- `stopPropagation()` — halts further bubbling/capturing
- `stopImmediatePropagation()` — halts propagation **and** other listeners on same element
- `preventDefault()` — cancels default browser action only, unrelated to propagation
- `{ once: true }` — auto-removes listener after first fire
- `removeEventListener` requires the **same function reference**
- `{ passive: true }` — promises no `preventDefault()`, improves scroll perf; calling it anyway is silently ignored
- Custom events: `new CustomEvent('name', {detail, bubbles:true})` + `dispatchEvent()`

### Event Delegation
One listener on a parent instead of many on children. Use `e.target.closest(selector)` to find the matching descendant. Works for elements added later, since bubbling doesn't care when they were created.

**Trap:** if a child's own listener calls `stopPropagation()`, it prevents the event from ever reaching a delegated parent listener — the parent's logic simply never runs.

## 9. Performance
- **Reflow** (layout recalculation) > **Repaint** (pixels, no layout change) > **Composite** (GPU only — `transform`/`opacity`) in cost, most→least expensive.
- **Layout thrashing:** interleaving reads (`offsetHeight`) and writes (`style.width=`) in a loop forces repeated sync reflows. Fix: batch all reads, then all writes.
- **Debounce** (fire once after pause — search input) vs **Throttle** (fire at fixed intervals during continuous activity — scroll tracking).

## 10. DOM vs Virtual DOM
Real DOM writes are expensive. React diffs a lightweight virtual tree against the previous one (reconciliation) and applies only the minimal real DOM changes, batched. `key` gives list items stable identity across re-renders so React doesn't misattribute state.

## 11. Shadow DOM
Encapsulated subtree with scoped styles/markup, used by Web Components — styles don't leak in or out.

## 12. Identifying "which element was clicked" — general pattern
```js
document.querySelectorAll('.box').forEach(box => {
  box.addEventListener('click', (e) => {
    console.log(e.currentTarget.dataset.id);
  });
});
```
Identify by `data-*` attributes, not by index or text content — decouples logic from content/position. For dynamic lists, same `dataset.id` idea but via delegation + `closest()`.

---

## Quick-Fire Q&A

**Q: Attribute vs property — example of divergence?**
A: `<input value="hi">` → after user types, `el.value` shows new text, `el.getAttribute('value')` still shows `"hi"`.

**Q: `getElementsByClassName` vs `querySelectorAll`?**
A: Live HTMLCollection (auto-updates) vs static NodeList (frozen snapshot).

**Q: `childNodes` vs `children`?**
A: `childNodes` includes text/comment nodes (whitespace counts); `children` = elements only.

**Q: `innerHTML` vs `textContent`?**
A: `innerHTML` parses HTML (XSS risk); `textContent` is safe plain text, no reflow.

**Q: Explain event delegation.**
A: One listener on a common ancestor; use `e.target`/`closest()` to identify which descendant triggered it. Efficient, works on dynamically added children.

**Q: `stopPropagation` vs `preventDefault`?**
A: First stops event travel through the DOM tree; second cancels default browser behavior only — unrelated to each other.

**Q: Why avoid reading `offsetHeight` in a loop right after a write?**
A: Forces synchronous reflow every iteration — layout thrashing. Batch reads, then writes.

**Q: Why does React use a Virtual DOM?**
A: Diffs a JS tree copy instead of the real DOM, then applies only minimal necessary changes in a batch — avoids expensive reflow-triggering writes on every state change.

**Q: Does `removeEventListener` work with a different but identical function?**
A: No — requires the exact same function reference used in `addEventListener`.

**Q: `DOMContentLoaded` vs `window.onload`?**
A: First fires once HTML is parsed (DOM ready); second waits for all resources (images, CSS) to finish loading too.
