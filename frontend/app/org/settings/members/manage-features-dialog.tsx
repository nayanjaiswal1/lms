"use client";

import { useEffect, useState, useTransition } from "react";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { FEATURE_META, type Feature } from "@/lib/features";
import { apiFetch, API, csrfToken } from "@/lib/client/api";

interface MemberFeatureFlag {
  key: Feature;
  enabled: boolean;
  overridden: boolean;
}

interface Props {
  orgId: string;
  userId: string;
  userName: string;
}

// Opened via the `manageFeatures` URL param (set by the row's "Features"
// button in member-table.tsx), so only one instance needs to be mounted per
// member row — same wiring as ManageRolesDialog in app/(app)/users.
export function ManageFeaturesDialog({ orgId, userId, userName }: Props) {
  const [openId, setOpenId] = useQueryState("manageFeatures");
  const open = openId === userId;

  const [flags, setFlags] = useState<MemberFeatureFlag[] | null>(null);
  const [isPending, startTransition] = useTransition();

  async function load() {
    const data = await apiFetch<{ flags: MemberFeatureFlag[] }>(
      `/orgs/${orgId}/user-features/${userId}`,
    );
    setFlags(data?.flags ?? []);
  }

  useEffect(() => {
    if (open) void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- load() closes over orgId/userId, stable for this row's dialog instance; only `open` toggling should retrigger the fetch
  }, [open]);

  function toggleFlag(key: Feature, next: boolean) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/orgs/${orgId}/user-features/${userId}/${key}`, {
        method: "PATCH",
        credentials: "include",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() },
        body: JSON.stringify({ enabled: next }),
      });
      if (res.ok) {
        toast.success(`${FEATURE_META[key].label} ${next ? "enabled" : "disabled"} for ${userName}.`);
        await load();
      } else {
        const body = await res.json().catch(() => null) as { error?: string } | null;
        toast.error(body?.error ?? "Failed to update feature.");
      }
    });
  }

  function resetFlag(key: Feature) {
    startTransition(async () => {
      const res = await fetch(`${API}/api/orgs/${orgId}/user-features/${userId}/${key}`, {
        method: "DELETE",
        credentials: "include",
        headers: { "X-CSRF-Token": csrfToken() },
      });
      if (res.ok) {
        toast.success(`${FEATURE_META[key].label} reset to default.`);
        await load();
      } else {
        toast.error("Failed to reset feature.");
      }
    });
  }

  return (
    <Dialog open={open} onOpenChange={(next) => void setOpenId(next ? userId : null)}>
      <DialogContent className="modal-responsive overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Manage features — {userName}</DialogTitle>
        </DialogHeader>

        {flags === null ? (
          <div className="space-y-3">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : flags.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            This organisation has no toggleable features enabled.
          </p>
        ) : (
          <div className="divide-y divide-border">
            {flags.map((flag) => {
              const meta = FEATURE_META[flag.key];
              return (
                <div className="flex items-center gap-4 py-3" key={flag.key}>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-foreground">{meta.label}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">{meta.description}</p>
                  </div>
                  {flag.overridden && (
                    <>
                      <Badge variant="secondary">Custom</Badge>
                      <button
                        className="text-xs text-primary hover:underline disabled:opacity-50 disabled:pointer-events-none"
                        disabled={isPending}
                        type="button"
                        onClick={() => resetFlag(flag.key)}
                      >
                        Reset
                      </button>
                    </>
                  )}
                  <Switch
                    aria-label={`Toggle ${meta.label} for ${userName}`}
                    checked={flag.enabled}
                    disabled={isPending}
                    onCheckedChange={(next) => toggleFlag(flag.key, next)}
                  />
                </div>
              );
            })}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
