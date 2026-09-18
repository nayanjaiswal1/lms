import { Inbox } from "lucide-react";

import { CaptureCard } from "@/components/captures/capture-card";
import type { Capture } from "@/lib/server/captures";

export function CaptureList({ captures }: { captures: Capture[] }) {
  if (captures.length === 0) {
    return (
      <div className="empty-state">
        <Inbox aria-hidden className="empty-state-icon" />
        <p className="font-medium text-muted-foreground">Nothing captured yet.</p>
        <p className="text-sm text-muted-foreground">
          Drop in a screenshot, a PDF, or a link above — it&apos;ll be waiting here shortly.
        </p>
      </div>
    );
  }

  return (
    <div className="grid-responsive-2 gap-3">
      {captures.map((capture) => (
        <CaptureCard capture={capture} key={capture.id} />
      ))}
    </div>
  );
}
