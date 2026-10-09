"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { withdrawWorkspaceInterestAction } from "@/lib/workspace/discover-actions";

interface WithdrawInterestButtonProps {
  workspaceId: string;
}

export function WithdrawInterestButton({ workspaceId }: WithdrawInterestButtonProps) {
  const [pending, startTransition] = useTransition();

  function onClick() {
    startTransition(async () => {
      const result = await withdrawWorkspaceInterestAction(workspaceId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Interest withdrawn.");
    });
  }

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={onClick}>
      {pending ? "Withdrawing…" : "Withdraw"}
    </Button>
  );
}
