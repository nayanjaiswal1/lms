import type { Metadata } from "next";
import Link from "next/link";
import { PlusCircle } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { InvitationList } from "@/components/workspace/invitation-list";
import { getMyPermissions } from "@/lib/server/permissions";
import { listMyWorkspaceInvitations, listWorkspaces } from "@/lib/workspace/server";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { PROJECT_STATUS_LABEL, PROJECT_STATUS_VARIANT, PROJECT_ROLE_LABEL } from "@/lib/workspace/roles";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Workspaces",
};

export default async function WorkspacesPage() {
  const [permissions, page, invitations] = await Promise.all([
    getMyPermissions(),
    listWorkspaces(undefined, 50),
    listMyWorkspaceInvitations(),
  ]);
  const canCreate = permissions.includes(PERMISSIONS.PROJECTS.CREATE);

  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Workspaces</h1>
          <p className="text-muted-foreground">Corporate-style projects — briefs, teams, tracks, and delivery.</p>
        </div>
        {canCreate && (
          <Button asChild className="gap-2">
            <Link href={ROUTES.WORKSPACES_NEW}>
              <PlusCircle aria-hidden className="h-4 w-4" />
              New workspace
            </Link>
          </Button>
        )}
      </div>

      <InvitationList invitations={invitations} />

      {page.items.length === 0 ? (
        <div className="empty-state">
          <p className="font-medium text-muted-foreground">
            {canCreate ? "No workspaces yet — create one to get started." : "You're not a member of any workspace yet."}
          </p>
        </div>
      ) : (
        <ResponsiveTable className="mt-6">
          <table className="w-full text-sm">
            <thead>
              <tr className="whitespace-nowrap text-left text-xs text-muted-foreground">
                <th className="px-3 py-2">Title</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">My role</th>
                <th className="px-3 py-2">Members</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {page.items.map((workspace) => (
                <tr className="whitespace-nowrap" key={workspace.id}>
                  <td className="min-w-0 px-3 py-2">
                    <Link className="truncate font-medium hover:underline" href={ROUTES.workspace(workspace.id)}>
                      {workspace.title}
                    </Link>
                    <span className="ml-2 text-xs text-muted-foreground">{workspace.key_prefix}</span>
                  </td>
                  <td className="px-3 py-2">
                    <Badge variant={PROJECT_STATUS_VARIANT[workspace.project_status]}>
                      {PROJECT_STATUS_LABEL[workspace.project_status]}
                    </Badge>
                  </td>
                  <td className="px-3 py-2">{workspace.my_role ? PROJECT_ROLE_LABEL[workspace.my_role] : "—"}</td>
                  <td className="px-3 py-2">
                    {workspace.member_count} / {workspace.team_size_max}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </ResponsiveTable>
      )}
    </main>
  );
}
