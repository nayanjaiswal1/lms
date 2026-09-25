import type { ReactNode } from "react";
import Link from "next/link";
import { ArrowRight, type LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

interface DashboardUpcomingRowProps {
  icon: LucideIcon;
  title: string;
  subtitle: ReactNode;
  subtitleTone?: "muted" | "destructive";
  /** null renders a dimmed non-interactive row (e.g. an exhausted assessment). */
  href: string | null;
}

// Single config-driven row for the merged Upcoming timeline — assessments and
// calendar events share the icon tile, truncated title, sub-line, and arrow,
// so the two item kinds can't drift apart.
export function DashboardUpcomingRow({
  icon: Icon,
  title,
  subtitle,
  subtitleTone = "muted",
  href,
}: DashboardUpcomingRowProps) {
  const content = (
    <>
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary/10">
        <Icon aria-hidden className="h-4 w-4 text-primary" />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold">{title}</p>
        <p className={cn("text-xs", subtitleTone === "destructive" ? "text-destructive" : "text-muted-foreground")}>
          {subtitle}
        </p>
      </div>
      <span aria-hidden className="flex shrink-0 items-center justify-center text-muted-foreground">
        <ArrowRight className="h-4 w-4" />
      </span>
    </>
  );

  if (!href) {
    return <div className="card-base flex items-center gap-4 p-4 opacity-60">{content}</div>;
  }

  return (
    <Link className="card-interactive flex items-center gap-4 p-4" href={href}>
      {content}
    </Link>
  );
}
