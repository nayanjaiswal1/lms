import { Badge } from "@/components/ui/badge";
import type { BuildStatus } from "@/lib/labs/builder/types";

const STATUS_UI: Record<BuildStatus, { label: string; className: string }> = {
  queued: { label: "Queued", className: "badge-muted" },
  rendering: { label: "Rendering", className: "badge-info" },
  verifying: { label: "Verifying", className: "badge-info" },
  verified: { label: "Verified", className: "badge-success" },
  failed: { label: "Failed", className: "badge-destructive" },
};

interface BuildStatusBadgeProps {
  status: BuildStatus | null;
}

export function BuildStatusBadge({ status }: BuildStatusBadgeProps) {
  const ui = status ? STATUS_UI[status] : { label: "Not built", className: "badge-muted" };
  return (
    <Badge className={ui.className} variant="outline">
      {ui.label}
    </Badge>
  );
}
