"use client";

import { useState } from "react";
import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { HoverCard, HoverCardContent, HoverCardTrigger } from "@/components/ui/hover-card";
import { Skeleton } from "@/components/ui/skeleton";
import { ProfileAvatar } from "@/components/shared/profile-avatar";
import { useHasAnyPermission } from "@/lib/auth/permissions";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { apiFetch } from "@/lib/client/api";
import ROUTES from "@/lib/routes";

interface UserPreview {
  name: string;
  email: string;
  avatar_url: string | null;
  org_role: string;
  role_names: string[];
  status: string;
  account_status: string;
}

interface Props {
  userId: string;
  className?: string;
  children: React.ReactNode;
}

// Same route the users list/audit log/roster tables link to
// (frontend/app/(app)/users/[id]/page.tsx) — this just previews it on hover
// instead of making every viewer click through to see if it was worth it.
// Gated the same way the destination page is: viewers without the RBAC
// permission just get plain, unlinked text, since the target would 404.
export function UserLink({ userId, className, children }: Props) {
  const canView = useHasAnyPermission([PERMISSIONS.ADMIN.VIEW_MEMBERS, PERMISSIONS.ADMIN.MANAGE_MEMBERS]);
  const [preview, setPreview] = useState<UserPreview | null>(null);
  const [loading, setLoading] = useState(false);

  if (!canView) return <>{children}</>;

  async function load() {
    if (preview || loading) return;
    setLoading(true);
    const data = await apiFetch<UserPreview>(`/admin/rbac/users/${userId}`);
    setPreview(data);
    setLoading(false);
  }

  return (
    <HoverCard closeDelay={100} openDelay={250} onOpenChange={(open) => open && void load()}>
      <HoverCardTrigger asChild>
        <Link className={className} href={ROUTES.userDetail(userId)}>
          {children}
        </Link>
      </HoverCardTrigger>
      <HoverCardContent>
        {loading || !preview ? (
          <div className="flex items-center gap-3">
            <Skeleton className="h-10 w-10 rounded-full" />
            <div className="flex-1 space-y-1.5">
              <Skeleton className="h-3.5 w-24" />
              <Skeleton className="h-3 w-32" />
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-3 min-w-0">
              <ProfileAvatar avatarUrl={preview.avatar_url} name={preview.name} size="sm" />
              <div className="min-w-0">
                <p className="truncate font-medium text-foreground">{preview.name}</p>
                <p className="truncate text-xs text-muted-foreground">{preview.email}</p>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-1.5">
              <Badge variant="outline">{preview.org_role}</Badge>
              {preview.role_names.map((name) => (
                <Badge key={name} variant="secondary">{name}</Badge>
              ))}
              {preview.status !== "active" && <Badge variant="destructive">org: {preview.status}</Badge>}
              {preview.account_status !== "active" && (
                <Badge variant="destructive">account: {preview.account_status}</Badge>
              )}
            </div>
          </div>
        )}
      </HoverCardContent>
    </HoverCard>
  );
}
