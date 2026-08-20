"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import type { PricingTier } from "@/lib/server/pricing";
import { setOrgTierAction } from "./actions";

interface OrgTierSelectorProps {
  orgId: string;
  currentTierId: string;
  tiers: PricingTier[];
}

export function OrgTierSelector({ orgId, currentTierId, tiers }: OrgTierSelectorProps) {
  const [isPending, startTransition] = useTransition();

  return (
    <Select
      disabled={isPending}
      value={currentTierId}
      onValueChange={(tierId) => {
        startTransition(async () => {
          const res = await setOrgTierAction(orgId, tierId);
          if (res.error) {
            toast.error(res.error);
            return;
          }
          toast.success("Plan tier updated.");
        });
      }}
    >
      <SelectTrigger className="w-full sm:w-[220px]">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {tiers.map((tier) => (
          <SelectItem key={tier.id} value={tier.id}>
            {tier.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
