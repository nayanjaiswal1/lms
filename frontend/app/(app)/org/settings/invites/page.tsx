import type { Metadata } from "next";
import { apiGet } from "@/lib/server/api";
import { InviteManager } from "./invite-manager";

export const metadata: Metadata = { title: "Invite Members — MindForge" };

interface OrgRef {
  id: string;
  name: string;
  role: string;
}

interface MeResponse {
  user: { id: string; name: string; email: string };
  orgs: OrgRef[];
}

interface Invite {
  id: string;
  email: string;
  role: string;
  invited_by: string;
  expires_at: string;
  accepted_at: string | null;
  revoked_at: string | null;
  created_at: string;
}

interface InvitePage {
  invites: Invite[];
  next_cursor: string;
  total: number;
}

interface SearchParams { status?: string; cursor?: string }
interface Props { searchParams: Promise<SearchParams> }

export default async function OrgInvitesPage({ searchParams }: Props) {
  const params = await searchParams;
  const status = params.status ?? "pending";

  const me = await apiGet<MeResponse>("/api/auth/me");

  if (me.orgs.length === 0) {
    return (
      <main className="page-container py-8">
        <div className="empty-state py-16">
          <p className="font-medium">No organization found</p>
          <p className="text-sm text-muted-foreground">
            You are not a member of any organization.
          </p>
        </div>
      </main>
    );
  }

  const activeOrg = me.orgs[0];

  if (activeOrg.role !== "admin" && activeOrg.role !== "owner") {
    return (
      <main className="page-container py-8">
        <div className="empty-state py-16">
          <p className="font-medium">Access denied</p>
          <p className="text-sm text-muted-foreground">
            You need admin or owner access to manage invites.
          </p>
        </div>
      </main>
    );
  }

  const invitePage = await apiGet<InvitePage>(
    `/api/orgs/${activeOrg.id}/invites?status=${status}&limit=50`,
  );

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div>
          <h1 className="page-title">Invite Members</h1>
          <p className="text-muted-foreground mt-1">
            Send invitations and manage pending, accepted, and revoked invites for{" "}
            <span className="font-medium text-foreground">{activeOrg.name}</span>.
          </p>
        </div>
      </div>

      <InviteManager
        orgId={activeOrg.id}
        initialInvites={invitePage.invites}
        initialNextCursor={invitePage.next_cursor}
        currentStatus={status}
      />
    </main>
  );
}
