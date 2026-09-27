"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Form } from "@/components/ui/form";
import { FormSelectField } from "@/components/ui/form-select-field";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { transferOwnerAction } from "@/lib/workspace/actions";
import type { Member } from "@/lib/workspace/types";

const TransferSchema = z.object({ to_user_id: z.string().min(1, "Pick a manager.") });
type TransferFormData = z.infer<typeof TransferSchema>;

interface TransferOwnerSectionProps {
  workspaceId: string;
  members: Member[];
}

export function TransferOwnerSection({ workspaceId, members }: TransferOwnerSectionProps) {
  const [confirmOpen, setConfirmOpen] = useState(false);
  const managers = members.filter((m) => m.role === "manager" && m.status === "active");
  const form = useForm<TransferFormData>({ resolver: zodResolver(TransferSchema), defaultValues: { to_user_id: "" } });

  async function onConfirm() {
    const result = await transferOwnerAction(workspaceId, form.getValues("to_user_id"));
    setConfirmOpen(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Ownership transferred.");
  }

  if (managers.length === 0) {
    return (
      <div className="card-base flex flex-col gap-2">
        <h2 className="subsection-title">Transfer ownership</h2>
        <p className="text-sm text-muted-foreground">
          Promote a member to manager first — ownership can only transfer to an active manager.
        </p>
      </div>
    );
  }

  return (
    <div className="card-base flex flex-col gap-3">
      <h2 className="subsection-title">Transfer ownership</h2>
      <p className="text-sm text-muted-foreground">You&apos;ll become a manager once transferred. This can&apos;t be undone by you alone.</p>
      <Form {...form}>
        <form className="flex flex-col gap-3 sm:flex-row sm:items-end" onSubmit={form.handleSubmit(() => setConfirmOpen(true))}>
          <div className="flex-1">
            <FormSelectField
              control={form.control}
              label="New owner"
              name="to_user_id"
              options={managers.map((m) => ({ label: m.name, value: m.user_id }))}
            />
          </div>
          <Button type="submit" variant="destructive">Transfer</Button>
        </form>
      </Form>
      <ConfirmDialog
        destructive
        confirmLabel="Transfer ownership"
        description="You will be demoted to manager. This action cannot be undone by you alone."
        open={confirmOpen}
        title="Transfer ownership?"
        onConfirm={onConfirm}
        onOpenChange={setConfirmOpen}
      />
    </div>
  );
}
