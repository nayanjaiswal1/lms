"use client";

import * as React from "react";
import { Pencil } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { CreateCohortGroupForm } from "@/app/(app)/cohort-groups/create-cohort-group-form";
import type { CohortGroup } from "@/lib/server/cohorts";

interface EditCohortGroupPanelProps {
  group: CohortGroup;
  groups: CohortGroup[];
}

export function EditCohortGroupPanel({ group, groups }: EditCohortGroupPanelProps) {
  const [open, setOpen] = React.useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button aria-label={`Edit ${group.name}`} size="icon" variant="ghost">
          <Pencil aria-hidden className="h-3.5 w-3.5" />
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit group</DialogTitle>
        </DialogHeader>
        <CreateCohortGroupForm editingGroup={group} groups={groups} onCreated={() => setOpen(false)} />
      </DialogContent>
    </Dialog>
  );
}
