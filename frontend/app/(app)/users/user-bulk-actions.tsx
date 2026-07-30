"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { BulkActionsBar } from "@/components/shared/bulk-actions-bar";
import { ConfirmDialog } from "@/components/shared/confirm-dialog";
import { useHasPermission } from "@/lib/auth/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { bulkRemoveUsersAction, bulkUpdateUserStatusAction } from "@/app/(app)/users/actions";

interface Props {
  orgId: string;
  memberIds: string[];
  count: number;
  onDone: () => void;
}

type ConfirmAction = "suspend" | "remove";

export function UserBulkActions({ orgId, memberIds, count, onDone }: Props) {
  const canManageMembers = useHasPermission(PERMISSIONS.ADMIN.MANAGE_MEMBERS);
  const [isPending, startTransition] = useTransition();
  const [confirmAction, setConfirmAction] = useState<ConfirmAction | null>(null);

  if (!canManageMembers) return null;

  function runBulk(action: () => Promise<{ error?: string }>, successMessage: string) {
    startTransition(async () => {
      const result = await action();
      if (result.error) toast.error(result.error);
      else toast.success(successMessage);
      setConfirmAction(null);
      onDone();
    });
  }

  function handleActivate() {
    runBulk(
      () => bulkUpdateUserStatusAction(orgId, memberIds, "active"),
      `${count} ${count === 1 ? "user" : "users"} activated.`,
    );
  }

  function handleSuspend() {
    runBulk(
      () => bulkUpdateUserStatusAction(orgId, memberIds, "suspended"),
      `${count} ${count === 1 ? "user" : "users"} suspended.`,
    );
  }

  function handleRemove() {
    runBulk(
      () => bulkRemoveUsersAction(orgId, memberIds),
      `${count} ${count === 1 ? "user" : "users"} removed.`,
    );
  }

  return (
    <>
      <BulkActionsBar
        actions={[
          { label: `Activate (${count})`, disabled: isPending, onClick: handleActivate },
          { label: `Suspend (${count})`, disabled: isPending, onClick: () => setConfirmAction("suspend") },
          {
            label: `Remove (${count})`,
            disabled: isPending,
            variant: "destructive",
            onClick: () => setConfirmAction("remove"),
          },
        ]}
        count={count}
        onClear={onDone}
      />
      <ConfirmDialog
        destructive
        confirmLabel="Suspend"
        description={`${count} ${count === 1 ? "user" : "users"} will lose access to the organization until reactivated.`}
        open={confirmAction === "suspend"}
        pending={isPending}
        title={`Suspend ${count} ${count === 1 ? "user" : "users"}?`}
        onConfirm={handleSuspend}
        onOpenChange={(open) => !open && setConfirmAction(null)}
      />
      <ConfirmDialog
        destructive
        confirmLabel="Remove"
        description={`${count} ${count === 1 ? "user" : "users"} will lose all access to this organization's courses, batches, and content. This can't be undone.`}
        open={confirmAction === "remove"}
        pending={isPending}
        title={`Remove ${count} ${count === 1 ? "user" : "users"} from organization?`}
        onConfirm={handleRemove}
        onOpenChange={(open) => !open && setConfirmAction(null)}
      />
    </>
  );
}
