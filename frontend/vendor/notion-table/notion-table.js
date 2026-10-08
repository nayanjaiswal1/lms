// <notion-table>: zero-dependency, Notion-style editable table (Web Component).
// The cell itself is the editor (contenteditable), so there is no input box, padding or margin to hide.
// One shared column handle + one shared row handle open a single native popover menu, no per-cell widgets.

const DEFAULT_COL = 'minmax(120px, 1fr)';
const ROW_COLOR = '_color'; // key on a row object holding its color class
const TEXT = {
  add: '+ New', search: 'Search actions…', color: 'Color', textColor: 'Text color', bgColor: 'Background color',
  default: 'Default', dup: 'Duplicate', dupKey: 'Ctrl+D', clear: 'Clear contents', del: 'Delete',
  col: { before: 'Insert left', after: 'Insert right', handle: 'Column actions' },
  row: { before: 'Insert above', after: 'Insert below', handle: 'Row actions' },
};

// [light text, dark text, light bg, dark bg], Notion's palette
const COLORS = {
  gray: ['#787774', '#9b9b9b', '#f1f1ef', '#2f2f2f'],
  brown: ['#9f6b53', '#ba856f', '#f4eeee', '#4a3228'],
  orange: ['#d9730d', '#c77d48', '#fbecdd', '#5c3b23'],
  yellow: ['#cb912f', '#ca9849', '#fbf3db', '#564328'],
  green: ['#448361', '#529e72', '#edf3ec', '#243d30'],
  blue: ['#337ea9', '#5e87c9', '#e7f3f8', '#143a4e'],
  purple: ['#9065b0', '#9d68d3', '#f6f3f9', '#3c2d49'],
  pink: ['#c14c8a', '#d15796', '#f9f2f5', '#4e2c3c'],
  red: ['#d44c47', '#df5452', '#fdebec', '#522e2a'],
};

const ICON = {
  color: 'M3 4h13v5H3z M16 6.5h4v5h-9v3 M11 14.5v6',
  chev: 'M9 6l6 6-6 6',
  'col-before': 'M19 12H5 M11 6l-6 6 6 6',
  'col-after': 'M5 12h14 M13 6l6 6-6 6',
  'row-before': 'M12 19V5 M6 11l6-6 6 6',
  'row-after': 'M12 5v14 M6 13l6 6 6-6',
  dup: 'M8 8h12v12H8z M16 8V4H4v12h4',
  clear: 'M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18z M9 9l6 6 M15 9l-6 6',
  del: 'M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13 M10 11v6 M14 11v6',
};
const svg = (d) => `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="${d}"/></svg>`;
const dots = (cols, rows) => `<svg width="${cols * 4 + 2}" height="${rows * 4 + 2}" fill="currentColor">${
  Array.from({ length: cols * rows }, (_, i) => `<circle cx="${(i % cols) * 4 + 3}" cy="${Math.floor(i / cols) * 4 + 3}" r="1.2"/>`).join('')}</svg>`;

