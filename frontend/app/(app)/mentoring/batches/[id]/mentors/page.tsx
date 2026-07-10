import { redirect } from "next/navigation";
import { GraduationCap } from "lucide-react";
import { getBatchMentors, getOrgId, getOrgMembersAll } from "@/lib/server/batches";
import { AddMentorPanel } from "@/components/batches/add-mentor-panel";
import { RemoveMentorButton } from "@/components/batches/remove-mentor-button";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchMentorsPage({ params }: Props) {
  const { id } = await params;

  const orgId = await getOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [mentors, orgMembers] = await Promise.all([
    getBatchMentors(id).catch(() => []),
    getOrgMembersAll(orgId).catch(() => []),
  ]);

  const currentMentorIds = mentors.map((m) => m.user_id);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-end">
        <AddMentorPanel batchId={id} currentMentorIds={currentMentorIds} orgMembers={orgMembers} />
      </div>

      {mentors.length === 0 ? (
        <div className="empty-state py-12">
          <GraduationCap aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="mt-3 font-medium">No mentors yet</p>
          <p className="text-sm text-muted-foreground">
            Use the &ldquo;Add mentor&rdquo; button to assign a mentor to this batch.
          </p>
        </div>
      ) : (
        <div className="table-responsive">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="pb-2 font-medium">Name</th>
                <th className="pb-2 font-medium">Email</th>
                <th className="pb-2 font-medium">Added</th>
                <th className="pb-2 font-medium sr-only">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {mentors.map((m) => (
                <tr key={m.user_id}>
                  <td className="py-2.5 pr-4 font-medium">{m.name}</td>
                  <td className="py-2.5 pr-4 text-muted-foreground">{m.email}</td>
                  <td className="py-2.5 pr-4 text-muted-foreground">
                    {new Date(m.added_at).toLocaleDateString()}
                  </td>
                  <td className="py-2.5 text-right">
                    <RemoveMentorButton batchId={id} userId={m.user_id} userName={m.name} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
