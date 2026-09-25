import Link from "next/link";
import type { LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/button";

export interface DashboardEmptyStateAction {
  href: string;
  label: string;
}

interface DashboardEmptyStateProps {
  icon: LucideIcon;
  message: string;
  action?: DashboardEmptyStateAction;
}

// Single config-driven empty state for dashboard sections — icon, message,
// and an optional CTA, so sections can't drift apart.
export function DashboardEmptyState({ icon: Icon, message, action }: DashboardEmptyStateProps) {
  return (
    <div className="empty-state">
      <Icon aria-hidden className="h-10 w-10 text-muted-foreground" />
      <p className="text-muted-foreground">{message}</p>
      {action && (
        <Button asChild size="sm" variant="outline">
          <Link href={action.href}>{action.label}</Link>
        </Button>
      )}
    </div>
  );
}