const CSS = `
:host { display: block; font: inherit; color: inherit;
  --_line: var(--nt-line, rgba(127,127,127,.25));
  --_hover: var(--nt-hover, rgba(127,127,127,.08));
  --_pad: var(--nt-pad, 6px 8px);
  --_focus: var(--nt-focus, #2383e2);
  --_menu: var(--nt-menu-bg, light-dark(#fff, #252525)); }
[hidden] { display: none !important; }
.wrap { position: relative; }
.row { display: grid; grid-template-columns: var(--nt-cols); border-bottom: 1px solid var(--_line);
  content-visibility: auto; contain-intrinsic-size: auto 33px; }
.body .row:hover { background: var(--_hover); }
.body .row.picked { background: var(--nt-picked, rgba(35,131,226,.16)); }
.cell { padding: var(--_pad); border-right: 1px solid var(--_line); outline: none; min-height: 1.4em;
  white-space: pre-wrap; overflow-wrap: anywhere; cursor: text; }
.cell:last-child { border-right: 0; }
.cell:focus { box-shadow: inset 0 0 0 2px var(--_focus); }
.head .cell { opacity: .65; font-size: .875em; }
.num { text-align: right; font-variant-numeric: tabular-nums; }
.ro { cursor: default; }
.cell:has(> .pick) { padding: 0; }
.pick { all: unset; box-sizing: border-box; display: block; width: 100%; min-height: 100%; padding: var(--_pad); cursor: pointer; }
.cell:has(> .multi) { padding: 0; }
.multi { all: unset; box-sizing: border-box; display: block; width: 100%; min-height: 1.4em; padding: var(--_pad); cursor: pointer; white-space: pre-wrap; }
.multi:focus-visible { box-shadow: inset 0 0 0 2px var(--_focus); }
.opts { position: fixed; inset: auto; margin: 0; min-width: 180px; max-height: 50vh; overflow: auto; padding: 6px; color: inherit;
  background: var(--_menu); border: 1px solid var(--_line); border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.25); }
.opts label { display: flex; align-items: center; gap: 8px; padding: 5px 8px; border-radius: 6px; cursor: pointer; }
.opts label:hover { background: var(--_hover); }
.pick:focus-visible { box-shadow: inset 0 0 0 2px var(--_focus); }
.img { display: block; width: 1.4em; height: 1.4em; object-fit: contain; border-radius: 4px; background: #fff; }
.add { all: unset; box-sizing: border-box; display: block; width: 100%; padding: var(--_pad); opacity: .65; cursor: pointer; }
.add:hover, .add:focus-visible { background: var(--_hover); opacity: 1; }
.handle { all: unset; position: absolute; z-index: 2; width: 18px; height: 18px; display: grid; place-items: center;
  border-radius: 4px; background: var(--_focus); color: #fff; cursor: grab; touch-action: none; opacity: 0; transition: opacity .1s; }
.drop { position: absolute; z-index: 3; pointer-events: none; background: var(--_focus); }
.dragging { opacity: .4; }
:host(:hover) .handle, :host(:focus-within) .handle { opacity: 1; }
:host([readonly]) .handle, :host([readonly]) .add { display: none; }
:host([readonly]) .cell { cursor: inherit; }
:host([readonly]) .body .row { cursor: pointer; }
.sel { position: absolute; z-index: 1; pointer-events: none; box-shadow: inset 0 0 0 2px var(--_focus); }
.menu { position: fixed; inset: auto; margin: 0; width: 260px; padding: 6px; overflow: visible; color: inherit;
  background: var(--_menu); border: 1px solid var(--_line); border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.25); }
.search { box-sizing: border-box; width: 100%; margin-bottom: 4px; padding: 6px 8px; font: inherit; color: inherit;
  background: transparent; border: 1px solid var(--_line); border-radius: 6px; outline: none; }
.search:focus { border-color: var(--_focus); box-shadow: 0 0 0 1px var(--_focus); }
.item { position: relative; }
.item button, .sub button { all: unset; box-sizing: border-box; display: flex; align-items: center; gap: 10px; width: 100%;
  padding: 6px 8px; border-radius: 6px; cursor: pointer; }
.item button:hover, .item button:focus-visible, .sub button:hover, .sub button:focus-visible { background: var(--_hover); }
.item span { flex: 1; }
kbd { font: inherit; font-size: .8em; opacity: .5; }
.sub { display: none; position: absolute; left: 100%; top: -6px; width: 220px; max-height: 60vh; overflow: auto; padding: 6px;
  background: var(--_menu); border: 1px solid var(--_line); border-radius: 10px; box-shadow: 0 8px 24px rgba(0,0,0,.25); }
.flip .sub { left: auto; right: 100%; }
.item:hover > .sub, .item:focus-within > .sub { display: block; }
.sub h4 { margin: 4px 8px; font-size: .75em; font-weight: 500; opacity: .6; }
.sw { display: grid; place-items: center; width: 20px; height: 20px; border: 1px solid var(--_line); border-radius: 4px; font-weight: 600; }
${Object.entries(COLORS).map(([n, [t, td, b, bd]]) =>
  `.t-${n}{color:light-dark(${t},${td})}.b-${n}{background:light-dark(${b},${bd})}`).join('')}
`;

