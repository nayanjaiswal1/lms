import { notFound, redirect } from "next/navigation";
import Link from "next/link";
import { Users } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import {
  getBatch,
  getBatchMembers,
  getOrgId,
  getOrgMembersAll,
} from "@/lib/server/batches";
import { AddMembersPanel } from "@/app/instructor/batches/[id]/add-members-panel";
import { RemoveMemberButton } from "@/app/instructor/batches/[id]/remove-member-button";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const batch = await getBatch(id).catch(() => null);
  return { title: batch ? `${batch.name} — MindForge` : "Batch — MindForge" };
}

export default async function InstructorBatchDetailPage({ params }: Props) {
  const { id } = await params;

  const orgId = await getOrgId();
  if (!orgId) redirect(ROUTES.ORG_SELECT);

  const [batch, members, orgMembers] = await Promise.all([
    getBatch(id).catch(() => null),
    getBatchMembers(id).catch(() => []),
    getOrgMembersAll(orgId).catch(() => []),
  ]);

  if (!batch) notFound();

  const currentMemberIds = members.map((m) => m.user_id);

  return (
    <main className="page-container py-8">
      <div className="page-header">
        <div className="flex items-center gap-3 flex-wrap">
          <Link
            className="text-sm text-muted-foreground hover:text-foreground"
            href={ROUTES.ADMIN_BATCHES}
          >
            Batches
          </Link>
          <span aria-hidden className="text-muted-foreground">/</span>
          <h1 className="page-title">{batch.name}</h1>
          <Badge variant={batch.status === "active" ? "default" : "secondary"}>
            {batch.status}
          </Badge>
        </div>
      </div>

      {batch.description && (
        <p className="mb-8 text-muted-foreground">{batch.description}</p>
      )}

      <section className="flex flex-col gap-6">
        <div className="flex items-center justify-between gap-4 flex-wrap">
          <div className="flex items-center gap-2">
            <Users aria-hidden className="h-5 w-5 text-muted-foreground" />
            <h2 className="section-title">Members</h2>
            <Badge variant="secondary">{members.length}</Badge>
          </div>
          <AddMembersPanel
            batchId={id}
            currentMemberIds={currentMemberIds}
            orgMembers={orgMembers}
          />
        </div>

        {members.length === 0 ? (
          <div className="empty-state py-12">
            <Users aria-hidden className="h-10 w-10 text-muted-foreground" />
            <p className="mt-3 font-medium">No members yet</p>
            <p className="text-sm text-muted-foreground">
              Use the &ldquo;Add members&rdquo; button to add org members to this batch.
            </p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left text-xs text-muted-foreground">
                  <th className="pb-2 font-medium">Name</th>
                  <th className="pb-2 font-medium">Email</th>
                  <th className="pb-2 font-medium sr-only">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {members.map((m) => (
                  <tr key={m.user_id}>
                    <td className="py-2.5 pr-4 font-medium">{m.name}</td>
                    <td className="py-2.5 pr-4 text-muted-foreground">{m.email}</td>
                    <td className="py-2.5 text-right">
                      <RemoveMemberButton
                        batchId={id}
                        userId={m.user_id}
                        userName={m.name}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
