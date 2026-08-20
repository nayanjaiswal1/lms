"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { FEATURE_META, type Feature } from "@/lib/features";
import type { PlanLimit } from "@/lib/server/entitlements";
import { updatePlanLimitAction } from "./limits-actions";

// lab_sessions_concurrent/lab_hours are quota keys, not FEATURES.* gates —
// FEATURE_META has no entry for them.
const QUOTA_LABELS: Record<string, string> = {
  lab_sessions_concurrent: "Concurrent lab sessions",
  lab_hours: "Lab hours per month",
};

function labelFor(key: string): string {
  return FEATURE_META[key as Feature]?.label ?? QUOTA_LABELS[key] ?? key;
}

interface PlanLimitRowProps {
  tierId: string;
  limit: PlanLimit;
}

export function PlanLimitRow({ tierId, limit }: PlanLimitRowProps) {
  const [isPending, startTransition] = useTransition();
  const [boolValue, setBoolValue] = useState(limit.bool_value ?? false);
  const [numericValue, setNumericValue] = useState(String(limit.numeric_value ?? 0));

  if (limit.kind === "gate") {
    return (
      <div className="flex items-center justify-between gap-4 border-b border-border py-3 last:border-0">
        <p className="text-sm font-medium text-foreground">{labelFor(limit.feature_key)}</p>
        <Switch
          aria-label={`Toggle ${labelFor(limit.feature_key)}`}
          checked={boolValue}
          disabled={isPending}
          onCheckedChange={(next) => {
            const prev = boolValue;
            setBoolValue(next);
            startTransition(async () => {
              const res = await updatePlanLimitAction(tierId, limit.feature_key, { kind: "gate", bool_value: next });
              if (res.error) {
                setBoolValue(prev);
                toast.error(res.error);
                return;
              }
              toast.success(`${labelFor(limit.feature_key)} updated.`);
            });
          }}
        />
      </div>
    );
  }

  return (
    <div className="flex items-center justify-between gap-4 border-b border-border py-3 last:border-0">
      <p className="text-sm font-medium text-foreground">{labelFor(limit.feature_key)}</p>
      <div className="flex items-center gap-2">
        <Input
          className="w-20"
          disabled={isPending}
          min={0}
          type="number"
          value={numericValue}
          onBlur={() => {
            const parsed = Number(numericValue);
            if (!Number.isFinite(parsed) || parsed < 0 || parsed === limit.numeric_value) return;
            startTransition(async () => {
              const res = await updatePlanLimitAction(tierId, limit.feature_key, {
                kind: "quota",
                numeric_value: parsed,
                period: limit.period,
              });
              if (res.error) {
                setNumericValue(String(limit.numeric_value ?? 0));
                toast.error(res.error);
                return;
              }
              toast.success(`${labelFor(limit.feature_key)} updated.`);
            });
          }}
          onChange={(e) => setNumericValue(e.target.value)}
        />
        <span className="text-xs text-muted-foreground">/ {limit.period}</span>
      </div>
    </div>
  );
}
