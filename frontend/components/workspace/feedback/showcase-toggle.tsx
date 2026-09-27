"use client";

import { useState } from "react";
import { toast } from "sonner";

import { Switch } from "@/components/ui/switch";
import { setShowcaseOptInAction } from "@/lib/workspace/phase5-actions";

interface ShowcaseToggleProps {
  workspaceId: string;
  optedIn: boolean;
}

export function ShowcaseToggle({ workspaceId, optedIn }: ShowcaseToggleProps) {
  const [checked, setChecked] = useState(optedIn);
  const [pending, setPending] = useState(false);

  async function toggle(next: boolean) {
    setChecked(next);
    setPending(true);
    const result = await setShowcaseOptInAction(workspaceId, next);
    setPending(false);
    if (result.error) {
      setChecked(!next);
      toast.error(result.error);
      return;
    }
    toast.success(next ? "Opted in to the showcase." : "Opted out of the showcase.");
  }

  return (
    <div className="flex items-center justify-between gap-3 border-t border-border pt-3">
      <div>
        <p className="text-sm font-medium">Showcase opt-in</p>
        <p className="text-xs text-muted-foreground">Let this project&apos;s outcomes be featured publicly.</p>
      </div>
      <Switch checked={checked} disabled={pending} onCheckedChange={toggle} />
    </div>
  );
}
