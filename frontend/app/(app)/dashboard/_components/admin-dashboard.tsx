import Link from "next/link";
import { Suspense } from "react";

import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/shared/page-header";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { getOrgMembersAll } from "@/lib/server/batches";
import { getCurrentOrgId } from "@/lib/server/claims";
import { getOrgInvites } from "@/lib/orgs/server";
import { countPendingInvites } from "@/lib/orgs/pending-invites";
import { getContentReportCounts } from "@/lib/server/content-reports";
import { getLabUsage } from "@/lib/server/lab-usage";
import { containerHours } from "@/lib/labs/usage-format";
import { DashboardSectionHeader } from "./section-header";
import { ListSkeleton, StatTiles, StatTilesSkeleton } from "./stat-tiles";

const ROLE_LABEL: Record<string, string> = {
  owner: "Owners",
  admin: "Admins",
  instructor: "Instructors",
  mentor: "Mentors",
  learner: "Learners",
};
const LAB_WINDOW_DAYS = 30;
const LAB_STUDENT_LIMIT = 50;

async function MemberCounts({ orgId }: { orgId: string }) {
  const members = await getOrgMembersAll(orgId);
  const byRole = new Map<string, number>();
  for (const m of members) byRole.set(m.role, (byRole.get(m.role) ?? 0) + 1);
  const tiles = [{ label: "Members", value: members.length }, ...[...byRole].map(([role, n]) => ({ label: ROLE_LABEL[role] ?? role, value: n }))];
  return <StatTiles tiles={tiles} />;
}

async function PendingInvites({ orgId }: { orgId: string }) {
  const page = await getOrgInvites(orgId).catch(() => null);
  if (!page) return null;
  const pending = { length: countPendingInvites(page.invites) };
  return (
    <StatTiles tiles={[{ label: "Pending invites", value: `${pending.length}${page.next_cursor ? "+" : ""}` }]} />
  );
}

async function ReportsTile() {
  const reports = await getContentReportCounts().catch(() => null);
  if (!reports) return null;
  return <StatTiles tiles={[{ label: "Open reports", value: reports.open, href: ROUTES.ADMIN_CONTENT_REPORTS }]} />;
}

async function LabTiles() {
  const usage = await getLabUsage(LAB_WINDOW_DAYS, LAB_STUDENT_LIMIT).catch(() => null);
  if (!usage) return null;
  return (
    <StatTiles
      tiles={[
        { label: `Lab sessions (${usage.window_days}d)`, value: usage.org.total_sessions, href: ROUTES.ADMIN_LABS_USAGE },
        { label: `Compute hours (${usage.window_days}d)`, value: containerHours(usage.org.total_container_seconds), href: ROUTES.ADMIN_LABS_USAGE },
      ]}
    />
  );
}

export async function AdminDashboard({ firstName, perms }: { firstName: string; perms: readonly string[] }) {
  const orgId = await getCurrentOrgId();
  const can = (code: string) => perms.includes(code);
  return (
    <main className="page-container">
      <PageHeader description="Organization overview." title={`Welcome back, ${firstName}`}>
        <div className="flex flex-wrap gap-2">
          <Button asChild size="sm" variant="outline"><Link href={ROUTES.USERS}>Users</Link></Button>
          {can(PERMISSIONS.ADMIN.MANAGE_ROLES) && (
            <Button asChild size="sm" variant="outline"><Link href={ROUTES.ADMIN_RBAC_ROLES}>Roles</Link></Button>
          )}
          <Button asChild size="sm" variant="outline"><Link href={ROUTES.ORG_SETTINGS}>Org settings</Link></Button>
          {can(PERMISSIONS.MODERATION.MANAGE) && (
            <Button asChild size="sm" variant="outline"><Link href={ROUTES.ADMIN_CONTENT_REPORTS}>Content reports</Link></Button>
          )}
          <Button asChild size="sm" variant="outline"><Link href={ROUTES.ADMIN_LABS_USAGE}>Lab usage</Link></Button>
        </div>
      </PageHeader>
      {orgId && (
        <div className="flex flex-col gap-8">
          <section>
            <DashboardSectionHeader link={{ href: ROUTES.USERS, label: "Manage" }} title="Members" />
            <Suspense fallback={<StatTilesSkeleton />}>
              <MemberCounts orgId={orgId} />
            </Suspense>
          </section>
          <section>
            <DashboardSectionHeader link={{ href: ROUTES.ORG_SETTINGS_INVITES, label: "Invites" }} title="Invitations" />
            <Suspense fallback={<ListSkeleton rows={1} />}>
              <PendingInvites orgId={orgId} />
            </Suspense>
          </section>
          {can(PERMISSIONS.ADMIN.MANAGE_ORG) && (
            <section>
              <DashboardSectionHeader link={{ href: ROUTES.ADMIN_LABS_USAGE, label: "Lab usage" }} title="Labs" />
              <Suspense fallback={<StatTilesSkeleton />}>
                <LabTiles />
              </Suspense>
            </section>
          )}
          {can(PERMISSIONS.MODERATION.MANAGE) && (
            <section>
              <DashboardSectionHeader link={{ href: ROUTES.ADMIN_CONTENT_REPORTS, label: "Review" }} title="Moderation" />
              <Suspense fallback={<StatTilesSkeleton />}>
                <ReportsTile />
              </Suspense>
            </section>
          )}
        </div>
      )}
    </main>
  );
}
