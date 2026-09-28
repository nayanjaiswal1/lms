"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Checkbox } from "@/components/ui/checkbox";
import { Label } from "@/components/ui/label";
import { updateModuleLabRequiredAction } from "@/lib/courses/actions";

interface ModuleLabRequiredToggleProps {
  moduleId: string;
  initialRequired: boolean;
}

/** Per-placement Required toggle for a lab module row — course_modules.lab_is_required
 * (migration 044), not the lab's own legacy default. */
export function ModuleLabRequiredToggle({ moduleId, initialRequired }: ModuleLabRequiredToggleProps) {
  const router = useRouter();
  const [required, setRequired] = useState(initialRequired);
  const [isPending, startTransition] = useTransition();

  function handleChange(next: boolean) {
    const prev = required;
    setRequired(next);
    startTransition(async () => {
      const result = await updateModuleLabRequiredAction(moduleId, next);
      if (!result.ok) {
        setRequired(prev);
        toast.error(result.error ?? "Failed to update Required.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex shrink-0 items-center gap-1.5">
      <Checkbox
        checked={required}
        disabled={isPending}
        id={`lab-required-${moduleId}`}
        onCheckedChange={(v) => handleChange(v === true)}
      />
      <Label className="cursor-pointer text-xs font-normal whitespace-nowrap" htmlFor={`lab-required-${moduleId}`}>
        Required
      </Label>
    </div>
  );
}
