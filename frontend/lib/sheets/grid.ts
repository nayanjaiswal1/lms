import { DIFFICULTY_OPTIONS } from "@/lib/constants";
import type { Column, Row } from "@/vendor/notion-table/notion-table";
import type { ProgressStatus, SheetItem } from "@/lib/server/sheets";

export const STATUS_LABEL: Record<ProgressStatus, string> = {
  todo: "To do",
  done: "Done",
  revisit: "Revisit",
};

export const STATUS_BY_LABEL: Record<string, ProgressStatus> = Object.fromEntries(
  Object.entries(STATUS_LABEL).map(([status, label]) => [label, status as ProgressStatus]),
);

export const STARRED_LABEL = "★ Starred";

const DIFFICULTY_LABEL: Record<string, string> = Object.fromEntries(
  DIFFICULTY_OPTIONS.map((o) => [o.value, o.label]),
);

export const GRID_COLUMNS: Column[] = [
  { key: "status", label: "Status", type: "select", options: Object.values(STATUS_LABEL), width: 120 },
  { key: "starred", label: "Star", type: "select", options: [STARRED_LABEL], width: 120 },
  { key: "day", label: "Day", type: "number", width: 70, readonly: true },
  { key: "topic", label: "Topic", width: 180, readonly: true },
  { key: "title", label: "Problem", readonly: true },
  { key: "difficulty", label: "Difficulty", width: 110, readonly: true },
  { key: "revision", label: "Revision", width: 120, readonly: true },
  { key: "url", label: "Link", type: "link", width: 80 },
];

/** `topicTag` is not a column — it keys the progress update fired by a cell edit. */
export interface GridRow extends Row {
  topicTag: string;
}

export function toGridRows(items: SheetItem[]): GridRow[] {
  return items.map((item) => ({
    status: STATUS_LABEL[item.status],
    starred: item.is_starred ? STARRED_LABEL : "",
    day: item.metadata?.day ?? "",
    topic: item.category ?? "",
    title: item.title,
    difficulty: item.difficulty ? DIFFICULTY_LABEL[item.difficulty] : "",
    revision: item.revision_at ? new Date(item.revision_at).toLocaleDateString() : "",
    url: item.external_url ?? "",
    topicTag: item.topic_tag,
  }));
}
