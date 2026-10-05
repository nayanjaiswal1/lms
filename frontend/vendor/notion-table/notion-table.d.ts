export type ColorClass = '' | `t-${ColorName}` | `b-${ColorName}`;
export type ColorName =
  | 'gray'
  | 'brown'
  | 'orange'
  | 'yellow'
  | 'green'
  | 'blue'
  | 'purple'
  | 'pink'
  | 'red';

export interface Column {
  key: string;
  label?: string;
  /**
   * `image`: the value is a URL shown as a small picture, not editable.
   * `select`: the value is picked from `options` in a dropdown.
   * `multiselect`: the value is a `string[]` ticked from `options` in a checkbox popover.
   */
  type?: 'text' | 'number' | 'image' | 'select' | 'multiselect';
  /** The choices of a `select`/`multiselect` column. A row's value that isn't listed is still shown. */
  options?: string[];
  /** Width in px; omitted = flexible. */
  width?: number;
  /** Text alignment; number columns are right-aligned by default. */
  align?: 'left' | 'center' | 'right';
  color?: ColorClass;
  /** Values are shown but can't be edited (e.g. computed or source columns). */
  readonly?: boolean;
}

/** A row is your own object; the table edits it in place. Its color lives under `_color`. */
export type Row = Record<string, unknown> & { _color?: ColorClass };

export interface CellChangeDetail {
  row: Row;
  index: number;
  key: string;
  value: string | number | string[];
}
export interface RowClickDetail {
  row: Row;
  index: number;
}
export interface SelectionChangeDetail {
  rows: Row[];
  indexes: number[];
}
export interface TableChangeDetail {
  action: 'rename' | 'color' | 'before' | 'after' | 'dup' | 'clear' | 'del' | 'move';
  target: 'row' | 'column';
  key?: string;
}

export type ChangeDetail =
  | ({ type: 'cell-change' } & CellChangeDetail)
  | ({ type: 'table-change' } & TableChangeDetail);

export declare class NotionTable extends HTMLElement {
  columns: Column[];
  rows: Row[];
  /** Mirrors the `readonly` attribute: no editing, handles or + New; rows emit `row-click`. */
  readOnly: boolean;
  /** Prefills rows added with + New / Enter on the last row. */
  newRow: (() => Row) | null;
  /** Identity field (e.g. 'id'): a duplicated row doesn't copy it, so rows without it are new. */
  rowKey: string | null;
  /** Rows picked with Ctrl/Cmd+click (toggle) or Shift+click (range from the anchor row), in table order. */
  readonly selectedRows: Row[];
  clearSelection(): void;
  addRow(data?: Row): HTMLElement;
  addEventListener(
    type: 'selection-change',
    listener: (e: CustomEvent<SelectionChangeDetail>) => void,
    options?: boolean | AddEventListenerOptions,
  ): void;
  addEventListener(
    type: 'cell-change',
    listener: (e: CustomEvent<CellChangeDetail>) => void,
    options?: boolean | AddEventListenerOptions,
  ): void;
  /** Fired after every `cell-change` and `table-change`, with `type` saying which. */
  addEventListener(
    type: 'change',
    listener: (e: CustomEvent<ChangeDetail>) => void,
    options?: boolean | AddEventListenerOptions,
  ): void;
  addEventListener(
    type: 'row-click',
    listener: (e: CustomEvent<RowClickDetail>) => void,
    options?: boolean | AddEventListenerOptions,
  ): void;
  addEventListener(
    type: 'table-change',
    listener: (e: CustomEvent<TableChangeDetail>) => void,
    options?: boolean | AddEventListenerOptions,
  ): void;
  addEventListener(
    type: string,
    listener: EventListenerOrEventListenerObject,
    options?: boolean | AddEventListenerOptions,
  ): void;
}

declare global {
  interface HTMLElementTagNameMap {
    'notion-table': NotionTable;
  }
}
