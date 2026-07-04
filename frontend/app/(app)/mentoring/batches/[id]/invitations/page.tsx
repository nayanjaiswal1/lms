import { InvitationList } from "@/components/batches/invitation-list";
import { BulkInviteForm } from "@/components/batches/bulk-invite-form";
import { getBatchInvitations } from "@/lib/server/batches";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchInvitationsPage({ params }: Props) {
  const { id } = await params;
  const invitations = await getBatchInvitations(id).catch(() => []);

  return (
    <div className="flex flex-col gap-8">
      <div>
        <h2 className="section-title mb-4">Invite students</h2>
        <div className="max-w-lg">
          <BulkInviteForm batchId={id} />
        </div>
      </div>
      <div>
        <h2 className="section-title mb-4">Sent invitations</h2>
        <InvitationList invitations={invitations} />
      </div>
    </div>
  );
}
