"use client";

import { useState } from "react";
import { toast } from "sonner";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { regenerateRoadmapAction } from "@/lib/roadmap/actions";

export function RegenerateRoadmapButton({ roadmapId }: { roadmapId: string }) {
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    const result = await regenerateRoadmapAction(roadmapId);
    setPending(false);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't start regeneration.");
      return;
    }
    toast.success("Regenerating your roadmap…");
  }

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={handleClick}>
      <RefreshCw aria-hidden className="mr-2 h-4 w-4" />
      {pending ? "Starting…" : "Regenerate"}
    </Button>
  );
}
