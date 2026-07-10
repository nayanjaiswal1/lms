"use client";

import * as React from "react";
import { Plus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { CreateBatchForm } from "@/app/(app)/batches/create-batch-form";

// BatchesPanel is the client island hosting the create-batch dialog toggle.
export function BatchesPanel() {
  const [open, setOpen] = React.useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <Plus /> New batch
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New batch</DialogTitle>
        </DialogHeader>
        <CreateBatchForm onCreated={() => setOpen(false)} />
      </DialogContent>
    </Dialog>
  );
}
