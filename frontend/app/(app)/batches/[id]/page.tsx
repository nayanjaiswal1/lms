import { redirect } from "next/navigation";
import { Users } from "lucide-react";
import { getBatchInvitations, getBatchRoster, getOrgId, getOrgMembersAll } from "@/lib/server/batches";
import { getCourses } from "@/lib/server/courses";
import { getImportJobStatusAction } from "@/app/(app)/batches/actions";
import { AddPeoplePanel } from "@/app/(app)/batches/[id]/add-people-panel";
import { BulkImportPanel } from "@/app/(app)/batches/[id]/bulk-import-panel";
import { PeopleList, type Person } from "@/app/(app)/batches/[id]/people-list";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ job?: string }>;
}

export default async function BatchPeoplePage({ params, searchParams }: Props) {
  const { id } = await params;
  const { job: jobId } = await searchParams;
  const orgId = await getOrgId();

  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [roster, orgMembers, invitations, courses, jobStatusResult] = await Promise.all([
    getBatchRoster(id).catch(() => ({ members: [], mentors: [] })),
    getOrgMembersAll(orgId).catch(() => []),
    getBatchInvitations(id).catch(() => []),
    getCourses().catch(() => []),
    jobId ? getImportJobStatusAction(id, jobId) : Promise.resolve(null),
  ]);
  const { members, mentors } = roster;
  const initialJobStatus = jobStatusResult?.data ?? null;

  const people: Person[] = [
    ...members.map((m) => ({ ...m, role: "member" as const })),
    ...mentors.map((m) => ({ ...m, role: "mentor" as const })),
  ].sort((a, b) => a.name.localeCompare(b.name));

  const currentMemberIds = members.map((m) => m.user_id);
  const currentMentorIds = mentors.map((m) => m.user_id);

  const addPeoplePanel = (
    <AddPeoplePanel
      batchId={id}
      currentMemberIds={currentMemberIds}
      currentMentorIds={currentMentorIds}
      invitations={invitations}
      orgMembers={orgMembers}
    />
  );

  return (
    <section className="flex flex-col gap-6">
      {people.length === 0 ? (
        <div className="empty-state py-12">
          <Users aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No people yet</p>
          <p className="text-sm text-muted-foreground">
            Add students or mentors to get started.
          </p>
          {addPeoplePanel}
        </div>
      ) : (
        <PeopleList actions={addPeoplePanel} batchId={id} people={people} />
      )}
      <BulkImportPanel batchId={id} courses={courses} initialJobStatus={initialJobStatus} orgMembers={orgMembers} />
    </section>
  );
}
