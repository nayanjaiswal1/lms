import Link from "next/link";
import { ArrowDown, ChevronDown, Download, ListChecks, ListFilter, Plus, Rss, ArrowUpDown, RefreshCw, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { AeIssuesPage } from "@/lib/server/gitlab-planning";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

interface IssuesToolbarProps {
  page: AeIssuesPage;
  state: string;
  density: "compact" | "normal";
  bulk: boolean;
}

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
          <h1 className="m-headline-xl tracking-tight text-foreground">Issues</h1>
          <span className="m-label-md rounded-full bg-muted px-2.5 py-0.5 text-primary">{page.open_count_label}</span>
          <span className="m-label-sm flex items-center gap-1 rounded-lg bg-muted px-2 py-0.5 text-muted-foreground">
            <RefreshCw aria-hidden className="size-3.5 text-success" />
            <span>{page.sync_label}</span>
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-1.5">
          <Button size="sm" variant="ghost" type="button">
            <Download aria-hidden className="size-4" />
            <span>Export CSV</span>
          </Button>
          <Button asChild size="sm" variant="ghost">
            <Link aria-pressed={bulk} href={href({ ...keep, bulk: bulk ? "0" : undefined })} scroll={false}>
              <ListChecks aria-hidden className="size-4" />
              <span>Bulk edit</span>
            </Link>
          </Button>
          <Button size="sm" type="button">
            <Plus aria-hidden className="size-4" />
            <span>New issue</span>
          </Button>
        </div>
      </div>

      {/* Status tabs */}
      <div className="flex-between rounded-xl bg-card px-2 shadow-card">
        <nav aria-label="Issue state" className="flex items-center gap-1.5 overflow-x-auto">
          {page.tabs.map((t) => {
            const active = t.key === state;
            return (
              <Link
                aria-current={active ? "page" : undefined}
                className={cn(
                  "m-headline-sm relative flex shrink-0 items-center gap-1 whitespace-nowrap p-2 transition-colors",
                  active ? "text-primary after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-primary" : "text-muted-foreground hover:text-foreground",
                )}
                href={href({ ...keep, state: t.key === "open" ? undefined : t.key })}
                key={t.key}
                scroll={false}
              >
                <span>{t.label}</span>
                <span className={cn("m-label-sm rounded-full px-1.5 text-xs", active ? "bg-(--m-primary-fixed) text-(--m-on-primary-fixed)" : "bg-muted text-muted-foreground")}>
                  {t.count}
                </span>
              </Link>
            );
          })}
        </nav>
        <div className="hidden items-center gap-1 py-1 sm:flex">
          <div className="flex items-center rounded-lg bg-muted p-0.5">
            {(["compact", "normal"] as const).map((d) => (
              <Link
                aria-current={density === d ? "true" : undefined}
                className={cn(
                  "m-label-sm rounded px-2 py-1 capitalize",
                  density === d ? "bg-card text-primary shadow-card" : "text-muted-foreground hover:text-foreground",
                )}
                href={href({ ...keep, density: d === "compact" ? undefined : d })}
                key={d}
                scroll={false}
              >
                {d}
              </Link>
            ))}
          </div>
          <Button aria-label="RSS feed" size="icon" variant="ghost" type="button">
            <Rss aria-hidden className="size-4.5" />
          </Button>
        </div>
      </div>

      {/* Search & filter bar */}
      <div className="flex flex-col gap-1.5 rounded-xl bg-card p-2 shadow-card">
        <div className="flex flex-col items-stretch gap-1.5 lg:flex-row lg:items-center">
          <div className="flex flex-1 flex-wrap items-center gap-1 rounded-lg bg-muted px-2 py-1.5 transition-colors focus-within:bg-muted">
            <ListFilter aria-hidden className="size-4.5 shrink-0 text-muted-foreground" />
            {page.filters.map((f) => (
              <span className="m-label-sm flex items-center gap-1 rounded-lg bg-card px-2 py-0.5 text-foreground shadow-card" data-mtone={f.tone} key={f.key}>
                <span className="text-muted-foreground">{f.key}:</span>
                <span className={cn("font-semibold", f.tone === "neutral" ? "text-foreground" : "text-(--mc)")}>{f.value}</span>
                <Button aria-label={`Remove ${f.key} filter`} className="ml-0.5 h-5 w-5 p-0" size="icon" variant="ghost" type="button">
                  <X aria-hidden className="size-3" />
                </Button>
              </span>
            ))}
            <input
              aria-label="Search or filter results"
              className="m-body-sm min-w-36 flex-1 bg-transparent text-foreground placeholder:text-muted-foreground focus:outline-none"
              placeholder="Search or filter results..."
              type="search"
            />
            <Button className="m-label-sm h-auto px-1.5 py-0.5 text-xs" variant="link" type="button">
              Clear all
            </Button>
          </div>
          <div className="flex shrink-0 items-center gap-1 self-end lg:self-auto">
            <Select defaultValue={page.sort_options[0]}>
              <SelectTrigger aria-label="Sort by" className="h-9 border-0 bg-muted px-2 shadow-none">
                <ArrowUpDown aria-hidden className="mr-1 size-4 text-muted-foreground" />
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {page.sort_options.map((o) => <SelectItem key={o} value={o}>{o}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button aria-label="Reverse sort direction" size="icon" variant="ghost" type="button">
              <ArrowDown aria-hidden className="size-4.5" />
            </Button>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-1 pt-1">
          <span className="m-label-sm mr-1 text-muted-foreground">Quick filters:</span>
          {page.quick_filters.map((q) => (
            <Button className="m-label-sm h-auto px-2.5 py-1" key={q.label} variant="ghost" type="button">
              {q.dot && <span className="size-1.5 rounded-full bg-(--mc)" data-mtone={q.dot} />}
              <span>{q.label}</span>
              <ChevronDown aria-hidden className="size-3.5" />
            </Button>
          ))}
        </div>
      </div>
    </>
  );
}
