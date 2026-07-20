"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { startRoadmapAction } from "@/lib/roadmap/actions";
import ROUTES from "@/lib/routes";

export function StartRoadmapButton({ roadmapId }: { roadmapId: string }) {
  const router = useRouter();
  const [pending, setPending] = useState(false);

  async function handleStart() {
    setPending(true);
    const result = await startRoadmapAction(roadmapId);
    setPending(false);
    if (!result.ok || !result.data) {
      toast.error(result.error ?? "Couldn't start this roadmap.");
      return;
    }
    toast.success("Roadmap added to your list.");
    router.push(ROUTES.roadmap(result.data.id));
  }

  return (
    <Button disabled={pending} size="sm" onClick={handleStart}>
      {pending ? "Starting…" : "Start this roadmap"}
    </Button>
  );
}
