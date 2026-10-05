import { DIFFICULTY_OPTIONS } from "@/lib/constants";
import type { Column, Row } from "@/vendor/notion-table/notion-table";
import type { ProgressStatus, SheetItem } from "@/lib/server/sheets";

const STATUS_LABEL: Record<ProgressStatus, string> = {
  todo: "To do",
  done: "Done",
  revisit: "Revisit",
};

const DIFFICULTY_LABEL: Record<string, string> = Object.fromEntries(
  DIFFICULTY_OPTIONS.map((o) => [o.value, o.label]),
);

export const GRID_COLUMNS: Column[] = [
  { key: "status", label: "Status", width: 100 },
  { key: "day", label: "Day", type: "number", width: 70 },
  { key: "topic", label: "Topic", width: 180 },
  { key: "title", label: "Problem" },
  { key: "difficulty", label: "Difficulty", width: 110 },
];

/** `url` is not a column — the grid opens it on row click. */
export interface GridRow extends Row {
  url: string | null;
}

export function toGridRows(items: SheetItem[]): GridRow[] {
  return items.map((item) => ({
    status: STATUS_LABEL[item.status],
    day: item.metadata?.day ?? "",
    topic: item.category ?? "",
    title: item.title,
    difficulty: item.difficulty ? DIFFICULTY_LABEL[item.difficulty] : "",
    url: item.external_url,
  }));
}
