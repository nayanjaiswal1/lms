import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

export interface DashboardSectionLink {
  href: string;
  label: string;
}

interface DashboardSectionHeaderProps {
  title: string;
  /** "section" for page-level sections, "subsection" for headers inside cards. */
  size?: "section" | "subsection";
  link?: DashboardSectionLink;
}

// Single config-driven header for every dashboard section — title plus an
// optional trailing link, so the markup can't drift between sections.
export function DashboardSectionHeader({ title, size = "section", link }: DashboardSectionHeaderProps) {
  return (
    <div className={cn("flex-between gap-4", size === "section" && "mb-4")}>
      <h2 className={size === "section" ? "section-title" : "subsection-title"}>{title}</h2>
      {link && (
        <Link className="flex items-center gap-1 text-sm text-primary hover:underline" href={link.href}>
          {link.label} <ArrowRight aria-hidden className="h-3.5 w-3.5" />
        </Link>
      )}
    </div>
  );
}
