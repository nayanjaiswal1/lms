"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { moveBatchToGroupAction } from "@/app/(app)/cohort-groups/actions";
import { cn } from "@/lib/utils";
import type { FlatCohortOption } from "@/lib/server/cohorts";

const UNGROUPED = "__ungrouped__";

interface MoveBatchSelectProps {
  batchId: string;
  batchName: string;
  currentGroupId: string | null;
  options: FlatCohortOption[];
  className?: string;
}

export function MoveBatchSelect({ batchId, batchName, currentGroupId, options, className }: MoveBatchSelectProps) {
  const router = useRouter();

  async function handleChange(value: string) {
    const groupId = value === UNGROUPED ? null : value;
    const res = await moveBatchToGroupAction(batchId, groupId);
    if (res.error) {
      toast.error(res.error);
      return;
    }
    toast.success(`${batchName} moved.`);
    router.refresh();
  }

  return (
    <Select value={currentGroupId ?? UNGROUPED} onValueChange={handleChange}>
      <SelectTrigger aria-label={`Cohort group for ${batchName}`} className={cn("w-full sm:w-[240px]", className)}>
        <SelectValue placeholder="— Ungrouped —" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={UNGROUPED}>— Ungrouped —</SelectItem>
        {options.map((o) => (
          <SelectItem key={o.id} value={o.id}>
            {o.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
