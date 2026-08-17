"use client";

import { ArrowLeft, History, UserPlus } from "lucide-react";
import { parseAsBoolean, parseAsStringEnum, useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { BulkInviteForm } from "@/app/(app)/users/bulk-invite-form";
import { InviteHistory } from "@/app/(app)/users/invite-history";

type View = "add" | "history";
const VIEWS = ["add", "history"] as const;

interface Props {
  orgId: string;
}

// Same trigger/dialog/view-switching pattern as AddPeoplePanel on the batch
// roster page (app/(app)/batches/[id]/add-people-panel.tsx). That panel also
// lets you pick from existing org members since a batch is a subset of the
// org — but every org member already lives on this page, so here it's just
// invite plus a history view over everything ever sent. One email or fifty
// go through the same bulk-capable form (see bulk-invite-form.tsx) — no
// separate single-invite step, since it was identical work either way.
export function AddPeoplePanel({ orgId }: Props) {
  const [open, setOpen] = useQueryState("add-people", parseAsBoolean.withDefault(false));
  const [view, setView] = useQueryState("people-view", parseAsStringEnum<View>([...VIEWS]).withDefault("add"));

  function handleOpenChange(next: boolean) {
    void setOpen(next);
    if (!next) void setView("add");
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button size="sm">
          <UserPlus aria-hidden className="mr-1.5 h-4 w-4" />
          Add people
        </Button>
      </DialogTrigger>
      <DialogContent className="modal-responsive max-h-[90vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader className="flex-row items-center gap-2 pr-16 space-y-0">
          {view === "history" ? (
            <>
              <Button
                aria-label="Back to add people"
                className="touch-target -ml-2 shrink-0"
                size="icon"
                variant="ghost"
                onClick={() => void setView("add")}
              >
                <ArrowLeft aria-hidden className="h-4 w-4" />
              </Button>
              <DialogTitle>Invite history</DialogTitle>
            </>
          ) : (
            <>
              <DialogTitle className="flex-1">Add people</DialogTitle>
              <Button
                aria-label="View invite history"
                className="touch-target shrink-0"
                size="icon"
                variant="ghost"
                onClick={() => void setView("history")}
              >
                <History aria-hidden className="h-4 w-4" />
              </Button>
            </>
          )}
        </DialogHeader>

        {view === "history" ? <InviteHistory orgId={orgId} /> : <BulkInviteForm orgId={orgId} />}
      </DialogContent>
    </Dialog>
  );
}
