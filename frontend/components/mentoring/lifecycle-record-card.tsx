import type { ReactNode } from "react";
import { Badge } from "@/components/ui/badge";
import { formatDateTime } from "@/lib/tickets/format";

interface LifecycleRecordCardProps {
  status: string;
  variant: "default" | "secondary" | "outline" | "destructive";
  timestamp: string;
  children: ReactNode;
}

// Shared card shell (status badge + timestamp header) for any status-driven
// record in a ticket's lifecycle — currently change requests and reports,
// same shape either way.
export function LifecycleRecordCard({ status, variant, timestamp, children }: LifecycleRecordCardProps) {
  return (
    <div className="card-base flex flex-col gap-3 p-4">
      <div className="flex items-center justify-between gap-4">
        <Badge variant={variant}>{status}</Badge>
        <span className="text-xs text-muted-foreground">{formatDateTime(timestamp)}</span>
      </div>
      {children}
    </div>
  );
}
