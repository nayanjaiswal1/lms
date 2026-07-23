"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { MessageSquare, BookOpen, Users, BarChart3, LineChart, ClipboardList } from "lucide-react";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";

interface Props {
  batchId: string;
  testsLabel: string;
}

export function BatchTabs({ batchId, testsLabel }: Props) {
  const pathname = usePathname();
  const base = ROUTES.batch(batchId);

  const TABS = [
    { href: base, label: "People", Icon: Users, exact: true },
    { href: `${base}/courses`, label: "Courses", Icon: BookOpen, exact: false },
    { href: `${base}/progress`, label: "Progress", Icon: BarChart3, exact: false },
    { href: `${base}/analytics`, label: "Analytics", Icon: LineChart, exact: false },
    { href: `${base}/tests`, label: testsLabel, Icon: ClipboardList, exact: false },
    { href: `${base}/chat`, label: "Chat", Icon: MessageSquare, exact: false },
  ] as const;

  return (
    <nav aria-label="Batch sections" className="mb-6 flex gap-1 border-b border-border overflow-x-auto">
      {TABS.map(({ href, label, Icon, exact }) => {
        const isActive = exact ? pathname === href : pathname.startsWith(href);
        return (
          <Link
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "flex items-center gap-1.5 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast whitespace-nowrap",
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
