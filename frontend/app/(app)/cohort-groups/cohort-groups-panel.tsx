"use client";

import * as React from "react";
import { Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { CreateCohortGroupForm } from "@/app/(app)/cohort-groups/create-cohort-group-form";
import type { CohortGroup } from "@/lib/server/cohorts";

interface CohortGroupsPanelProps {
  groups: CohortGroup[];
  presetParentId?: string;
  triggerLabel?: string;
  triggerVariant?: "default" | "outline" | "ghost";
  triggerSize?: "default" | "sm" | "icon";
}

// CohortGroupsPanel is the client island hosting the create-group dialog
// toggle — reused both for the page-level "New group" button and each tree
// node's "+ add child" affordance (via presetParentId).
export function CohortGroupsPanel({
  groups,
  presetParentId,
  triggerLabel = "New group",
  triggerVariant = "default",
  triggerSize = "default",
}: CohortGroupsPanelProps) {
  const [open, setOpen] = React.useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size={triggerSize} variant={triggerVariant}>
          <Plus aria-hidden className="h-4 w-4" />
          {triggerSize !== "icon" && triggerLabel}
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New group</DialogTitle>
        </DialogHeader>
        <CreateCohortGroupForm groups={groups} presetParentId={presetParentId} onCreated={() => setOpen(false)} />
      </DialogContent>
    </Dialog>
  );
}
