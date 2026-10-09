"use client";

import { RefreshCw } from "lucide-react";
import { useTransition } from "react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { reprovisionCohortTeamAction } from "@/lib/workspace/cohort-actions";

interface ReprovisionTeamButtonProps {
  teamId: string;
  cohortId: string;
}

export function ReprovisionTeamButton({ teamId, cohortId }: ReprovisionTeamButtonProps) {
  const [pending, start] = useTransition();

  const run = () =>
    start(async () => {
      const res = await reprovisionCohortTeamAction(teamId, cohortId);
      if (res.error) toast.error(res.error);
      else toast.success("Reprovision queued.");
    });

  return (
    <Button disabled={pending} size="sm" variant="outline" onClick={run}>
      <RefreshCw aria-hidden className="mr-1.5 h-4 w-4" />
      {pending ? "Queuing…" : "Reprovision"}
    </Button>
  );
}
