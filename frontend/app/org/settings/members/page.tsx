import type { Metadata } from "next";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { getOrgMembers, getOrgInvites } from "@/lib/server/orgs";
import { MemberTable } from "@/app/org/settings/members/member-table";
import { InviteForm } from "@/app/org/settings/members/invite-form";
import { InviteList } from "@/app/org/settings/members/invite-list";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = {
  title: "Members — Organisation Settings",
};

async function getCurrentOrgId(): Promise<string | null> {
  const store = await cookies();
  const token = store.get("access_token")?.value;
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(
      Buffer.from(parts[1], "base64url").toString(),
    ) as { org_id?: string };
    return payload.org_id ?? null;
  } catch {
    return null;
  }
}

export default async function MembersPage() {
  const orgId = await getCurrentOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [memberPage, invitePage] = await Promise.all([
    getOrgMembers(orgId),
    getOrgInvites(orgId),
  ]);

  const pendingCount = invitePage.invites.filter(
    (inv) => inv.accepted_at === null && inv.revoked_at === null,
  ).length;

  return (
    <div className="space-y-8">
      {/* Invite form */}
      <div className="card-base p-6">
        <h2 className="text-lg font-semibold text-foreground mb-4">Invite a Member</h2>
        <InviteForm orgId={orgId} />
      </div>

      {/* Members + Invites — stacked on mobile, side by side on lg */}
      <div className="stack-lg items-start">
        {/* Members table */}
        <section className="flex-1 min-w-0 card-base p-6">
          <div className="flex items-center gap-2 mb-4">
            <h2 className="text-lg font-semibold text-foreground">Members</h2>
            <Badge variant="secondary">{memberPage.members.length}</Badge>
          </div>
          <MemberTable members={memberPage.members} orgId={orgId} />
        </section>

        {/* Pending invites */}
        <section className="flex-1 min-w-0 card-base p-6">
          <div className="flex items-center gap-2 mb-4">
            <h2 className="text-lg font-semibold text-foreground">Pending Invites</h2>
            {pendingCount > 0 && (
              <Badge variant="secondary">{pendingCount}</Badge>
            )}
          </div>
          <InviteList invites={invitePage.invites} orgId={orgId} />
        </section>
      </div>
    </div>
  );
}
