"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Globe, Lock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { updateRoadmapAction } from "@/lib/roadmap/actions";

export function PublishRoadmapToggle({ roadmapId, isPublic }: { roadmapId: string; isPublic: boolean }) {
  const [pending, setPending] = useState(false);

  async function handleClick() {
    setPending(true);
    const result = await updateRoadmapAction(roadmapId, { is_public: !isPublic });
    setPending(false);
    if (!result.ok) {
      toast.error(result.error ?? "Couldn't update sharing.");
      return;
    }
    toast.success(isPublic ? "Roadmap is now private." : "Roadmap shared to Discover.");
  }

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={handleClick}>
      {isPublic ? <Lock aria-hidden className="mr-2 h-4 w-4" /> : <Globe aria-hidden className="mr-2 h-4 w-4" />}
      {pending ? "Saving…" : isPublic ? "Make private" : "Share to Discover"}
    </Button>
  );
}
