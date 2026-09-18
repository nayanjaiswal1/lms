import { Badge } from "@/components/ui/badge";
import type { CaptureStatus } from "@/lib/server/captures";

const LABELS: Record<CaptureStatus, string> = {
  pending: "Queued",
  processing: "Reading…",
  ready: "Ready to review",
  failed: "Failed",
  promoted: "Saved",
  dismissed: "Dismissed",
};

const VARIANTS: Record<CaptureStatus, "default" | "secondary" | "destructive" | "outline"> = {
  pending: "secondary",
  processing: "secondary",
  ready: "default",
  failed: "destructive",
  promoted: "outline",
  dismissed: "outline",
};

export function CaptureStatusBadge({ status }: { status: CaptureStatus }) {
  return <Badge variant={VARIANTS[status]}>{LABELS[status]}</Badge>;
}
