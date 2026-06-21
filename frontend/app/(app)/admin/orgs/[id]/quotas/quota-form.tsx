"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { updateQuotaAction } from "@/app/(app)/admin/orgs/[id]/quotas/actions";
import type { OrgJobStats } from "@/lib/jobs/types";
import type { ActionResult } from "@/lib/server/api";

const PRIORITY_OPTIONS = [
  { value: "1", label: "1 — Critical" },
  { value: "2", label: "2 — High" },
  { value: "3", label: "3 — Normal" },
  { value: "4", label: "4 — Low" },
  { value: "5", label: "5 — Background" },
];

interface Props {
  orgID: string;
  current: OrgJobStats["quota"];
}

const initialState: ActionResult = {};

export function QuotaForm({ orgID, current }: Props) {
  const boundAction = updateQuotaAction.bind(null, orgID);
  const [state, formAction, pending] = useActionState(boundAction, initialState);

  return (
    <form action={formAction} className="form-stack max-w-sm">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="max_concurrent">Max Concurrent Jobs</Label>
        <Input
          id="max_concurrent"
          name="max_concurrent"
          type="number"
          min={1}
          max={50}
          defaultValue={current.max_concurrent}
          required
        />
        <p className="text-xs text-muted-foreground">Range: 1–50</p>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="max_queued">Max Queued Jobs</Label>
        <Input
          id="max_queued"
          name="max_queued"
          type="number"
          min={10}
          max={1000}
          defaultValue={current.max_queued}
          required
        />
        <p className="text-xs text-muted-foreground">Range: 10–1000</p>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="priority_floor">Priority Floor</Label>
        <Select
          name="priority_floor"
          defaultValue={String(current.priority_floor)}
        >
          <SelectTrigger id="priority_floor">
            <SelectValue placeholder="Select priority…" />
          </SelectTrigger>
          <SelectContent>
            {PRIORITY_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <p className="text-xs text-muted-foreground">
          Jobs below this priority will not be accepted.
        </p>
      </div>

      {state.error && (
        <p className="text-sm text-destructive" role="alert">
          {state.error}
        </p>
      )}
      {state.ok && (
        <p className="text-sm text-foreground" role="status">
          Quota updated successfully.
        </p>
      )}

      <Button type="submit" disabled={pending} className="w-full sm:w-auto">
        {pending ? "Saving…" : "Save Quota"}
      </Button>
    </form>
  );
}
