"use client";

import * as React from "react";
import Link from "next/link";
import { UserPlus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { AddStudentsForm, type OrgMember } from "@/app/(app)/batches/[id]/add-students-form";
import ROUTES from "@/lib/routes";

interface AddStudentsPanelProps {
  batchId: string;
  orgMembers: OrgMember[];
  currentMemberIds: string[];
}

export function AddStudentsPanel({ batchId, orgMembers, currentMemberIds }: AddStudentsPanelProps) {
  const [open, setOpen] = React.useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
          Add students
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Add students</DialogTitle>
        </DialogHeader>

        <AddStudentsForm
          batchId={batchId}
          currentMemberIds={currentMemberIds}
          orgMembers={orgMembers}
          onClose={() => setOpen(false)}
        />

        <p className="text-center text-xs text-muted-foreground">
          Adding many at once?{" "}
          <Link className="text-primary hover:underline" href={ROUTES.batchImport(batchId)}>
            Bulk import from Excel
          </Link>
        </p>
      </DialogContent>
    </Dialog>
  );
}
