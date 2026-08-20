"use client";

import { parseAsString, useQueryState } from "nuqs";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import type { PlanLimit } from "@/lib/server/entitlements";
import { PlanLimitRow } from "./plan-limit-row";

interface EditPlanLimitsDialogProps {
  tierId: string;
  tierName: string;
  limits: PlanLimit[];
}

export function EditPlanLimitsDialog({ tierId, tierName, limits }: EditPlanLimitsDialogProps) {
  const [openId, setOpenId] = useQueryState("edit-limits", parseAsString);
  const isOpen = openId === tierId;

  return (
    <Dialog open={isOpen} onOpenChange={(next) => void setOpenId(next ? tierId : null)}>
      <DialogTrigger asChild>
        <Button size="sm" variant="outline">
          Limits
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive">
        <DialogHeader>
          <DialogTitle>{tierName} limits</DialogTitle>
        </DialogHeader>
        <div className="flex flex-col">
          {limits.map((limit) => (
            <PlanLimitRow key={limit.feature_key} limit={limit} tierId={tierId} />
          ))}
        </div>
      </DialogContent>
    </Dialog>
  );
}
