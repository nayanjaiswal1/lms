"use client";

import * as React from "react";
import { Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { CreateBatchForm } from "@/app/(app)/batches/create-batch-form";
import { useTerminology } from "@/lib/terminology-context";

// BatchesPanel is the client island hosting the create-batch dialog toggle.
export function BatchesPanel() {
  const [open, setOpen] = React.useState(false);
  const t = useTerminology();

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <Plus /> New {t.class_.toLowerCase()}
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New {t.class_.toLowerCase()}</DialogTitle>
        </DialogHeader>
        <CreateBatchForm onCreated={() => setOpen(false)} />
      </DialogContent>
    </Dialog>
  );
}
