"use client";

import { useState, useTransition } from "react";
import { Ban, RotateCcw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { disableRoleAction, enableRoleAction } from "@/app/(app)/admin/rbac/roles/actions";

interface Props {
  roleId: string;
  roleName: string;
  isActive: boolean;
}

// Edit already lives on the role name link in role-table.tsx (same base
// destination) — no need for a duplicate "Edit" entry here. Disable/Enable
// are the only distinct actions left, so each is a single icon button, not
// a menu. Disabling loses the role's grants for every assigned member, so
// it's confirmed; re-enabling just restores the prior state, so it isn't.
export function RoleActionsMenu({ roleId, roleName, isActive }: Props) {
  const [isPending, startTransition] = useTransition();
  const [confirmOpen, setConfirmOpen] = useState(false);

  function handleEnable() {
    startTransition(async () => {
      const result = await enableRoleAction(roleId);
      if (result.error) toast.error(result.error);
      else toast.success(`${roleName} enabled.`);
    });
  }

  function handleDisable() {
    startTransition(async () => {
      const result = await disableRoleAction(roleId);
      if (result.error) toast.error(result.error);
      else toast.success(`${roleName} disabled.`);
    });
  }

  if (!isActive) {
    return (
      <Button
        aria-label={`Enable ${roleName}`}
        className="touch-target text-muted-foreground hover:text-foreground"
        disabled={isPending}
        size="sm"
        variant="ghost"
        onClick={handleEnable}
      >
        <RotateCcw aria-hidden className="h-4 w-4" />
      </Button>
    );
  }

  return (
    <>
      <Button
        aria-label={`Disable ${roleName}`}
        className="touch-target text-muted-foreground hover:text-destructive"
        disabled={isPending}
        size="sm"
        variant="ghost"
        onClick={() => setConfirmOpen(true)}
      >
        <Ban aria-hidden className="h-4 w-4" />
      </Button>
      <ConfirmDialog
        destructive
        confirmLabel="Disable"
        description={`Members assigned "${roleName}" will lose the permissions it grants. You can re-enable it later.`}
        open={confirmOpen}
        pending={isPending}
        title={`Disable ${roleName}?`}
        onConfirm={handleDisable}
        onOpenChange={setConfirmOpen}
      />
    </>
  );
}
