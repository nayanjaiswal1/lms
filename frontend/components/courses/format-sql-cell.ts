import type { SqlValue } from "sql.js";

/** Display text for one sql.js result cell; blobs are shown as a placeholder. */
export function formatSqlCell(value: SqlValue): string {
  if (value === null) return "NULL";
  if (value instanceof Uint8Array) return "[blob]";
  return String(value);
}
