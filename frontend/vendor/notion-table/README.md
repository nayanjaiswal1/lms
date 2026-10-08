# notion-table

Notion-style editable table as a zero-dependency Web Component. Works in plain HTML, React, Vue, Svelte, Angular, anything.

- Cells are the editor: no input boxes, no padding or margin to fight
- Fast: typing never re-renders; off-screen rows aren't painted (10k rows stay smooth)
- Select columns: pick a value from a dropdown (native `<select>`, keyboard friendly)
- Multiselect columns: tick several values from a checkbox popover
- Column/row handle menu: search, color, insert, duplicate (Ctrl+D), clear, delete
- Drag handles to reorder rows and columns
- Light/dark aware, themeable with CSS variables

## Install

```sh
npm i notion-table
```

## Use

```html
<notion-table id="t"></notion-table>
<script type="module">
  import 'notion-table';
  const t = document.getElementById('t');
  t.columns = [
    { key: 'name', label: 'Name' },
    { key: 'qty', label: 'Qty', type: 'number', width: 90 },
  ];
  t.rows = [{ name: 'Task 1', qty: 3 }];
  t.addEventListener('cell-change', (e) => console.log(e.detail));  // { row, index, key, value }
  t.addEventListener('table-change', (e) => console.log(e.detail)); // { action, target }
  t.addEventListener('change', (e) => console.log(e.detail));       // after either of the two above
</script>
```

`rows` and `columns` are edited in place, so read `t.rows` / `t.columns` any time to save.

### Select columns

```js
t.columns = [
  { key: 'task', label: 'Task' },
  { key: 'status', label: 'Status', type: 'select', options: ['Todo', 'Doing', 'Done'] },
];
```

A select stays pickable in a `readonly` table; set the column's `readonly: true` to lock it. Picking a value fires `cell-change` (and `change`) like typing does. In a select cell, ↑/↓ and Enter work the dropdown; Tab, Esc and Ctrl+D work as everywhere else.

### Multiselect columns

```js
{ key: 'tags', label: 'Tags', type: 'multiselect', options: ['Work', 'Trip', 'Gift'] }
```

The row value is a `string[]`. Clicking the cell opens a checkbox list; each tick fires `cell-change` with the new array. A value that isn't in `options` is still listed, so loading data never changes it.

### Selecting rows

Ctrl/Cmd+click a row to toggle it; Shift+click selects the range from the anchor row (Ctrl+Shift adds it to the selection). Works in read-only mode too (no `row-click`). Listen for `selection-change` (`detail.rows`, `detail.indexes`), read `t.selectedRows`, call `t.clearSelection()`. Style with `--nt-picked`; selection doesn't fire `change`.

### Row identity

Set `t.rowKey = 'id'` when rows carry an id from your data. A duplicated row (menu or Ctrl+D) then doesn't copy it, so when saving, a row without an id is new and any id is an existing row; ids missing from `t.rows` were deleted.

```js
t.rowKey = 'id';
t.newRow = () => ({ date: today() }); // prefill for + New / Enter on the last row
t.addEventListener('change', () => (dirty = true));
```

### Column options

| Option | Meaning |
| --- | --- |
| `key`, `label` | Row field and header text |
| `type` | `text` (default), `number` (right-aligned), `image` (the value is a URL shown as a small picture, not editable), `link` (the value is a URL shown as an "Open" link in a new tab, not editable), `select` (a dropdown of `options`), or `multiselect` (checkboxes of `options`, the value is a `string[]`) |
| `options` | The choices of a `select` column. A row's value that isn't listed is still shown, so loading data never changes it |
| `width` | Width in px; omitted = flexible |
| `align` | `left` / `center` / `right` |
| `color` | `t-<color>` text or `b-<color>` background |
| `readonly` | Values are shown but can't be typed into (e.g. computed or source columns) |

### Read-only / edit mode

Add the `readonly` attribute (or set `t.readOnly = true`) for a plain view: no editing, no drag handles, no `+ New`. Clicking a row then emits `row-click` (`{ row, index }`). Remove it to switch back to editing; unsaved edits in `rows` are kept.

```html
<notion-table readonly></notion-table>
<script type="module">
  t.addEventListener('row-click', (e) => openDetails(e.detail.row));
  editButton.onclick = () => (t.readOnly = !t.readOnly);
</script>
```

### React 19

```jsx
import 'notion-table';
<notion-table columns={cols} rows={rows} />
```

React 18: set `columns`/`rows` through a `ref`. In Next.js, import it in a `'use client'` component.

### Vue

Tell Vue it's a custom element (`compilerOptions.isCustomElement: (tag) => tag === 'notion-table'`), then bind with `:columns.prop` / `:rows.prop`.

## Keys

| Key | Action |
| --- | --- |
| Enter / ↓ | Next row (adds a row at the end) |
| Shift+Enter / ↑ | Previous row |
| Tab | Next cell |
| Ctrl+D | Duplicate row |
| Esc | Stop editing |

## Theming

```css
notion-table {
  --nt-pad: 6px 8px;      /* cell padding, 0 for none */
  --nt-line: #e9e9e7;     /* borders */
  --nt-hover: #f5f5f5;    /* row hover */
  --nt-focus: #2383e2;    /* focus ring, handles, drop line */
  --nt-menu-bg: #fff;     /* menu background */
}
```

Dark mode follows `color-scheme` (set `color-scheme: dark` on your page). Style internals with `::part(cell | row | head | body | add | menu)`.

Colors set from the menu are stored as `column.color` and `row._color` (`t-red` text, `b-red` background).

## License

MIT
