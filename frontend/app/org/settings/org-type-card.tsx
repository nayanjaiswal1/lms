"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ORG_TYPE_OPTIONS } from "@/lib/constants";
import { updateOrgTypeAction } from "@/app/org/settings/actions";

interface OrgTypeCardProps {
  orgId: string;
  orgType: string | null;
}

export function OrgTypeCard({ orgId, orgType }: OrgTypeCardProps) {
  const [value, setValue] = useState(orgType ?? "");
  const [isPending, startTransition] = useTransition();

  const onSave = () => {
    if (!value) return;
    startTransition(async () => {
      const res = await updateOrgTypeAction(orgId, value);
      if (res.error) {
        toast.error(res.error);
        return;
      }
      toast.success("Organisation type saved.");
    });
  };

  return (
    <div className="card-base p-6">
      <h3 className="text-base font-semibold text-foreground">Organisation Type</h3>
      <p className="text-sm text-muted-foreground mt-0.5 mb-4">
        Changes the wording across the app — e.g. &quot;Teacher&quot; and &quot;Class&quot; for a
        school, &quot;Trainer&quot; and &quot;Team&quot; for a company.
      </p>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
        <div className="flex-1 space-y-1.5">
          <Label htmlFor="org-type">Type</Label>
          <Select onValueChange={setValue} value={value || undefined}>
            <SelectTrigger id="org-type" aria-label="Select organisation type" className="w-full sm:w-64">
              <SelectValue placeholder="Select a type…" />
            </SelectTrigger>
            <SelectContent>
              {ORG_TYPE_OPTIONS.map((opt) => (
                <SelectItem key={opt.value} value={opt.value}>
                  {opt.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <Button disabled={isPending || !value || value === orgType} onClick={onSave} type="button">
          {isPending ? "Saving…" : "Save"}
        </Button>
      </div>
    </div>
  );
}
