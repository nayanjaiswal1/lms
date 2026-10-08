/** The API list envelope: GET ...?limit=&cursor= → { items, next_cursor }.
 *  next_cursor is absent on the last page (backend internal/pagination). */
export interface Page<T> {
  items: T[];
  next_cursor?: string;
}

/** Backend pagination.MaxLimit — the largest page one request can ask for. */
export const MAX_PAGE_LIMIT = 200;

/** Appends ?cursor= (and keeps any existing query) when a cursor is given. */
export function withCursor(path: string, cursor?: string): string {
  if (!cursor) return path;
  return `${path}${path.includes("?") ? "&" : "?"}cursor=${encodeURIComponent(cursor)}`;
}

/** Reads every page of a small, bounded collection (a lesson's highlights, an
 *  org's FAQ list) that the UI renders whole. Unbounded user-generated feeds
 *  page through the UI with <NextPageLink> instead. */
export async function fetchAllPages<T>(get: (path: string) => Promise<Page<T>>, path: string): Promise<T[]> {
  const sep = path.includes("?") ? "&" : "?";
  const items: T[] = [];
  let cursor: string | undefined;
  do {
    const page = await get(withCursor(`${path}${sep}limit=${MAX_PAGE_LIMIT}`, cursor));
    items.push(...page.items);
    cursor = page.next_cursor;
  } while (cursor);
  return items;
}
