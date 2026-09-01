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
DOM is the browser's live, in-memory JS object tree built from parsed HTML. It is not the HTML itself; `document` is the root of that tree.

## 2. Node Types
`1` Element · `3` Text (whitespace between tags counts!) · `8` Comment · `9` Document · `11` DocumentFragment

## 3. Traversal
- **All nodes:** `parentNode`, `childNodes`, `firstChild`, `nextSibling`
- **Elements only:** `parentElement`, `children`, `firstElementChild`, `nextElementSibling`
- `closest(selector)` walks **up** from an element until a match is found, or returns `null` if none does

## 4. Selecting Elements
| Method | Returns |
|---|---|
| `getElementById` | single element |
| `getElementsByClassName`/`TagName` | **live** HTMLCollection |
| `querySelector`/`querySelectorAll` | single / **static** NodeList |

**Gotcha:** live collections auto-update on DOM changes; static ones don't. Mutating a live collection mid-loop skips elements. Convert with `Array.from()` first.

## 5. Creating/Mutating
`createElement`, `appendChild`/`append` (multiple nodes/strings), `prepend`, `insertBefore`, `replaceChild`, `remove()`, `cloneNode(deep)` (never copies listeners), `createDocumentFragment()` (batch inserts so the browser does one reflow instead of many).

## 6. Attribute vs Property
- **Attribute** = string from HTML source, frozen at load time (`getAttribute`/`setAttribute`)
- **Property** = live current state (`el.value`, `el.checked`)
- These diverge after user interaction: `el.value` updates live, but `el.getAttribute('value')` stays at whatever the HTML originally said.
- **Boolean attributes** (`checked`, `disabled`, `required`, `readonly`, `selected`): presence means true, absence means false. When present, `getAttribute` returns `""`. When absent, it returns `null`, never `"true"`/`"false"`.
- Disable a button the standard way with the property: `button.disabled = true`.

## 7. Content: innerHTML vs textContent vs innerText
- `innerHTML` parses its input as HTML, which is an XSS risk, and re-renders the whole subtree.
- `textContent` is plain text. It's safe, includes hidden text, and needs no reflow.
- `innerText` respects CSS visibility but forces a reflow to compute, making it the slowest of the three.
- `innerHTML +=` destroys and recreates all child nodes, which kills any listeners already attached to them.

## 8. Events
**Flow:** capturing (top to down), then target, then bubbling (bottom to up). Default listeners run in the bubbling phase; pass `{ capture: true }` to run in the capturing phase instead.

- `e.target` is the actual clicked element. `e.currentTarget` is the element the listener is attached to.
- `stopPropagation()` halts further bubbling/capturing.
- `stopImmediatePropagation()` halts propagation and also stops other listeners on the same element from firing.
- `preventDefault()` cancels the default browser action only; it has nothing to do with propagation.
- `{ once: true }` auto-removes the listener after it fires once.
- `removeEventListener` only works with the **same function reference** that was passed to `addEventListener`.
- `{ passive: true }` is a promise that the listener won't call `preventDefault()`. It improves scroll performance; calling it anyway is silently ignored.
- Custom events: `new CustomEvent('name', {detail, bubbles:true})` plus `dispatchEvent()`.

### Event Delegation
Put one listener on a parent instead of many on children, and use `e.target.closest(selector)` to find the matching descendant. This works for elements added later too, since bubbling doesn't care when an element was created.

**Trap:** if a child's own listener calls `stopPropagation()`, the event never reaches a delegated parent listener at all, so the parent's logic simply never runs.

## 9. Performance
Cost ranking from most to least expensive: **Reflow** (layout recalculation), then **Repaint** (pixels only, no layout change), then **Composite** (GPU only, e.g. `transform`/`opacity`).

**Layout thrashing:** interleaving reads (`offsetHeight`) and writes (`style.width=`) in a loop forces a synchronous reflow on every iteration. Fix by batching all reads first, then all writes.

**Debounce** fires once after activity pauses (good for a search input). **Throttle** fires at fixed intervals during continuous activity (good for scroll tracking).

## 10. DOM vs Virtual DOM
Real DOM writes are expensive. React diffs a lightweight virtual tree against the previous one (reconciliation) and applies only the minimal real DOM changes, batched together. `key` gives list items stable identity across re-renders so React doesn't misattribute state to the wrong item.

## 11. Shadow DOM
An encapsulated subtree with scoped styles and markup, used by Web Components: styles don't leak in or out of it.

## 12. Identifying "which element was clicked": general pattern
```js
document.querySelectorAll('.box').forEach(box => {
  box.addEventListener('click', (e) => {
    console.log(e.currentTarget.dataset.id);
  });
});
```
Walking through this: each `.box` element gets its own listener attached at setup time. When any box is clicked, that specific listener fires with `e.currentTarget` pointing at the box the listener was attached to (not necessarily the exact element clicked, if the box has children). Reading `dataset.id` off it logs whatever `data-id` value that box was given in HTML.

Identify elements by `data-*` attributes rather than by index or text content, since that decouples the logic from content or position. For dynamic lists where elements don't exist yet at setup time, use the same `dataset.id` idea but through delegation with `closest()` instead of a per-element listener.

---

## Quick-Fire Q&A

**Q: Attribute vs property, an example of divergence?**
A: `<input value="hi">`. After the user types, `el.value` shows the new text, but `el.getAttribute('value')` still shows `"hi"`.

**Q: `getElementsByClassName` vs `querySelectorAll`?**
A: A live HTMLCollection that auto-updates vs a static NodeList that's a frozen snapshot.

**Q: `childNodes` vs `children`?**
A: `childNodes` includes text and comment nodes, so whitespace counts. `children` is elements only.

**Q: `innerHTML` vs `textContent`?**
A: `innerHTML` parses HTML and carries an XSS risk. `textContent` is safe plain text and needs no reflow.

**Q: Explain event delegation.**
A: Put one listener on a common ancestor, then use `e.target`/`closest()` to identify which descendant triggered it. It's efficient and works on children added later.

**Q: `stopPropagation` vs `preventDefault`?**
A: The first stops the event from continuing to travel through the DOM tree. The second cancels default browser behavior only. They're unrelated to each other.

**Q: Why avoid reading `offsetHeight` in a loop right after a write?**
A: It forces a synchronous reflow every iteration, layout thrashing. Batch reads, then writes.

**Q: Why does React use a Virtual DOM?**
A: It diffs a JS tree copy instead of the real DOM, then applies only the minimal necessary changes in one batch, avoiding expensive reflow-triggering writes on every state change.

**Q: Does `removeEventListener` work with a different but identical function?**
A: No. It requires the exact same function reference used in `addEventListener`.

**Q: `DOMContentLoaded` vs `window.onload`?**
A: The first fires once the HTML is parsed and the DOM is ready. The second waits for all resources, images and CSS included, to finish loading too.