const cap = (s) => s[0].toUpperCase() + s.slice(1);
const swatch = (cls, label) => `<button data-act="color" data-color="${cls}"><b class="sw ${cls}">A</b>${label}</button>`;
const COLOR_MENU = `<h4>${TEXT.textColor}</h4>${swatch('', TEXT.default)}${Object.keys(COLORS).map((n) => swatch(`t-${n}`, cap(n))).join('')}
  <h4>${TEXT.bgColor}</h4>${swatch('', TEXT.default)}${Object.keys(COLORS).map((n) => swatch(`b-${n}`, `${cap(n)} background`)).join('')}`;

// Importing on a server (SSR) must not crash: there is no HTMLElement there.
export class NotionTable extends (globalThis.HTMLElement ?? class {}) {
  #cols = [];
  #rows = [];
  #data = new WeakMap(); // row element -> row object (no indices to re-number on insert/delete)
  #hot = null; // last hovered/focused cell, where the handles sit
  #target = null; // what the open menu acts on
  #drag = null; // active handle drag
  #noClick = false; // swallow the click that ends a drag
  #wrap; #head; #body; #colH; #rowH; #sel; #drop; #menu; #opts;
  #picked = new Set(); // row objects selected with Ctrl/Alt+click
  #anchor = null; // last row toggled, where an Alt+click range starts
  #multi = null; // the multiselect cell whose checkbox popover is open

  constructor() {
    super();
    const root = this.attachShadow({ mode: 'open' });
    root.innerHTML = `<style>${CSS}</style>
      <div class="wrap">
        <div class="row head" part="head" role="row"></div>
        <div class="body" part="body" role="rowgroup"></div>
        <button class="handle" data-type="col" aria-label="${TEXT.col.handle}">${dots(3, 2)}</button>
        <button class="handle" data-type="row" aria-label="${TEXT.row.handle}" hidden>${dots(2, 3)}</button>
        <div class="sel" hidden></div>
        <div class="drop" hidden></div>
      </div>
      <button class="add" part="add">${TEXT.add}</button>
      <div class="menu" part="menu" popover role="menu"></div>
      <div class="opts" part="menu" popover></div>`;
    const $ = (s) => root.querySelector(s);
    [this.#wrap, this.#head, this.#body, this.#sel, this.#drop, this.#menu, this.#opts] = ['.wrap', '.head', '.body', '.sel', '.drop', '.menu', '.opts'].map($);
    [this.#colH, this.#rowH] = root.querySelectorAll('.handle');

    // Edits write straight into the row object, with no re-render, so the caret never jumps.
    this.#wrap.addEventListener('input', (e) => {
      const pick = e.target.tagName === 'SELECT' ? e.target : null;
      const cell = pick ? pick.parentNode : e.target;
      const col = this.#cols[cell.dataset.c];
      const text = pick ? pick.value : cell.textContent;
      if (cell.parentNode === this.#head) {
        col.label = text;
        return this.#emit('table-change', { action: 'rename', target: 'column', key: col.key });
      }
      const n = Number(text);
      const value = col.type === 'number' && text.trim() && !isNaN(n) ? n : text;
      const row = this.#data.get(cell.parentNode);
      row[col.key] = value;
      this.#emit('cell-change', { row, index: this.#rows.indexOf(row), key: col.key, value });
    });

    this.#wrap.addEventListener('keydown', (e) => {
      const pick = e.target.tagName === 'SELECT' || e.target.classList.contains('multi');
      const cell = pick ? e.target.parentNode : e.target;
      if (e.isComposing || !cell.classList.contains('cell')) return;
      const row = cell.parentNode;
      const isHead = row === this.#head;
      if (e.key === 'Escape') return e.target.blur();
      if ((e.ctrlKey || e.metaKey) && e.key === 'd' && !isHead) {
        e.preventDefault();
        this.#target = { type: 'row', el: row };
        return this.#act('dup');
      }
      if (pick) return; // arrows and Enter belong to the dropdown
      const down = (e.key === 'Enter' && !e.shiftKey) || e.key === 'ArrowDown';
      const up = (e.key === 'Enter' && e.shiftKey) || e.key === 'ArrowUp';
      if (!down && !up) return;
      e.preventDefault();
      let next = down
        ? (isHead ? this.#body.firstElementChild : row.nextElementSibling)
        : (isHead ? null : row.previousElementSibling ?? this.#head);
      if (!next && e.key === 'Enter' && down) next = this.addRow();
      if (next) focusEnd(next.children[cell.dataset.c]);
    });

    // Ctrl/Cmd+click toggles a row, Shift+click selects from the anchor row (Ctrl+Shift adds the range), as in a file manager; no caret, no editing, no row-click.
    const modified = (e) => e.ctrlKey || e.metaKey || e.shiftKey;
    this.#wrap.addEventListener('mousedown', (e) => { if (modified(e) && e.target.closest?.('.body .row')) e.preventDefault(); });
    this.#wrap.addEventListener('click', (e) => {
      const hit = modified(e) && e.target.closest?.('.body .row');
      if (hit) return this.#pick(hit, e.shiftKey, e.ctrlKey || e.metaKey);
      const btn = e.target.closest?.('.multi');
      if (btn) return this.#openMulti(btn.parentNode);
      const el = this.readOnly && e.target.closest('.row');
      if (!el || el === this.#head) return;
      const row = this.#data.get(el);
      this.#emit('row-click', { row, index: this.#rows.indexOf(row) });
    });

