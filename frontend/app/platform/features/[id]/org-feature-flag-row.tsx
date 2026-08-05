"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { FEATURE_META, type Feature } from "@/lib/features";
import { setOrgFeatureFlagAction, clearOrgFeatureFlagAction } from "@/app/platform/features/[id]/actions";

export interface OrgFeatureFlagData {
  key: Feature;
  enabled: boolean;
  overridden: boolean;
}

interface Props {
  orgId: string;
  flag: OrgFeatureFlagData;
}

export function OrgFeatureFlagRow({ orgId, flag }: Props) {
  const [enabled, setEnabled] = useState(flag.enabled);
  const [overridden, setOverridden] = useState(flag.overridden);
  const [isPending, startTransition] = useTransition();
  const meta = FEATURE_META[flag.key];

  function handleToggle(next: boolean) {
    const prev = enabled;
    setEnabled(next);
    startTransition(async () => {
      const result = await setOrgFeatureFlagAction(orgId, flag.key, next);
      if (result.error) {
        setEnabled(prev);
        toast.error(result.error);
        return;
      }
      setOverridden(true);
      toast.success(`${meta.label} ${next ? "enabled" : "disabled"} for this organisation.`);
    });
  }

  function handleReset() {
    startTransition(async () => {
      const result = await clearOrgFeatureFlagAction(orgId, flag.key);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      setEnabled(true);
      setOverridden(false);
      toast.success(`${meta.label} reset to default.`);
    });
  }

  return (
    <div className="flex items-center gap-4 py-4 border-b border-border last:border-0">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-foreground">{meta.label}</p>
        <p className="text-xs text-muted-foreground mt-0.5">{meta.description}</p>
      </div>
      {overridden && (
        <>
          <Badge variant="secondary">Overridden</Badge>
          <button
            className="text-xs text-primary hover:underline disabled:opacity-50 disabled:pointer-events-none"
            disabled={isPending}
            type="button"
            onClick={handleReset}
          >
            Reset
          </button>
        </>
      )}
      <Switch
        aria-label={`Toggle ${meta.label} for this organisation`}
        checked={enabled}
        disabled={isPending}
        onCheckedChange={handleToggle}
      />
    </div>
  );
}
