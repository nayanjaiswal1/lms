"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ClipboardList, Settings, UsersRound } from "lucide-react";

import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

interface Props {
  assessmentId: string;
}

export function AssessmentTabsNav({ assessmentId }: Props) {
  const pathname = usePathname();

  const TABS = [
    { href: ROUTES.assessmentEditBatches(assessmentId), label: "Assign", Icon: UsersRound, exact: false },
    { href: ROUTES.assessmentEdit(assessmentId), label: "Questions", Icon: ClipboardList, exact: true },
    { href: ROUTES.assessmentEditSettings(assessmentId), label: "Test configuration", Icon: Settings, exact: false },
  ] as const;

  return (
    <nav aria-label="Assessment sections" className="mb-8 flex gap-1 border-b border-border">
      {TABS.map(({ href, label, Icon, exact }) => {
        const isActive = exact ? pathname === href : pathname.startsWith(href);
        return (
          <Link
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "flex items-center gap-1.5 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast",
              isActive
                ? "border-primary text-primary"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
            href={href}
            key={href}
          >
            <Icon aria-hidden className="h-4 w-4" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
