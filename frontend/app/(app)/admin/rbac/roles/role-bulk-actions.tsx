"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { BulkActionsBar, type BulkAction } from "@/components/shared/bulk-actions-bar";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { bulkDisableRolesAction, bulkEnableRolesAction } from "@/app/(app)/admin/rbac/roles/actions";

interface Props {
  roles: { id: string; isActive: boolean }[];
  onDone: () => void;
}

// Mirrors role-actions-menu.tsx: a role is either Enable-eligible (disabled)
// or Disable-eligible (active), never both, so a mixed selection can show
// both actions at once, each acting only on its matching subset.
export function RoleBulkActions({ roles, onDone }: Props) {
  const [isPending, startTransition] = useTransition();
  const [confirmOpen, setConfirmOpen] = useState(false);

  const count = roles.length;
  const activeIds = roles.filter((r) => r.isActive).map((r) => r.id);
  const inactiveIds = roles.filter((r) => !r.isActive).map((r) => r.id);

  function handleEnable() {
    startTransition(async () => {
      const result = await bulkEnableRolesAction(inactiveIds);
      if (result.error) toast.error(result.error);
      else toast.success(`${inactiveIds.length} ${inactiveIds.length === 1 ? "role" : "roles"} enabled.`);
      onDone();
    });
  }

  function handleDisable() {
    startTransition(async () => {
      const result = await bulkDisableRolesAction(activeIds);
      if (result.error) toast.error(result.error);
      else toast.success(`${activeIds.length} ${activeIds.length === 1 ? "role" : "roles"} disabled.`);
      setConfirmOpen(false);
      onDone();
    });
  }

  const actions: BulkAction[] = [];
  if (inactiveIds.length > 0) {
    actions.push({ label: `Enable (${inactiveIds.length})`, disabled: isPending, onClick: handleEnable });
  }
  if (activeIds.length > 0) {
    actions.push({
      label: `Disable (${activeIds.length})`,
      disabled: isPending,
      variant: "destructive",
      onClick: () => setConfirmOpen(true),
    });
  }

  return (
    <>
      <BulkActionsBar actions={actions} count={count} onClear={onDone} />
      <ConfirmDialog
        destructive
        confirmLabel="Disable"
        description={`Members assigned any of these ${activeIds.length} ${activeIds.length === 1 ? "role" : "roles"} will lose the permissions they grant. You can re-enable them later.`}
        open={confirmOpen}
        pending={isPending}
        title={`Disable ${activeIds.length} ${activeIds.length === 1 ? "role" : "roles"}?`}
        onConfirm={handleDisable}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
