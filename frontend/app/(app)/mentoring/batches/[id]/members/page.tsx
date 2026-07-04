import { getBatchMembers } from "@/lib/server/batches";

interface Props {
  params: Promise<{ id: string }>;
}

export default async function MentorBatchMembersPage({ params }: Props) {
  const { id } = await params;
  const members = await getBatchMembers(id).catch(() => []);

  return (
    <div className="flex flex-col gap-6">
      <div className="table-responsive">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-left text-xs text-muted-foreground">
              <th className="pb-2 font-medium">Name</th>
              <th className="pb-2 font-medium">Email</th>
              <th className="pb-2 font-medium">Role</th>
              <th className="pb-2 font-medium">Joined</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {members.map((m) => (
              <tr key={m.user_id}>
                <td className="py-2.5 pr-4 font-medium">{m.name}</td>
                <td className="py-2.5 pr-4 text-muted-foreground">{m.email}</td>
                <td className="py-2.5 pr-4 capitalize text-muted-foreground">{m.role ?? "—"}</td>
                <td className="py-2.5 text-muted-foreground">
                  {m.joined_at ? new Date(m.joined_at).toLocaleDateString() : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {members.length === 0 && (
          <p className="py-4 text-center text-sm text-muted-foreground">No members yet.</p>
        )}
      </div>
    </div>
  );
}
