import { redirect } from "next/navigation";
import { Users } from "lucide-react";
import { getBatchMembers, getBatchMentors, getOrgId, getOrgMembersAll } from "@/lib/server/batches";
import { AddStudentsPanel } from "@/app/(app)/batches/[id]/add-students-panel";
import { AddMentorPanel } from "@/components/batches/add-mentor-panel";
import { PeopleList, type Person } from "@/app/(app)/batches/[id]/people-list";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function BatchPeoplePage({ params }: Props) {
  const { id } = await params;
  const orgId = await getOrgId();

  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [members, mentors, orgMembers] = await Promise.all([
    getBatchMembers(id).catch(() => []),
    getBatchMentors(id).catch(() => []),
    getOrgMembersAll(orgId).catch(() => []),
  ]);

  const people: Person[] = [
    ...members.map((m) => ({ ...m, role: "member" as const })),
    ...mentors.map((m) => ({ ...m, role: "mentor" as const })),
  ].sort((a, b) => a.name.localeCompare(b.name));

  const currentMemberIds = members.map((m) => m.user_id);
  const currentMentorIds = mentors.map((m) => m.user_id);

  return (
    <section className="flex flex-col gap-6">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-2">
          <Users aria-hidden className="h-5 w-5 text-muted-foreground" />
          <h2 className="section-title">People</h2>
        </div>
        <div className="flex items-center gap-2">
          <AddStudentsPanel batchId={id} currentMemberIds={currentMemberIds} orgMembers={orgMembers} />
          <AddMentorPanel batchId={id} currentMentorIds={currentMentorIds} orgMembers={orgMembers} />
        </div>
      </div>

      {people.length === 0 ? (
        <div className="empty-state py-12">
          <Users aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No people yet</p>
          <p className="text-sm text-muted-foreground">
            Use &ldquo;Add students&rdquo; or &ldquo;Add mentor&rdquo; to add people to this batch.
          </p>
        </div>
      ) : (
        <PeopleList batchId={id} people={people} />
      )}
    </section>
  );
}
