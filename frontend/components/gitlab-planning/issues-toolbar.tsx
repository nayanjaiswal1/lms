import Link from "next/link";
import { ArrowDown, ChevronDown, Download, ListChecks, ListFilter, Plus, Rss, ArrowUpDown, RefreshCw, X } from "lucide-react";
import type { AeIssuesPage } from "@/lib/server/gitlab-planning";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

interface IssuesToolbarProps {
  page: AeIssuesPage;
  state: string;
  density: "compact" | "normal";
  bulk: boolean;
}

const GHOST_BTN = "m-headline-sm flex h-8 items-center gap-1 rounded-lg bg-(--m-sc-lowest) px-2 text-(--m-on-surface-variant) shadow-sm transition-colors hover:bg-(--m-sc-low) hover:text-(--m-on-surface)";

function href(params: Record<string, string | undefined>) {
  const q = new URLSearchParams(Object.entries(params).filter((e): e is [string, string] => Boolean(e[1])));
  const s = q.toString();
  return s ? `${ROUTES.GITLAB_ISSUES}?${s}` : ROUTES.GITLAB_ISSUES;
}

export function IssuesToolbar({ page, state, density, bulk }: IssuesToolbarProps) {
  const keep = { state: state === "open" ? undefined : state, density: density === "compact" ? undefined : density, bulk: bulk ? undefined : "0" };

  return (
    <>
      <div className="flex flex-col justify-between gap-2 sm:flex-row sm:items-center">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="m-headline-xl tracking-tight text-(--m-on-surface)">Issues</h1>
          <span className="m-label-md rounded-full bg-(--m-sc-high) px-2.5 py-0.5 text-(--m-primary)">{page.open_count_label}</span>
          <span className="m-label-sm flex items-center gap-1 rounded-lg bg-(--m-sc-low) px-2 py-0.5 text-(--m-on-surface-variant)">
            <RefreshCw aria-hidden className="size-3.5 text-(--m-tertiary)" />
            <span>{page.sync_label}</span>
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <button className={GHOST_BTN} type="button">
            <Download aria-hidden className="size-4" />
            <span>Export CSV</span>
          </button>
          <Link aria-pressed={bulk} className={GHOST_BTN} href={href({ ...keep, bulk: bulk ? "0" : undefined })} scroll={false}>
            <ListChecks aria-hidden className="size-4" />
            <span>Bulk edit</span>
          </Link>
          <button className="m-headline-sm flex h-8 items-center gap-1 rounded-lg bg-(--m-primary) px-3 text-(--m-sc-lowest) shadow-sm transition-colors hover:bg-(--m-primary-container)" type="button">
            <Plus aria-hidden className="size-4" />
            <span>New issue</span>
          </button>
        </div>
      </div>

      {/* Status tabs */}
      <div className="flex items-center justify-between rounded-xl bg-(--m-sc-lowest) px-2 shadow-sm">
        <nav aria-label="Issue state" className="flex items-center gap-1.5 overflow-x-auto">
          {page.tabs.map((t) => {
            const active = t.key === state;
            return (
              <Link
                aria-current={active ? "page" : undefined}
                className={cn(
                  "m-headline-sm relative flex shrink-0 items-center gap-1 whitespace-nowrap p-2 transition-colors",
                  active ? "text-(--m-primary) after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-(--m-primary)" : "text-(--m-on-surface-variant) hover:text-(--m-on-surface)",
                )}
                href={href({ ...keep, state: t.key === "open" ? undefined : t.key })}
                key={t.key}
                scroll={false}
              >
                <span>{t.label}</span>
                <span className={cn("m-label-sm rounded-full px-1.5 text-[11px]", active ? "bg-(--m-primary-fixed) text-(--m-on-primary-fixed)" : "bg-(--m-sc-high) text-(--m-on-surface-variant)")}>
                  {t.count}
                </span>
              </Link>
            );
          })}
        </nav>
        <div className="hidden items-center gap-1 py-1 sm:flex">
          <div className="flex items-center rounded-lg bg-(--m-sc-low) p-0.5">
            {(["compact", "normal"] as const).map((d) => (
              <Link
                aria-current={density === d ? "true" : undefined}
                className={cn(
                  "m-label-sm rounded px-2 py-1 capitalize",
                  density === d ? "bg-(--m-sc-lowest) text-(--m-primary) shadow-2xs" : "text-(--m-on-surface-variant) hover:text-(--m-on-surface)",
                )}
                href={href({ ...keep, density: d === "compact" ? undefined : d })}
                key={d}
                scroll={false}
              >
                {d}
              </Link>
            ))}
          </div>
          <button aria-label="RSS feed" className="rounded-lg p-1 text-(--m-on-surface-variant) hover:bg-(--m-sc-low) hover:text-(--m-on-surface)" type="button">
            <Rss aria-hidden className="size-4.5" />
          </button>
        </div>
      </div>

      {/* Search & filter bar */}
      <div className="flex flex-col gap-1.5 rounded-xl bg-(--m-sc-lowest) p-2 shadow-sm">
        <div className="flex flex-col items-stretch gap-1.5 lg:flex-row lg:items-center">
          <div className="flex flex-1 flex-wrap items-center gap-1 rounded-lg bg-(--m-sc-low) px-2 py-1.5 transition-colors focus-within:bg-(--m-sc)">
            <ListFilter aria-hidden className="size-4.5 shrink-0 text-(--m-on-surface-variant)" />
            {page.filters.map((f) => (
              <span className="m-label-sm flex items-center gap-1 rounded-lg bg-(--m-sc-lowest) px-2 py-0.5 text-(--m-on-surface) shadow-2xs" data-mtone={f.tone} key={f.key}>
                <span className="text-(--m-on-surface-variant)">{f.key}:</span>
                <span className={cn("font-semibold", f.tone === "neutral" ? "text-(--m-on-surface)" : "text-(--mc)")}>{f.value}</span>
                <button aria-label={`Remove ${f.key} filter`} className="ml-0.5 flex items-center text-(--m-on-surface-variant) hover:text-(--m-error)" type="button">
                  <X aria-hidden className="size-3" />
                </button>
              </span>
            ))}
            <input
              aria-label="Search or filter results"
              className="m-body-sm min-w-36 flex-1 bg-transparent text-(--m-on-surface) placeholder:text-(--m-on-surface-variant) focus:outline-none"
              placeholder="Search or filter results..."
              type="search"
            />
            <button className="m-label-sm rounded px-1.5 py-0.5 text-[11px] text-(--m-on-surface-variant) hover:bg-(--m-sc-highest) hover:text-(--m-on-surface)" type="button">
              Clear all
            </button>
          </div>
          <div className="flex shrink-0 items-center gap-1 self-end lg:self-auto">
            <label className="flex h-9 items-center rounded-lg bg-(--m-sc-low) px-2 py-1.5">
              <ArrowUpDown aria-hidden className="mr-1 size-4 text-(--m-on-surface-variant)" />
              <span className="sr-only">Sort by</span>
              <select className="m-body-sm cursor-pointer bg-transparent pr-1 text-(--m-on-surface) focus:outline-none">
                {page.sort_options.map((o) => <option key={o}>{o}</option>)}
              </select>
            </label>
            <button aria-label="Reverse sort direction" className="flex size-9 items-center justify-center rounded-lg bg-(--m-sc-low) text-(--m-on-surface-variant) transition-colors hover:bg-(--m-sc) hover:text-(--m-on-surface)" type="button">
              <ArrowDown aria-hidden className="size-4.5" />
            </button>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-1 pt-1">
          <span className="m-label-sm mr-1 text-(--m-on-surface-variant)">Quick filters:</span>
          {page.quick_filters.map((q) => (
            <button className="m-label-sm flex items-center gap-1 rounded-lg bg-(--m-sc-low) px-2.5 py-1 text-(--m-on-surface-variant) transition-colors hover:bg-(--m-sc) hover:text-(--m-on-surface)" key={q.label} type="button">
              {q.dot && <span className="size-1.5 rounded-full bg-(--mc)" data-mtone={q.dot} />}
              <span>{q.label}</span>
              <ChevronDown aria-hidden className="size-3.5" />
            </button>
          ))}
        </div>
      </div>
    </>
  );
}