    const track = (e) => this.#track(e.target.closest?.('.cell'));
    this.#wrap.addEventListener('pointerover', track);
    this.#wrap.addEventListener('focusin', track);
    // Handle: click opens the menu, drag (> 4px) reorders.
    for (const h of [this.#colH, this.#rowH]) {
      h.addEventListener('click', () => {
        if (this.#noClick) this.#noClick = false;
        else this.#open(h.dataset.type, h);
      });
      h.addEventListener('pointerdown', (e) => {
        this.#noClick = false;
        if (!this.#hot || e.button !== 0) return;
        h.setPointerCapture(e.pointerId);
        const type = h.dataset.type;
        this.#drag = { type, x: e.clientX, y: e.clientY, moved: false,
          src: type === 'col' ? +this.#hot.dataset.c : this.#hot.parentNode };
      });
      h.addEventListener('pointermove', (e) => {
        const d = this.#drag;
        if (!d || (!d.moved && Math.hypot(e.clientX - d.x, e.clientY - d.y) < 4)) return;
        if (!d.moved && d.type === 'row') d.src.classList.add('dragging');
        d.moved = true;
        this.#dragOver(d, e.clientX, e.clientY);
      });
      h.addEventListener('pointerup', () => this.#endDrag(true));
      h.addEventListener('pointercancel', () => this.#endDrag(false));
    }

    this.#menu.addEventListener('click', (e) => {
      const b = e.target.closest('button[data-act]');
      if (!b) return;
      this.#act(b.dataset.act, b.dataset.color);
      this.#menu.hidePopover();
      if (this.#hot?.isConnected) focusEnd(this.#hot);
    });
    this.#opts.addEventListener('change', () => {
      const td = this.#multi;
      const col = this.#cols[td.dataset.c];
      const row = this.#data.get(td.parentNode);
      const value = [...this.#opts.querySelectorAll('input:checked')].map((i) => i.value);
      row[col.key] = value;
      td.firstElementChild.textContent = value.join(', ');
      this.#emit('cell-change', { row, index: this.#rows.indexOf(row), key: col.key, value });
    });
    this.#opts.addEventListener('toggle', (e) => { if (e.newState === 'closed' && this.#multi?.isConnected) this.#multi.firstElementChild.focus(); });
    this.#menu.addEventListener('input', (e) => {
      const q = e.target.value.trim().toLowerCase();
      for (const it of this.#menu.querySelectorAll('.item')) it.hidden = !it.textContent.toLowerCase().includes(q);
    });
    this.#menu.addEventListener('keydown', (e) => this.#menuKey(e));
    this.#menu.addEventListener('toggle', (e) => { if (e.newState === 'closed') this.#sel.hidden = true; });

    root.querySelector('.add').addEventListener('click', () => focusEnd(this.addRow().firstElementChild));
  }

  // `readonly` attribute: plain view, no editing, no handles, no + New; clicking a row emits `row-click`.
  static observedAttributes = ['readonly'];
  attributeChangedCallback(name, old, now) {
    if ((old === null) === (now === null)) return;
    if (this.#menu.matches(':popover-open')) this.#menu.hidePopover();
    this.#render(); // rows keep any unsaved edits; only the DOM is rebuilt
  }

  get readOnly() { return this.hasAttribute('readonly'); }
  set readOnly(v) { this.toggleAttribute('readonly', !!v); }

  connectedCallback() {
    this.setAttribute('role', 'table');
    // Frameworks can set properties before this script defines the element; re-apply them through the setters.
    for (const p of ['columns', 'rows', 'readOnly']) {
      if (Object.hasOwn(this, p)) { const v = this[p]; delete this[p]; this[p] = v; }
    }
  }

  /** @param {{key: string, label?: string, type?: 'text'|'number'|'image'|'link'|'select'|'multiselect', options?: string[], width?: number, align?: 'left'|'center'|'right', color?: string, readonly?: boolean}[]} cols */
  set columns(cols) { this.#cols = cols; this.#render(); }
  get columns() { return this.#cols; }

  /** Rows are mutated in place as the user types. A row's color class lives under row._color. */
  set rows(rows) { this.#rows = rows; this.#picked.clear(); this.#anchor = null; this.#render(); }
  get rows() { return this.#rows; }

  /** Optional `() => row` used to prefill rows added with + New / Enter on the last row. */
  newRow = null;

  /** Optional identity field (e.g. 'id'): a duplicated row doesn't copy it, so rows without it are new. */
  rowKey = null;

  addRow(data = this.newRow?.() ?? {}) {
    this.#rows.push(data);
    const el = this.#row(data);
    this.#body.append(el);
    return el;
  }

  // Every edit (a cell or the table's shape) also emits `change`, so "save on any edit" needs one listener.
  #emit(type, detail) {
    this.dispatchEvent(new CustomEvent(type, { detail }));
    if (type === 'cell-change' || type === 'table-change') this.dispatchEvent(new CustomEvent('change', { detail: { type, ...detail } }));
  }

  #render() {
    this.style.setProperty('--nt-cols', this.#cols.map((c) => (c.width ? `${c.width}px` : DEFAULT_COL)).join(' '));
    const edit = !this.readOnly;
    this.#head.replaceChildren(...this.#cols.map((col, c) => cell(col.label ?? col.key, col, c, 'columnheader', edit)));
    const frag = document.createDocumentFragment();
    for (const r of this.#rows) frag.append(this.#row(r));
    this.#body.replaceChildren(frag);
    this.#hot = null;
    this.#rowH.hidden = true;
  }

  #row(data) {
    const el = document.createElement('div');
    el.className = `row ${data[ROW_COLOR] ?? ''}`;
    el.setAttribute('role', 'row');
    el.setAttribute('part', 'row');
    const edit = !this.readOnly;
    this.#cols.forEach((col, c) => el.append(cell(data[col.key] ?? '', col, c, 'cell', edit)));
    this.#data.set(el, data);
    el.classList.toggle('picked', this.#picked.has(data));
    return el;
  }

  /** Rows selected with Ctrl/Alt+click, in table order. */
  get selectedRows() { return this.#rows.filter((r) => this.#picked.has(r)); }

  clearSelection() {
    this.#picked.clear();
    this.#anchor = null;
    this.#paint();
  }

  #pick(el, range, add) {
    const data = this.#data.get(el);
    const from = this.#rows.indexOf(this.#anchor);
    if (range && from >= 0) {
      const [a, b] = [from, this.#rows.indexOf(data)].sort((x, y) => x - y);
      if (!add) this.#picked.clear(); // standard: Shift+click replaces the selection with anchor..row
      for (const r of this.#rows.slice(a, b + 1)) this.#picked.add(r);
    } else if (range) {
      this.#picked.clear();
      this.#picked.add(data);
      this.#anchor = data;
    } else {
      if (!this.#picked.delete(data)) this.#picked.add(data);
      this.#anchor = data;
    }
    this.#paint();
    const rows = this.selectedRows;
    this.#emit('selection-change', { rows, indexes: rows.map((r) => this.#rows.indexOf(r)) });
  }

  #paint() {
    for (const el of this.#body.children) el.classList.toggle('picked', this.#picked.has(this.#data.get(el)));
  }

  // One shared checkbox popover under the clicked multiselect cell; value = checked options, in option order.
  #openMulti(td) {
    const col = this.#cols[td.dataset.c];
    const row = this.#data.get(td.parentNode);
    const have = new Set(row[col.key] ?? []);
    const choices = [...new Set([...(col.options ?? []), ...have])];
    this.#multi = td;
    this.#opts.replaceChildren(...choices.map((o) => {
      const label = document.createElement('label');
      const box = Object.assign(document.createElement('input'), { type: 'checkbox', value: o, checked: have.has(o) });
      label.append(box, o);
      return label;
    }));
    this.#opts.showPopover();
    const r = td.getBoundingClientRect();
    const below = r.bottom + 4 + this.#opts.offsetHeight <= innerHeight;
    this.#opts.style.left = `${Math.max(8, Math.min(r.left, innerWidth - this.#opts.offsetWidth - 8))}px`;
    this.#opts.style.top = `${Math.max(8, below ? r.bottom + 4 : r.top - 4 - this.#opts.offsetHeight)}px`;
    this.#opts.querySelector('input')?.focus();
  }

  // Move the two shared handles to the hovered/focused cell's column and row.
  #track(td) {
    if (!td || this.#menu.matches(':popover-open')) return;
    this.#hot = td;
    const w = this.#wrap.getBoundingClientRect();
    const r = td.getBoundingClientRect();
    this.#colH.style.left = `${r.left - w.left + r.width / 2 - 9}px`;
    this.#colH.style.top = '-9px';
    this.#rowH.hidden = td.parentNode === this.#head;
    if (!this.#rowH.hidden) {
      const rr = td.parentNode.getBoundingClientRect();
      this.#rowH.style.left = '-9px';
      this.#rowH.style.top = `${rr.top - w.top + rr.height / 2 - 9}px`;
    }
  }

  // Show the blue drop line where the dragged column/row would land.
  #dragOver(d, x, y) {
    const w = this.#wrap.getBoundingClientRect();
    const line = this.#drop.style;
    if (d.type === 'col') {
      const cells = [...this.#head.children];
      let i = cells.findIndex((c) => x < c.getBoundingClientRect().right);
      if (i < 0) i = cells.length - 1;
      const r = cells[i].getBoundingClientRect();
      const before = x < r.left + r.width / 2;
      d.to = before ? i : i + 1;
      Object.assign(line, { left: `${(before ? r.left : r.right) - w.left - 1}px`, top: '0', width: '2px', height: `${w.height}px` });
    } else {
      // ponytail: auto-scroll only steps on pointer moves; add a rAF loop if holding still at the edge must keep scrolling.
      if (y < 40) scrollBy(0, -12);
      else if (y > innerHeight - 40) scrollBy(0, 12);
      const row = this.shadowRoot.elementFromPoint(w.left + w.width / 2, y)?.closest('.body .row');
      if (!row) return;
      const r = row.getBoundingClientRect();
      d.target = row;
      d.before = y < r.top + r.height / 2;
      Object.assign(line, { left: '0', top: `${(d.before ? r.top : r.bottom) - w.top - 1}px`, width: `${w.width}px`, height: '2px' });
    }
    this.#drop.hidden = false;
  }

  #endDrag(commit) {
    const d = this.#drag;
    this.#drag = null;
    this.#drop.hidden = true;
    if (!d?.moved) return;
    this.#noClick = true;
    if (d.type === 'row') d.src.classList.remove('dragging');
    if (!commit) return;
    if (d.type === 'col') {
      if (d.to == null || d.to === d.src || d.to === d.src + 1) return;
      const [col] = this.#cols.splice(d.src, 1);
      this.#cols.splice(d.to > d.src ? d.to - 1 : d.to, 0, col);
      this.#render();
    } else {
      if (!d.target || d.target === d.src) return;
      const data = this.#data.get(d.src);
      this.#rows.splice(this.#rows.indexOf(data), 1);
      const ti = this.#rows.indexOf(this.#data.get(d.target));
      this.#rows.splice(d.before ? ti : ti + 1, 0, data);
      if (d.before) d.target.before(d.src); else d.target.after(d.src);
      this.#track(this.#hot);
    }
    this.#emit('table-change', { action: 'move', target: d.type === 'col' ? 'column' : 'row' });
  }

  #open(type, handle) {
    if (!this.#hot) return;
    const c = +this.#hot.dataset.c;
    this.#target = type === 'col' ? { type, c } : { type, el: this.#hot.parentNode };
    const L = TEXT[type];
    const item = (act, label, extra = '') => `<div class="item"><button data-act="${act}">${svg(ICON[act] ?? ICON[`${type}-${act}`])}<span>${label}</span>${extra}</button></div>`;
    this.#menu.innerHTML = `<input class="search" placeholder="${TEXT.search}" aria-label="${TEXT.search}">
      <div class="item"><button>${svg(ICON.color)}<span>${TEXT.color}</span>${svg(ICON.chev)}</button><div class="sub">${COLOR_MENU}</div></div>
      ${item('before', L.before)}${item('after', L.after)}${item('dup', TEXT.dup, `<kbd>${TEXT.dupKey}</kbd>`)}
      ${item('clear', TEXT.clear)}${item('del', TEXT.del)}`;

    // Outline the column or row being acted on (one overlay, not a class on every cell).
    const w = this.#wrap.getBoundingClientRect();
    const r = (type === 'col' ? this.#head.children[c] : this.#target.el).getBoundingClientRect();
    Object.assign(this.#sel.style, type === 'col'
      ? { left: `${r.left - w.left}px`, top: '0', width: `${r.width}px`, height: `${w.height}px` }
      : { left: '0', top: `${r.top - w.top}px`, width: `${w.width}px`, height: `${r.height}px` });
    this.#sel.hidden = false;

    const m = this.#menu;
    m.showPopover();
    const h = handle.getBoundingClientRect();
    const fits = h.right + 4 + m.offsetWidth + 8 <= innerWidth;
    const left = fits ? h.right + 4 : h.left - 4 - m.offsetWidth;
    m.style.left = `${Math.max(8, left)}px`;
    m.style.top = `${Math.max(8, Math.min(h.top, innerHeight - m.offsetHeight - 8))}px`;
    m.classList.toggle('flip', Math.max(8, left) + m.offsetWidth * 2 > innerWidth);
    m.querySelector('.search').focus();
  }

  #menuKey(e) {
    if ((e.ctrlKey || e.metaKey) && e.key === 'd') {
      e.preventDefault();
      return this.#menu.querySelector('[data-act="dup"]').click();
    }
    if (e.key === 'Escape' && this.#hot?.isConnected) return focusEnd(this.#hot);
    const list = [this.#menu.querySelector('.search'), ...this.#menu.querySelectorAll('.item:not([hidden]) > button')];
    const i = list.indexOf(this.shadowRoot.activeElement);
    if (e.key === 'Enter' && i === 0) {
      e.preventDefault();
      const first = list[1];
      return first?.dataset.act ? first.click() : first?.focus();
    }
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    e.preventDefault();
    list[(i + (e.key === 'ArrowDown' ? 1 : -1) + list.length) % list.length]?.focus();
  }

  #act(act, color = '') {
    const t = this.#target;
    if (t.type === 'col') this.#colAct(act, t.c, color);
    else this.#rowAct(act, t.el, color);
    this.#emit('table-change', { action: act, target: t.type === 'col' ? 'column' : 'row' });
  }

  // Column ops touch every row, so they re-render; they're rare, typing never re-renders.
  #colAct(act, c, color) {
    const cols = this.#cols;
    const col = cols[c];
    if (act === 'color') col.color = color;
    else if (act === 'before' || act === 'after') cols.splice(act === 'after' ? c + 1 : c, 0, { key: this.#newKey(), label: '' });
    else if (act === 'dup') {
      const key = this.#newKey();
      for (const r of this.#rows) r[key] = r[col.key];
      cols.splice(c + 1, 0, { ...col, key });
    } else if (act === 'clear') for (const r of this.#rows) r[col.key] = blank(col);
    else if (act === 'del') {
      if (cols.length === 1) return;
      for (const r of this.#rows) delete r[col.key];
      cols.splice(c, 1);
    }
    this.#render();
  }

  // Row ops patch only the affected row element.
  #rowAct(act, el, color) {
    const data = this.#data.get(el);
    const i = this.#rows.indexOf(data);
    if (act === 'color') {
      data[ROW_COLOR] = color;
      el.className = `row ${color}`;
    } else if (act === 'before' || act === 'after' || act === 'dup') {
      const obj = act === 'dup' ? { ...data } : {};
      if (this.rowKey) delete obj[this.rowKey];
      this.#rows.splice(act === 'before' ? i : i + 1, 0, obj);
      const nel = this.#row(obj);
      if (act === 'before') el.before(nel); else el.after(nel);
      this.#hot = nel.children[this.#hot?.dataset.c ?? 0];
    } else if (act === 'clear') {
      for (const col of this.#cols) data[col.key] = blank(col);
      for (const td of el.children) {
        const pick = td.querySelector('select');
        if (pick) pick.value = '';
        else if (td.querySelector('.multi')) td.firstElementChild.textContent = '';
        else td.textContent = '';
      }
    } else if (act === 'del') {
      this.#rows.splice(i, 1);
      el.remove();
      this.#rowH.hidden = true;
    }
  }

  #newKey() {
    let k = this.#cols.length + 1;
    while (this.#cols.some((c) => c.key === `col${k}`)) k++;
    return `col${k}`;
  }
}

const blank = (col) => (col.type === 'multiselect' ? [] : '');

function cell(text, col, c, role, edit = true) {
  const el = document.createElement('div');
  el.className = `cell ${col.type === 'number' ? 'num' : ''} ${col.color ?? ''}`;
  el.dataset.c = c;
  if (col.align) el.style.textAlign = col.align;
  el.setAttribute('role', role);
  el.setAttribute('part', 'cell');
  // An image cell holds a URL and is display-only (e.g. a logo).
  if (col.type === 'image' && role === 'cell') {
    if (text) el.append(Object.assign(document.createElement('img'), { src: text, alt: '', loading: 'lazy', className: 'img' }));
    return el;
  }
  // A link cell holds a URL, shown as an "Open" anchor in a new tab; display-only.
  if (col.type === 'link' && role === 'cell') {
    if (text) el.append(Object.assign(document.createElement('a'), { href: text, target: '_blank', rel: 'noopener noreferrer', textContent: 'Open' }));
    return el;
  }
  // A select cell picks its value from `col.options` with a native <select>; a value that isn't
  // one of them (old data) is kept as an extra choice, so just showing a row never changes it.
  // (stays pickable in a `readonly` table; mark the column `readonly` to lock it)
  if (col.type === 'select' && role === 'cell' && !col.readonly) {
    const pick = document.createElement('select');
    pick.className = 'pick';
    pick.setAttribute('aria-label', col.label || col.key);
    const choices = [...new Set(['', ...(col.options ?? []), String(text)])];
    pick.append(...choices.map((o) => new Option(o, o)));
    pick.value = String(text);
    el.append(pick);
    return el;
  }
  // A multiselect cell is a button showing the picked values; clicking opens the checkbox popover.
  const shown = Array.isArray(text) ? text.join(', ') : text;
  if (col.type === 'multiselect' && role === 'cell' && edit && !col.readonly) {
    el.append(Object.assign(document.createElement('button'), { className: 'multi', type: 'button', textContent: shown }));
    el.firstElementChild.setAttribute('aria-label', col.label || col.key);
    return el;
  }
  // A `readonly` column shows its values but can't be typed into (its header can be renamed).
  if (col.readonly && role === 'cell') el.classList.add('ro');
  else if (edit) el.setAttribute('contenteditable', 'plaintext-only');
  if (col.type === 'number' && role === 'cell') el.setAttribute('inputmode', 'decimal');
  el.textContent = shown;
  return el;
}

function focusEnd(el) {
  const pick = el.querySelector('select, .multi');
  if (pick) return pick.focus();
  el.focus();
  const sel = getSelection();
  sel.selectAllChildren(el);
  sel.collapseToEnd();
}

if (globalThis.customElements && !customElements.get('notion-table')) customElements.define('notion-table', NotionTable);
