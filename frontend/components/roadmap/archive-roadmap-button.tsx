"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Archive, ArchiveRestore } from "lucide-react";
import { Button } from "@/components/ui/button";
import { updateRoadmapAction } from "@/lib/roadmap/actions";

export function ArchiveRoadmapButton({ roadmapId, archived }: { roadmapId: string; archived: boolean }) {
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    const result = await updateRoadmapAction(roadmapId, { status: archived ? "active" : "archived" });
    setPending(false);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't update this roadmap.");
      return;
    }
    toast.success(archived ? "Roadmap reactivated." : "Roadmap archived.");
  }

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={handleClick}>
      {archived ? (
        <ArchiveRestore aria-hidden className="mr-2 h-4 w-4" />
      ) : (
        <Archive aria-hidden className="mr-2 h-4 w-4" />
      )}
      {pending ? "Saving…" : archived ? "Reactivate" : "Archive"}
    </Button>
  );
}
