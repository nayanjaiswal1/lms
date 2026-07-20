"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Checkbox } from "@/components/ui/checkbox";
import { updateModuleProgressAction } from "@/lib/roadmap/actions";

interface ModuleProgressToggleProps {
  roadmapId: string;
  moduleId: string;
  completed: boolean;
  title: string;
}

export function ModuleProgressToggle({ roadmapId, moduleId, completed, title }: ModuleProgressToggleProps) {
  const [pending, setPending] = useState(false);

  async function handleChange(checked: boolean) {
    setPending(true);
    const result = await updateModuleProgressAction(roadmapId, moduleId, checked);
    setPending(false);
    if (!result.ok) toast.error(result.error ?? "Couldn't update progress.");
  }

  return (
    <Checkbox
      aria-label={completed ? `Mark "${title}" incomplete` : `Mark "${title}" complete`}
      checked={completed}
      className="touch-target"
      disabled={pending}
      onCheckedChange={handleChange}
    />
  );
}
