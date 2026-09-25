import { ChevronLeft, ChevronRight } from "lucide-react";
import type { AeIssuesPage } from "@/lib/server/gitlab-planning";
import { cn } from "@/lib/utils";

interface IssuesPaginationProps {
  pagination: AeIssuesPage["pagination"];
  shown: number;
}

const PAGE_BTN = "m-label-md flex h-8 min-w-8 items-center justify-center rounded-lg px-2 transition-colors";

export function IssuesPagination({ pagination, shown }: IssuesPaginationProps) {
  const { from, total, pages, current } = pagination;

  return (
    <footer className="flex flex-col items-center justify-between gap-2 py-2 sm:flex-row">
      <p className="m-body-sm text-(--m-on-surface-variant)">
        Showing <span className="font-semibold text-(--m-on-surface)">{shown ? `${from} - ${from + shown - 1}` : "0"}</span> of{" "}
        <span className="font-semibold text-(--m-on-surface)">{total}</span> open issues
      </p>
      <nav aria-label="Pagination" className="flex items-center gap-1">
        <button disabled className={cn(PAGE_BTN, "gap-0.5 text-(--m-on-surface-variant) disabled:opacity-40")} type="button">
          <ChevronLeft aria-hidden className="size-4" />
          <span>Prev</span>
        </button>
        {pages.map((p, i) =>
          p === "…" ? (
            <span className="px-1 text-(--m-on-surface-variant)" key={`gap-${i}`}>…</span>
          ) : (
            <button
              aria-current={p === current ? "page" : undefined}
              className={cn(PAGE_BTN, p === current ? "bg-(--m-primary) text-(--m-sc-lowest)" : "text-(--m-on-surface) hover:bg-(--m-sc-low)")}
              key={p}
              type="button"
            >
              {p}
            </button>
          ),
        )}
        <button className={cn(PAGE_BTN, "gap-0.5 bg-(--m-sc-lowest) text-(--m-on-surface) shadow-sm hover:bg-(--m-sc-low)")} type="button">
          <span>Next</span>
          <ChevronRight aria-hidden className="size-4" />
        </button>
      </nav>
    </footer>
  );
}
