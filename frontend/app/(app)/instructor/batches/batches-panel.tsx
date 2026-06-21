"use client";

import * as React from "react";
import { Plus, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { CreateBatchForm } from "@/app/instructor/batches/create-batch-form";

// BatchesPanel is the client island hosting the create-batch form toggle.
export function BatchesPanel() {
  const [open, setOpen] = React.useState(false);

  if (!open) {
    return (
      <Button onClick={() => setOpen(true)}>
        <Plus /> New batch
      </Button>
    );
  }

  return (
    <div className="card-raised flex w-full max-w-md flex-col gap-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">New batch</h2>
        <Button aria-label="Close" size="icon" variant="ghost" onClick={() => setOpen(false)}>
          <X />
        </Button>
      </div>
      <CreateBatchForm onCreated={() => setOpen(false)} />
    </div>
  );
}
