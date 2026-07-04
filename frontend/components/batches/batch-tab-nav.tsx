"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { MessageSquare, BookOpen, Users, BarChart3 } from "lucide-react";
import ROUTES from "@/lib/routes";

interface BatchTabNavProps {
  batchId: string;
}

export function BatchTabNav({ batchId }: BatchTabNavProps) {
  const pathname = usePathname();

  const TABS = [
    { href: ROUTES.mentoringBatchMembers(batchId), label: "Members", Icon: Users },
    { href: ROUTES.mentoringBatchCourses(batchId), label: "Courses", Icon: BookOpen },
    { href: ROUTES.mentoringBatchInvitations(batchId), label: "Invitations", Icon: MessageSquare },
    { href: ROUTES.mentoringBatchProgress(batchId), label: "Progress", Icon: BarChart3 },
  ] as const;

  return (
    <nav className="mb-6 flex gap-1 border-b border-border" aria-label="Batch sections">
      {TABS.map(({ href, label, Icon }) => {
        const isActive = pathname === href;
        return (
          <Link
            key={href}
            href={href}
            className={`flex items-center gap-1.5 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors duration-fast ${
              isActive
                ? "border-primary text-primary"
                : "border-transparent text-muted-foreground hover:text-foreground"
            }`}
            aria-current={isActive ? "page" : undefined}
          >
            <Icon aria-hidden className="h-4 w-4" />
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
